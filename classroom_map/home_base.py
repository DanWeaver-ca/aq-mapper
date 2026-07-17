"""Home Base — the one-window classroom dashboard for the lab debrief.

Reads a folder of AQ Mapper CSV exports and writes classroom_dashboard.html:
a single self-contained page with four tabs (Map · Interpolated · Heatmap ·
Stats), a header showing points/groups/indoor-outdoor counts, and a group
checklist so you can see at a glance who has reported and who is missing.

This supersedes the four separate windows written by build_map.py, which is
kept unchanged as the v1 reference — the figures and colours here match it.
Only the map background tiles need internet; everything else is embedded.

Usage:
  python3 home_base.py [csv_dir] [-o OUT.html]
                       [--expect N | --roster FILE] [--title TITLE]

  --expect 25        checklist expects groups named "Group 1".."Group 25"
  --roster file.txt  checklist expects the group names listed one per line
  (neither)          checklist simply lists the groups that have reported

CSV handling is deliberately forgiving of real classroom files: UTF-8 BOMs
(Excel re-saves), missing optional columns from older app versions, and one
bad file skips with a visible note instead of killing the whole build.
"""
import argparse
import base64
import glob
import io
import json
import os
import sys
from datetime import datetime
from html import escape

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import plotly.io as pio
from plotly.offline import get_plotlyjs
from plotly.subplots import make_subplots
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def _default_title():
    """Header title from /deploy.config.json (EVENT_TITLE) when the repo is
    present; the hub also runs standalone (folder copied to a laptop), so
    fall back to the UTSC reference title. --title always wins."""
    path = os.environ.get("AQ_CONFIG",
                          os.path.join(HERE, "..", "deploy.config.json"))
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh).get("EVENT_TITLE") or "UTSC Air Quality"
    except Exception:
        return "UTSC Air Quality"


# A clean, low-clutter basemap so the data points stand out (the detailed OSM
# style scatters parking/transit markers that compete with the readings).
BASEMAP = "carto-positron"

# Toolbar config: a high-res "download as image" camera button.
IMG_CONFIG = {"displaylogo": False, "scrollZoom": True,
              "toImageButtonOptions": {"format": "png", "scale": 2,
                                       "filename": "aq_class_map"}}

# Material colours used by the app's MapVariable bands.
G, O, D, R, B = "#4CAF50", "#FF9800", "#FF5722", "#F44336", "#2196F3"

# Perceptual scale for "spread" colouring + the interpolated field (viridis).
VIRIDIS_STOPS = [(0.0, (68, 1, 84)), (0.25, (59, 82, 139)),
                 (0.5, (33, 145, 140)), (0.75, (94, 201, 98)),
                 (1.0, (253, 231, 37))]
VIRIDIS = [[p, f"rgb{rgb}"] for p, rgb in VIRIDIS_STOPS]

# Per variable: csv column, label, unit, band thresholds (upper bounds), band
# colours (len = thresholds+1), and the colour-axis display range. Mirrors
# lib/models/map_variable.dart — keep in sync if the app changes.
VARS = [
    dict(col="PM2.5(ug/m3)", label="PM2.5", unit="µg/m³",
         thr=[12, 35, 55], colors=[G, O, D, R], cmin=0, cmax=80),
    dict(col="PM10(ug/m3)", label="PM10", unit="µg/m³",
         thr=[25, 50, 100], colors=[G, O, D, R], cmin=0, cmax=140),
    dict(col="CO2(ppm)", label="CO₂", unit="ppm",
         thr=[800, 1000, 1500], colors=[G, O, D, R], cmin=400, cmax=2000),
    dict(col="HCHO(mg/m3)", label="HCHO", unit="mg/m³",
         thr=[0.04, 0.08, 0.1], colors=[G, O, D, R], cmin=0, cmax=0.15),
    dict(col="TEMPERATURE", label="Temp", unit="°C",
         thr=[15, 24, 30], colors=[B, G, O, R], cmin=5, cmax=35),
    dict(col="HUMIDITY(%)", label="RH", unit="%",
         thr=[30, 60, 80], colors=[B, G, O, R], cmin=10, cmax=100),
]

