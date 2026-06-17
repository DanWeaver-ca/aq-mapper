"""Generate synthetic AQ Mapper CSV exports for prototyping the classroom map.

Writes one app-format CSV per group into sample_csvs/, each with a plausible
walking route through a different part of UTSC and a spatial pollution field
(higher near roads / indoors, lower in the woods). Purely for the Plotly
prototype — not real data.
"""
import csv
import math
import os
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "sample_csvs")
os.makedirs(OUT, exist_ok=True)

HEADERS = [
    "DATE", "PM2.5(ug/m3)", "PM10(ug/m3)", "PARTICLES(per/L)", "CO2(ppm)",
    "HCHO(mg/m3)", "TEMPERATURE", "HUMIDITY(%)", "TEMPUNIT",
    "LATITUDE", "LONGITUDE", "GROUP", "DEVICE", "LOCATION_TYPE",
    "PM2.5_VAR(ug/m3)", "PM10_VAR(ug/m3)", "CO2_VAR(ppm)", "HCHO_VAR(mg/m3)",
    "TEMPERATURE_VAR", "HUMIDITY_VAR(%)", "UID", "NOTES",
]

UTSC = (43.7841, -79.1873)
rng = np.random.default_rng(42)

# Pollution hotspots (lat, lon, strength) — e.g. Military Trail road, a parking
# lot — that raise nearby PM2.5/CO2.
HOTSPOTS = [
    (43.7855, -79.1865, 22),   # road along the north edge
    (43.7828, -79.1840, 16),   # parking / loading
]

# Each group walks a short route (start, end) in a different sector, indoors or
# out, so filtering to one group visibly jumps to its part of campus.
GROUPS = [
    dict(name="Group 1", dev="UTSC-AQMS-01", indoor=False,
         a=(43.7860, -79.1905), b=(43.7852, -79.1882), note="north woods"),
    dict(name="Group 2", dev="UTSC-AQMS-02", indoor=False,
         a=(43.7858, -79.1862), b=(43.7840, -79.1858), note="Military Trail"),
    dict(name="Group 3", dev="UTSC-AQMS-03", indoor=True,
         a=(43.7835, -79.1878), b=(43.7842, -79.1888), note="Student Centre"),
    dict(name="Group 4", dev="UTSC-AQMS-04", indoor=False,
         a=(43.7825, -79.1845), b=(43.7820, -79.1872), note="south valley"),
    dict(name="Group 5", dev="UTSC-AQMS-05", indoor=True,
         a=(43.7845, -79.1870), b=(43.7849, -79.1860), note="science wing"),
]


def pm_field(lat, lon, indoor):
    base = 5.0
    for hlat, hlon, strength in HOTSPOTS:
        d = math.hypot((lat - hlat) * 111000, (lon - hlon) * 82000)  # meters
        base += strength * math.exp(-(d / 120.0) ** 2)
    if indoor:
        base += 6.0  # cooking / poor ventilation
    return max(1.0, base + rng.normal(0, 1.2))


def co2_field(indoor):
    return (rng.normal(950, 130) if indoor else rng.normal(430, 18))


for gi, g in enumerate(GROUPS):
    rows = []
    n = int(rng.integers(16, 24))
    for i in range(n):
        t = i / max(1, n - 1)
        lat = g["a"][0] + (g["b"][0] - g["a"][0]) * t + rng.normal(0, 0.00018)
        lon = g["a"][1] + (g["b"][1] - g["a"][1]) * t + rng.normal(0, 0.00018)
        pm25 = pm_field(lat, lon, g["indoor"])
        pm10 = pm25 * rng.uniform(1.4, 1.8)
        particles = int(pm25 * rng.uniform(120, 180))
        co2 = co2_field(g["indoor"])
        hcho = max(0.0, rng.normal(0.06 if g["indoor"] else 0.02, 0.012))
        temp = rng.normal(23.5 if g["indoor"] else 21.0, 0.8)
        humidity = rng.normal(45 if g["indoor"] else 58, 4)
        minute = 8 + i  # spread across the lab period
        date = f"2026-06-10 10:{minute:02d}:{int(rng.integers(0,60)):02d}"
        rows.append([
            date, round(pm25, 1), round(pm10, 1), particles, round(co2),
            round(hcho, 3), round(temp, 1), round(humidity, 1), "C",
            f"{lat:.6f}", f"{lon:.6f}", g["name"], g["dev"],
            "indoor" if g["indoor"] else "outdoor",
            round(rng.uniform(0.5, 2.0), 1), round(rng.uniform(1, 3), 1),
            round(rng.uniform(5, 25)), round(rng.uniform(0.002, 0.01), 3),
            round(rng.uniform(0.1, 0.4), 1), round(rng.uniform(1, 4), 1),
            f"{g['dev']}-{1000+i}-{gi}", g["note"],
        ])
    path = os.path.join(OUT, f"group_{gi+1:02d}.csv")
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(HEADERS)
        w.writerows(rows)
    print(f"wrote {path} ({len(rows)} rows)")
