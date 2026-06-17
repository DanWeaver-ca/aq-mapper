"""Classroom AQ map (Plotly) — the projected maps for the lab debrief.

Reads a folder of AQ Mapper CSV exports, de-duplicates by UID, and writes
self-contained interactive HTML:
  - classroom_map.html   : points map. Show dropdown (All / Outdoor / Indoor /
                           each group) + Colour-by dropdown with two modes per
                           variable — "health" (absolute app bands) and
                           "spread" (stretched to this dataset's range for
                           contrast).
  - classroom_heatmap.html      : PM2.5 density heatmap.
  - classroom_stats.html        : indoor-vs-outdoor + per-group summary.
  - classroom_interpolated.html : IDW-estimated PM2.5 field with the real
                           points overlaid (an honest "estimated between
                           samples" surface — the same problem global models
                           face over data-sparse regions).
Usage:  python3 build_map.py [csv_dir] [out_dir]
"""
import base64
import glob
import io
import os
import sys
import numpy as np
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
csv_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "sample_csvs")
out_dir = sys.argv[2] if len(sys.argv) > 2 else HERE

# A clean, low-clutter basemap so the data points stand out (the detailed OSM
# style scatters parking/transit markers that compete with the readings).
BASEMAP = "carto-positron"

# Toolbar config: a high-res "download as image" camera button.
IMG_CONFIG = {"displaylogo": False,
              "toImageButtonOptions": {"format": "png", "scale": 2,
                                       "filename": "utsc_class_map"}}

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
    point) doesn't blow out the colour scale. Falls back gracefully when all
    values are (nearly) equal."""
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


GRIDN = 160  # interpolation grid resolution


def _coords(df):
    p = df.dropna(subset=["LATITUDE", "LONGITUDE"])
    return (p["LATITUDE"].to_numpy(float), p["LONGITUDE"].to_numpy(float),
            float(np.cos(np.radians(p["LATITUDE"].mean()))))


def median_spacing(df):
    """Median nearest-neighbour distance of the samples (cos-lat scaled) — the
    natural unit for the smoothing radius, robust to a lone outlier."""
    lat, lon, coslat0 = _coords(df)
    if len(lat) < 2:
        return 0.003
    P = np.column_stack([lon * coslat0, lat])
    nn = [np.sqrt(((P - P[i]) ** 2).sum(1))[np.arange(len(P)) != i].min()
          for i in range(len(P))]
    return float(np.median(nn))


def make_grid(df, pad):
    """A lat/lon grid over the data, padded by `pad` (cos-lat scaled) so the
    field can fade fully to transparent before the image edge (no hard
    boundary)."""
    lat, lon, coslat0 = _coords(df)
    plat, plon = pad, pad / coslat0
    latmin, latmax = lat.min() - plat, lat.max() + plat
    lonmin, lonmax = lon.min() - plon, lon.max() + plon
    glat = np.linspace(latmax, latmin, GRIDN)   # row 0 = north
    glon = np.linspace(lonmin, lonmax, GRIDN)
    LonG, LatG = np.meshgrid(glon, glat)
    return LonG, LatG, coslat0, (latmin, latmax, lonmin, lonmax)


def gaussian_field(df, col, r, LonG, LatG, coslat0):
    """Gaussian-weighted interpolation with smoothing radius `r` (the GISTEMP
    analogue): each sample's influence ~ exp(-(d/r)^2). Larger r → smoother and
    wider coverage. Returns the field and a fade mask (transparent where the
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


# --- load + merge + dedup -------------------------------------------------
files = sorted(glob.glob(os.path.join(csv_dir, "*.csv")))
if not files:
    sys.exit(f"No CSVs found in {csv_dir}")
df = pd.concat((pd.read_csv(f) for f in files), ignore_index=True)
df = df.drop_duplicates(subset="UID")
for v in VARS:
    df[v["col"]] = pd.to_numeric(df[v["col"]], errors="coerce")
df["LATITUDE"] = pd.to_numeric(df["LATITUDE"], errors="coerce")
df["LONGITUDE"] = pd.to_numeric(df["LONGITUDE"], errors="coerce")
df = df.dropna(subset=["LATITUDE", "LONGITUDE"])
df["LOCATION_TYPE"] = df["LOCATION_TYPE"].fillna("").str.lower()
groups = sorted(df["GROUP"].dropna().unique())
ctr = dict(lat=df["LATITUDE"].mean(), lon=df["LONGITUDE"].mean())
print(f"{len(files)} files -> {len(df)} unique points, {len(groups)} groups")

HOVER_COLS = ["GROUP", "DEVICE", "LOCATION_TYPE", "PM2.5(ug/m3)",
              "PM10(ug/m3)", "PARTICLES(per/L)", "CO2(ppm)", "HCHO(mg/m3)",
              "TEMPERATURE", "HUMIDITY(%)"]
HOVER = ("<b>%{customdata[0]}</b> · %{customdata[1]} · %{customdata[2]}<br>"
         "PM2.5 %{customdata[3]} µg/m³ · PM10 %{customdata[4]}<br>"
         "Particles %{customdata[5]} /L<br>"
         "CO₂ %{customdata[6]} ppm · HCHO %{customdata[7]} mg/m³<br>"
         "Temp %{customdata[8]} °C · RH %{customdata[9]} %<extra></extra>")

# One trace per (group, setting) so a single filter menu can scope by group OR
# by indoor/outdoor without Plotly's multi-dropdown visibility conflict.
default = VARS[0]
traces = []
for g in groups:
    for setting in ("outdoor", "indoor"):
        gd = df[(df["GROUP"] == g) & (df["LOCATION_TYPE"] == setting)]
        if not gd.empty:
            traces.append((g, setting, gd))

fig = go.Figure()
for g, setting, gd in traces:
    fig.add_trace(go.Scattermapbox(
        lat=gd["LATITUDE"], lon=gd["LONGITUDE"], mode="markers",
        name=f"{g} · {setting}", showlegend=False,
        marker=dict(size=13, opacity=0.92, color=gd[default["col"]],
                    coloraxis="coloraxis"),
        customdata=gd[HOVER_COLS].values, hovertemplate=HOVER))

n_out = int((df["LOCATION_TYPE"] == "outdoor").sum())
n_in = int((df["LOCATION_TYPE"] == "indoor").sum())


def visible_for(predicate):
    return [predicate(g, s) for (g, s, _) in traces]


# --- Show (filter) dropdown ----------------------------------------------
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

# --- Colour-by dropdown: two modes per variable --------------------------
# "health" = absolute app bands; "spread" = stretched to this dataset's robust
# range (reveals contrast when readings cluster in one band). Each button fully
# sets the colouring, so the two modes never fight each other.
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
               "coloraxis.colorbar.title.text": f"{v['label']}<br>{v['unit']}"}]))
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
    mapbox=dict(style=BASEMAP, center=ctr, zoom=14.4),
    coloraxis=dict(
        colorscale=stepped_scale(default["thr"], default["colors"],
                                 default["cmin"], default["cmax"]),
        cmin=default["cmin"], cmax=default["cmax"],
        colorbar=dict(title=dict(text=f"{default['label']}<br>{default['unit']}"),
                      tickvals=default["thr"],
                      ticktext=[str(t) for t in default["thr"]],
                      thickness=16, len=0.7, y=0.5)),
    margin=dict(l=0, r=0, t=58, b=0),
    title=dict(text="UTSC Air Quality — class map", x=0.5, xanchor="center"),
    updatemenus=[
        dict(buttons=show_buttons, x=0.01, xanchor="left", y=0.99, yanchor="top",
             bgcolor="white", bordercolor="#bbb", showactive=True),
        dict(buttons=var_buttons, x=0.16, xanchor="left", y=0.99, yanchor="top",
             bgcolor="white", bordercolor="#bbb", showactive=True),
    ],
    annotations=[
        dict(text="Show", x=0.01, xref="paper", y=1.0, yref="paper",
             yanchor="bottom", showarrow=False, font=dict(size=11, color="#666")),
        dict(text="Colour by", x=0.16, xref="paper", y=1.0, yref="paper",
             yanchor="bottom", showarrow=False, font=dict(size=11, color="#666")),
    ],
)
map_html = os.path.join(out_dir, "classroom_map.html")
fig.write_html(map_html, include_plotlyjs="inline", config=IMG_CONFIG)
print("wrote", map_html)

