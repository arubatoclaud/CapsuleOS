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
               "primary_container", "mark", "glow", "accent", "danger", "warning", "ok",
               "cream", "dim"]

def render_row(name, wall_png, outdir):
    hue, sat, mean_l, bins, share = w.analyze(wall_png)
    chromatic = hue is not None
    if not chromatic:
        hue, sat = 0.09, 0.0
    pill = w.build_palette(hue, sat, mean_l, chromatic, bins=bins, chroma_share=share)
    ramp = w.chroma_ramp(share) if chromatic else 0.0
    term = w.build_base16(pill, pill.pop("trio"), chromatic, ramp)
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
