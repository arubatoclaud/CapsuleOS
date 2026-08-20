# Anchored Analogous Palette Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-hue wallpaper palette in `wallcolors.py` with an anchored analogous trio (depth/dominant/glow) on a fixed value-tier architecture, fanned out to every rice consumer.

**Architecture:** All color math lives in `configs/hypr/scripts/wallcolors.py` as pure, testable functions; `main()` only does I/O. The terminal base16 is generated in-house (matugen removed). QML, fastfetch, zsh, bat, SDDM changes are consumer re-pointing only. A repo-only contact-sheet script validates before deploy.

**Tech Stack:** Python 3 stdlib (`colorsys`, no new deps), pytest, imagemagick (`magick`), QML (quickshell), zsh.

**Spec:** `docs/superpowers/specs/2026-08-21-analogous-palette-design.md` (rev 3, approved). The spec travels with this plan; executors read both.

## Global Constraints

- Hue units: **degrees [0, 360)** in all NEW functions; the existing `tint(hue_turns, s, l)` keeps turns — convert with `tint_deg()` only.
- All hue arithmetic circular (shortest arc); test wraparound at 0°/360°.
- Value bands anchored to generated `surface` (= base00): Voice = [Y₄.₅, Y₄.₅+0.05], Light = [Y₆, Y₆+0.06] where Yc = c·(Y(base00)+0.05)−0.05.
- Chroma ceilings: `GLOW_SAT_CAP = 0.60`, `ACC_SAT_CAP = 0.65`, `MARK_SAT_CAP = 0.55`; hues 90°–200° get ceilings 0.15 tighter.
- Companion window 15°–45°, snap needs bin ≥ 8% of chromatic weight AND image chromatic share ≥ 15%; fallback ±25°.
- Role dead zone: companion ΔY < 0.03 at reference (s=0.6, l=0.5) → H− companion is depth.
- Yellow guard: dominant ∈ [50°, 95°] → glow hue clamped out of (70°, 110°), warm side (69°).
- Semantic family bounds: red ∈ [345°, 20°], green ∈ [95°, 150°], yellow ∈ [40°, 65°]; bend = 15° toward dominant, shortest arc.
- ANSI 4/5/6 pairwise hue distance ≥ 30°; if trio tighter, terminal cyan/magenta = dominant ± 40°.
- Saturation ramps linearly 0→1 across chromatic share 8%→20% (no cliff at the achromatic threshold).
- `colors.json` keeps every existing key; new keys are additive (`danger`, `warning`, `ok`).
- Repo is source of truth; nothing touches `~/.config` until the final deploy task (live machine runs from `~/.config`).
- Tests run: `cd ~/capsuleos/configs/hypr/scripts && python -m pytest test_wallcolors.py -q`.
- Commit after every task (repo `~/capsuleos`).

## File Structure

- `configs/hypr/scripts/wallcolors.py` — all palette math + fan-out (modified heavily).
- `configs/hypr/scripts/test_wallcolors.py` — NEW; property + case tests for the pure functions.
- `configs/hypr/scripts/palette-preview.py` — NEW; repo-only contact-sheet harness (never deployed).
- `configs/hypr/scripts/wallpaper.sh` — one-line SDDM `error=` change.
- `configs/fastfetch/config.jsonc.in` — NEW in repo (adopted from live `~/.config/fastfetch/config.jsonc.in`); slot remap.
- `configs/quickshell/pill/Singletons/Dyn.qml`, `configs/quickshell/lock/Singletons/Dyn.qml` — status-token adapter props + regenerated fallbacks.
- `configs/quickshell/pill/Singletons/Theme.qml` — `danger` token.
- `configs/quickshell/pill/{Pill,Launcher,Recorder}.qml` — `#e0533f` → `Theme.danger`.
- `configs/quickshell/pill/Osd.qml` — shimmer gradient → glow.
- `configs/ghostty/config` — static fallback palette regen.
- `configs/zsh/zshrc` — `FZF_DEFAULT_OPTS` colors.
- `configs/bat/config` — NEW; `--theme="ansi"`.
- `installer/deploy.py` — `NIGHT_DEFAULT` regen + bat in `DEPLOY_SET`.

---

### Task 1: Extract pure `build_palette()` from `main()`

Make the palette derivation callable without I/O so every later task is testable. **No behavior change** — current single-hue logic, verbatim.

**Files:**
- Modify: `configs/hypr/scripts/wallcolors.py:362-434` (the derivation half of `main()`)
- Create: `configs/hypr/scripts/test_wallcolors.py`

**Interfaces:**
- Produces: `build_palette(hue, sat, mean_l, chromatic, bins=None) -> dict` — `hue` in **turns** [0,1) (matches `analyze()` today), returns the pill dict exactly as `main()` builds it (all keys `surface`…`primary`, `light`). `bins` accepted and ignored for now (Task 3 fills it).

- [ ] **Step 1: Write the failing test**

```python
# configs/hypr/scripts/test_wallcolors.py
import wallcolors as w

FLOWER = dict(hue=216/360, sat=0.61, mean_l=0.08, chromatic=True)

def test_build_palette_keys_and_contract():
    p = w.build_palette(**FLOWER)
    for k in ["surface", "surface_container_low", "surface_container",
              "surface_container_high", "surface_container_highest",
              "outline_variant", "primary_container", "on_primary_container",
              "outline", "cream", "bright", "subtle", "dim", "faint",
              "icon_dim", "tick_rest", "mark", "glow", "primary"]:
        assert k in p and p[k].startswith("#"), k
    assert p["light"] is False
    assert p["primary"] == p["mark"]

def test_build_palette_mark_contrast_holds():
    p = w.build_palette(**FLOWER)
    eff = w.alpha_composite(p["surface_container_high"],
                            w.tint(FLOWER["hue"], FLOWER["sat"], FLOWER["mean_l"]),
                            w.SURF_ALPHA)
    assert w.contrast_ratio(p["mark"], eff) >= w.MARK_CONTRAST - 0.01

def test_build_palette_achromatic_has_no_hue():
    p = w.build_palette(hue=0.09, sat=0.0, mean_l=0.3, chromatic=False)
    r, g, b = (int(p["surface"][i:i+2], 16) for i in (1, 3, 5))
    assert max(r, g, b) - min(r, g, b) <= 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/capsuleos/configs/hypr/scripts && python -m pytest test_wallcolors.py -q`
Expected: FAIL — `AttributeError: module 'wallcolors' has no attribute 'build_palette'`

- [ ] **Step 3: Extract the function**

