# Anchored Analogous Palette — Design Spec

Date: 2026-08-21
Status: awaiting review
Supersedes: the discarded triadic palette attempt (2026-08-21)

## Goal

Redesign the wallpaper→palette pipeline (`configs/hypr/scripts/wallcolors.py`)
from a single-hue tint into an **anchored analogous** system with a **fixed
value architecture**, so the rice reads as unified, curated, and editorial on
*any* wallpaper — deep and atmospheric, never neon.

Decisions locked during brainstorming:

- **Dynamic**: generated from whatever wallpaper is set; no per-wallpaper
  hand-tuning.
- **Vibe**: deep & atmospheric — depth hue sinks into surfaces, dominant
  carries the UI, the third hue is rationed to glow/highlights.
- **Coverage**: pill/quickshell, ghostty, starship, fastfetch, zsh,
  SDDM/lock, GTK/Qt, hyprland borders.
- **Terminal semantics**: hue-bent — red/green/yellow stay recognizable but
  are pulled toward the palette family and value-matched.
- **No neon**: hard chroma ceilings on every generated color.
- **Value, not just hue**: all chromatic colors snap to fixed
  perceived-luminance tiers; the tonal composition is constant across
  wallpapers.
- **Robustness first**: the triadic attempt died on "bad on some wallpapers";
  this design is validated on a contact sheet across many wallpapers before
  deployment.

## 1. Palette model

### Hue trio

`analyze()` keeps its existing 30°-binned histogram (weighted-saturation
winner, per-bin best candidate) but returns all bins instead of only the
winner.

