# Getting started with Home Base

*A first-time walkthrough for the instructor (or TA) running the classroom
dashboard. No programming needed — allow ~10 minutes for the one-time setup.
A printable copy of this guide lives beside it as `Home_Base_Guide.docx`.*

**Home Base** takes the CSV files that student groups send from the AQ Mapper
phone app, merges them, and builds one interactive dashboard
(`classroom_dashboard.html`) you project for the debrief: the class map, an
interpolated "estimated field", a heatmap, summary statistics — and a
checklist of which groups have reported.

## 1. What you need

- A **laptop** — Windows or Mac (Linux works too).
- **Python 3** — free; install steps below.
- **This folder** (`classroom_map/`) — from cloning the repo or downloading
  it as a ZIP (GitHub → Code → Download ZIP).
- Student CSVs on lab day — but not for setup: **sample data is bundled**, so
  you can rehearse everything without a single real reading.

## 2. One-time setup (per computer)

### 2.1 Install Python

- **Windows:** open the Microsoft Store, search "Python 3", click Install.
  (Or use python.org — on the first installer screen, tick **"Add Python to
  PATH"**.)
- **Mac:** Python 3 is usually already there. If not, install from
  python.org.

> **Already have Anaconda?** That *is* Python 3 — skip the install. But
> Anaconda keeps itself out of the normal terminal: open **Anaconda Prompt**
> from the Start menu and use *that* window for every command in this guide.
> (No Anaconda Prompt in the Start menu? Use the full-path row in the
> troubleshooting table.)

Confirm it worked — open a terminal (Windows: *Command Prompt*; Mac:
*Terminal*) and type:

```
python --version
```

> If Windows says "python is not recognized", try `py --version`. On Mac use
> `python3 --version`. Whichever word works (`python` / `py` / `python3`),
> use it in every command below.

### 2.2 Install the libraries

In the terminal, move into this folder — type `cd ` (with a space), drag the
`classroom_map` folder onto the terminal window, press Enter — then run:

```
pip install -r requirements.txt
```

> If `pip` isn't found, try `pip3 install -r requirements.txt` or
> `python -m pip install -r requirements.txt`. Once per computer is enough.

### 2.3 Rehearse with the bundled sample data

Double-click the launcher — **`run_windows.bat`** (Windows) or
**`run_mac.command`** (Mac; the first time, right-click → Open → Open, which
tells macOS you trust it). With no real CSVs present, it automatically builds
the dashboard from the bundled fake class of five groups and opens it in your
browser. (The Windows launcher finds Python on its own: `python` on PATH,
then `py`, then a standard Anaconda install.)

You should see a header ("100 points · 5 groups · …"), a row of green group
chips, and four tabs: **Map · Interpolated · Heatmap · Stats**. Click through
them. If that works, you are ready for lab day.

## 3. Lab day

1. **Collect the CSVs.** Each group taps **"Send to instructor"** on the
   app's Data screen and AirDrops or emails you a file named like
   `aq_UTSC-AQMS-07_20260716_143022.csv`.
2. **Drop every file into the `csvs/` folder.** Filenames don't matter.
   Adding the same file twice is harmless — readings are de-duplicated
   automatically.
3. **Double-click the launcher.** The dashboard opens; put the browser
   window on the projector (F11 = full screen on Windows).

Re-run the launcher any time — it takes seconds, so build the map *as files
arrive* and let the **group checklist** tell you who is still missing while
students are back in the room.

To make the checklist expect your full class list, run from the terminal:

```
python home_base.py csvs --expect 25            # expects Group 1 .. Group 25
python home_base.py csvs --roster roster.txt    # or your own names, one per line
python home_base.py csvs --title "Northview HS" # change the header title
```

(Name matching ignores case and extra spaces, but spelling has to match what
students typed into the app.)

## 4. Using the dashboard in the debrief

- **Map tab** — start with one group ("here's Group 2's afternoon"), then
  switch **Show** to *All groups* for the reveal; *Outdoor*/*Indoor* filters
  the discussion. **Colour by** picks the variable: **· health bands** uses
  the same absolute colours as the phones (most of campus is reassuringly
  green); **· spread** re-stretches the colours to today's data range —
  switch to it when everything looks one colour and structure appears
  *within* the green. That switch is itself worth discussing: same data,
  different story.
- **Interpolated tab** — the smooth surface is an *estimate* between the
  points, fading where nobody sampled. Widen **Field · radius** from tight
  to wide: more coverage, more guesswork — the same trade-off NASA's GISTEMP
  temperature maps make with their 250 km vs 1200 km smoothing radius. "If
  you were designing a city's sensor network, where would you add sensors?"
- **Heatmap tab** — quick visual of PM2.5 hotspots.
- **Stats tab** — the indoor-vs-outdoor CO₂ bars are usually the story of
  the day; the table lets every group find itself.
- **Camera icon** (top-right of any tab) downloads that view as a PNG for
  your slides.

## 5. Afterwards

`classroom_dashboard.html` is one self-contained file — email it to
students or post it on the course page; it opens in any browser. Internet is
needed only for the map's background tiles.

**Privacy note:** the CSVs contain GPS tracks and the group names students
typed. Keep the `csvs/` folder off shared drives and out of any public repo
(in this repository it is already gitignored).

## 6. Troubleshooting

| If you see… | Do this |
|---|---|
| "python is not recognized" (Windows) | Use `py` instead of `python`, use the **Anaconda Prompt** if you have Anaconda, or reinstall Python with "Add Python to PATH" ticked. |
| "Python was not found; run without arguments to install from the Microsoft Store…" | Windows' decoy python — no real Python is on your PATH. With Anaconda: open **Anaconda Prompt** instead, or run by full path: `C:\ProgramData\anaconda3\python.exe home_base.py csvs` (Anaconda may also live in `%LOCALAPPDATA%\anaconda3` or `%USERPROFILE%\anaconda3`). Without Anaconda: do step 2.1. |
| "command not found: python" (Mac) | Use `python3` (and `pip3`). |
| "No module named plotly / pandas / PIL" | Step 2.2 was skipped — run the pip install command inside this folder. |
| An old Plotly install errors on `Scattermap` | Upgrade: `pip install -U "plotly>=5.24,<7"`. |
| Mac: "cannot be opened … unidentified developer" | Right-click `run_mac.command` → Open (first time only). |
| "No CSVs found" | Put the groups' files in the `csvs/` folder, then run again. |
| ⚠ "file skipped" in the dashboard header | That file wasn't an app export — a raw Temtop download has no GPS and can't be used. Ask the group to re-send from the app's Data screen. |
| Map background is blank grey | No internet — the points and stats still work; connect to wifi and reload for the basemap. |
| A group's points sit far off campus | Their phone gave a coarse (cell-tower) location. Have students enable Precise Location; discuss it — real networks screen for exactly this. |
| A group sent data but their chip is grey | The name they typed in the app doesn't match your roster spelling — check the received chips for the name they actually used. |

## 7. Where the pieces live

| File | What it is |
|---|---|
| `home_base.py` | builds `classroom_dashboard.html` from a folder of CSVs |
| `run_windows.bat` / `run_mac.command` | double-click: build + open |
| `csvs/` | drop the class's CSV files here |
| `sample_csvs/` · `make_sample_data.py` | bundled fake class · regenerate it |
| `build_map.py` | the previous version (four separate HTML files) — kept for reference |
| `make_guide.py` → `Home_Base_Guide.docx` | regenerates the printable copy of this guide |
| `README.md` | shorter reference version of all this |

Colour thresholds live in the `VARS` list at the top of `home_base.py` and
match the phone app (`aq_mapping_app/lib/models/map_variable.dart`) — if a
band changes there, change it here too.