In `wallcolors.py`, move the block of `main()` from `# Dark-only depth:` (line ~388) through `pill["light"] = False` (line ~434) into:

```python
def build_palette(hue, sat, mean_l, chromatic, bins=None):
    """Pure palette derivation: no filesystem, no subprocess. `hue` in turns."""
    base = DEPTH_MIN + (DEPTH_MAX - DEPTH_MIN) * min(mean_l, DEPTH_PIVOT) / DEPTH_PIVOT
    ...  # the moved block, verbatim, ending with pill["light"] = False
    return pill
```

`main()` shrinks to: parse args / `analyze()` exactly as now, then `pill = build_palette(hue, sat, mean_l, chromatic)`, then the existing writes (`colors.json`, `render_fastfetch`, gtk/qt, matugen/base16/ghostty — untouched this task).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/capsuleos/configs/hypr/scripts && python -m pytest test_wallcolors.py -q`
Expected: 3 passed

- [ ] **Step 5: Smoke the CLI path unchanged**

Run: `cd ~/capsuleos/configs/hypr/scripts && python3 wallcolors.py --hue 216 dark 0.6 && python3 -c "import json;d=json.load(open('/home/wannabeartist/.cache/capsuleos/colors.json'));print(d['mark'],d['glow'])"`
Expected: two hex colors print; no traceback. (This overwrites the cache — the live pill re-reads it; that is fine and reversible by re-running `wallpaper.sh`.)

- [ ] **Step 6: Commit**

```bash
cd ~/capsuleos && git add configs/hypr/scripts/wallcolors.py configs/hypr/scripts/test_wallcolors.py && git commit -m "refactor: extract pure build_palette() from main()"
```

---

### Task 2: Circular-hue helpers and trio derivation

**Files:**
- Modify: `configs/hypr/scripts/wallcolors.py` (new functions after `tint()`)
- Test: `configs/hypr/scripts/test_wallcolors.py`

**Interfaces:**
- Produces:
  - `tint_deg(h_deg, s, l) -> "#rrggbb"` — degree wrapper over `tint`.
  - `signed_arc(a_deg, b_deg) -> float` — signed shortest arc a→b, in (−180, 180].
  - `circ_clamp(h_deg, lo_deg, hi_deg) -> float` — clamp onto the circular interval lo→hi (interval may cross 0°).
  - `hue_luminance(h_deg) -> float` — `rel_luminance(tint_deg(h, 0.6, 0.5))` (the spec's fixed reference).
  - `derive_trio(dominant_deg, bins, chroma_share) -> dict(depth=, dominant=, glow=)` — all hues in degrees. `bins` = `{bin_index: {"weight": frac_of_chromatic, "hue": deg, "sat": s}}`.

- [ ] **Step 1: Write the failing tests**

```python
def test_signed_arc_wraps():
    assert w.signed_arc(350, 10) == 20
    assert w.signed_arc(10, 350) == -20
    assert abs(w.signed_arc(0, 180)) == 180

def _bins(*entries):  # (weight, hue, sat) triples
    return {i: {"weight": wt, "hue": h, "sat": s}
            for i, (wt, h, s) in enumerate(entries)}

def test_trio_snaps_to_real_neighbor_hue():
    t = w.derive_trio(216, _bins((0.92, 216, 0.61), (0.08, 196, 0.52)), 0.24)
    assert t["dominant"] == 216
    assert 196 in (t["depth"], t["glow"])          # snapped, not 191 offset
    assert 241 in (t["depth"], t["glow"])          # empty side falls back to +25

def test_trio_ignores_neighbors_when_chroma_share_low():
    t = w.derive_trio(216, _bins((0.92, 216, 0.61), (0.08, 196, 0.52)), 0.10)
    assert {t["depth"], t["glow"]} == {191, 241}   # pure offsets below 15% share

def test_trio_roles_by_luminance():
    t = w.derive_trio(30, _bins((1.0, 30, 0.7)), 0.5)   # orange dominant
    assert t["depth"] == 5 and t["glow"] == 55          # red side deep, gold side glows

def test_trio_dead_zone_uses_ccw_convention():
    # 250 deg (blue-violet) sits at the hue circle's luminance minimum, so its
    # +/-25 companions have near-identical intrinsic Y (dY ~ 0.0007).
    t = w.derive_trio(250, _bins((1.0, 250, 0.6)), 0.5)
    assert abs(w.hue_luminance(225) - w.hue_luminance(275)) < 0.03  # precondition
    assert t["depth"] == 225 and t["glow"] == 275        # H- is depth by convention

def test_trio_yellow_guard():
    t = w.derive_trio(60, _bins((1.0, 60, 0.8)), 0.5)
    assert not (70 < t["glow"] < 110)

def test_trio_wraparound_red_dominant():
    t = w.derive_trio(355, _bins((1.0, 355, 0.7)), 0.5)
    assert t["dominant"] == 355
    assert sorted((w.signed_arc(355, t["depth"]), w.signed_arc(355, t["glow"]))) == [-25, 25]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/capsuleos/configs/hypr/scripts && python -m pytest test_wallcolors.py -q`
Expected: new tests FAIL with AttributeError on `signed_arc` / `derive_trio`

- [ ] **Step 3: Implement**

```python
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/capsuleos/configs/hypr/scripts && python -m pytest test_wallcolors.py -q`
Expected: all pass

- [ ] **Step 5: Commit**

```bash
cd ~/capsuleos && git add -u configs/hypr/scripts && git commit -m "feat: circular hue helpers and anchored analogous trio derivation"
```

---

### Task 3: `analyze()` returns the histogram bins

**Files:**
- Modify: `configs/hypr/scripts/wallcolors.py:107-139` (`analyze`), `main()` call site
- Test: `configs/hypr/scripts/test_wallcolors.py`

**Interfaces:**
- Produces: `analyze(wallpaper) -> (hue_turns, sat, mean_l, bins, chroma_share)` — first three unchanged in meaning; `bins` in the `derive_trio` format (hues in **degrees**, weights normalized to fraction of chromatic weight); `chroma_share` = chromatic pixels / total. Achromatic image → `(None, 0.0, mean_l, {}, share)`.

- [ ] **Step 1: Write the failing test (synthetic images via magick)**

```python
import subprocess, tempfile, os

def _img(spec, size="64x64"):
    f = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
    subprocess.run(["magick", "-size", size] + spec + [f.name], check=True)
    return f.name

