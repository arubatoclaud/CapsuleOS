import wallcolors as w
import subprocess, tempfile, os, colorsys

FLOWER = dict(hue=216/360, sat=0.61, mean_l=0.08, chromatic=True)

def _img(spec, size="64x64"):
    f = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
    subprocess.run(["magick", "-size", size] + spec + [f.name], check=True)
    return f.name

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
