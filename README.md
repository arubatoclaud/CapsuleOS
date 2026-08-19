<div align="center">

# CapsuleOS

### macOS Golden Gate — the release Apple never shipped.

*Everything you need, in one capsule.*

<img src="assets/hero.png" alt="CapsuleOS desktop — the pill over a Golden Gate night" width="100%">

</div>

Every macOS release is named after a California landmark, and the most famous
one never got its turn. CapsuleOS fixes that: a Hyprland + Quickshell desktop
styled as the fictional **macOS Golden Gate** — cold night-bridge surfaces,
fog-grey type, and International Orange burning through as amber.

The whole shell lives in a single capsule-shaped bar. Click it and it morphs:
media player, calendar, mixer, launcher, settings — twenty-six surfaces, one
pill, zero windows-that-look-like-1998.

Forked with love from [Ricelin](https://github.com/Gakuseei/Ricelin), whose
hand-written Quickshell pill is the entire chassis. Go star it.

## The tour

| | |
|---|---|
| <img src="assets/shell.png" alt="Morphing surfaces"> | **One shape-shifting bar.** Media, calendar, wallpaper picker, clipboard history, mixer, network, bluetooth, screen recording, launcher, lock — every surface morphs out of the same capsule and folds back into it. |
| <img src="assets/retheme.gif" alt="Live retheme"> | **Retheme in one keypress.** `Super+B` shuffles the wallpaper and matugen repaints the entire desktop from it — shell, window borders, terminal, lock screen. The curated Golden Gate palette is always the fallback. |

## Highlights

- **Materials** — Glass, Frost or Ink. Pick your translucency in Settings and
  the pill, the popups and your terminal all agree on it.
- **Motion** — Calm (Apple's own curve), Spring, or Glide. One *Feel* setting
  drives both the shell and Hyprland, so everything animates in the same
  language. A bezier editor is folded underneath for the obsessive.
- **Auto-hide** — the pill slides off the top edge at rest, exactly like the
  Mac menu bar. Mouse up to bring it home.
- **Settings, all of them** — ten searchable pages covering appearance,
  windows, displays, input, keybinds, workspaces, recording, wallpaper and
  session. Rebind keys and edit workspace rules without touching a config file.
- **Session sanity** — do-not-disturb, keep-awake, game mode, night light,
  idle lock and suspend, all one click deep.
- **Sonoma lock** — thin-weight clock, avatar, frosted password capsule.

## Stack

Hyprland (Lua config) · Quickshell · ghostty · zsh · Inter + JetBrains Mono Nerd · matugen

## Install

> **Warning:** young installer. Read it first, keep backups.

    curl -fsSL https://raw.githubusercontent.com/arubatoclaud/CapsuleOS/main/install.sh | bash

Works on Arch, Debian/Ubuntu, Fedora and openSUSE families (the installer maps
your distro from `os-release`).

| Flag | What it does |
|---|---|
| `--quickstart` | defaults, no questions |
| `--full` | also install the daily-driver apps |
| `--sddm` | the goldengate login theme |
| `--no-deps` | configs only — the sudoless path |
| `--dry-run` | change nothing, show everything |
| `--reinstall` | force the wizard on an existing install |
| `--uninstall` | leave the way you came |

On a sudoless machine use `--no-deps` and install the package list from
`installer/packages.json` by other means. Fonts can go to
`~/.local/share/fonts` without root.

Your existing `~/.zshrc` is never touched. Your monitor layout is never
overwritten. Screenshots are bring-your-own (grim + slurp work well).

## The `capsuleos` CLI

The shell ships its own control command:

    capsuleos status                    what's running and the installed version
    capsuleos update                    check, show changelog, apply, restart
    capsuleos restart [pill|lock|all]   cycle a surface
    capsuleos log     [pill|lock]       follow the quickshell log
    capsuleos start / stop              watchdog control

`update` pulls the latest release and three-way-merges it: files you have
customised are protected, everything else moves forward, and a timestamped
backup lands next to your data dir before a single byte changes.

## Keybinds

The starter set — everything is rebindable from **Settings → Keybinds**.

| Key | Action |
|---|---|
| `Super` + `Return` | terminal |
| `Super` + `Space` | app launcher |
| `Super` + `V` | clipboard history |
| `Super` + `C` | wallpaper picker |
| `Super` + `B` | shuffle wallpaper and retheme |
| `Super` + `E` | file manager |
| `Super` + `T` | toggle floating |
| `Super` + `L` | lock |

## Wallpapers

CapsuleOS ships no bundled wallpapers yet — see [WALLPAPERS.md](WALLPAPERS.md)
for where to hunt Golden-Gate-at-night material and where to drop it. The
picker's folder is configurable from **Settings → Wallpaper**.

## Credits

The pill, the installer, the update engine and most of what you see are
[Gakuseei's Ricelin](https://github.com/Gakuseei/Ricelin), reskinned.
Lock/SDDM asset credits: [CREDITS](configs/sddm/themes/goldengate/CREDITS.md).