- **Dominant hue H**: chosen exactly as today (winner bin's best hue).
- **Companions, one per side of H**: if a histogram bin whose best hue lies
  15°–45° from H on that side holds ≥ 8% of chromatic weight, the companion
  **snaps to that bin's best hue** (a real color from the image). Otherwise
  it falls back to a fixed ±25° offset. Candidate hues closer than 12° to H
  are ignored (too close to buy direction).
- **Role assignment by intrinsic luminance, not side**: compute relative
  luminance of each companion at a fixed reference (s, l); the
  lower-luminance hue becomes the **depth hue** (surfaces), the
  higher-luminance hue becomes the **glow hue** (filament/highlights).
  Example results: blue flower → violet surfaces, steel-cyan glow; orange
  sunset → deep red-orange surfaces, golden glow.

### Value architecture

A fixed ladder of perceived-luminance tiers, measured with the existing
`rel_luminance()`:

| Tier | Members | Rule |
|---|---|---|
| Deeps | surface ramp (6 steps) | existing `DARK_STEPS` ladder, unchanged structure |
| Structure | `outline`, `primary_container` | one mid-value band |
| Voice | `mark`, ANSI 1–6 | one shared value band; every accent normalized to equal perceived lightness |
| Light | `glow`, ANSI 9–14 | one band above Voice, rationed |
| Ink | text ramp (`cream`…`tick_rest`) | existing tiers, untouched |

Every generated color chooses hue and chroma first, then snaps its value to
its tier. Hues vary by wallpaper; the tonal composition never does.

### Chroma ceilings (no neon)

- `GLOW_SAT_CAP`: 0.90 → ~0.60
- accent saturation ceiling (`acc_sat` cap): 0.82 → ~0.65
- `MARK_SAT_CAP` 0.55 stays.
- Ceilings are enforced for every chromatic output, including ANSI slots.

### Role → hue mapping

- Surface ramp + `outline` + `outline_variant`: **depth hue** (existing
  lightness steps; surface saturation slightly below today's cap).
- `mark` / `primary` / `primary_container` / `on_primary_container`:
  **dominant hue**; existing frost-composite contrast clamp (≥ 4.5:1)
  unchanged.
- `glow`: **glow hue**.
- Text ramp: near-neutral with a whisper of dominant (as today) —
  readability untouchable.

### Edge cases

- **Achromatic wallpaper** (`chroma < 8%`): all three hues collapse to the
  neutral grey ramp, exactly as today. No invented color.
- **Manual `--hue` mode** (pill hue/sat wheel): companions are pure ±25°
  offsets; no histogram. CLI contract unchanged (mode word still accepted
  and ignored).
- **One-sided wallpapers** (e.g. the flower has no violet mass): missing
  side uses the offset fallback; at 25° an invented neighbor cannot clash —
  the anti-triadic insurance.

## 2. Terminal: in-house base16, matugen retired

matugen is removed from the pipeline (last call deleted; dependency gone).
The scheme ghostty reads from `~/.cache/capsuleos/ghostty-colors` is
generated directly:

- **base00–07 (bg→fg ramp)**: from the surface ramp (depth hue) and text
  ramp. Terminal background = `surface`; the terminal and pill share one
  canvas.
- **ANSI 1–6 / 9–14**:
  - red / green / yellow: hue-bent 15° toward the dominant (clamped so each
    stays inside its recognizable family), de-saturated to the editorial
    ceiling — still instantly readable in git diffs and errors.
  - blue = dominant hue, cyan = glow hue, magenta = depth hue.
  - Normal slots normalized to the **Voice** band, brights to **Light**.
- The graduated `ANSI_CONTRAST_FLOOR` clamps remain as a final safety net;
  value normalization should make them rarely fire.
- `cursor-color`, `selection-*`: re-pointed at pill keys.
- Atomic write of `ghostty-colors` is preserved.

**Starship**: no redesign. It uses only `bright-*` slots and inherits the
scheme; the "normal slots collapse to monochrome" failure mode is deleted by
construction.

**zsh**: syntax highlighting reads ANSI slots and comes along free; verify
`zshrc` hardcodes no hex values (fix any found).

## 3. Fan-out

`colors.json` keeps every existing key; consumers inherit without interface
changes.

- **Pill/quickshell**: no QML changes; surfaces/`mark`/`glow` carry the new
  hues and values.
- **Fastfetch**: remap the seven `__LOGO*__` template slots across the trio
  (depth ramp → dominant → glow) so the bottom color strip becomes the
  palette's signature.
- **SDDM/lock**: reads `colors.json` via `wallpaper.sh`; zero changes.
- **GTK/Qt**: `write_qtct` role table inherits; Highlight/Link stay on
  dominant.
- **hyprland borders** (`hypr-colors.lua`): `active` = `mark` (as today);
  `inactive` moves from matugen base01 to a surface-ramp step.

## 4. Validation

### Preview harness (repo-only, not deployed)

A small script runs the generator over every wallpaper in
`~/CapsuleOS/wallpapers` plus a synthetic set (pure red, orange sunset,
green forest, greyscale, low-saturation pastel) and renders **one contact
sheet**: wallpaper thumbnail + swatch row + terminal mockup per wallpaper.
Reviewed together before deployment — failures are caught in a PNG, not on
the live desktop.

### Test guarantees (`test_wallcolors.py` additions)

Property-style assertions that must hold for any input:

- every Voice-tier color inside its value band (likewise Light tier);
- `mark` ≥ 4.5:1 against the frost composite;
- every floored ANSI foreground above its `ANSI_CONTRAST_FLOOR`;
- no output exceeds its chroma ceiling (no-neon as a test, not a vibe);
- companions always 15°–45° from dominant;
- achromatic in → achromatic out (no invented hue anywhere).

## 5. Deploy & rollback

All edits land in the repo (`~/capsuleos`); the live machine runs from
`~/.config`, so changes take effect only after the normal deploy step.
Rollback = git revert + re-run `wallpaper.sh`.

## Out of scope

- Light palettes (Night Glass stays dark-only).
- Per-wallpaper manual overrides.
- Rewiring QML consumers onto the `mark`/`glow` split (`primary` keeps
  tracking `mark`).
- GRUB theme.