REQUIRED_COLS = ["LATITUDE", "LONGITUDE", "GROUP", "UID"]
HOVER_COLS = ["GROUP", "DEVICE", "LOCATION_TYPE", "PM2.5(ug/m3)",
              "PM10(ug/m3)", "PARTICLES(per/L)", "CO2(ppm)", "HCHO(mg/m3)",
              "TEMPERATURE", "HUMIDITY(%)"]
HOVER = ("<b>%{customdata[0]}</b> · %{customdata[1]} · %{customdata[2]}<br>"
         "PM2.5 %{customdata[3]} µg/m³ · PM10 %{customdata[4]}<br>"
         "Particles %{customdata[5]} /L<br>"
         "CO₂ %{customdata[6]} ppm · HCHO %{customdata[7]} mg/m³<br>"
         "Temp %{customdata[8]} °C · RH %{customdata[9]} %<extra></extra>")

GRIDN = 160  # interpolation grid resolution


# --- shared helpers (ported unchanged from build_map.py) -------------------

def stepped_scale(thr, colors, cmin, cmax):
    """A piecewise-constant colourscale reproducing the discrete health bands."""
    span = cmax - cmin
    stops = [[0.0, colors[0]]]
    for i, t in enumerate(thr):
        p = min(1.0, max(0.0, (t - cmin) / span))
        stops.append([p, colors[i]])
        stops.append([p, colors[i + 1]])
    stops.append([1.0, colors[-1]])
    return stops


def robust_range(series):
    """5th–95th percentile range, so one bad outlier (e.g. a cell-tower GPS
    point) doesn't blow out the colour scale."""
    s = pd.to_numeric(series, errors="coerce").dropna()
    if len(s) == 0:
        return 0.0, 1.0
    lo, hi = float(s.quantile(0.05)), float(s.quantile(0.95))
    if hi - lo < 1e-9:
        m = float(s.mean())
        lo, hi = m - 0.5, m + 0.5
    return round(lo, 3), round(hi, 3)


def viridis_rgb(norm):
    """Map a [0,1] array to RGB uint8 via VIRIDIS_STOPS (no matplotlib dep)."""
    ps = np.array([p for p, _ in VIRIDIS_STOPS])
    cs = np.array([c for _, c in VIRIDIS_STOPS], dtype=float)
    out = np.empty(norm.shape + (3,), dtype=float)
    for ch in range(3):
        out[..., ch] = np.interp(norm, ps, cs[:, ch])
    return out.astype(np.uint8)


def _coords(df):
    p = df.dropna(subset=["LATITUDE", "LONGITUDE"])
    return (p["LATITUDE"].to_numpy(float), p["LONGITUDE"].to_numpy(float),
            float(np.cos(np.radians(p["LATITUDE"].mean()))))


def median_spacing(df):
    """Median nearest-neighbour distance of the samples (cos-lat scaled)."""
    lat, lon, coslat0 = _coords(df)
    if len(lat) < 2:
        return 0.003
    P = np.column_stack([lon * coslat0, lat])
    nn = [np.sqrt(((P - P[i]) ** 2).sum(1))[np.arange(len(P)) != i].min()
          for i in range(len(P))]
    return float(np.median(nn))


def make_grid(df, pad):
    """A lat/lon grid over the data, padded so the field can fade fully to
    transparent before the image edge (no hard boundary)."""
    lat, lon, coslat0 = _coords(df)
    plat, plon = pad, pad / coslat0
    latmin, latmax = lat.min() - plat, lat.max() + plat
    lonmin, lonmax = lon.min() - plon, lon.max() + plon
    glat = np.linspace(latmax, latmin, GRIDN)   # row 0 = north
    glon = np.linspace(lonmin, lonmax, GRIDN)
    LonG, LatG = np.meshgrid(glon, glat)
    return LonG, LatG, coslat0, (latmin, latmax, lonmin, lonmax)


