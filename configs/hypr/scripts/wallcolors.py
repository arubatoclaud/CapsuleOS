#!/usr/bin/env python3
"""
Generate the rice colour set from a wallpaper and fan it out to the consumers.
One histogram pass yields both the area-dominant chromatic hue (binned by hue
family so a small vivid accent never hijacks the theme) and the mean lightness.

The palette is DARK-ONLY ("Night Glass"): the mean lightness no longer flips the
pill between a light and a dark scheme, it only picks how far *up* the dark end
the surface ramp sits, so a bright wallpaper yields a lighter dark -- never a
light inversion. The dominant hue tints every tier in HSL; an achromatic
wallpaper drops to a neutral grey ramp.

The accent is split in two. `mark` is the UI-duty accent: chroma capped so it
never screams under text and icons, lightness contrast-clamped against the pill
surface as it actually composites over the wallpaper. `glow` is the filament
colour: the same hue at the full computed saturation (capped so it stays hot but
never neon) at a fixed mid-high lightness, used for light effects rather than
legibility. matugen still builds the dark base16 the always-dark terminal reads;
the pill JSON carries surfaces, both accents and the contrast-matched text.

Usage:
    wallcolors.py <wallpaper-path>
    wallcolors.py --hue <degrees> [mode] [saturation]

`mode` is a legacy dark/light word: it is ACCEPTED AND IGNORED (the palette is
dark-only now), kept only so existing callers keep working unchanged.
"""
import colorsys
import configparser
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

CACHE = Path.home() / ".cache" / "capsuleos"
GTK_THEMES_DIR = Path("/usr/share/themes")
ICON_THEMES_DIR = Path("/usr/share/icons")
# Adwaita / Adwaita-dark ship compiled into GTK itself (no directory under
# /usr/share/themes since GTK 3.20), so they're always available and don't
# need the on-disk probe third-party themes do.
BUILTIN_GTK_THEMES = {"Adwaita", "Adwaita-dark"}
QT_CONFIG_HOMES = {"qt6ct": Path.home() / ".config" / "qt6ct",
                    "qt5ct": Path.home() / ".config" / "qt5ct"}
# QPalette::ColorRole declaration order (Qt6, pre-6.6 Accent role) used by
# qt6ct/qt5ct's [ColorScheme] active_colors/inactive_colors/disabled_colors
# lists: 21 comma-separated #AARRGGBB values in enum order. Window/Base come
# from the surface ramp, WindowText/Text/ButtonText from the text ramp,
# Highlight/Link from the accent.
QT_ROLE_KEYS = [
    "cream",                     # 0  WindowText
    "surface_container_high",    # 1  Button
    "surface",                   # 2  Light
    "surface_container_low",     # 3  Midlight
    "surface_container_highest", # 4  Dark
    "surface_container",         # 5  Mid
    "cream",                     # 6  Text
    "bright",                    # 7  BrightText
    "cream",                     # 8  ButtonText
    "surface",                   # 9  Base
    "surface_container",         # 10 Window
    "outline",                   # 11 Shadow
    "primary",                   # 12 Highlight
    "surface",                   # 13 HighlightedText
    "primary",                   # 14 Link
    "primary_container",         # 15 LinkVisited
    "surface_container_low",     # 16 AlternateBase
    "surface_container",         # 17 NoRole (reserved, unused by Qt itself)
    "surface_container_high",    # 18 ToolTipBase
    "cream",                     # 19 ToolTipText
    "faint",                     # 20 PlaceholderText
]

SURF_NAMES = ["surface", "surface_container_low", "surface_container",
              "surface_container_high", "surface_container_highest", "outline_variant"]
DARK_STEPS = [0.0, 0.022, 0.038, 0.065, 0.100, 0.225]
TEXT_KEYS = ["cream", "bright", "subtle", "dim", "faint", "icon_dim", "tick_rest"]
DARK_TEXT = [(0.90, 0.05), (0.97, 0.03), (0.73, 0.07), (0.54, 0.06),
             (0.44, 0.05), (0.81, 0.07), (0.75, 0.08)]

