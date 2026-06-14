"""Pre-download OpenStreetMap tiles for the UTSC campus so the app's map works
offline in the field. Writes flat-named PNGs to assets/tiles/<z>_<x>_<y>.png
(flat because Flutter's pubspec can't glob nested asset folders).

The OfflineFirstTileProvider serves these bundled tiles first and falls back to
the live tile server for anything not pre-downloaded. Re-run to refresh/extend.

Usage:  python3 download_campus_tiles.py
"""
import math
import os
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "tiles")
os.makedirs(OUT, exist_ok=True)

# Campus bounding box (a bit beyond UTSC: woods, valley, roads) and the zoom
# levels students actually use. 18 is omitted to keep the bundle small (~2MB);
# add it here if you want building-level detail offline.
LAT_MIN, LAT_MAX = 43.776, 43.793
LON_MIN, LON_MAX = -79.198, -79.176
ZOOMS = [14, 15, 16, 17]
TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
# OSM tile policy requires a descriptive User-Agent; this is a one-time, small,
# bounded download for an educational app — well within fair use.
UA = "AQMapper-UTSC-campus-precache/1.0 (educational; contact UTSC)"


def deg2tile(lat, lon, z):
    n = 2 ** z
    x = int((lon + 180.0) / 360.0 * n)
    y = int((1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * n)
    return x, y


total, fetched, skipped = 0, 0, 0
for z in ZOOMS:
    x0, y1 = deg2tile(LAT_MIN, LON_MIN, z)  # bottom-left -> min x, max y
    x1, y0 = deg2tile(LAT_MAX, LON_MAX, z)  # top-right   -> max x, min y
    for x in range(min(x0, x1), max(x0, x1) + 1):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            total += 1
            dest = os.path.join(OUT, f"{z}_{x}_{y}.png")
            if os.path.exists(dest):
                skipped += 1
                continue
            url = TILE_URL.format(z=z, x=x, y=y)
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            try:
                with urllib.request.urlopen(req, timeout=20) as r:
                    open(dest, "wb").write(r.read())
                fetched += 1
                time.sleep(0.1)  # be polite to the tile server
            except Exception as e:
                print(f"  failed {z}/{x}/{y}: {e}")

size_mb = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT)
              if f.endswith(".png")) / 1048576
print(f"tiles: {total} in bbox | fetched {fetched}, already had {skipped}")
print(f"assets/tiles total: {len(os.listdir(OUT))} files, {size_mb:.1f} MB")