# --- PM2.5 density heatmap ------------------------------------------------
heat = px.density_mapbox(
    df, lat="LATITUDE", lon="LONGITUDE", z="PM2.5(ug/m3)", radius=28,
    center=ctr, zoom=14.4, mapbox_style=BASEMAP,
    color_continuous_scale="Turbo", title="UTSC PM2.5 density — all groups")
heat.update_layout(margin=dict(l=0, r=0, t=58, b=0))
heat_html = os.path.join(out_dir, "classroom_heatmap.html")
heat.write_html(heat_html, include_plotlyjs="inline", config=IMG_CONFIG)
print("wrote", heat_html)

# --- summary-stats panel -------------------------------------------------
def setting_mean(col, setting):
    sel = df[df["LOCATION_TYPE"] == setting][col]
    return round(float(sel.mean()), 1) if len(sel) else None

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
        marker_color=["#2196F3", "#E64A19"], text=[setting_mean(col, "outdoor"),
        setting_mean(col, "indoor")], textposition="outside", cliponaxis=False,
        showlegend=False), row=1, col=ci)
gstats = df.groupby("GROUP")
header = ["Group", "n"] + [v["label"] for v in VARS]
cells = [list(groups), [int(gstats.size()[g]) for g in groups]]
for v in VARS:
    cells.append([round(float(gstats[v["col"]].mean()[g]), 1) for g in groups])
stats.add_trace(go.Table(
    header=dict(values=header, fill_color="#00695C",
                font=dict(color="white", size=12), align="center"),
    cells=dict(values=cells, align="center",
               fill_color=[["#f3f8f7", "white"] * len(groups)])), row=2, col=1)