def gaussian_field(df, col, r, LonG, LatG, coslat0):
    """Gaussian-weighted interpolation with smoothing radius r (the GISTEMP
    analogue). Returns the field and a fade mask (transparent where the
    nearest sample is well beyond r)."""
    p = df.dropna(subset=[col, "LATITUDE", "LONGITUDE"])
    lat = p["LATITUDE"].to_numpy(float)
    lon = p["LONGITUDE"].to_numpy(float)
    z = pd.to_numeric(p[col], errors="coerce").to_numpy(float)
    num = np.zeros_like(LonG)
    den = np.zeros_like(LonG)
    nearest = np.full_like(LonG, np.inf)
    for la, lo, zz in zip(lat, lon, z):
        d = np.sqrt(((LonG - lo) * coslat0) ** 2 + (LatG - la) ** 2)
        nearest = np.minimum(nearest, d)
        w = np.exp(-(d / r) ** 2)
        num += w * zz
        den += w
    field = num / np.where(den > 0, den, 1)
    fade = np.exp(-(nearest / (1.3 * r)) ** 2)
    return field, fade


def field_datauri(field, fade, lo, hi):
    norm = np.clip((field - lo) / (hi - lo + 1e-9), 0, 1)
    rgba = np.empty(field.shape + (4,), dtype=np.uint8)
    rgba[..., :3] = viridis_rgb(norm)
    rgba[..., 3] = (np.clip(fade, 0, 1) * 0.62 * 255).astype(np.uint8)
    buf = io.BytesIO()
    Image.fromarray(rgba, "RGBA").save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


# --- loading (forgiving of real classroom files) ---------------------------

def load_folder(csv_dir):
    """Read every CSV in csv_dir. Returns (df, n_files_ok, skipped) where
    skipped is a list of (filename, reason). One bad file never kills the
    build — it is reported in the dashboard header instead."""
    files = sorted(glob.glob(os.path.join(csv_dir, "*.csv")))
    if not files:
        sys.exit(f"No CSVs found in {csv_dir}")
    frames, skipped = [], []
    for f in files:
        name = os.path.basename(f)
        try:
            # utf-8-sig strips the BOM Excel adds when a student re-saves.
            d = pd.read_csv(f, encoding="utf-8-sig")
            missing = [c for c in REQUIRED_COLS if c not in d.columns]
            if missing:
                raise ValueError(
                    "missing column(s) " + ", ".join(missing) +
                    " — is this a raw Temtop file instead of an app export?")
            frames.append(d)
        except Exception as e:  # noqa: BLE001 — report anything, keep going
            skipped.append((name, str(e)[:160]))
    if not frames:
        sys.exit("No readable app exports found:\n  " +
                 "\n  ".join(f"{n}: {r}" for n, r in skipped))

    df = pd.concat(frames, ignore_index=True)
    df = df.drop_duplicates(subset="UID")
    # Older app versions may lack newer columns — fill so hover/stats work.
    for c in set(c["col"] for c in VARS) | set(HOVER_COLS):
        if c not in df.columns:
            df[c] = np.nan
    for v in VARS:
        df[v["col"]] = pd.to_numeric(df[v["col"]], errors="coerce")
    df["LATITUDE"] = pd.to_numeric(df["LATITUDE"], errors="coerce")
    df["LONGITUDE"] = pd.to_numeric(df["LONGITUDE"], errors="coerce")
    df = df.dropna(subset=["LATITUDE", "LONGITUDE"])
    if df.empty:
        sys.exit("The CSVs contained no rows with GPS coordinates.")
    df["LOCATION_TYPE"] = df["LOCATION_TYPE"].fillna("").astype(str).str.lower()
    df["GROUP"] = df["GROUP"].fillna("(no group)").astype(str)
    return df, len(files) - len(skipped), skipped


# --- the four figures (ported from build_map.py) ---------------------------

