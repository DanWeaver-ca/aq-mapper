"""Paper figure: smoke day vs clear day on one health-band scale.

Two Home-Base-style panels (CARTO positron basemap, the app's PM2.5 band
colours) from the real class data. Student data itself is NOT in the repo
(student_measurements_2026/ is gitignored); point --data at it.

Run:  python3 make_fig_smoke_vs_clean.py [--data DIR] [-o OUT.png]
Tiles are fetched once and cached beside the output (internet needed on
first run). © CARTO, © OpenStreetMap contributors — attribution is drawn
into the figure, as required.
"""
import argparse
import io
import math
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "classroom_map"))
import home_base as hb  # noqa: E402

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import matplotlib  # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.colors import BoundaryNorm, ListedColormap  # noqa: E402
from PIL import Image  # noqa: E402

PM = "PM2.5(ug/m3)"
ZOOM = 15
TILE_URL = "https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png"
# Union bbox of the class routes, with margin (lat_min, lat_max, lon_min, lon_max)
BBOX = (43.7775, 43.7915, -79.1985, -79.1775)

SMOKE = ("2026-07-15", "15 July 2026 — wildfire smoke (N95s issued)")
CLEAR = ("2026-08-12", "12 August 2026 — clear day")


def is_staff(g):
    g = str(g).strip().lower()
    return g == "dw test" or g.startswith("ta-") or g.startswith("ta_")


def load_day(base, day):
    df, _, _ = hb.load_folder(os.path.join(base, day))
    df["_when"] = pd.to_datetime(df["DATE"], errors="coerce")
    df = df[df["_when"].dt.date.astype(str) == day]
    df = df[~df["GROUP"].map(is_staff)].copy()
    df[PM] = pd.to_numeric(df[PM], errors="coerce")
    df["LATITUDE"] = df["LATITUDE"].astype(float)
    df["LONGITUDE"] = df["LONGITUDE"].astype(float)
    return df.dropna(subset=[PM, "LATITUDE", "LONGITUDE"])


