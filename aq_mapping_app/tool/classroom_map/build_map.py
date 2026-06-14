"""Classroom AQ map (Plotly) — the projected map for the lab debrief.

Reads a folder of AQ Mapper CSV exports, de-duplicates by UID, and writes a
self-contained interactive HTML map:
  - Show dropdown: All groups / Outdoor / Indoor / each group  ("here's group 2")
  - Colour by dropdown: PM2.5 / PM10 / CO2 / HCHO / Temp / Humidity
  - colours and thresholds match the phone app's legend bands exactly
  - hover shows every reading
Plus a PM2.5 density-heatmap HTML. Usage:
    python3 build_map.py [csv_dir] [out_dir]
"""
import glob
import os
import sys
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots

# Toolbar config: a high-res "download as image" camera button so the
# instructor can save the current map view straight into slides/reports.
IMG_CONFIG = {"displaylogo": False,
              "toImageButtonOptions": {"format": "png", "scale": 2,
                                       "filename": "utsc_class_map"}}

HERE = os.path.dirname(os.path.abspath(__file__))
csv_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "sample_csvs")
out_dir = sys.argv[2] if len(sys.argv) > 2 else HERE

# Material colours used by the app's MapVariable bands.
G, O, D, R, B = "#4CAF50", "#FF9800", "#FF5722", "#F44336", "#2196F3"

# Per variable: csv column, label, unit, band thresholds (upper bounds),
# band colours (len = thresholds+1), and the colour-axis display range.
# Mirrors lib/models/map_variable.dart — keep in sync if the app changes.
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
    """A piecewise-constant Plotly colourscale that reproduces the discrete
    legend bands as hard steps between the thresholds."""
    span = cmax - cmin
    stops = [[0.0, colors[0]]]
    for i, t in enumerate(thr):
        p = min(1.0, max(0.0, (t - cmin) / span))
        stops.append([p, colors[i]])      # end of band i
        stops.append([p, colors[i + 1]])  # start of band i+1
    stops.append([1.0, colors[-1]])
    return stops


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
traces = []  # (group, setting, dataframe-slice)
for g in groups:
    for setting in ("outdoor", "indoor"):
        gd = df[(df["GROUP"] == g) & (df["LOCATION_TYPE"] == setting)]
        if gd.empty:
            continue
        traces.append((g, setting, gd))

fig = go.Figure()
for g, setting, gd in traces:
    fig.add_trace(go.Scattermapbox(
        lat=gd["LATITUDE"], lon=gd["LONGITUDE"], mode="markers",
        name=f"{g} · {setting}", showlegend=False,
        marker=dict(size=13, opacity=0.92, color=gd[default["col"]],
                    coloraxis="coloraxis"),
        customdata=gd[HOVER_COLS].values, hovertemplate=HOVER,
    ))

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

# --- Colour-by dropdown: recolour every trace + restyle the band colourbar -
var_buttons = []
for v in VARS:
    scale = stepped_scale(v["thr"], v["colors"], v["cmin"], v["cmax"])
    colors = [gd[v["col"]].tolist() for (_, _, gd) in traces]
    var_buttons.append(dict(
        label=f"{v['label']} ({v['unit']})", method="update",
        args=[{"marker.color": colors},
              {"coloraxis.colorscale": scale,
               "coloraxis.cmin": v["cmin"], "coloraxis.cmax": v["cmax"],
               "coloraxis.colorbar.tickvals": v["thr"],
               "coloraxis.colorbar.ticktext": [str(t) for t in v["thr"]],
               "coloraxis.colorbar.title.text": f"{v['label']}<br>{v['unit']}"}],
    ))

fig.update_layout(
    mapbox=dict(style="open-street-map",
                center=dict(lat=df["LATITUDE"].mean(),
                            lon=df["LONGITUDE"].mean()), zoom=14.4),
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

# --- PM2.5 density heatmap (all groups) ----------------------------------
heat = px.density_mapbox(
    df, lat="LATITUDE", lon="LONGITUDE", z="PM2.5(ug/m3)", radius=28,
    center=dict(lat=df["LATITUDE"].mean(), lon=df["LONGITUDE"].mean()),
    zoom=14.4, mapbox_style="open-street-map", color_continuous_scale="Turbo",
    title="UTSC PM2.5 density — all groups")
heat.update_layout(margin=dict(l=0, r=0, t=58, b=0))
heat_html = os.path.join(out_dir, "classroom_heatmap.html")
heat.write_html(heat_html, include_plotlyjs="inline", config=IMG_CONFIG)
print("wrote", heat_html)

# --- summary-stats panel for the debrief ---------------------------------
# Indoor-vs-outdoor bars for the two headline pollutants + a per-group means
# table. Gives the *story* to narrate over the map.
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

# --- optional static exports (need kaleido; instructors don't) -----------
# A PNG + a vector PDF of the map for slides/reports, plus snapshots.
try:
    fig.write_image(os.path.join(out_dir, "classroom_map.png"),
                    width=1200, height=820, scale=2)
    fig.write_image(os.path.join(out_dir, "classroom_map.pdf"),
                    width=1200, height=820)
    heat.write_image(os.path.join(out_dir, "classroom_heatmap.png"),
                     width=1200, height=820, scale=2)
    stats.write_image(os.path.join(out_dir, "classroom_stats.png"),
                      width=1200, height=820, scale=2)
    print("wrote PNG/PDF exports")
except Exception as e:
    print("Image export skipped (kaleido not required):", str(e)[:80])
