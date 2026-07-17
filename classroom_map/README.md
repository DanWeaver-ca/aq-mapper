# Classroom AQ Map (Python / Plotly)

The lab-debrief tool that runs on the **instructor's laptop** (Windows or Mac).
Students collect data on their phones with the AQ Mapper app and send you their
CSVs; this tool merges everyone's data and renders **Home Base** — a single
dashboard you project to the class.

Colours and thresholds match the phone app's legend bands exactly
(`aq_mapping_app/lib/models/map_variable.dart`), so the projected map looks
like the phones.

**First time?** Follow [GETTING_STARTED.md](GETTING_STARTED.md) — a
step-by-step walkthrough with troubleshooting, written for a TA or colleague.
`Home_Base_Guide.docx` is the same guide as a printable/emailable Word file
(regenerate it with `python make_guide.py` after editing).

## What you get — `classroom_dashboard.html`

One self-contained page with four tabs:

- **Map** — interactive points map on a clean basemap.
  **Show ▾**: All groups / Outdoor / Indoor / each individual group
  (e.g. "here's Group 2", then "let's see everyone").
  **Colour by ▾**: each variable in two modes — **· health bands** (absolute
  air-quality colours, matching the phone app) and **· spread** (stretched to
  this dataset's range, so you can see contrast even when every reading falls
  in one health band). Hover any point for all of its readings.
- **Interpolated** — an estimated field between the sample points
  (Gaussian-weighted), fading where you sampled less, with the real readings
  on top. The **Field · radius** dropdown selects the variable *and* a
  smoothing radius (tight or wide): widening it fills more area but with more
  guesswork — the same trade-off as NASA GISTEMP's 250–1200 km smoothing
  (https://data.giss.nasa.gov/gistemp/maps). A teaching artifact for how
  global models handle data-sparse regions.
- **Heatmap** — PM2.5 density of all groups.
- **Stats** — indoor-vs-outdoor averages for PM2.5 and CO₂, plus a per-group
  means table (the *story* for the debrief).

Above the tabs, a header shows the class totals and a **group checklist**:
green chips for groups whose data is in (with point counts), grey chips for
groups still missing — so you can see who's outstanding *while* the class is
running. Files that couldn't be read are reported in the header instead of
crashing the build (Excel re-saves and raw Temtop files are the usual
culprits).

**Save a view for slides:** the camera icon in each tab's toolbar downloads
the current view as a PNG.

The dashboard is **one self-contained HTML file** (~5 MB) — double-click to
open in any browser, email it to students afterward. Only the map background
tiles need internet (classroom wifi); everything else is embedded.

## One-time setup
1. Install Python 3 (Windows: python.org or the Microsoft Store; Mac: built-in).
2. Install the libraries:
   ```
   pip install -r requirements.txt
   ```

## Each lab
1. Put every group's exported CSV into the **`csvs/`** folder (any filenames).
   Re-importing the same file is harmless — rows are de-duplicated by `UID`.
2. Run it:
   - **Windows:** double-click `run_windows.bat`
   - **Mac:** double-click `run_mac.command` (first time: right-click → Open)
   - **Or any OS:** `python home_base.py csvs`
3. The dashboard opens in your browser. Project it and use the tabs.

**Group checklist options** (optional):
```
python home_base.py csvs --expect 25          # expects "Group 1".."Group 25"
python home_base.py csvs --roster roster.txt  # expects the names in the file
python home_base.py csvs --title "My School"  # header title (default UTSC)
```
Without a roster the checklist simply lists the groups that have reported.

## Try it with sample data
No CSVs yet? Generate a fake class and build the dashboard:
```
python make_sample_data.py      # writes 5 groups into sample_csvs/
python home_base.py sample_csvs
```

## Files
| File | Purpose |
|------|---------|
| `home_base.py` | reads CSVs → writes `classroom_dashboard.html` |
| `build_map.py` | **v1 reference** — the same four views as separate HTML files (`classroom_map/heatmap/stats/interpolated.html`), kept unchanged; also has optional kaleido PNG/PDF export |
| `make_sample_data.py` | generates synthetic UTSC data for testing |
| `csvs/` | drop the groups' real CSV exports here |
| `requirements.txt` | Python dependencies |
| `run_windows.bat`, `run_mac.command` | double-click launchers (build + open the dashboard) |
| `GETTING_STARTED.md` | first-time walkthrough (this folder's front door) |
| `make_guide.py` → `Home_Base_Guide.docx` | printable twin of the walkthrough |

## Keeping colours in sync with the app
The band thresholds live in the `VARS` list at the top of `home_base.py` (and
mirrored in the frozen `build_map.py`) and match
`aq_mapping_app/lib/models/map_variable.dart`. If you change a band in the
app, update it here too so the projected map keeps matching the phones.