def build_points_fig(df, groups, ctr):
    """Points map: Show dropdown (All/Outdoor/Indoor/per-group) + Colour-by
    dropdown with a health-bands and a spread mode per variable."""
    default = VARS[0]
    traces = []
    for g in groups:
        for setting in ("outdoor", "indoor"):
            gd = df[(df["GROUP"] == g) & (df["LOCATION_TYPE"] == setting)]
            if not gd.empty:
                traces.append((g, setting, gd))

    fig = go.Figure()
    for g, setting, gd in traces:
        fig.add_trace(go.Scattermap(
            lat=gd["LATITUDE"], lon=gd["LONGITUDE"], mode="markers",
            name=f"{g} · {setting}", showlegend=False,
            marker=dict(size=13, opacity=0.92, color=gd[default["col"]],
                        coloraxis="coloraxis"),
            customdata=gd[HOVER_COLS].values, hovertemplate=HOVER))

    n_out = int((df["LOCATION_TYPE"] == "outdoor").sum())
    n_in = int((df["LOCATION_TYPE"] == "indoor").sum())

    def visible_for(predicate):
        return [predicate(g, s) for (g, s, _) in traces]

    show_buttons = [
        dict(label=f"All groups ({len(df)})", method="restyle",
             args=[{"visible": visible_for(lambda g, s: True)}]),
        dict(label=f"Outdoor ({n_out})", method="restyle",
             args=[{"visible": visible_for(lambda g, s: s == "outdoor")}]),
        dict(label=f"Indoor ({n_in})", method="restyle",
             args=[{"visible": visible_for(lambda g, s: s == "indoor")}]),
    ]
    for g in groups:
        n = int((df["GROUP"] == g).sum())
        show_buttons.append(dict(
            label=f"{g} ({n})", method="restyle",
            args=[{"visible": visible_for(lambda gg, s, g=g: gg == g)}]))

    var_buttons = []
    for v in VARS:
        vals = [gd[v["col"]].tolist() for (_, _, gd) in traces]
        health = stepped_scale(v["thr"], v["colors"], v["cmin"], v["cmax"])
        var_buttons.append(dict(
            label=f"{v['label']} · health bands", method="update",
            args=[{"marker.color": vals},
                  {"coloraxis.colorscale": health,
                   "coloraxis.cmin": v["cmin"], "coloraxis.cmax": v["cmax"],
                   "coloraxis.colorbar.tickvals": v["thr"],
                   "coloraxis.colorbar.ticktext": [str(t) for t in v["thr"]],
                   "coloraxis.colorbar.title.text":
                       f"{v['label']}<br>{v['unit']}"}]))
        lo, hi = robust_range(df[v["col"]])
        var_buttons.append(dict(
            label=f"{v['label']} · spread", method="update",
            args=[{"marker.color": vals},
                  {"coloraxis.colorscale": VIRIDIS,
                   "coloraxis.cmin": lo, "coloraxis.cmax": hi,
                   "coloraxis.colorbar.tickvals": None,
                   "coloraxis.colorbar.ticktext": None,
                   "coloraxis.colorbar.title.text":
                       f"{v['label']} ({v['unit']})<br>spread"}]))

    fig.update_layout(
        map=dict(style=BASEMAP, center=ctr, zoom=14.4),
        coloraxis=dict(
            colorscale=stepped_scale(default["thr"], default["colors"],
                                     default["cmin"], default["cmax"]),
            cmin=default["cmin"], cmax=default["cmax"],
            colorbar=dict(
                title=dict(text=f"{default['label']}<br>{default['unit']}"),
                tickvals=default["thr"],
                ticktext=[str(t) for t in default["thr"]],
                thickness=16, len=0.7, y=0.5)),
        margin=dict(l=0, r=0, t=40, b=0),
        updatemenus=[
            dict(buttons=show_buttons, x=0.01, xanchor="left", y=0.99,
                 yanchor="top", bgcolor="white", bordercolor="#bbb",
                 showactive=True),
            dict(buttons=var_buttons, x=0.16, xanchor="left", y=0.99,
                 yanchor="top", bgcolor="white", bordercolor="#bbb",
                 showactive=True),
        ],
        annotations=[
            dict(text="Show", x=0.01, xref="paper", y=1.0, yref="paper",
                 yanchor="bottom", showarrow=False,
                 font=dict(size=11, color="#666")),
            dict(text="Colour by", x=0.16, xref="paper", y=1.0, yref="paper",
                 yanchor="bottom", showarrow=False,
                 font=dict(size=11, color="#666")),
        ],
    )
    return fig


def build_heatmap_fig(df, ctr):
    heat = px.density_map(
        df, lat="LATITUDE", lon="LONGITUDE", z="PM2.5(ug/m3)", radius=28,
        center=ctr, zoom=14.4, map_style=BASEMAP,
        color_continuous_scale="Turbo")
    heat.update_layout(margin=dict(l=0, r=0, t=40, b=0),
                       title=dict(text="PM2.5 density — all groups",
                                  x=0.5, xanchor="center",
                                  font=dict(size=14)))
    return heat