# Night Glass surface depth: the base lightness the DARK_STEPS ramp is built on.
# A pitch-black wallpaper bottoms out at DEPTH_MIN, anything at or above
# DEPTH_PIVOT mean lightness tops out at DEPTH_MAX -- a lighter dark, still dark.
DEPTH_MIN, DEPTH_MAX, DEPTH_PIVOT = 0.06, 0.16, 0.85
# Accent split. mark does UI duty (text, icons, controls) so its chroma is held
# down and its lightness is contrast-clamped; glow is a light effect, so it only
# gets the "hot but never neon" chroma ceiling and a fixed lightness.
MARK_SAT_CAP = 0.55
MARK_CONTRAST = 4.5
GLOW_SAT_CAP = 0.90
GLOW_L = 0.62
# The pill body renders translucent over the wallpaper (Theme.qml surfAlpha,
# frost default 0.86), so the accent is clamped against the surface as it
# actually composites, not against the flat surface swatch. The MARK_CONTRAST
# contract is therefore stated against the *frost* composite: it holds exactly
# on frost and with margin on ink (alpha 1.0), while glass lets more wallpaper
# through and trades legibility for translucency by design. The pipeline cannot
# see the runtime material flag, so guarding glass is the renderer's job, not
# this file's -- and the renderer no longer guards it either: glass now
# composites at the user's own window-background opacity (Theme.glassAlpha), so
# on glass the MARK_CONTRAST guarantee is user-governed and thinner glass is an
# explicit choice, not a palette failure.
SURF_ALPHA = 0.86