stats.update_layout(
    title=dict(text="UTSC Air Quality — class summary", x=0.5, xanchor="center"),
    margin=dict(l=10, r=10, t=70, b=10), height=640)
stats_html = os.path.join(out_dir, "classroom_stats.html")
stats.write_html(stats_html, include_plotlyjs="inline", config=IMG_CONFIG)
print("wrote", stats_html)

# --- interpolated field (variable + smoothing-radius selectable) ---------
# Gaussian interpolation à la GISTEMP: a "smoothing radius" knob (tight/medium/
# wide) shows how sparse points fill more area as you widen it. One combined
# dropdown switches both variable and radius (Plotly menus can't share state,
# and both control the same image layer, so they must live in one menu).
spacing = median_spacing(df)
RADII = [("tight", 0.7 * spacing), ("wide", 3.2 * spacing)]
LonG, LatG, coslat0, (latmin, latmax, lonmin, lonmax) = make_grid(
    df, pad=3.0 * RADII[-1][1])
COORDS = [[lonmin, latmax], [lonmax, latmax], [lonmax, latmin], [lonmin, latmin]]

ranges = {v["col"]: robust_range(df[v["col"]]) for v in VARS}
images = {}  # (col, radius_key) -> data-URI of the rendered field
for v in VARS:
    lo, hi = ranges[v["col"]]
    for rkey, r in RADII:
        fld, fade = gaussian_field(df, v["col"], r, LonG, LatG, coslat0)
        images[(v["col"], rkey)] = field_datauri(fld, fade, lo, hi)


def img_layer(col, rkey):
    return [dict(sourcetype="image", source=images[(col, rkey)], below="",
                 coordinates=COORDS)]


dft, dfr = VARS[0], "tight"
dlo, dhi = ranges[dft["col"]]
interp = go.Figure(go.Scattermapbox(
    lat=df["LATITUDE"], lon=df["LONGITUDE"], mode="markers",
    marker=dict(size=11, color=df[dft["col"]], coloraxis="coloraxis"),
    customdata=df[HOVER_COLS].values, hovertemplate=HOVER, name=""))

field_buttons, active_idx, i = [], 0, 0
for v in VARS:
    lo, hi = ranges[v["col"]]
    for rkey, _ in RADII:
        if v is dft and rkey == dfr:
            active_idx = i
        field_buttons.append(dict(
            label=f"{v['label']} · {rkey}", method="update",
            args=[{"marker.color": [df[v["col"]].tolist()]},
                  {"mapbox.layers": img_layer(v["col"], rkey),
                   "coloraxis.cmin": lo, "coloraxis.cmax": hi,
                   "coloraxis.colorbar.title.text": f"{v['label']}<br>{v['unit']}"}]))
        i += 1

interp.update_layout(
    mapbox=dict(style=BASEMAP, center=ctr, zoom=14.6,
                layers=img_layer(dft["col"], dfr)),
    coloraxis=dict(colorscale=VIRIDIS, cmin=dlo, cmax=dhi,
                   colorbar=dict(title=dict(
                       text=f"{dft['label']}<br>{dft['unit']}"),
                       thickness=16, len=0.7)),
    updatemenus=[dict(buttons=field_buttons, active=active_idx, x=0.01,
                      xanchor="left", y=0.99, yanchor="top", bgcolor="white",
                      bordercolor="#bbb", showactive=True)],
    margin=dict(l=0, r=0, t=52, b=46),
    title=dict(text="UTSC — interpolated field (estimated)",
               x=0.5, xanchor="center"),
    annotations=[
        dict(text="Field · radius", x=0.01, xref="paper", y=1.0, yref="paper",
             yanchor="bottom", showarrow=False, font=dict(size=11, color="#666")),
        dict(text="Smooth colour = estimated field between samples; widening the "
                  "radius (tight→wide) fills more area but with more guesswork — "
                  "exactly the trade-off in NASA GISTEMP's 250→1200 km smoothing. "
                  "Dots = real readings.",
             x=0.5, xref="paper", y=0, yref="paper", yanchor="top",
             showarrow=False, font=dict(size=11, color="#555"))])
interp_html = os.path.join(out_dir, "classroom_interpolated.html")
interp.write_html(interp_html, include_plotlyjs="inline", config=IMG_CONFIG)
print("wrote", interp_html)

# --- optional static exports (need kaleido; instructors don't) -----------
try:
    fig.write_image(os.path.join(out_dir, "classroom_map.png"),
                    width=1200, height=820, scale=2)
    fig.write_image(os.path.join(out_dir, "classroom_map.pdf"),
                    width=1200, height=820)
    heat.write_image(os.path.join(out_dir, "classroom_heatmap.png"),
                     width=1200, height=820, scale=2)
    stats.write_image(os.path.join(out_dir, "classroom_stats.png"),
                      width=1200, height=820, scale=2)
    interp.write_image(os.path.join(out_dir, "classroom_interpolated.png"),
                       width=1200, height=820, scale=2)
    print("wrote PNG/PDF exports")
except Exception as e:
    print("Image export skipped (kaleido not required):", str(e)[:80])
