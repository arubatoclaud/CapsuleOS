# Anchored Analogous Palette — Design Spec

Date: 2026-08-21
Status: awaiting review (rev 3 — adds blindspot-round decisions: fzf/bat
coverage, semantic status tokens, fallback-palette regeneration)
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
  SDDM/lock, GTK/Qt, hyprland borders, fzf, bat. (btop explicitly out —
  fullscreen and self-contained, keeps its stock theme.)
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
winner. All hue arithmetic is **circular** (shortest arc, wrap at 0°/360°) —
signed side comparisons must wrap correctly for red/magenta dominants.

- **Dominant hue H**: chosen exactly as today (winner bin's best hue).
- **Companions, one per side of H**: if a histogram bin whose best hue lies
  15°–45° from H on that side holds ≥ 8% of chromatic weight, **and** the
  image's total chromatic share is ≥ 15%, the companion **snaps to that
  bin's best hue** (a real color from the image). Otherwise it falls back to
  a fixed ±25° offset. (Below 15% chromatic share the histogram sliver is
  noise; snapping to it would build the trio from a lens flare.)
- **Role assignment by intrinsic luminance, with a stability dead zone**:
  compute the relative luminance of each companion hue at the fixed
  reference **(s = 0.6, l = 0.5)**. The lower-luminance hue becomes the
  **depth hue** (surfaces), the higher-luminance hue the **glow hue**
  (filament/highlights). If the two differ by **ΔY < 0.03**, assign by
  fixed convention instead: the counter-clockwise (H−) companion is depth.
  Rationale: where the hue circle's luminance curve is locally symmetric
  (measured: green ~120–160°, blue-violet ~250°, magenta ~310–340°) the
  companions are near-equal, and without the dead zone a few degrees of
  histogram jitter would flip surface/glow identity between near-identical
  wallpapers.
  Example results: blue flower → violet surfaces, steel-cyan glow; orange
  sunset → deep red-orange surfaces, golden glow.
- **Yellow-zone guard**: when H ∈ ~50°–95°, the glow hue is clamped out of
  the 70°–110° chartreuse trough (bias companions warm, toward orange).
  Symmetric neighbors of a golden dominant otherwise yield olive-on-khaki —
  the opposite of curated.

### Value architecture

A fixed ladder of perceived-luminance tiers, measured with the existing
`rel_luminance()` (Y; CIELAB L* is a pure function of Y, so equal-Y is a
legitimate proxy for equal lightness). Bands are anchored to the actual
generated `surface` (= terminal base00), not to absolute constants, since
the surface base varies with wallpaper mean lightness:

| Tier | Members | Band |
|---|---|---|
| Deeps | surface ramp (6 steps) | existing `DARK_STEPS` ladder, unchanged structure |
| Structure | `outline`, `primary_container` | Y between top of Deeps and bottom of Voice |
| Voice | `mark`, ANSI 1–6 | Y ∈ [Y₄.₅, Y₄.₅ + 0.05], where Y₄.₅ = smallest Y giving 4.5:1 vs base00 |
| Light | `glow`, ANSI 9–14 | Y ∈ [Y₆, Y₆ + 0.06], where Y₆ = smallest Y giving 6:1 vs base00 |
| Ink | text ramp (`cream`…`tick_rest`) | existing tiers, untouched |

Every generated color chooses hue and chroma first, then snaps its value to
its tier by adjusting lightness at fixed hue/sat (desaturating only when the
gamut demands it — e.g. saturated red tops out at Y = 0.2126, so bright red
lands as a desaturated salmon-leaning red; this is accepted and normal for
editorial schemes). Hues vary by wallpaper; the tonal composition never
does.

**Mark exception**: `mark` keeps its existing ≥ 4.5:1 frost-composite clamp,
which on bright wallpapers lifts it *above* the Voice band (the composite
surface is much lighter than base00). The rule is **band or clamp,
whichever is higher**; the property test asserts that rule, not naive band
membership.

**ANSI floors replaced**: the graduated `ANSI_CONTRAST_FLOOR` (3.0→5.6)
existed to rescue matugen's bg→fg ramp in slots 1–6. With matugen retired,
slots 1–6 are true accents: the graduation is replaced by a **uniform
4.5:1 floor vs base00** (achievable by every hue family, including red,
within sRGB). Slot 8 (bright black / comments) keeps a 3.0:1 floor. Value
normalization makes the floors near-tautological rather than a corrective.

### Chroma ceilings (no neon)

- `GLOW_SAT_CAP`: 0.90 → ~0.60
- accent saturation ceiling (`acc_sat` cap): 0.82 → ~0.65
- `MARK_SAT_CAP` 0.55 stays.
- HSL saturation is hue-uneven (S 0.60 green reads far louder than S 0.60
  red at equal Y), so the caps are **per-hue-zone**: the 90°–200°
  green/cyan zone gets ceilings ~0.15 tighter than the values above.
- Ceilings are enforced for every chromatic output, including ANSI slots.

### Role → hue mapping

- Surface ramp + `outline` + `outline_variant`: **depth hue** (existing
  lightness steps; surface saturation slightly below today's cap).
- `mark` / `primary` / `primary_container` / `on_primary_container`:
  **dominant hue**; frost-composite contrast clamp unchanged.
- `glow`: **glow hue**.
- Text ramp: near-neutral with a whisper of dominant (as today) —
  readability untouchable.

### Semantic status tokens

`colors.json` grows three first-class status colors — **`danger`,
`warning`, `ok`** — generated exactly like the terminal's hue-bent
red/yellow/green: 15° bend toward the dominant along the shortest arc,
clamped to the same numeric family bounds, per-hue-zone chroma ceilings,
Voice-band value. Because they do UI duty over the pill like `mark`, they
also get the frost-composite contrast clamp (band or clamp, whichever is
higher).

Consumers re-pointed at them:

- The three hardcoded `#e0533f` armed/fail reds in
  `pill/Pill.qml`, `pill/Launcher.qml`, `pill/Recorder.qml` → `danger`
  via Theme.
- `wallpaper.sh`'s SDDM mapping `error=\(.primary)` → `error=\(.danger)` —
  the accent stops impersonating an error color.

### Complementary accent (user addition at the pre-deploy gate)

One **punch accent** on complementary color theory: `accent` =
dominant + 180°, chroma-capped like every accent (`sat_cap` at
`ACC_SAT_CAP`), snapped to the **Light band** (the loudest single color in
the rice, still no neon), then frost-clamped like `mark`. Achromatic
wallpaper → neutral (a complement of grey is an invented hue; the
semantic exception does not apply). On cool wallpapers the accent lands
near `warning`'s hue family — they remain distinct by value tier (Light
vs Voice).

Wiring (focal points only): new `accent` key in `colors.json`; ghostty
`cursor-color` moves from `mark` to `accent` (dynamic + static fallback
block); fzf pointer follows via a `jq` read of `colors.json` at shell
init. Hyprland active border and all pill UI stay on `mark`.

### Fallback palettes regenerated

The static fallbacks that render before `colors.json` exists still carry
the old orange scheme; they are regenerated **once** to a representative
anchored-analogous set (derived from the manual-mode default hue) so a
fresh install matches the system's character:

- `quickshell/pill/Singletons/Dyn.qml` and
  `quickshell/lock/Singletons/Dyn.qml` fallback property blocks (now
  including the status trio);
- the static palette block in `configs/ghostty/config` (the cache file
  still overrides it at runtime).
- `pill/Osd.qml`'s hardcoded warm-white shimmer gradient re-points at the
  glow hue so light effects follow the palette.

### Edge cases

- **Achromatic wallpaper** (chromatic share < 8%): all three hues collapse
  to the neutral grey ramp, exactly as today. No invented color — EXCEPT
  semantic colors (the status trio and the terminal's red/green/yellow
  slots), which keep their fixed editorial chroma so git diffs and errors
  stay legible on greyscale wallpapers. The terminal's blue/magenta/cyan
  DO go neutral (they derive from the trio, which no longer exists).
  (User-ruled at the contact-sheet gate, 2026-08-21.)
- **Near-achromatic ramp, not a cliff**: between 8% and 20% chromatic
  share, all saturation ceilings scale linearly from 0 → full, so two
  film-still wallpapers at 7.9% and 8.3% chroma differ by a whisper of
  tint, not by a whole three-hue identity.
- **Manual `--hue` mode** (pill hue/sat wheel): companions are pure ±25°
  offsets; no histogram. CLI contract unchanged (mode word still accepted
  and ignored).
- **One-sided wallpapers** (e.g. the flower has no violet mass): missing
  side uses the offset fallback; at 25° an invented neighbor cannot clash —
  the anti-triadic insurance.

## 2. Terminal: in-house base16, matugen retired

matugen is removed from the pipeline (last call deleted; dependency gone).
The scheme ghostty reads from `~/.cache/capsuleos/ghostty-colors` is
generated directly.

**base00–07 (bg→fg ramp)** — exact mapping (monotone in lightness):

| Slot | Source |
|---|---|
| base00 | `surface` |
| base01 | `surface_container` |
| base02 | `surface_container_highest` |
| base03 | `faint` |
| base04 | `dim` |
| base05 | `subtle` |
| base06 | `cream` |
| base07 | `bright` |

**ANSI 1–6 / 9–14**:

- red / green / yellow: hue-bent **15° toward the dominant along the
  shortest arc**, clamped to numeric family bounds so each stays
  recognizable — red ∈ [345°, 20°], green ∈ [95°, 150°], yellow ∈
  [40°, 65°] — and de-saturated to the editorial ceiling.
- blue = dominant hue; cyan = glow hue; magenta = depth hue — **subject to
  a minimum inter-slot separation**: pairwise hue distance between ANSI
  4/5/6 must be ≥ 30°. When the trio is tighter (companions snapped near
  the 15° minimum), the *terminal's* cyan and magenta spread outward to
  dominant ± 40° regardless of where the UI companions sit. The terminal is
  allowed to be less subtle than the pill; three indistinguishable cool
  slots would delete real information from syntax highlighting and starship
  (`bright-cyan` vs `bright-purple`).
- Normal slots normalized to the **Voice** band, brights to **Light**.
- Uniform 4.5:1 floor as a final safety net (see value architecture).

**Cursor / selection** — exact keys: `cursor-color` = `accent` (complementary
punch; was `mark` before the accent addition);
`selection-background` = `surface_container_highest` (Deeps tier — never a
mid-value key); `selection-foreground` = `bright`. Property test: every
floored ANSI slot ≥ 3:1 against `selection-background`.

Atomic write of `ghostty-colors` is preserved.

**Starship**: no config redesign. It uses only `bright-*` slots and
inherits the scheme; the value-collapse failure mode ("normal slots turn
monochrome") is deleted by construction, and the hue-collapse risk is
handled by the ≥ 30° inter-slot separation above.

**zsh**: syntax highlighting reads ANSI slots and comes along free; verify
`zshrc` hardcodes no hex values (fix any found).

## 3. Fan-out

`colors.json` keeps every existing key; consumers inherit without interface
changes.

- **Pill/quickshell**: no QML changes; surfaces/`mark`/`glow` carry the new
  hues and values.
- **Fastfetch** — exact template slot assignment:
  `__KEYS__` = `mark`, `__SEP__` = `dim`, `__LOGO1__` = `mark`,
  `__LOGO2__` = `glow`, `__LOGO3__` = `surface_container` (depth),
  `__LOGO4__` = `surface_container_high` (depth), `__LOGO5__` =
  `on_primary_container`, `__LOGO6__` = `outline` (depth), `__LOGO7__` =
  `bright` — the bottom strip walks depth → dominant → glow → ink, the
  palette's signature as a colophon.
- **SDDM/lock**: reads `colors.json` via `wallpaper.sh`; zero changes.
- **GTK/Qt**: `write_qtct` role table inherits; Highlight/Link stay on
  dominant.
- **hyprland borders** (`hypr-colors.lua`): `active` = `mark` (as today);
  `inactive` = `outline_variant` (surface-ramp step 6).
- **fzf**: `FZF_DEFAULT_OPTS` in `zshrc` gains a `--color` spec using
  **ANSI slot names only** (e.g. `hl:6`, `pointer:4`, `prompt:5`) — it
  follows the palette through the terminal scheme with no generation step.
- **bat**: `--theme=ansi` (via `~/.config/bat/config`) — bat's built-in
  ANSI theme reads the terminal palette; no generation step. The `cat`
  alias needs no change.

## 4. Validation

### Preview harness (repo-only, not deployed)

A small script runs the generator over every wallpaper in
`~/CapsuleOS/wallpapers` plus a synthetic set — pure red, orange sunset,
**golden-hour yellow**, **chartreuse forest**, green forest, **cyan/teal
sea**, **blue-hour city**, **magenta/pink**, greyscale, low-saturation
pastel, a **near-8%-chroma film still**, and a **two-peak image** (to
exercise role-assignment stability) — and renders **one contact sheet**:
wallpaper thumbnail + swatch row + terminal mockup per wallpaper. Reviewed
together before deployment — failures are caught in a PNG, not on the live
desktop. Green- and cyan-dominant sheets are the explicit no-neon pass
criterion (the neon-prone classes under HSL caps).

### Test guarantees (`test_wallcolors.py` additions)

Property-style assertions that must hold for any input:

- every Voice-tier color inside its value band (`mark`: band **or**
  frost-clamp result, whichever is higher); likewise Light tier;
- `mark` ≥ 4.5:1 against the frost composite;
- every ANSI foreground ≥ 4.5:1 vs base00 (slot 8: ≥ 3.0:1), and every
  floored slot ≥ 3:1 vs `selection-background`;
- pairwise hue distance between ANSI 4/5/6 ≥ 30°;
- no output exceeds its (per-hue-zone) chroma ceiling;
- companions always 15°–45° from dominant (circular distance), except the
  yellow-zone guard may clamp glow to 69°, as close as 4° from a 50–95°
  dominant;
- glow hue never inside 70°–110° when the dominant is in the yellow zone;
- role assignment stable under the dead zone (ΔY < 0.03 → H− companion is
  depth);
- base03–07 monotone in lightness;
- `danger`/`warning`/`ok` inside their family bounds, Voice band (or
  frost clamp, whichever is higher), and chroma ceilings;
- achromatic in → achromatic out (no invented hue anywhere), and
  saturation ramps continuously across the 8%–20% chromatic window (no
  cliff).

## 5. Deploy & rollback

All edits land in the repo (`~/capsuleos`); the live machine runs from
`~/.config`, so changes take effect only after the normal deploy step.
Rollback = git revert + re-run `wallpaper.sh`.

## Out of scope

- Light palettes (Night Glass stays dark-only).
- Per-wallpaper manual overrides.
- btop theming (self-contained fullscreen tool, stock theme kept).
- Rewiring QML consumers onto the `mark`/`glow` split (`primary` keeps
  tracking `mark`).
- GRUB theme.
- OKLCH/CIELAB color-space rewrite (equal-Y snapping + per-hue-zone caps
  are the pragmatic approximation; revisit only if the contact sheet shows
  Helmholtz–Kohlrausch loudness imbalances the caps can't tame).
