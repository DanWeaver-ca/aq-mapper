# AQ Mapper — Instructor's Overview

*Written 2026-08-07, on the eve of lab 3. Audience: future Dan, returning
after months of teaching to write the paper (or run the next cohort) and
needing the whole picture back in ~15 minutes. The always-current technical
status lives in `CLAUDE.md`; this document is the orientation layer above it.*

---

## 1. What this project is

One repo, two products, one config file:

```
 students' phones                        instructor's laptop
┌────────────────────┐   Send to class  ┌─────────────────────┐
│ AQ Mapper          │ ───────────────► │ Google Sheet        │
│ (Flutter web PWA)  │   (primary)      │ ("readings" tab)    │
│ readings + GPS     │                  └─────────┬───────────┘
│                    │   Send to instructor       │ File → Download → .csv
│                    │ ────────────────┐          ▼
└────────────────────┘  email/AirDrop  └──► classroom_map/csvs/
                        (backup)                  │ home_base.py
                                                  ▼
                                        classroom_dashboard.html
                                        (projected at the debrief)
```

- **`aq_mapping_app/`** — the Flutter app. ONE codebase; ships as a web
  PWA (GitHub Pages) so mixed iOS/Android personal phones need no app
  store; still builds native iOS/Android. Students carry Temtop M2000+
  sensors (no GPS of their own), type readings in, the phone adds
  coordinates.
- **`classroom_map/`** — the Python/Plotly "Home Base" debrief tool.
  Merges everyone's CSVs into one self-contained tabbed dashboard
  (Map · Interpolated · Heatmap · Stats + group checklist).
- **`deploy.config.json`** — the one-file institution config (branding,
  campus coords, device IDs, `UPLOAD_URL`). Drives the app build, the web
  shell, and every Python tool. Adopters fork + edit this one file
  (`SETUP.md` is their walkthrough).

## 2. Where things live

| Thing | Where |
|---|---|
| Live app (the QR target) | https://danweaver-ca.github.io/aq-mapper/ |
| Generic demo | https://danweaver-ca.github.io/aq-mapper/demo/ |
| Repo (public) | https://github.com/DanWeaver-ca/aq-mapper |
| Upload endpoint + sheet | **Dedicated project Google account** (created 2026-08-07 — credentials wherever you keep them; NOT in this repo). Per-event lifecycle: deploy fresh each lab (`UPLOAD_URL` in deploy.config.json during the window), archive + delete after — see SETUP_UPLOAD.md "Closing up" |
| Deployment | GitHub Actions → Pages on every push to main; builds TWICE (UTSC config at `/`, demo config at `/demo/`) |
| Lab-day ops manual | `docs/lab_day_claude_context.md` — self-contained; paste into a claude.ai chat when away from this computer |

## 3. Version timeline & field lessons (the paper's skeleton)

| Date | Event | Lesson → response |
|---|---|---|
| 2026-06-13 | Web/PWA distribution decided; classroom hub pivoted to Python | No MDM/app store for visiting students; instructor laptop is Windows |
| 2026-06-16 | Real-device campus test (2 phones, 11 points) | Worked; one Android gave ~1.4 km cell-tower fix → "Precise Location" briefing line |
| 2026-06-17 | Repo reorganized; tag **`v1.0.0`** = native-capable state | — |
| 2026-07-16 | **Lab 1** (first full class) | App + debrief worked; **~half the CSV exports never arrived by email** → v1.1 send/save split, v1.2 one-file config (07-17); Home Base became one tabbed dashboard |
| 2026-07-22 | **Lab 2** (tag **`v2.0-lab2`**) | Send failure persisted: students with **no email account**, and QR opened **inside WeChat** (webview can't share/save files; separate storage sandbox) |
| 2026-07-24 | **v3 / app 2.0.0** built | "Send to class" one-tap upload (Apps Script→Sheet), bilingual WeChat interceptor, campus-POI layer — all config-gated OFF |
| 2026-08-07 | **Activation** (reviewed by a second model before execution) | Decision: upload **primary**, email **backup**. Power Automate ruled out (no app/licence on the U of T account); Google framed as *transit, not storage* (sheet deleted after each debrief). Endpoint made last-write-wins (edits propagate); Home Base duplicate-UID precedence (latest email > earlier email > sheet download, keyed on the RECEIVED_AT column); `home_base_v2.py` frozen fallback. **Full rehearsal passed** (phone→sheet, edit-overwrite, real Google download→dashboard on Mac AND on the lab-day Windows laptop, rebuilt from repo ZIP). Tag **`v3.0-lab3`** |
| ~2026-08-10 | **Lab 3** | **ALL groups' data arrived — the send failure is closed, by two changes at once.** The tech ("Send to class" primary), *and* a **redesigned pre-lab session**: 1-page reference sheet (rev4) picked up at the door → instrument sign-out → guided sensor setup to the all-values screen → app session setup → **first measurement taken and submitted together in the classroom** → TAs circulating → **the Google Sheet projected live**, so each group *watched their own row arrive* before leaving. Every group walked out with a proven pipeline. Groups then re-sent regularly all afternoon — the sheet doubled as a **live progress tracker** (the "live dashboard" goal met by the sheet alone; the idempotent-resend design shaping behaviour). **In-WeChat uploads: none observed** (path stays field-untested; camera-scan briefing + overlay steering held). **Junk: one row** — a group re-submitted a reading with blank values + a location note; hand-deleted in the sheet (new UID, so last-write-wins correctly didn't overwrite; the "instructor eyeballs" layer doing its job). **Backup earned its keep: 2 groups** hit field connectivity trouble → email, and AirDrop-to-TA on return (TA emailed it on). Pre-lab artifacts (ref sheet rev4, app-overview deck, Temtop-device deck) live in the OneDrive teaching folder, not this repo |
| 2026-08-12 | **Season close-out** | Endpoint lifecycle ends with the event: UPLOAD_URL blanked in config (pushed); Apps Script deployment archived + sheet deleted (manual, on the project Google account). Pattern documented in SETUP_UPLOAD.md "Closing up": per-event deployment, **secured by lifetime, not secrecy** (the URL ships in a public bundle — it can never be a secret; committed URLs in git history are fossils pointing at archived deployments) |

