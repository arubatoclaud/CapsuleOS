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
GLOW_SAT_CAP = 0.60
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
    share = chroma / total if total else 0.0
    out_bins = {}
    if chroma:
        for idx, bk in buckets.items():
            if bk["best"]:
                out_bins[idx] = {"weight": bk["wsat"] / sum(v["wsat"] for v in buckets.values()),
                                 "hue": bk["best"][1] * 360.0,
                                 "sat": bk["best"][2]}
    if not buckets or chroma < 0.08 * total:
        return None, 0.0, mean_l, {}, share
    win = max(buckets.values(), key=lambda v: v["wsat"])
    return win["best"][1], win["best"][2], mean_l, out_bins, share


def matugen(source_hex):
    out = subprocess.run(
        ["matugen", "color", "hex", source_hex, "-m", "dark", "-j", "hex"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(out.stdout)


def tint(hue, sat, light):
    r, g, b = colorsys.hls_to_rgb(hue % 1.0, max(0.0, min(1.0, light)), max(0.0, min(1.0, sat)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def tint_deg(h_deg, s, l):
    return tint((h_deg % 360.0) / 360.0, s, l)


def signed_arc(a_deg, b_deg):
    """Signed shortest arc a->b in (-180, 180]."""
    d = (b_deg - a_deg) % 360.0
    return d - 360.0 if d > 180.0 else d


def circ_clamp(h_deg, lo_deg, hi_deg):
    """Clamp onto the circular interval lo->hi (walking clockwise lo..hi)."""
    if (h_deg - lo_deg) % 360.0 <= (hi_deg - lo_deg) % 360.0:
        return h_deg % 360.0
    # outside: snap to the nearer endpoint by circular distance
    if abs(signed_arc(h_deg, lo_deg)) <= abs(signed_arc(h_deg, hi_deg)):
        return lo_deg % 360.0
    return hi_deg % 360.0


def hue_luminance(h_deg):
    """Intrinsic luminance of a hue at the spec's fixed reference (s=0.6, l=0.5)."""
    return rel_luminance(tint_deg(h_deg, 0.6, 0.5))


COMPANION_MIN, COMPANION_MAX, COMPANION_OFFSET = 15.0, 45.0, 25.0
SNAP_BIN_WEIGHT, SNAP_CHROMA_SHARE = 0.08, 0.15
ROLE_DEAD_ZONE = 0.03
YELLOW_ZONE, CHARTREUSE_TROUGH, WARM_EDGE = (50.0, 95.0), (70.0, 110.0), 69.0


def derive_trio(dominant_deg, bins, chroma_share):
    """Depth/dominant/glow hues (degrees). bins: {i: {weight, hue, sat}},
    weight as a fraction of chromatic weight."""
    def companion(side):  # side: -1 (counter-clockwise) or +1
        if chroma_share >= SNAP_CHROMA_SHARE:
            best = None
            for b in bins.values():
                d = signed_arc(dominant_deg, b["hue"]) * side
                if COMPANION_MIN <= d <= COMPANION_MAX and b["weight"] >= SNAP_BIN_WEIGHT:
                    if best is None or b["weight"] > best["weight"]:
                        best = b
            if best:
                return best["hue"] % 360.0
        return (dominant_deg + COMPANION_OFFSET * side) % 360.0

    ccw, cw = companion(-1), companion(+1)
    if abs(hue_luminance(ccw) - hue_luminance(cw)) < ROLE_DEAD_ZONE:
        depth, glow = ccw, cw            # convention: H- companion is depth
    elif hue_luminance(ccw) < hue_luminance(cw):
        depth, glow = ccw, cw
    else:
        depth, glow = cw, ccw
    if YELLOW_ZONE[0] <= dominant_deg % 360.0 <= YELLOW_ZONE[1] \
            and CHARTREUSE_TROUGH[0] < glow < CHARTREUSE_TROUGH[1]:
        glow = WARM_EDGE                 # bias warm, out of the olive trough
    return {"depth": depth, "dominant": dominant_deg % 360.0, "glow": glow}


VOICE_CONTRAST, VOICE_WIDTH = 4.5, 0.05
LIGHT_CONTRAST, LIGHT_WIDTH = 6.0, 0.06
GREEN_ZONE, GREEN_ZONE_PENALTY = (90.0, 200.0), 0.15
RAMP_LO, RAMP_HI = 0.08, 0.20


def band(target_contrast, base00_hex, width):
    y = target_contrast * (rel_luminance(base00_hex) + 0.05) - 0.05
    return (y, y + width)


def voice_band(base00_hex):
    return band(VOICE_CONTRAST, base00_hex, VOICE_WIDTH)


def light_band(base00_hex):
    return band(LIGHT_CONTRAST, base00_hex, LIGHT_WIDTH)


def snap_to_band(hex_color, band_tuple):
    lo, hi = band_tuple
    if lo <= rel_luminance(hex_color) <= hi:
        return hex_color
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    target = (lo + hi) / 2
    lo_l, hi_l = 0.0, 1.0            # Y is monotone in HSL lightness at fixed h,s
    for _ in range(40):
        mid = (lo_l + hi_l) / 2
        if rel_luminance(tint(h, s, mid)) < target:
            lo_l = mid
        else:
            hi_l = mid
    return tint(h, s, hi_l)


def sat_cap(h_deg, base_cap):
    h = h_deg % 360.0
    if GREEN_ZONE[0] <= h <= GREEN_ZONE[1]:
        return max(0.05, base_cap - GREEN_ZONE_PENALTY)
    return base_cap


def chroma_ramp(share):
    if share <= RAMP_LO:
        return 0.0
    if share >= RAMP_HI:
        return 1.0
    return (share - RAMP_LO) / (RAMP_HI - RAMP_LO)


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


ACC_SAT_CAP = 0.65          # was inline 0.82

SEMANTIC_FAMILIES = {"danger": (0.0, (345.0, 20.0)),
                     "ok": (120.0, (95.0, 150.0)),
                     "warning": (55.0, (40.0, 65.0))}
SEMANTIC_BEND = 15.0
SEMANTIC_SAT = 0.55         # fixed editorial chroma; NOT scaled by chroma_ramp --
                            # status must stay legible on achromatic wallpapers


def bend_semantic(base_hue_deg, dominant_deg, bounds):
    d = signed_arc(base_hue_deg, dominant_deg)
    bent = base_hue_deg + max(-SEMANTIC_BEND, min(SEMANTIC_BEND, d))
    return circ_clamp(bent, *bounds)


def build_palette(hue, sat, mean_l, chromatic, bins=None, chroma_share=1.0):
    """Anchored analogous palette. `hue` in turns; internal hue math in degrees."""
    base = DEPTH_MIN + (DEPTH_MAX - DEPTH_MIN) * min(mean_l, DEPTH_PIVOT) / DEPTH_PIVOT
    ramp = chroma_ramp(chroma_share) if chromatic else 0.0
    H = (hue * 360.0) % 360.0
    trio = (derive_trio(H, bins or {}, chroma_share) if chromatic
            else {"depth": H, "dominant": H, "glow": H})
    dep, dom, glo = trio["depth"], trio["dominant"], trio["glow"]

    surf_sat = min(max(sat, 0.30 if chromatic else 0.0), 0.42) * ramp
    acc_sat = min(max(sat, 0.30) + 0.12, sat_cap(dom, ACC_SAT_CAP)) * ramp if chromatic else 0.05

    pill = {name: tint_deg(dep, surf_sat, base + step)
            for name, step in zip(SURF_NAMES, DARK_STEPS)}
    pill["outline"] = tint_deg(dep, surf_sat, base + 0.35)
    pill["primary_container"] = tint_deg(dom, min(acc_sat + 0.08, sat_cap(dom, 0.90)), 0.34)
    pill["on_primary_container"] = tint_deg(dom, min(acc_sat, 0.45), 0.86)
    for key, (lit, st) in zip(TEXT_KEYS, DARK_TEXT):
        pill[key] = tint_deg(dom, st * ramp if chromatic else st, lit)

    wall_mean = tint(hue, sat, mean_l)
    eff_surface = alpha_composite(pill["surface_container_high"], wall_mean, SURF_ALPHA)

    voice = voice_band(pill["surface"])
    mark = snap_to_band(tint_deg(dom, min(acc_sat, sat_cap(dom, MARK_SAT_CAP)), 0.60), voice)
    mark = clamp_light(mark, MARK_CONTRAST, eff_surface)     # band OR clamp, higher wins

    glow_sat = min(max(sat, 0.30) + 0.12, sat_cap(glo, GLOW_SAT_CAP)) * ramp if chromatic else 0.05
    glow = snap_to_band(tint_deg(glo, glow_sat, GLOW_L), light_band(pill["surface"]))

    pill["mark"], pill["glow"], pill["primary"] = mark, glow, mark
    pill["light"] = False
    pill["trio"] = trio

    for name, (base_h, bounds) in SEMANTIC_FAMILIES.items():
        h = bend_semantic(base_h, dom, bounds) if chromatic else base_h
        c = snap_to_band(tint_deg(h, sat_cap(h, SEMANTIC_SAT), 0.55), voice)
        pill[name] = clamp_light(c, MARK_CONTRAST, eff_surface)

    return pill


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
        bins, chroma_share = {}, 1.0
    else:
        wallpaper = sys.argv[1]
        if not Path(wallpaper).is_file():
            return 0
        hue, sat, mean_l, bins, chroma_share = analyze(wallpaper)
        chromatic = hue is not None
        if not chromatic:
            hue, sat = 0.09, 0.0
    CACHE.mkdir(parents=True, exist_ok=True)

    pill = build_palette(hue, sat, mean_l, chromatic, bins=bins, chroma_share=chroma_share)
    trio = pill.pop("trio")

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
