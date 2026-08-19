<div align="center">

# CapsuleOS

### macOS Golden Gate — the release Apple never shipped.

*One pill. A bridge at night. The desktop California deserved.*

</div>

Every macOS release is named after a California landmark. Somehow, the most
famous one never got its turn. CapsuleOS fixes that: a Hyprland + Quickshell
desktop styled as the fictional **macOS Golden Gate** — cold night-bridge
surfaces, fog-grey type, and International Orange burning through as amber.

Forked with love from [Ricelin](https://github.com/Gakuseei/Ricelin), whose
hand-written Quickshell pill is the entire chassis. Go star it.

## Highlights

- **The Pill** — one shape-shifting bar: media, calendar, wallpaper picker,
  clipboard history, mixer, network, bluetooth, launcher, lock.
- **Materials** — Glass, Frost or Ink. Pick your translucency in Settings.
- **Motion** — Calm (Apple's own curve), Spring, or Glide. The shell and
  Hyprland animate in the same language.
- **Auto-hide** — the pill slides off the top edge at rest, exactly like the
  Mac menu bar. Mouse up to bring it home.
- **Night bridge, day wallpaper** — matugen still repaints everything from
  your wallpaper when you want it to; the curated theme is the fallback.
- **Sonoma lock** — thin-weight clock, avatar, frosted password capsule.

## Stack

Hyprland (Lua) · Quickshell · ghostty · zsh · Inter + JetBrains Mono Nerd · matugen

## Install

> **Warning:** young installer, read it first, keep backups.

    curl -fsSL https://raw.githubusercontent.com/arubatoclaud/CapsuleOS/main/install.sh | bash

Flags: `--quickstart` (defaults, no questions) · `--full` (daily apps) ·
`--sddm` (goldengate login theme) · `--no-deps` (configs only — the sudoless
path) · `--dry-run` (change nothing).

On a sudoless machine use `--no-deps` and install the package list from
`installer/packages.json` by other means. Fonts can go to
`~/.local/share/fonts` without root.

Your existing `~/.zshrc` is never touched. Your monitor layout is never
overwritten. Screenshots are bring-your-own (grim + slurp work well).

## Keybinds

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

## Credits

The pill, the installer, the update engine and most of what you see are
[Gakuseei's Ricelin](https://github.com/Gakuseei/Ricelin), reskinned.
Lock/SDDM asset credits: [CREDITS](configs/sddm/themes/goldengate/CREDITS.md).
