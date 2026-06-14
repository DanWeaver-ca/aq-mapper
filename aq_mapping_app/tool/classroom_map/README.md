# Classroom AQ Map (Python / Plotly)

The lab-debrief map that runs on the **instructor's laptop** (Windows or Mac).
Students collect data on their phones with the AQ Mapper app, export CSVs, and
send them to you; this tool merges everyone's CSVs and renders an interactive
map you project to the class.

Colours and thresholds match the phone app's legend bands exactly
(`lib/models/map_variable.dart`), so the projected map looks like the phones.

## What you get
- **`classroom_map.html`** — interactive points map:
  - **Show ▾**: All groups / Outdoor / Indoor / each individual group
    (e.g. "here's Group 2", then "let's see everyone").
  - **Colour by ▾**: PM2.5 / PM10 / CO₂ / HCHO / Temp / Humidity.
  - Hover any point for all of its readings.
- **`classroom_heatmap.html`** — PM2.5 density heatmap of all groups.
- **`classroom_stats.html`** — summary panel: indoor-vs-outdoor averages for
  PM2.5 and CO₂, plus a per-group means table (the *story* for the debrief).

**Save a map for slides:** in any of the HTML views, click the camera icon in
the top-right toolbar to download the current view as a PNG. (If you have the
optional `kaleido` package installed, `build_map.py` also writes
`classroom_map.png/.pdf` and `classroom_stats.png` automatically.)

Both are **self-contained HTML files** — double-click to open in any browser,
and you can email them to students afterward. Only the map background tiles
need internet (classroom wifi); everything else is embedded.

## One-time setup
1. Install Python 3 (Windows: python.org or the Microsoft Store; Mac: built-in).
2. Install the two libraries:
   ```
   pip install -r requirements.txt
   ```

## Each lab
1. Put every group's exported CSV into the **`csvs/`** folder (any filenames).
   Re-importing the same file is harmless — rows are de-duplicated by `UID`.
2. Run it:
   - **Windows:** double-click `run_windows.bat`
   - **Mac:** double-click `run_mac.command` (first time: right-click → Open)
   - **Or any OS:** `python build_map.py csvs`
3. The map opens in your browser. Project it and use the dropdowns.

## Try it with sample data
No CSVs yet? Generate a fake class and build the map:
```
python make_sample_data.py      # writes 5 groups into sample_csvs/
python build_map.py sample_csvs
```

## Files
| File | Purpose |
|------|---------|
| `build_map.py` | reads CSVs → writes the map + heatmap HTML |
| `make_sample_data.py` | generates synthetic UTSC data for testing |
| `csvs/` | drop the groups' real CSV exports here |
| `requirements.txt` | Python dependencies |
| `run_windows.bat`, `run_mac.command` | double-click launchers |

## Keeping colours in sync with the app
The band thresholds live in the `VARS` list at the top of `build_map.py` and
mirror `aq_mapping_app/lib/models/map_variable.dart`. If you change a band in
the app, update it here too so the projected map keeps matching the phones.