def build_stats_fig(df, groups):
    def setting_mean(col, setting):
        sel = df[df["LOCATION_TYPE"] == setting][col]
        return round(float(sel.mean()), 1) if sel.notna().any() else None

    def cell(x):
        return "–" if pd.isna(x) else round(float(x), 1)

    stats = make_subplots(
        rows=2, cols=2,
        specs=[[{"type": "xy"}, {"type": "xy"}],
               [{"type": "table", "colspan": 2}, None]],
        row_heights=[0.42, 0.58], vertical_spacing=0.12,
        subplot_titles=("PM2.5 — indoor vs outdoor (µg/m³)",
                        "CO₂ — indoor vs outdoor (ppm)", ""))
    for ci, col in enumerate(["PM2.5(ug/m3)", "CO2(ppm)"], start=1):
        stats.add_trace(go.Bar(
            x=["Outdoor", "Indoor"],
            y=[setting_mean(col, "outdoor"), setting_mean(col, "indoor")],
            marker_color=["#2196F3", "#E64A19"],
            text=[setting_mean(col, "outdoor"), setting_mean(col, "indoor")],
            textposition="outside", cliponaxis=False,
            showlegend=False), row=1, col=ci)
    gstats = df.groupby("GROUP")
    header = ["Group", "n"] + [v["label"] for v in VARS]
    cells = [list(groups), [int(gstats.size()[g]) for g in groups]]
    for v in VARS:
        means = gstats[v["col"]].mean()
        cells.append([cell(means[g]) for g in groups])
    stats.add_trace(go.Table(
        header=dict(values=header, fill_color="#00695C",
                    font=dict(color="white", size=12), align="center"),
        cells=dict(values=cells, align="center",
                   fill_color=[["#f3f8f7", "white"] * len(groups)])),
        row=2, col=1)
    stats.update_layout(margin=dict(l=10, r=10, t=40, b=10), height=640)
    return stats


def build_interp_fig(df, ctr):
    """Estimated field with a combined Field · radius dropdown — the sparse-
    data lesson (cf. NASA GISTEMP's 250–1200 km smoothing radius)."""
    spacing = median_spacing(df)
    radii = [("tight", 0.7 * spacing), ("wide", 3.2 * spacing)]
    LonG, LatG, coslat0, (latmin, latmax, lonmin, lonmax) = make_grid(
        df, pad=3.0 * radii[-1][1])
    coords = [[lonmin, latmax], [lonmax, latmax],
              [lonmax, latmin], [lonmin, latmin]]

    ranges = {v["col"]: robust_range(df[v["col"]]) for v in VARS}
    images = {}
    for v in VARS:
        lo, hi = ranges[v["col"]]
        for rkey, r in radii:
            fld, fade = gaussian_field(df, v["col"], r, LonG, LatG, coslat0)
            images[(v["col"], rkey)] = field_datauri(fld, fade, lo, hi)

    def img_layer(col, rkey):
        return [dict(sourcetype="image", source=images[(col, rkey)],
                     below="", coordinates=coords)]

    dft, dfr = VARS[0], "tight"
    dlo, dhi = ranges[dft["col"]]
    interp = go.Figure(go.Scattermap(
        lat=df["LATITUDE"], lon=df["LONGITUDE"], mode="markers",
        marker=dict(size=11, color=df[dft["col"]], coloraxis="coloraxis"),
        customdata=df[HOVER_COLS].values, hovertemplate=HOVER, name=""))

    field_buttons, active_idx, i = [], 0, 0
    for v in VARS:
        lo, hi = ranges[v["col"]]
        for rkey, _ in radii:
            if v is dft and rkey == dfr:
                active_idx = i
            field_buttons.append(dict(
                label=f"{v['label']} · {rkey}", method="update",
                args=[{"marker.color": [df[v["col"]].tolist()]},
                      {"map.layers": img_layer(v["col"], rkey),
                       "coloraxis.cmin": lo, "coloraxis.cmax": hi,
                       "coloraxis.colorbar.title.text":
                           f"{v['label']}<br>{v['unit']}"}]))
            i += 1

    interp.update_layout(
        map=dict(style=BASEMAP, center=ctr, zoom=14.6,
                    layers=img_layer(dft["col"], dfr)),
        coloraxis=dict(colorscale=VIRIDIS, cmin=dlo, cmax=dhi,
                       colorbar=dict(title=dict(
                           text=f"{dft['label']}<br>{dft['unit']}"),
                           thickness=16, len=0.7)),
        updatemenus=[dict(buttons=field_buttons, active=active_idx, x=0.01,
                          xanchor="left", y=0.99, yanchor="top",
                          bgcolor="white", bordercolor="#bbb",
                          showactive=True)],
        margin=dict(l=0, r=0, t=40, b=46),
        annotations=[
            dict(text="Field · radius", x=0.01, xref="paper", y=1.0,
                 yref="paper", yanchor="bottom", showarrow=False,
                 font=dict(size=11, color="#666")),
            dict(text="Smooth colour = estimated field between samples; "
                      "widening the radius (tight→wide) fills more area but "
                      "with more guesswork — exactly the trade-off in NASA "
                      "GISTEMP's 250→1200 km smoothing. Dots = real readings.",
                 x=0.5, xref="paper", y=0, yref="paper", yanchor="top",
                 showarrow=False, font=dict(size=11, color="#555"))])
    return interp