That last row is the paper's missing data point. The arc — *email fails →
split send/save → still fails → remove the file from the transport
entirely* — is the design-iteration story for The Physics Teacher; the
config-file adopter story is JOSE's.

## 4. How the pieces stay consistent

- **CSV format is the contract** — Temtop-native column names first, app
  columns after, `UID` per row. The Apps Script sheet is column-for-column
  identical to the app export, which is why its download drops straight
  into `csvs/`. **Never rename columns** (app ↔ endpoint ↔ hub ↔ Temtop
  comparison all depend on them).
- **Dedup chain by UID:** app DB has a unique index (import merges are
  idempotent) → endpoint is last-write-wins (re-sends cheap, edits
  overwrite in place, `RECEIVED_AT` = last arrival) → Home Base
  `load_folder` keeps one copy per UID with precedence *latest app export >
  earlier app export > sheet download* (sheet files self-identify by
  having a RECEIVED_AT column; filenames never matter).
- **Colour bands** live twice: `lib/models/map_variable.dart` and the
  `VARS` list in `home_base.py` — change one, change both.
- **Handout/guide generators embed their own text**: `make_handout.py`,
  `make_qr.py`, `classroom_map/make_guide.py` (the printable
  `Home_Base_Guide.docx` lags GETTING_STARTED.md unless re-run).

## 5. Fallbacks (three layers, all rehearsed)

1. **Config:** set `"UPLOAD_URL": ""` in deploy.config.json, push → site
   reverts to exact lab-2 behaviour (no button, stern WeChat warning).
   Editable from any browser via github.com if away from this machine.
2. **Hub:** `classroom_map/home_base_v2.py` = frozen lab-2 tool, runs
   identically (`python3 home_base_v2.py csvs`).
3. **Repo:** `git checkout v2.0-lab2` (or `v1.0.0` for the pre-web state).

Endpoint kill switch: Apps Script → Deploy → Manage deployments →
Archive (instant, from any browser).

## 6. Command cheat sheet

```bash
# Flutter app (from aq_mapping_app/; export XDG_CONFIG_HOME=$HOME/Projects/.config)
flutter analyze && flutter test     # 53 tests green expected
flutter run                         # device/simulator
flutter build web --release

# Home Base (from classroom_map/)
python3 home_base.py csvs --expect 25        # dashboard + full checklist
python3 make_sample_data.py                  # synthetic class → sample_csvs/
python3 home_base_v2.py csvs                 # frozen lab-2 fallback

# History
git tag -l                                   # v1.0.0, v2.0-lab2, v3.0-lab3
```

## 7. Paper trail

- `docs/article_draft.md` — activity-paper draft + **venue notes**
  (2026-07-18 plan: The Physics Teacher first, JOSE software paper in
  parallel, BAMS/Eos/conference for the atmospheric community; TA
  summer-school pilot → possible JGE study later, needs REB).
- `docs/v2_improvement_plan.md` §5 — pre-submission polish list
  (screenshots/GIF from **sample data only** — never real student GPS;
  CI + badges; CITATION.cff + Zenodo DOI).
- Claims about what failed in the field: this document's timeline + git
  history dates + `CLAUDE.md` status bullets are the record.

## 8. Open threads (deliberately not done)

- **WeChat in-webview upload**: still never exercised in real WeChat — none
  observed at lab 3 (the camera-scan briefing + overlay steering kept
  everyone in real browsers, which is the better outcome anyway). For the
  paper: claim the *steering* worked; do NOT claim in-WeChat upload works.
- **All-blank readings**: lab 3 produced one submitted reading with no
  sensor values, only a location note. Consider a soft "save anyway?"
  warning when every sensor field is empty (fits the existing hard/soft
  validation pattern; no schema change).
- Campus POI layer (`campus_pois.geojson`): built, never drawn/deployed.
- Live LAN/Dash Home Base with auto-refreshing checklist (the v2.0 dream);
  the upload code path was designed to point at a LAN endpoint someday.
- Institutional (non-Google) receiver: the app only needs a URL returning
  `{ok, received, added, updated, total}` — a ~30-line PHP script on
  U of T web space is a drop-in replacement when worth arranging.
- zh-CN app strings; group-code picker + `ACCURACY_M` column (⚠ needs DB
  schema v3 + migration + ffi test — see CLAUDE.md rule).

## 9. Deeper documentation index

| Doc | Purpose |
|---|---|
| `CLAUDE.md` | authoritative technical status + working rules |
| `SETUP.md` | adopter walkthrough (fork → config → Pages) |
| `classroom_map/upload_endpoint/SETUP_UPLOAD.md` | endpoint setup, lab-day flow, **Rollback** |
| `classroom_map/GETTING_STARTED.md` | Home Base first-time walkthrough + troubleshooting table |
| `docs/lab_day_claude_context.md` | paste-into-Claude ops manual for lab day |
| `student_handout/` | QR codes + reference sheets (regenerate via the make_*.py scripts) |