def test_analyze_returns_bins_and_share():
    path = _img(["xc:#3060c0"])                       # one saturated blue
    try:
        hue, sat, mean_l, bins, share = w.analyze(path)
        assert hue is not None and share > 0.9
        assert len(bins) >= 1
        total = sum(b["weight"] for b in bins.values())
        assert abs(total - 1.0) < 0.01                # weights are fractions
        top = max(bins.values(), key=lambda b: b["weight"])
        assert abs(signed := w.signed_arc(top["hue"], hue * 360)) < 15
    finally:
        os.unlink(path)

def test_analyze_achromatic_empty_bins():
    path = _img(["gradient:black-white"])
    try:
        hue, sat, mean_l, bins, share = w.analyze(path)
        assert hue is None and bins == {} and share < 0.08
    finally:
        os.unlink(path)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `ValueError: not enough values to unpack` (analyze returns 3 today)

- [ ] **Step 3: Implement**

In `analyze()`, keep the existing loop untouched; change only the tail:

```python
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
```

Update `main()`'s call: `hue, sat, mean_l, bins, chroma_share = analyze(wallpaper)`; the `--hue` branch sets `bins, chroma_share = {}, 1.0`.

- [ ] **Step 4: Run all tests**

Expected: all pass (Task 1 tests still green — `build_palette` signature untouched so far)

- [ ] **Step 5: Commit**

```bash
cd ~/capsuleos && git add -u configs/hypr/scripts && git commit -m "feat: analyze() exposes hue histogram bins and chromatic share"
```

---

### Task 4: Value-tier machinery (bands, snapping, per-zone chroma caps, chroma ramp)

**Files:**
- Modify: `configs/hypr/scripts/wallcolors.py`
- Test: `configs/hypr/scripts/test_wallcolors.py`

**Interfaces:**
- Produces:
  - `band(target_contrast, base00_hex, width) -> (y_lo, y_hi)`; `voice_band(base00)` = `band(4.5, base00, 0.05)`; `light_band(base00)` = `band(6.0, base00, 0.06)`.
  - `snap_to_band(hex_color, band_tuple) -> hex` — moves lightness at fixed hue/sat until relative luminance lands inside the band (targets band midpoint; HSL lightness→Y is monotone so bisection is safe).
  - `sat_cap(h_deg, base_cap) -> float` — `base_cap - 0.15` when 90 ≤ h ≤ 200, else `base_cap`; floor at 0.05.
  - `chroma_ramp(share) -> float` — 0.0 below 0.08, 1.0 above 0.20, linear between.

- [ ] **Step 1: Write the failing tests**