# --- checklist + page assembly ---------------------------------------------

def roster_chips(groups, df, expected):
    """Checklist HTML: green chip per reporting group (with point count),
    grey chip per expected-but-missing group. Matching is case/space
    insensitive so 'group 7' still ticks off 'Group 7'."""
    def norm(s):
        return " ".join(str(s).split()).casefold()

    received = {norm(g): g for g in groups}
    counts = df.groupby("GROUP").size()
    chips = [f'<span class="chip ok">{escape(g)} · {int(counts[g])}</span>'
             for g in groups]
    missing = [e for e in expected if norm(e) not in received]
    chips += [f'<span class="chip missing">{escape(e)}</span>'
              for e in missing]
    label = (f"{len(groups)} of {len(expected)} groups in"
             if expected else f"{len(groups)} groups in")
    if expected and not missing:
        label += " — everyone!"
    return label, "".join(chips)


PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — Home Base</title>
<script>{plotlyjs}</script>
<style>
  * {{ box-sizing: border-box; margin: 0; }}
  body {{ font-family: -apple-system, "Segoe UI", Roboto, sans-serif;
         background: #fafdfc; height: 100vh; display: flex;
         flex-direction: column; overflow: hidden; }}
  header {{ padding: 10px 16px 8px; border-bottom: 2px solid #00695C;
            background: white; flex: none; }}
  header h1 {{ font-size: 18px; color: #00695C; display: inline; }}
  header .meta {{ color: #555; font-size: 13px; margin-left: 12px; }}
  header .warn {{ color: #8a6100; font-size: 12px; margin-top: 4px; }}
  .chips {{ margin-top: 6px; line-height: 24px; }}
  .chips .label {{ font-size: 12px; color: #555; margin-right: 8px; }}
  .chip {{ display: inline-block; font-size: 12px; border-radius: 12px;
           padding: 1px 9px; margin: 1px 3px 1px 0; }}
  .chip.ok {{ background: #E0F2F1; color: #00695C;
              border: 1px solid #B2DFDB; }}
  .chip.missing {{ background: #f5f5f5; color: #999;
                   border: 1px dashed #ccc; }}
  nav {{ display: flex; gap: 4px; padding: 6px 16px 0; background: white;
         border-bottom: 1px solid #ddd; flex: none; }}
  nav button {{ font-size: 14px; padding: 7px 18px; border: none;
                background: none; cursor: pointer; color: #555;
                border-bottom: 3px solid transparent; }}
  nav button.active {{ color: #00695C; font-weight: 600;
                       border-bottom-color: #00695C; }}
  main {{ flex: 1; min-height: 0; }}
  .pane {{ display: none; height: 100%; overflow: auto; }}
  .pane.active {{ display: block; }}
  .pane .plotly-graph-div {{ min-height: 300px; }}
</style>
</head>
<body>
<header>
  <h1>{title} — Home Base</h1>
  <span class="meta">{meta}</span>
  {warn}
  <div class="chips"><span class="label">{chip_label}</span>{chips}</div>
</header>
<nav>
  <button data-t="tab-map" class="active" onclick="show('tab-map')">Map</button>
  <button data-t="tab-interp" onclick="show('tab-interp')">Interpolated</button>
  <button data-t="tab-heat" onclick="show('tab-heat')">Heatmap</button>
  <button data-t="tab-stats" onclick="show('tab-stats')">Stats</button>
</nav>
<main>
  <section class="pane active" id="tab-map">{fig_map}</section>
  <section class="pane" id="tab-interp">{fig_interp}</section>
  <section class="pane" id="tab-heat">{fig_heat}</section>
  <section class="pane" id="tab-stats">{fig_stats}</section>
</main>
<script>
  function show(id) {{
    document.querySelectorAll('.pane').forEach(
      p => p.classList.toggle('active', p.id === id));
    document.querySelectorAll('nav button').forEach(
      b => b.classList.toggle('active', b.dataset.t === id));
    // Panes render at zero size while hidden; fix up on first show.
    const gd = document.querySelector('#' + id + ' .plotly-graph-div');
    if (gd) Plotly.Plots.resize(gd);
  }}
  window.addEventListener('resize', () => {{
    const gd = document.querySelector('.pane.active .plotly-graph-div');
    if (gd) Plotly.Plots.resize(gd);
  }});
</script>
</body>
</html>
"""


def fig_html(fig, full_height=True):
    return pio.to_html(
        fig, full_html=False, include_plotlyjs=False, config=IMG_CONFIG,
        default_width="100%",
        default_height="100%" if full_height else None)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Build the one-window classroom dashboard.")
    ap.add_argument("csv_dir", nargs="?",
                    default=os.path.join(HERE, "sample_csvs"),
                    help="folder of AQ Mapper CSV exports "
                         "(default: bundled sample data)")
    ap.add_argument("-o", "--out",
                    default=os.path.join(HERE, "classroom_dashboard.html"),
                    help="output HTML path")
    ap.add_argument("--expect", type=int, metavar="N",
                    help='checklist expects groups "Group 1".."Group N"')
    ap.add_argument("--roster", metavar="FILE",
                    help="checklist expects the group names in FILE "
                         "(one per line; overrides --expect)")
    ap.add_argument("--title", default=_default_title(),
                    help="event title shown in the header "
                         "(default: EVENT_TITLE from deploy.config.json)")
    args = ap.parse_args(argv)

    df, n_ok, skipped = load_folder(args.csv_dir)
    groups = sorted(df["GROUP"].unique())
    ctr = dict(lat=df["LATITUDE"].mean(), lon=df["LONGITUDE"].mean())
    n_out = int((df["LOCATION_TYPE"] == "outdoor").sum())
    n_in = int((df["LOCATION_TYPE"] == "indoor").sum())
    print(f"{n_ok} files -> {len(df)} unique points, {len(groups)} groups"
          + (f" ({len(skipped)} files skipped)" if skipped else ""))
    for name, reason in skipped:
        print(f"  skipped {name}: {reason}")

    expected = []
    if args.roster:
        with open(args.roster, encoding="utf-8-sig") as fh:
            expected = [ln.strip() for ln in fh if ln.strip()]
    elif args.expect:
        expected = [f"Group {i}" for i in range(1, args.expect + 1)]
    chip_label, chips = roster_chips(groups, df, expected)

    meta = (f"{len(df)} points · {len(groups)} groups · "
            f"{n_out} outdoor / {n_in} indoor · "
            f"built {datetime.now():%H:%M} from {n_ok} files")
    warn = ""
    if skipped:
        items = " · ".join(f"{escape(n)} ({escape(r)})" for n, r in skipped)
        warn = f'<div class="warn">⚠ {len(skipped)} file(s) skipped: {items}</div>'

    html = PAGE.format(
        title=escape(args.title), plotlyjs=get_plotlyjs(),
        meta=escape(meta), warn=warn, chip_label=chip_label, chips=chips,
        fig_map=fig_html(build_points_fig(df, groups, ctr)),
        fig_interp=fig_html(build_interp_fig(df, ctr)),
        fig_heat=fig_html(build_heatmap_fig(df, ctr)),
        fig_stats=fig_html(build_stats_fig(df, groups), full_height=False),
    )
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(html)
    print("wrote", args.out, f"({os.path.getsize(args.out) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
