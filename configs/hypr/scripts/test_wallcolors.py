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