def merc(lat, lon, z):
    n = 2.0 ** z
    x = (lon + 180.0) / 360.0 * n
    r = math.radians(lat)
    y = (1.0 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2.0 * n
    return x, y


def fetch_basemap(cache_dir):
    """Stitch cached CARTO tiles covering BBOX; returns (image, extent in
    fractional tile coords (x0, x1, y0, y1))."""
    os.makedirs(cache_dir, exist_ok=True)
    x0f, y1f = merc(BBOX[0], BBOX[2], ZOOM)   # south-west
    x1f, y0f = merc(BBOX[1], BBOX[3], ZOOM)   # north-east
    xs = range(int(x0f), int(x1f) + 1)
    ys = range(int(y0f), int(y1f) + 1)
    tile_px = 512  # @2x tiles
    mosaic = Image.new("RGB", (len(list(xs)) * tile_px,
                               len(list(ys)) * tile_px))
    for i, xt in enumerate(xs):
        for j, yt in enumerate(ys):
            path = os.path.join(cache_dir, f"{ZOOM}_{xt}_{yt}.png")
            if not os.path.exists(path):
                url = TILE_URL.format(z=ZOOM, x=xt, y=yt)
                req = urllib.request.Request(
                    url, headers={"User-Agent": "aq-mapper-paper-figure"})
                with urllib.request.urlopen(req, timeout=20) as resp:
                    data = resp.read()
                with open(path, "wb") as fh:
                    fh.write(data)
            mosaic.paste(Image.open(path).convert("RGB"),
                         (i * tile_px, j * tile_px))
    extent = (min(xs), max(xs) + 1, max(ys) + 1, min(ys))  # x0,x1,y1,y0
    return mosaic, extent


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(
        HERE, "..", "..", "student_measurements_2026"))
    ap.add_argument("-o", "--out",
                    default=os.path.join(HERE, "fig_smoke_vs_clean.png"))
    args = ap.parse_args()

    v = hb.VARS[0]
    cmap = ListedColormap(v["colors"])
    bounds = [0] + list(v["thr"]) + [80]
    norm = BoundaryNorm(bounds, cmap.N)

    basemap, ext = fetch_basemap(os.path.join(HERE, "_tile_cache"))

    fig, axes = plt.subplots(1, 2, figsize=(12.6, 5.6))
    days = [(axes[0], *SMOKE), (axes[1], *CLEAR)]
    for ax, day, title in days:
        d = load_day(args.data, day)
        ax.imshow(basemap, extent=ext, interpolation="bilinear")
        xy = np.array([merc(la, lo, ZOOM) for la, lo in
                       zip(d["LATITUDE"], d["LONGITUDE"])])
        vals = np.clip(d[PM].to_numpy(), 0, 79.9)
        indoor = (d["LOCATION_TYPE"] == "indoor").to_numpy()
        sc = ax.scatter(xy[~indoor, 0], xy[~indoor, 1], c=vals[~indoor],
                        cmap=cmap, norm=norm, s=55, edgecolor="white",
                        linewidth=1.0, zorder=3, label="outdoor")
        ax.scatter(xy[indoor, 0], xy[indoor, 1], c=vals[indoor], cmap=cmap,
                   norm=norm, s=55, marker="s", edgecolor="black",
                   linewidth=1.0, zorder=3, label="indoor")
        out_median = d.loc[~indoor, PM].median()
        ax.set_title(f"{title}\noutdoor median {out_median:.0f} µg/m³",
                     fontsize=11)
        # crop to bbox
        xw, ys_ = merc(BBOX[1], BBOX[2], ZOOM)
        xe, yn = merc(BBOX[0], BBOX[3], ZOOM)
        ax.set_xlim(xw, xe)
        ax.set_ylim(yn, ys_)  # y grows southward in tile coords
        ax.set_xticks([]); ax.set_yticks([])
        # 500 m scale bar (tile-x units per metre at this latitude)
        lat_mid = (BBOX[0] + BBOX[1]) / 2
        m_per_tile = 40075016.686 * math.cos(math.radians(lat_mid)) / 2**ZOOM
        bar = 500 / m_per_tile
        bx, by = xw + 0.06 * (xe - xw), yn - 0.06 * (yn - ys_)
        ax.plot([bx, bx + bar], [by, by], color="#222", lw=3, zorder=4)
        ax.plot([bx, bx], [by - 0.006, by + 0.006], color="#222", lw=3,
                zorder=4)
        ax.plot([bx + bar, bx + bar], [by - 0.006, by + 0.006], color="#222",
                lw=3, zorder=4)
        ax.text(bx + bar / 2, by + 0.012, "500 m", ha="center", fontsize=9,
                color="#222", zorder=4,
                bbox=dict(fc="white", alpha=0.7, ec="none", pad=1))
        ax.legend(loc="lower right", fontsize=8, framealpha=0.9)
        ax.text(0.995, 0.005, "© CARTO © OpenStreetMap contributors",
                transform=ax.transAxes, ha="right", va="bottom", fontsize=6,
                color="#666",
                bbox=dict(fc="white", alpha=0.6, ec="none", pad=1))

    # annotate the deliberate cigarette-smoke sample on the clear panel
    d3 = load_day(args.data, CLEAR[0])
    hot = d3.loc[d3[PM].idxmax()]
    hx, hy = merc(hot["LATITUDE"], hot["LONGITUDE"], ZOOM)
    axes[1].annotate(f"{hot[PM]:.0f} µg/m³ —\nheld beside a cigarette",
                     xy=(hx, hy), xytext=(12, 26),
                     textcoords="offset points", fontsize=8.5,
                     arrowprops=dict(arrowstyle="->", color="#222", lw=1),
                     bbox=dict(fc="white", alpha=0.85, ec="#999", pad=2),
                     zorder=5)

    cb = fig.colorbar(sc, ax=axes, fraction=0.03, pad=0.015,
                      ticks=v["thr"], spacing="proportional")
    cb.set_label("PM2.5 (µg/m³) — health bands, matching the app legend",
                 fontsize=10)
    fig.suptitle("The same campus, four weeks apart — one colour scale",
                 fontsize=14)
    fig.savefig(args.out, dpi=250, bbox_inches="tight")
    print("wrote", args.out)


if __name__ == "__main__":
    main()
