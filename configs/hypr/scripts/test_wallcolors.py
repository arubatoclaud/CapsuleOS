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