```python
def _Y(hexc):
    return w.rel_luminance(hexc)

def test_band_anchoring():
    lo, hi = w.voice_band("#0a111a")
    assert abs((lo + 0.05) / (_Y("#0a111a") + 0.05) - 4.5) < 0.01
    assert abs(hi - lo - 0.05) < 1e-9

def test_snap_to_band_reaches_band_even_for_red():
    lo, hi = w.voice_band("#0a111a")
    snapped = w.snap_to_band(w.tint_deg(0, 0.65, 0.30), (lo, hi))
    assert lo <= _Y(snapped) <= hi

def test_snap_is_noop_inside_band():
    lo, hi = w.voice_band("#0a111a")
    c = w.snap_to_band(w.tint_deg(216, 0.5, 0.6), (lo, hi))
    assert c == w.snap_to_band(c, (lo, hi))

def test_sat_cap_green_zone_tighter():
    assert w.sat_cap(120, 0.65) == 0.50
    assert w.sat_cap(216, 0.65) == 0.65
    assert w.sat_cap(0, 0.65) == 0.65

def test_chroma_ramp_continuous():
    assert w.chroma_ramp(0.05) == 0.0
    assert w.chroma_ramp(0.25) == 1.0
    assert abs(w.chroma_ramp(0.14) - 0.5) < 0.01
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: AttributeError on the new names

- [ ] **Step 3: Implement**

```python
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
```

- [ ] **Step 4: Run all tests** — Expected: all pass

- [ ] **Step 5: Commit**

```bash
cd ~/capsuleos && git add -u configs/hypr/scripts && git commit -m "feat: value bands, band snapping, per-zone chroma caps, chroma ramp"
```

---

### Task 5: Rebuild `build_palette()` on the trio + tiers

The behavior change. The pill dict's hues split across the trio; values snap to tiers; ceilings tighten.

**Files:**
- Modify: `configs/hypr/scripts/wallcolors.py` (`build_palette`, constants), `main()` call sites
- Test: `configs/hypr/scripts/test_wallcolors.py`

**Interfaces:**
- Consumes: `derive_trio`, `voice_band`/`light_band`/`snap_to_band`/`sat_cap`/`chroma_ramp`, `tint_deg`.
- Produces: `build_palette(hue, sat, mean_l, chromatic, bins=None, chroma_share=1.0) -> dict` — same keys as before PLUS `trio` (dict of the three hues in degrees, for base16/preview; `main()` pops it before writing `colors.json`). Constants change: `GLOW_SAT_CAP = 0.60`, new `ACC_SAT_CAP = 0.65` replacing the inline `0.82`.

- [ ] **Step 1: Update Task 1's golden expectations + write the new tests**

Task 1's `test_build_palette_keys_and_contract` / mark-contrast / achromatic tests must keep passing unchanged (contract stability is the point). Add:

```python
def _hue_of(hexc):
    r, g, b = (int(hexc[i:i+2], 16)/255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return (h * 360) % 360, s, l

def test_palette_roles_split_across_trio():
    p = w.build_palette(**FLOWER, bins={}, chroma_share=1.0)
    t = p["trio"]
    sh, _, _ = _hue_of(p["surface_container_highest"])
    assert abs(w.signed_arc(sh, t["depth"])) < 3        # surfaces on depth hue
    mh, _, _ = _hue_of(p["mark"])
    assert abs(w.signed_arc(mh, t["dominant"])) < 3     # mark on dominant
    gh, _, _ = _hue_of(p["glow"])
    assert abs(w.signed_arc(gh, t["glow"])) < 3         # glow on glow hue

def test_glow_in_light_band_and_capped():
    p = w.build_palette(**FLOWER, bins={}, chroma_share=1.0)
    lo, hi = w.light_band(p["surface"])
    assert lo <= w.rel_luminance(p["glow"]) <= hi
    _, s, _ = _hue_of(p["glow"])
    assert s <= w.sat_cap(p["trio"]["glow"], w.GLOW_SAT_CAP) + 0.02

def test_mark_band_or_clamp_whichever_higher():
    bright = dict(hue=216/360, sat=0.61, mean_l=0.85, chromatic=True)  # snowy wall
    p = w.build_palette(**bright, bins={}, chroma_share=1.0)
    lo, _ = w.voice_band(p["surface"])
    eff = w.alpha_composite(p["surface_container_high"],
                            w.tint(bright["hue"], bright["sat"], bright["mean_l"]),
                            w.SURF_ALPHA)
    assert w.contrast_ratio(p["mark"], eff) >= w.MARK_CONTRAST - 0.01
    assert w.rel_luminance(p["mark"]) >= lo - 0.01     # never below the band

def test_near_achromatic_ramps_not_cliffs():
    lo = w.build_palette(216/360, 0.6, 0.1, True, bins={}, chroma_share=0.09)
    hi = w.build_palette(216/360, 0.6, 0.1, True, bins={}, chroma_share=0.20)
    _, s_lo, _ = _hue_of(lo["mark"])
    _, s_hi, _ = _hue_of(hi["mark"])
    assert s_lo < s_hi * 0.35                           # 9% share is a whisper of tint

def test_manual_hue_mode_offsets():
    p = w.build_palette(30/360, 0.5, 0.12, True, bins=None, chroma_share=1.0)
    t = p["trio"]
    assert sorted((round(w.signed_arc(30, t["depth"])), round(w.signed_arc(30, t["glow"])))) == [-25, 25]
```

Also add `import colorsys` at the top of the test file.

- [ ] **Step 2: Run tests to verify the new ones fail**

Expected: KeyError `'trio'` etc.

- [ ] **Step 3: Implement**

Replace `build_palette`'s body:

```python
ACC_SAT_CAP = 0.65          # was inline 0.82
# GLOW_SAT_CAP constant edited in place: 0.90 -> 0.60

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
    return pill
```

In `main()`: pass `bins=bins, chroma_share=chroma_share` (from Task 3's analyze; the `--hue` branch passes `bins=None, chroma_share=1.0`), and `trio = pill.pop("trio")` before `json.dumps` — keep `trio` in a local for Task 7.

- [ ] **Step 4: Run all tests** — Expected: all pass (including Task 1's untouched contract tests)

- [ ] **Step 5: Eyeball the flower palette**

Run: `cd ~/capsuleos/configs/hypr/scripts && python3 -c "
import wallcolors as w
p = w.build_palette(216/360, 0.61, 0.08, True, bins={0:{'weight':0.92,'hue':216,'sat':0.61},1:{'weight':0.08,'hue':196,'sat':0.52}}, chroma_share=0.24)
print({k: p[k] for k in ('surface','surface_container_highest','mark','glow')}, p['trio'])"`
Expected: surfaces lean violet vs mark's blue; glow leans cyan; hexes near rev-1 swatch (`#0b0b16`-family surfaces, `#94b0db`-family mark, `#69c0d3`-family glow).

- [ ] **Step 6: Commit**

```bash
cd ~/capsuleos && git add -u configs/hypr/scripts && git commit -m "feat: build_palette on anchored analogous trio + value tiers"
```

---

### Task 6: Semantic status tokens + SDDM error re-point

**Files:**
- Modify: `configs/hypr/scripts/wallcolors.py` (`build_palette` tail), `configs/hypr/scripts/wallpaper.sh:211`
- Test: `configs/hypr/scripts/test_wallcolors.py`

**Interfaces:**
- Produces:
  - `bend_semantic(base_hue_deg, dominant_deg, bounds) -> deg` — 15° toward dominant along shortest arc, then `circ_clamp` into `bounds`.
  - `SEMANTIC_FAMILIES = {"danger": (0.0, (345.0, 20.0)), "ok": (120.0, (95.0, 150.0)), "warning": (55.0, (40.0, 65.0))}`
  - `colors.json` gains keys `danger`, `warning`, `ok` (band-or-frost-clamp like `mark`).

- [ ] **Step 1: Write the failing tests**

```python
def _in_family(h, lo, hi):
    return (h - lo) % 360 <= (hi - lo) % 360

def test_status_tokens_exist_in_family_and_band():
    p = w.build_palette(**FLOWER, bins={}, chroma_share=1.0)
    lo_b, _ = w.voice_band(p["surface"])
    for name, (_, (flo, fhi)) in w.SEMANTIC_FAMILIES.items():
        h, s, _ = _hue_of(p[name])
        # 1 deg tolerance: 8-bit RGB quantization shifts a boundary hue ~0.3 deg
        assert _in_family(h, (flo - 1) % 360, (fhi + 1) % 360), (name, h)
        assert w.rel_luminance(p[name]) >= lo_b - 0.01, name

def test_bend_semantic_shortest_arc_and_clamp():
    assert w.bend_semantic(0, 216, (345, 20)) == 345    # 0 bends toward 216 ccw, clamped
    assert w.bend_semantic(120, 216, (95, 150)) == 135  # full 15 toward 216
    assert w.bend_semantic(55, 30, (40, 65)) == 40      # bends warm, clamped at 40

def test_status_tokens_survive_achromatic():
    p = w.build_palette(0.09, 0.0, 0.3, False, bins={}, chroma_share=0.0)
    h, s, _ = _hue_of(p["danger"])
    assert s > 0.1                                      # danger stays red even on grey walls
```

- [ ] **Step 2: Run tests to verify they fail** — Expected: KeyError `'danger'`

- [ ] **Step 3: Implement**

```python
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
```

In `build_palette`, after `pill["trio"] = trio` (semantics bend toward the dominant even when the wallpaper is achromatic — bend toward `dom` which equals H then; harmless):

```python
    for name, (base_h, bounds) in SEMANTIC_FAMILIES.items():
        h = bend_semantic(base_h, dom, bounds) if chromatic else base_h
        c = snap_to_band(tint_deg(h, sat_cap(h, SEMANTIC_SAT), 0.55), voice)
        pill[name] = clamp_light(c, MARK_CONTRAST, eff_surface)
```

In `wallpaper.sh` line 211, change the jq program:
`"error=\(.primary)"` → `"error=\(.danger // .primary)"` (the `//` fallback keeps SDDM working if an old colors.json is on disk).

- [ ] **Step 4: Run all tests** — Expected: all pass

- [ ] **Step 5: Shell-check the script edit**

Run: `bash -n ~/capsuleos/configs/hypr/scripts/wallpaper.sh`
Expected: no output

- [ ] **Step 6: Commit**

```bash
cd ~/capsuleos && git add -u configs/hypr/scripts && git commit -m "feat: semantic status tokens (danger/warning/ok); SDDM error uses danger"
```

---

### Task 7: In-house base16 — matugen retired

**Files:**
- Modify: `configs/hypr/scripts/wallcolors.py` (new `build_base16`, `main()` tail; delete `matugen()`; replace `ANSI_CONTRAST_FLOOR`)
- Test: `configs/hypr/scripts/test_wallcolors.py`

**Interfaces:**
- Consumes: `pill` dict + `trio` from `build_palette`.
- Produces: `build_base16(pill, trio, chromatic) -> dict` mapping `"base00".."base0f"` → hex. Slot semantics: base00–07 = bg→fg ramp; base08..base0f = ANSI 8–15 brights? **No** — this dict is keyed by GHOSTTY PALETTE INDEX for clarity instead: return `{"bg":…, "fg":…, "cursor":…, "sel_bg":…, "sel_fg":…, "palette": [c0..c15]}`. `main()` writes ghostty lines from it and `hypr-colors.lua` inactive from `pill["outline_variant"]`.

- [ ] **Step 1: Write the failing tests**

```python
def _term(p=None):
    p = p or w.build_palette(**FLOWER, bins={}, chroma_share=1.0)
    return p, w.build_base16(p, p["trio"], True)

def test_terminal_ramp_slots():
    p, t = _term()
    c = t["palette"]
    assert t["bg"] == c[0] == p["surface"]
    assert c[15] == p["bright"] and c[7] == p["subtle"]
    assert t["cursor"] == p["mark"]
    assert t["sel_bg"] == p["surface_container_highest"]
    assert t["sel_fg"] == p["bright"] and t["fg"] == p["bright"]

def test_terminal_ramp_monotone():
    _, t = _term()
    ys = [w.rel_luminance(c) for c in
          (t["palette"][0], t["palette"][8],  # bg, bright-black
           t["palette"][7], t["palette"][15])]
    assert ys == sorted(ys)

def test_ansi_cool_slots_separated():
    _, t = _term()
    hues = [ _hue_of(t["palette"][i])[0] for i in (4, 5, 6) ]  # blue, magenta, cyan
    for i in range(3):
        for j in range(i + 1, 3):
            assert abs(w.signed_arc(hues[i], hues[j])) >= 29.5, (hues[i], hues[j])

def test_ansi_floors_uniform():
    _, t = _term()
    for i in list(range(1, 7)) + list(range(9, 15)):
        assert w.contrast_ratio(t["palette"][i], t["palette"][0]) >= 4.5 - 0.02, i
    assert w.contrast_ratio(t["palette"][8], t["palette"][0]) >= 3.0 - 0.02

def test_ansi_vs_selection_bg():
    _, t = _term()
    for i in list(range(1, 7)) + [8] + list(range(9, 15)):
        assert w.contrast_ratio(t["palette"][i], t["sel_bg"]) >= 3.0 - 0.02, i

def test_brights_in_light_band():
    p, t = _term()
    lo, hi = w.light_band(p["surface"])
    for i in (9, 10, 11, 12, 13, 14):
        assert lo - 0.01 <= w.rel_luminance(t["palette"][i]) <= hi + 0.01, i
```

- [ ] **Step 2: Run tests to verify they fail** — Expected: AttributeError `build_base16`

- [ ] **Step 3: Implement**

```python
ANSI_FLOOR, ANSI_FLOOR_BRIGHT_BLACK, ANSI_SELECTION_FLOOR = 4.5, 3.0, 3.0
COOL_MIN_SEP, COOL_SPREAD = 30.0, 40.0

def build_base16(pill, trio, chromatic):
    """Terminal scheme straight from the pill palette. Returns bg/fg/cursor/
    selection + a 16-entry ANSI palette list."""
    dep, dom, glo = trio["depth"], trio["dominant"], trio["glow"]
    voice = voice_band(pill["surface"])
    light = light_band(pill["surface"])

    # cool slots: dominant/depth/glow, spread out if the trio is too tight
    blue, magenta, cyan = dom, dep, glo
    pairs = [(blue, magenta), (blue, cyan), (magenta, cyan)]
    if chromatic and min(abs(signed_arc(a, b)) for a, b in pairs) < COOL_MIN_SEP:
        magenta, cyan = (dom - COOL_SPREAD) % 360, (dom + COOL_SPREAD) % 360
        # keep magenta on the depth side: swap if depth was clockwise of dominant
        if signed_arc(dom, dep) > 0:
            magenta, cyan = cyan, magenta

    sem = {n: bend_semantic(h, dom, b) if chromatic else h
           for n, (h, b) in SEMANTIC_FAMILIES.items()}
    hues = [sem["danger"], sem["ok"], sem["warning"], blue, magenta, cyan]  # ANSI 1..6

    def accent(h_deg, band_t):
        s = sat_cap(h_deg, ACC_SAT_CAP) if chromatic else 0.05
        c = snap_to_band(tint_deg(h_deg, s, 0.55), band_t)
        return clamp_light(c, ANSI_FLOOR, pill["surface"])

    normals = [accent(h, voice) for h in hues]
    brights = [accent(h, light) for h in hues]

    palette = [pill["surface"]] + normals + [pill["subtle"]]          # 0..7
    palette += [clamp_light(pill["faint"], ANSI_FLOOR_BRIGHT_BLACK, pill["surface"])]  # 8
    palette += brights + [pill["bright"]]                              # 9..15

    for i in list(range(1, 7)) + [8] + list(range(9, 15)):             # selection safety
        palette[i] = clamp_light(palette[i], ANSI_SELECTION_FLOOR,
                                 pill["surface_container_highest"])

    return {"bg": pill["surface"], "fg": pill["bright"],
            "cursor": pill["mark"],
            "sel_bg": pill["surface_container_highest"], "sel_fg": pill["bright"],
            "palette": palette}
```

In `main()`: delete the `matugen()` function and its try/except; replace the tail with:

```python
    term = build_base16(pill, trio, chromatic)
    (CACHE / "hypr-colors.lua").write_text(
        'return {\n    active = "%s",\n    inactive = "%s",\n}\n'
        % (pill["primary"], pill["outline_variant"]))
    lines = [f'background = {term["bg"]}', f'foreground = {term["fg"]}',
             f'cursor-color = {term["cursor"]}',
             f'selection-background = {term["sel_bg"]}',
             f'selection-foreground = {term["sel_fg"]}']
    lines += [f'palette = {i}={c}' for i, c in enumerate(term["palette"])]
```

Keep the atomic tmp-write/replace exactly as is. Update the module docstring's matugen sentence.

- [ ] **Step 4: Run all tests** — Expected: all pass

- [ ] **Step 5: Confirm matugen is gone**

Run: `grep -c matugen ~/capsuleos/configs/hypr/scripts/wallcolors.py`
Expected: `0`

- [ ] **Step 6: Commit**

```bash
cd ~/capsuleos && git add -u configs/hypr/scripts && git commit -m "feat: in-house base16 terminal scheme; retire matugen"
```

---

### Task 8: Fastfetch — adopt template into repo, remap slots

**Files:**
- Create: `configs/fastfetch/config.jsonc.in` (copy of live `~/.config/fastfetch/config.jsonc.in` — the repo's `DEPLOY_SET` already expects `configs/fastfetch/` but the directory is missing from the repo)
- Modify: `configs/hypr/scripts/wallcolors.py` (`render_fastfetch` repl table)
- Test: `configs/hypr/scripts/test_wallcolors.py`

**Interfaces:**
- Consumes: `pill` with `danger`/`warning`/`ok`/`mark`/`glow` keys.
- Produces: template slot map — `__KEYS__`=mark, `__SEP__`=dim, `__LOGO1__`=mark, `__LOGO2__`=glow, `__LOGO3__`=surface_container, `__LOGO4__`=surface_container_high, `__LOGO5__`=on_primary_container, `__LOGO6__`=outline, `__LOGO7__`=bright.

- [ ] **Step 1: Adopt the template**

```bash
mkdir -p ~/capsuleos/configs/fastfetch
cp ~/.config/fastfetch/config.jsonc.in ~/capsuleos/configs/fastfetch/config.jsonc.in
```

- [ ] **Step 2: Write the failing test**

```python
def test_fastfetch_slot_map():
    assert w.FASTFETCH_SLOTS == {
        "__KEYS__": "mark", "__SEP__": "dim",
        "__LOGO1__": "mark", "__LOGO2__": "glow",
        "__LOGO3__": "surface_container", "__LOGO4__": "surface_container_high",
        "__LOGO5__": "on_primary_container", "__LOGO6__": "outline",
        "__LOGO7__": "bright"}
```

- [ ] **Step 3: Run test to verify it fails** — Expected: AttributeError

- [ ] **Step 4: Implement**

In `render_fastfetch`, hoist the mapping to a module constant and build `repl` from it:

```python
FASTFETCH_SLOTS = {"__KEYS__": "mark", "__SEP__": "dim",
                   "__LOGO1__": "mark", "__LOGO2__": "glow",
                   "__LOGO3__": "surface_container",
                   "__LOGO4__": "surface_container_high",
                   "__LOGO5__": "on_primary_container", "__LOGO6__": "outline",
                   "__LOGO7__": "bright"}
```

```python
    repl = {"__GOLDENGATE__": str(ff / "goldengate.txt")}
    repl.update({slot: seq(pill[key]) for slot, key in FASTFETCH_SLOTS.items()})
```

- [ ] **Step 5: Run all tests** — Expected: all pass

- [ ] **Step 6: Commit**

```bash
cd ~/capsuleos && git add configs/fastfetch configs/hypr/scripts && git commit -m "feat: adopt fastfetch template into repo; remap slots across the trio"
```

---

### Task 9: QML — danger token, hardcoded reds, shimmer, fallback palettes

No pytest here (QML); each step carries its own check. Generate the new fallback set first, then re-point.

**Files:**
- Modify: `configs/quickshell/pill/Singletons/Dyn.qml:68-88`, `configs/quickshell/lock/Singletons/Dyn.qml:45-49`
- Modify: `configs/quickshell/pill/Singletons/Theme.qml` (accent vocabulary block, ~line 112)
- Modify: `configs/quickshell/pill/Pill.qml:1095`, `configs/quickshell/pill/Launcher.qml:400`, `configs/quickshell/pill/Recorder.qml:1366`, `configs/quickshell/pill/Osd.qml:491-493`
- Modify: `configs/ghostty/config:24-42` (static palette block), `installer/deploy.py:93-102` (`NIGHT_DEFAULT`)

**Interfaces:**
- Consumes: `wallcolors.build_palette` + `build_base16` (to print the representative fallback set).
- Produces: `Dyn.danger/warning/ok` adapter properties (default `""`), `Theme.danger` (falls back to `"#e0533f"` when dynamic colors are absent).

- [ ] **Step 1: Generate the representative fallback set**

Run (manual-mode default hue is 30 per `flags.json` `manualHue`):
`cd ~/capsuleos/configs/hypr/scripts && python3 -c "
import json, wallcolors as w
p = w.build_palette(30/360, 0.5, 0.12, True, bins=None, chroma_share=1.0)
t = w.build_base16(p, p.pop('trio'), True)
print(json.dumps(p, indent=2)); print(t['palette'])"`
Record the output — it is pasted into the next four steps. (Values are deterministic; re-run any time.)

- [ ] **Step 2: Update both `Dyn.qml` fallbacks + add status props**

In `pill/Singletons/Dyn.qml` replace each `property string <key>: "#…"` hex (lines 68–84) with the Step-1 value for that key, and append inside the `JsonAdapter`:

```qml
            // Empty by default so a pre-status colors.json falls back in Theme
            // instead of pinning stale reds onto a wallpaper palette.
            property string danger: ""
            property string warning: ""
            property string ok: ""
```

Mirror the five keys in `lock/Singletons/Dyn.qml:45-49` with the same Step-1 values (and add the same three status props).

Check: `grep -c 'property string' configs/quickshell/pill/Singletons/Dyn.qml` — expect 3 more than before (22).

- [ ] **Step 3: Expose `Theme.danger` and re-point the three reds**

In `pill/Singletons/Theme.qml`, next to the `mark`/`glow` tokens (~line 112):

```qml
    readonly property color danger: (dyn && Dyn.danger !== "") ? Dyn.danger : "#e0533f"
```

Then replace the literal `"#e0533f"` with `Theme.danger` at `Pill.qml:1095`, `Launcher.qml:400`, `Recorder.qml:1366`.

Check: `grep -rn 'e0533f' configs/quickshell/pill --include='*.qml'` → only the Theme.qml fallback remains (1 hit).

- [ ] **Step 4: Shimmer rides the glow**

In `Osd.qml:491-493`, the gradient's middle stop `"#55ffe6d6"` becomes a glow-derived stop; keep the transparent ends:

```qml
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.alpha(Theme.glow, 0.33) }
                        GradientStop { position: 1.0; color: "transparent" }
```

- [ ] **Step 5: Regenerate the static ghostty block and deploy.py NIGHT_DEFAULT**

In `configs/ghostty/config:24-42`: `cursor-color` = Step-1 `mark`; `palette = 0..15` lines = the Step-1 `t['palette']` list in order. Keep the `config-file = ?…` override line untouched.
In `installer/deploy.py` `NIGHT_DEFAULT`: replace each of the 8 values with the Step-1 value for the same key.

- [ ] **Step 6: Syntax-check QML**

Run: `qmllint ~/capsuleos/configs/quickshell/pill/Singletons/*.qml ~/capsuleos/configs/quickshell/pill/{Pill,Launcher,Recorder,Osd}.qml 2>&1 | grep -iE "error|syntax" | head`
Expected: no errors (warnings acceptable — match the pre-change baseline). If `qmllint` is absent, fall back to `qs -p ~/capsuleos/configs/quickshell/pill --check` or skip with a note.

- [ ] **Step 7: Commit**

```bash
cd ~/capsuleos && git add -u configs installer && git commit -m "feat: QML danger token, fallback palette regen, shimmer on glow"
```

---

### Task 10: fzf + bat follow the terminal

**Files:**
- Modify: `configs/zsh/zshrc:31-35` (fzf block)
- Create: `configs/bat/config`
- Modify: `installer/deploy.py:34-39` (`DEPLOY_SET`)

- [ ] **Step 1: fzf colors via ANSI slot indexes** (after the existing `FZF_DEFAULT_COMMAND` lines)

```zsh
export FZF_DEFAULT_OPTS="--color=fg:7,bg:-1,hl:6,fg+:15,bg+:0,hl+:14,info:8,border:8,prompt:4,pointer:12,marker:13,spinner:8,header:8"
```

(Indexes only — the palette flows through the terminal scheme; nothing to regenerate.)

- [ ] **Step 2: bat ansi theme**

```
# configs/bat/config
--theme="ansi"
```

- [ ] **Step 3: Register bat in the deploy set** — in `installer/deploy.py` `DEPLOY_SET`, after the fastfetch tuple:

```python
    ("bat",        "bat",                                   "bat"),
```

- [ ] **Step 4: Verify**

Run: `zsh -n ~/capsuleos/configs/zsh/zshrc && python3 -c "import ast; ast.parse(open('/home/wannabeartist/capsuleos/installer/deploy.py').read())" && echo OK`
Expected: `OK`

Also confirm the spec's "zshrc hardcodes no hex colors" check:
Run: `grep -cE '#[0-9a-fA-F]{6}' ~/capsuleos/configs/zsh/zshrc`
Expected: `0`

- [ ] **Step 5: Commit**

```bash
cd ~/capsuleos && git add configs/zsh configs/bat installer && git commit -m "feat: fzf and bat follow the terminal palette via ANSI"
```

---

### Task 11: Contact-sheet preview harness

**Files:**
- Create: `configs/hypr/scripts/palette-preview.py` (repo-only; never deployed — add a comment saying so)

**Interfaces:**
- Consumes: `wallcolors.analyze`, `build_palette`, `build_base16`.
- Produces: `palette-preview.py [outdir]` → writes `contact-sheet.png` (default outdir: cwd).

- [ ] **Step 1: Write the harness**

```python
#!/usr/bin/env python3
"""Contact-sheet preview for the anchored analogous palette. Repo-only tool:
never deployed, never called by the pipeline. For each wallpaper (real ones
from ~/CapsuleOS/wallpapers plus a synthetic set) it renders one row: thumb,
pill swatches, terminal mockup colors."""
import subprocess, sys, tempfile
from pathlib import Path
import wallcolors as w

SYNTH = {  # name -> magick args (64x64 is plenty for analyze())
    "pure-red":        ["xc:#c03030"],
    "orange-sunset":   ["gradient:#e07030-#301818"],
    "golden-hour":     ["gradient:#e0b040-#403010"],
    "chartreuse":      ["gradient:#a0c030-#203010"],
    "green-forest":    ["gradient:#307040-#102018"],
    "cyan-sea":        ["gradient:#30a0b0-#102830"],
    "blue-hour":       ["gradient:#3050a0-#101830"],
    "magenta-pink":    ["gradient:#c040a0-#301020"],
    "greyscale":       ["gradient:black-white"],
    "pastel":          ["xc:#c8c0d8"],
    "near-8pct":       ["-size", "64x64", "xc:#404040", "-fill", "#3060c0",
                       "-draw", "rectangle 0,0 6,63"],   # ~10% chromatic strip
    "two-peak":        ["-size", "64x64", "xc:#3050a0", "-fill", "#308090",
                       "-draw", "rectangle 32,0 63,63"],
}
SWATCH_KEYS = ["surface", "surface_container_highest", "outline",
               "primary_container", "mark", "glow", "danger", "warning", "ok",
               "cream", "dim"]

def render_row(name, wall_png, outdir):
    hue, sat, mean_l, bins, share = w.analyze(wall_png)
    chromatic = hue is not None
    if not chromatic:
        hue, sat = 0.09, 0.0
    pill = w.build_palette(hue, sat, mean_l, chromatic, bins=bins, chroma_share=share)
    term = w.build_base16(pill, pill.pop("trio"), chromatic)
    cells = [pill[k] for k in SWATCH_KEYS] + term["palette"][1:7] + term["palette"][9:15]
    row = outdir / f"row-{name}.png"
    args = ["magick", "(", wall_png, "-resize", "120x68^", "-gravity", "center",
            "-extent", "120x68", ")"]
    for c in cells:
        args += ["(", "-size", "34x68", f"xc:{c}", ")"]
    args += ["+append", "-bordercolor", "#000000", "-border", "0x2",
             "-fill", "#cccccc", "-pointsize", "13", "-gravity", "southwest",
             "-annotate", "+4+4", name, str(row)]
    subprocess.run(args, check=True)
    return row

def main():
    outdir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    outdir.mkdir(parents=True, exist_ok=True)
    rows = []
    with tempfile.TemporaryDirectory() as td:
        for name, spec in SYNTH.items():
            png = str(Path(td) / f"{name}.png")
            pre = [] if spec[0].startswith("-") else ["-size", "64x64"]
            subprocess.run(["magick"] + pre + spec + [png], check=True)
            rows.append(render_row(f"synth-{name}", png, outdir))
        walls = sorted(Path.home().glob("CapsuleOS/wallpapers/*"))
        for wp in walls:
            if wp.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
                rows.append(render_row(wp.stem[:24], str(wp), outdir))
    sheet = outdir / "contact-sheet.png"
    subprocess.run(["magick"] + [str(r) for r in rows] + ["-append", str(sheet)],
                   check=True)
    for r in rows:
        r.unlink()
    print(sheet)

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it**

Run: `cd ~/capsuleos/configs/hypr/scripts && python3 palette-preview.py /tmp/claude-1000/-home-wannabeartist/8056b89e-1618-406e-864a-a6d126105a30/scratchpad/preview`
Expected: prints the contact-sheet path; every synthetic row renders (a traceback on any wallpaper class is a real palette bug — fix it, don't skip the row).

- [ ] **Step 3: REVIEW GATE — send the contact sheet to the user.** Wait for approval of the visual result before Task 12. Iterate on constants (offsets, caps, bands) if the user asks; each iteration re-runs the pytest suite plus this preview.

- [ ] **Step 4: Commit**

```bash
cd ~/capsuleos && git add configs/hypr/scripts/palette-preview.py && git commit -m "feat: contact-sheet preview harness for palette validation"
```

---

### Task 13: Complementary punch accent (user addition; executes BEFORE Task 12)

**Files:**
- Modify: `configs/hypr/scripts/wallcolors.py` (`build_palette` tail, `build_base16` cursor), `configs/hypr/scripts/test_wallcolors.py`, `configs/zsh/zshrc` (fzf pointer), `configs/ghostty/config` (static cursor-color)

**Interfaces:**
- Produces: `colors.json` key `accent` — hue = dominant+180°, Light band, frost-clamped; achromatic → neutral. `build_base16` cursor = `pill["accent"]`.

- [ ] **Step 1: Tests.** Add to test_wallcolors.py:

```python
def test_accent_complementary_and_punchy():
    p = w.build_palette(**FLOWER, bins={}, chroma_share=1.0)
    h, s, _ = _hue_of(p["accent"])
    assert abs(w.signed_arc(h, (p["trio"]["dominant"] + 180) % 360)) < 2
    lo, _ = w.light_band(p["surface"])
    assert w.rel_luminance(p["accent"]) >= lo - 0.01

def test_accent_achromatic_neutral():
    p = w.build_palette(0.09, 0.0, 0.3, False, bins={}, chroma_share=0.0)
    _, s, _ = _hue_of(p["accent"])
    assert s < 0.1
```

And amend `test_terminal_ramp_slots`: `assert t["cursor"] == p["mark"]` becomes `assert t["cursor"] == p["accent"]`.

- [ ] **Step 2: Run — new tests fail, cursor assertion fails.**

- [ ] **Step 3: Implement.** In `build_palette`, after the status-token loop, before `return pill`:

```python
    # Complementary punch: the one pop against the analogous field.
    comp = (dom + 180.0) % 360.0
    if chromatic:
        acc = snap_to_band(tint_deg(comp, sat_cap(comp, ACC_SAT_CAP), 0.55),
                           light_band(pill["surface"]))
        pill["accent"] = clamp_light(acc, MARK_CONTRAST, eff_surface)
    else:
        pill["accent"] = snap_to_band(tint_deg(comp, 0.05, 0.55),
                                      light_band(pill["surface"]))
```

In `build_base16`, the return dict's `"cursor": pill["mark"]` becomes `"cursor": pill["accent"]`.

In `configs/zsh/zshrc`, directly after the FZF_DEFAULT_OPTS export:

```zsh
[ -f "${XDG_CACHE_HOME:-$HOME/.cache}/capsuleos/colors.json" ] && command -v jq >/dev/null && \
  export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=pointer:$(jq -r .accent "${XDG_CACHE_HOME:-$HOME/.cache}/capsuleos/colors.json")"
```

In `configs/ghostty/config`, regenerate the static `cursor-color` line: run the Task-9 Step-1 generator command and paste the printed `accent` value.

- [ ] **Step 4: All 35 tests green; `zsh -n zshrc` clean.**

- [ ] **Step 5: Regenerate the contact sheet** (add `"accent"` to `SWATCH_KEYS` in palette-preview.py after `"glow"`) and re-run it to the scratchpad preview dir.

- [ ] **Step 6: Commit** — `git add -u configs && git commit -m "feat: complementary punch accent (token + cursor + fzf pointer)"`

---

### Task 12: Deploy to live + verify

Only after the Task 11 user gate. The live machine runs from `~/.config` (CapsuleOS deploy gotcha).

**Files:** none in repo — this task copies repo → live.

- [ ] **Step 1: Deploy changed configs**

```bash
cp ~/capsuleos/configs/hypr/scripts/{wallcolors.py,wallpaper.sh} ~/.config/hypr/scripts/
cp -r ~/capsuleos/configs/quickshell/pill/. ~/.config/quickshell/pill/
cp -r ~/capsuleos/configs/quickshell/lock/. ~/.config/quickshell/lock/
cp ~/capsuleos/configs/fastfetch/config.jsonc.in ~/.config/fastfetch/
cp ~/capsuleos/configs/ghostty/config ~/.config/ghostty/config
mkdir -p ~/.config/bat && cp ~/capsuleos/configs/bat/config ~/.config/bat/config
```

For the zshrc: the live file may carry local edits — diff first (`diff ~/capsuleos/configs/zsh/zshrc ~/.zshrc`); if only the fzf block differs, append the `FZF_DEFAULT_OPTS` line to `~/.zshrc` rather than overwriting.

- [ ] **Step 2: Regenerate live colors**

Run: `bash ~/.config/hypr/scripts/wallpaper.sh init`
Expected: exits 0; check `tail -5 ~/.local/state/capsuleos/wallcolors.log` for no tracebacks.

- [ ] **Step 3: Verify each consumer**

```bash
python3 -c "import json; d=json.load(open('/home/wannabeartist/.cache/capsuleos/colors.json')); print([d[k] for k in ('danger','warning','ok','mark','glow')])"
grep -c "palette = " ~/.cache/capsuleos/ghostty-colors      # expect 16
grep inactive ~/.cache/capsuleos/hypr-colors.lua            # a surface-ramp hex
head -3 ~/.config/fastfetch/config.jsonc                    # rendered, no __SLOTS__
```

Then by eye (user): pill colors, a ghostty window (`fastfetch`, `ls`, a git diff, `fzf` via ctrl-T, `bat` on a source file), lock screen.

- [ ] **Step 4: Final commit + report**

```bash
cd ~/capsuleos && git status --short   # expect clean; commit any stragglers
```

Report results honestly — anything that looks wrong goes back through Task 11's iterate loop, not hand-tuned live.