def analyze(wallpaper):
    out = subprocess.run(
        ["magick", wallpaper, "-alpha", "off", "-resize", "200x200", "-colors", "48",
         "-depth", "8", "-format", "%c", "histogram:info:-"],
        capture_output=True, text=True).stdout
    buckets, total, lum, chroma = {}, 0, 0.0, 0
    for line in out.splitlines():
        m = re.search(r"\s*(\d+):\s*\([^)]*\)\s*#([0-9A-Fa-f]{6,16})", line)
        if not m:
            continue
        count, hex_str = int(m.group(1)), m.group(2)
        if len(hex_str) > 6:
            # Q16/HDRI builds print 16-bit (and alpha) components; keep the
            # high byte of each of the first three so #RRRRGGGGBBBB -> #RRGGBB
            step = len(hex_str) // (4 if len(hex_str) % 3 else 3)
            hex_str = "".join(hex_str[i:i + 2] for i in range(0, 3 * step, step))
        r, g, b = (int(hex_str[i:i + 2], 16) / 255 for i in (0, 2, 4))
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        total += count
        lum += count * l
        if s < 0.15 or l < 0.05 or l > 0.92:
            continue
        chroma += count
        bucket = buckets.setdefault((int(h * 360) // 30) % 12, {"wsat": 0.0, "best": None})
        bucket["wsat"] += count * s
        score = count * s * (1 if 0.12 < l < 0.55 else 0.4)
        if not bucket["best"] or score > bucket["best"][0]:
            bucket["best"] = (score, h, s)
    mean_l = lum / total if total else 0.0
    if not buckets or chroma < 0.08 * total:
        return None, 0.0, mean_l
    win = max(buckets.values(), key=lambda v: v["wsat"])
    return win["best"][1], win["best"][2], mean_l


def matugen(source_hex):
    out = subprocess.run(
        ["matugen", "color", "hex", source_hex, "-m", "dark", "-j", "hex"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(out.stdout)


def tint(hue, sat, light):
    r, g, b = colorsys.hls_to_rgb(hue % 1.0, max(0.0, min(1.0, light)), max(0.0, min(1.0, sat)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def _linearize(c8):
    c = c8 / 255.0
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def rel_luminance(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return 0.2126 * _linearize(r) + 0.7152 * _linearize(g) + 0.0722 * _linearize(b)


def contrast_ratio(hex_a, hex_b):
    la, lb = rel_luminance(hex_a), rel_luminance(hex_b)
    lighter, darker = max(la, lb), min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)


def alpha_composite(fg_hex, bg_hex, alpha):
    fr, fgc, fb = (int(fg_hex[i:i + 2], 16) for i in (1, 3, 5))
    br, bgc, bb = (int(bg_hex[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % (
        round(fr * alpha + br * (1 - alpha)),
        round(fgc * alpha + bgc * (1 - alpha)),
        round(fb * alpha + bb * (1 - alpha)),
    )


def clamp_light(hex_color, target, bg_hex):
    """
    Smallest lightness >= the input's whose tint meets `target` WCAG contrast
    against `bg_hex`; hue/sat are held fixed so only lightness moves, and the
    result is never darker than the input (a lift, never a floor). This is the
    right direction whenever the colour sits ABOVE its background, which in a
    dark-only palette is always: the terminal's ANSI foregrounds over base00,
    and the accent over the pill surface.

    Best-effort escape: if even white falls short of `target` it returns white,
    so the caller ships a sub-target colour. Unreachable at SURF_ALPHA = 0.86.
    """
    if contrast_ratio(hex_color, bg_hex) >= target:
        return hex_color
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if contrast_ratio(tint(h, s, 1.0), bg_hex) < target:
        return tint(h, s, 1.0)  # best effort: even white falls short of target
    lo, hi = l, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if contrast_ratio(tint(h, s, mid), bg_hex) >= target:
            hi = mid
        else:
            lo = mid
    return tint(h, s, hi)


# Minimum WCAG contrast for each terminal palette slot against the terminal
# background. base16 maps 1-6 to a bg->fg ramp, but terminal programs use
# those slots as *foreground* text (ANSI 31-36), so the low steps must stay
# legible; the graduated targets keep the ramp monotone instead of bunching
# every step at one floor. Accents (8-15) just get a readability floor.
ANSI_CONTRAST_FLOOR = {1: 3.0, 2: 3.4, 3: 3.8, 4: 4.3, 5: 4.9, 6: 5.6}
ANSI_CONTRAST_FLOOR.update({i: 3.0 for i in range(8, 16)})


def render_fastfetch(pill):
    """
    Recolour the fastfetch readout from the same pill palette. fastfetch has no
    daemon, so writing the rendered config is enough, the next run picks it up.
    The accent drives the keys and the bridge cables, the surface ramp the bridge body,
    and a dim text tone the section rules, so it tracks the wallpaper like the
    pill and terminal do.
    """
    ff = Path.home() / ".config" / "fastfetch"
    tmpl = ff / "config.jsonc.in"
    if not tmpl.is_file():
        print("wallcolors: config.jsonc.in missing in ~/.config/fastfetch, skipping "
              "fastfetch recolour (apply the CapsuleOS update or re-run the installer)",
              file=sys.stderr)
        return
    seq = lambda h: "%d;%d;%d" % tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
    repl = {
        "__GOLDENGATE__": str(ff / "goldengate.txt"),
        "__KEYS__": seq(pill["primary"]),
        "__SEP__": seq(pill["dim"]),
        "__LOGO1__": seq(pill["primary"]),
        "__LOGO2__": seq(pill["on_primary_container"]),
        "__LOGO3__": seq(pill["surface_container"]),
        "__LOGO4__": seq(pill["surface_container_high"]),
        "__LOGO5__": seq(pill["subtle"]),
        "__LOGO6__": seq(pill["outline"]),
        "__LOGO7__": seq(pill["bright"]),
    }
    out = tmpl.read_text()
    for key, val in repl.items():
        out = out.replace(key, val)
    (ff / "config.jsonc").write_text(out)


def _gtk_theme_exists(name):
    return name in BUILTIN_GTK_THEMES or (GTK_THEMES_DIR / name).is_dir()


def _icon_theme_exists(name):
    return (ICON_THEMES_DIR / name).is_dir()


def write_gtk(pill):
    """
    Fan the palette out to GTK3/GTK4 settings.ini plus live gsettings, so
    GTK apps (and libadwaita ones, which ignore settings.ini) sit on the same
    dark scheme the pill does. Only themes actually present on disk are referenced,
    a probe miss just drops that line instead of pointing GTK at a name that
    won't resolve, and each gsettings call is independent so a missing
    schema on one key never blocks the rest.
    """
    # Night Glass is dark-only; there is no light palette to track.

    gtk_theme = "Adwaita-dark"
    if not _gtk_theme_exists(gtk_theme):
        gtk_theme = None

    icon_theme = "Papirus-Dark"
    if not _icon_theme_exists(icon_theme):
        icon_theme = "Papirus" if _icon_theme_exists("Papirus") else None

    cursor_theme = "Bibata-Modern-Ice" if _icon_theme_exists("Bibata-Modern-Ice") else None

    lines = ["[Settings]", "gtk-application-prefer-dark-theme=1"]
    if gtk_theme:
        lines.append(f"gtk-theme-name={gtk_theme}")
    if icon_theme:
        lines.append(f"gtk-icon-theme-name={icon_theme}")
    if cursor_theme:
        lines.append(f"gtk-cursor-theme-name={cursor_theme}")
    settings_ini = "\n".join(lines) + "\n"

    for ver in ("gtk-3.0", "gtk-4.0"):
        target_dir = Path.home() / ".config" / ver
        target_dir.mkdir(parents=True, exist_ok=True)
        (target_dir / "settings.ini").write_text(settings_ini)

    def _gset(key, value):
        try:
            subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, value],
                            capture_output=True, check=True)
        except (OSError, subprocess.SubprocessError):
            pass

    if gtk_theme:
        _gset("gtk-theme", gtk_theme)
    if icon_theme:
        _gset("icon-theme", icon_theme)
    if cursor_theme:
        _gset("cursor-theme", cursor_theme)
    _gset("color-scheme", "prefer-dark")


def _argb(hex6):
    """#RRGGBB -> #AARRGGBB (opaque) for qt6ct/qt5ct's ARGB scheme format."""
    return "#ff" + hex6[1:]


def _qt_color_list(pill, dim_text=False):
    keys = QT_ROLE_KEYS
    if dim_text:
        # Disabled state: mute the text-bearing roles a step so widgets read
        # as inactive without hand-deriving a whole second palette.
        dim_map = {"cream": "dim", "bright": "subtle"}
        keys = [dim_map.get(k, k) for k in keys]
    return ", ".join(_argb(pill[k]) for k in keys)


def write_qtct(pill):
    """
    Point qt6ct/qt5ct at a generated color scheme so Qt apps (dolphin,
    kdialog, ...) pick up the palette too. Only runs for a *ct tool that's
    actually installed, since QT_QPA_PLATFORMTHEME only takes effect when
    its target config tool is present; generating for an absent one would be
    dead weight nobody reads.
    """
    for name, home in QT_CONFIG_HOMES.items():
        if shutil.which(name) is None:
            continue
        colors_dir = home / "colors"
        colors_dir.mkdir(parents=True, exist_ok=True)
        scheme_path = colors_dir / "capsuleos.conf"
        active = _qt_color_list(pill)
        disabled = _qt_color_list(pill, dim_text=True)
        scheme_path.write_text(
            "[ColorScheme]\n"
            f"active_colors={active}\n"
            f"inactive_colors={active}\n"
            f"disabled_colors={disabled}\n"
        )

        conf_path = home / f"{name}.conf"
        cfg = configparser.ConfigParser()
        cfg.optionxform = str
        if conf_path.is_file():
            cfg.read(conf_path)
        if not cfg.has_section("Appearance"):
            cfg.add_section("Appearance")
        cfg.set("Appearance", "custom_palette", "true")
        cfg.set("Appearance", "color_scheme_path", str(scheme_path))
        with conf_path.open("w") as f:
            cfg.write(f)


def main():
    if len(sys.argv) < 2:
        print("usage: wallcolors.py <wallpaper-path>\n"
              "       wallcolors.py --hue <degrees> [mode] [saturation]\n"
              "  mode: legacy dark/light word, accepted and IGNORED "
              "(the palette is dark-only)", file=sys.stderr)
        return 1
    if sys.argv[1] == "--hue":
        hue = (float(sys.argv[2]) % 360) / 360.0
        # sys.argv[3] is the legacy dark/light mode word. It is accepted and
        # ignored: Night Glass has no light palette, but callers still pass it,
        # so dropping the slot would shift the saturation argument.
        sat = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
        sat = max(0.0, min(1.0, sat))
        mean_l = 0.12
        chromatic = sat > 0.02
    else:
        wallpaper = sys.argv[1]
        if not Path(wallpaper).is_file():
            return 0
        hue, sat, mean_l = analyze(wallpaper)
        chromatic = hue is not None
        if not chromatic:
            hue, sat = 0.09, 0.0
    CACHE.mkdir(parents=True, exist_ok=True)

    # Dark-only depth: mean lightness picks where in the dark end the ramp
    # starts, so a bright wallpaper lifts the surface without inverting it.
    base = DEPTH_MIN + (DEPTH_MAX - DEPTH_MIN) * min(mean_l, DEPTH_PIVOT) / DEPTH_PIVOT
    surf_sat = min(max(sat, 0.30 if chromatic else 0.0), 0.45)
    acc_sat = min(max(sat, 0.30) + 0.12, 0.82) if chromatic else 0.05
    acc_l, deep_l, on_container_l = 0.70, 0.34, 0.86

    pill = {name: tint(hue, surf_sat, base + step) for name, step in zip(SURF_NAMES, DARK_STEPS)}
    pill["primary_container"] = tint(hue, min(acc_sat + 0.08, 0.9), deep_l)
    pill["on_primary_container"] = tint(hue, min(acc_sat, 0.45), on_container_l)
    pill["outline"] = tint(hue, surf_sat, base + 0.35)
    for key, (lit, st) in zip(TEXT_KEYS, DARK_TEXT):
        pill[key] = tint(hue, st, lit)

    # Accent split. Both tiers share the winning hue; what differs is their job.
    # The clamp reference is the pill card as it actually composites over the
    # wallpaper, not the flat swatch, so a bright wall can't quietly eat the
    # accent's contrast.
    wall_mean = tint(hue, sat, mean_l)
    eff_surface = alpha_composite(pill["surface_container_high"], wall_mean, SURF_ALPHA)

    # mark: UI duty. Chroma capped so it stays a mark and not a highlighter,
    # then lifted until it clears MARK_CONTRAST against eff_surface. The lift is
    # the only correct direction here: the palette is dark-only, so the accent
    # always sits ABOVE its background, contrast grows with lightness, and
    # darkening (clamp_dark) would walk away from the target -- on a bright
    # wallpaper it bottoms out at its near-black best-effort branch. clamp_light
    # no-ops when acc_l already passes, so this one call covers both cases.
    mark_sat = min(acc_sat, MARK_SAT_CAP)
    mark = clamp_light(tint(hue, mark_sat, acc_l), MARK_CONTRAST, eff_surface)

    # glow: filament light, never text. It rides the same saturation ramp as the
    # accent but under its own, higher ceiling -- hot, but never neon -- at a
    # fixed mid-high lightness so effects that stack it (gradients, bloom) start
    # from a predictable place. Deliberately NOT derived from acc_sat: that
    # would re-impose the accent's 0.82 and make GLOW_SAT_CAP decorative. The
    # achromatic branch is carried over verbatim so a greyscale wallpaper still
    # gets a grey glow instead of an invented hue.
    glow_sat = min(max(sat, 0.30) + 0.12, GLOW_SAT_CAP) if chromatic else 0.05
    glow = tint(hue, glow_sat, GLOW_L)

    pill["mark"] = mark
    pill["glow"] = glow
    # primary is the field every current consumer renders; it tracks mark until
    # the QML side is rewired onto the split.
    pill["primary"] = mark
    pill["light"] = False

    (CACHE / "colors.json").write_text(json.dumps(pill, indent=2) + "\n")
    render_fastfetch(pill)

    try:
        write_gtk(pill)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        print(f"wallcolors: GTK theme fan-out failed ({exc}), skipping", file=sys.stderr)

    try:
        write_qtct(pill)
    except (OSError, ValueError, KeyError, configparser.Error) as exc:
        print(f"wallcolors: Qt theme fan-out failed ({exc}), skipping", file=sys.stderr)

    try:
        b = {k: v["dark"]["color"] for k, v in
             matugen(tint(hue, sat, 0.45) if chromatic else "#787878")["base16"].items()}
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        return 0

    (CACHE / "hypr-colors.lua").write_text(
        'return {\n    active = "%s",\n    inactive = "%s",\n}\n'
        % (pill["primary"], b["base01"]))

    lines = [
        f'background = {b["base00"]}',
        f'foreground = {b["base07"]}',
        f'cursor-color = {pill["primary"]}',
        f'selection-background = {b["base02"]}',
        f'selection-foreground = {b["base07"]}',
    ]
    # Contrast-floor the foreground-role slots only; the background /
    # selection lines above keep the untouched darks so the theme stays dark.
    for i in range(16):
        color = b["base%02x" % i]
        if i in ANSI_CONTRAST_FLOOR:
            color = clamp_light(color, ANSI_CONTRAST_FLOOR[i], b["base00"])
        lines.append(f'palette = {i}={color}')
    # Atomic swap: a ghostty reload signal can land mid-write, and a truncated
    # read fails its whole config load (surfaces as a font-init notification).
    tmp = CACHE / "ghostty-colors.tmp"
    tmp.write_text("\n".join(lines) + "\n")
    tmp.replace(CACHE / "ghostty-colors")
    return 0


if __name__ == "__main__":
    sys.exit(main())
