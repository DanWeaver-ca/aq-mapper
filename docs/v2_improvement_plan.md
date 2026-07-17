# AQ Mapper v2 — Improvement Plan

*Drafted 2026-07-16, the day after the first full class run. Planning document only — no code has been changed. The v1 reference state is git tag `v1.0.0` plus two small uncommitted tweaks in `classroom_map/` (scroll-zoom in the Plotly toolbar config, and `pillow` added to `requirements.txt` — **these should be committed**, since `build_map.py` now imports PIL and a fresh install without pillow crashes).*

---

## 0. Where v1 stands

Strong foundations worth keeping and pointing readers at:

- Clear two-product structure (`aq_mapping_app/` phone app, `classroom_map/` hub) with READMEs at every level, MIT license, tagged release.
- 45 Flutter tests including schema-migration and CSV round-trip tests; `flutter analyze` clean.
- Real student CSVs and generated HTML are gitignored — nothing private can leak into the public repo.
- Code comments are already good *where they exist* (services, `build_map.py` header); the gaps are structural (see §4, §5), not stylistic.

The two field-tested pain points from 2026-07-15:
1. **Only ~half the groups' CSVs arrived by email.** On the web build, "Export & Share" triggers a plain browser download (`csv_export_platform_web.dart`); students then had to locate the file (iOS Files app — Safari's download UI is subtle) and manually attach it to an email. Many stalled at one of those steps.
2. **"Home base" is four separate windows** (`classroom_map.html`, `classroom_heatmap.html`, `classroom_stats.html`, `classroom_interpolated.html`), each a separately opened file, awkward to drive live on a projector.

---

## 1. Getting the data to the instructor (fix for "half the CSVs")

Ranked options. "Offline" = works with no internet in the room.

| # | Option | Student taps | Needs internet | Infra to maintain | Effort |
|---|--------|:---:|:---:|---|:---:|
| A | **One-tap "Send to instructor" upload** | 1 | yes | ~30-line cloud endpoint | M |
| B | **Web Share API share sheet on web** | 2–3 | no (for AirDrop) | none | S |
| C | **Home-base LAN receiver** (Phase 2) | 1 | no | laptop app + hotspot | M–L |
| D | **QR-code handoff** (screen → webcam) | 1 | no | none | M |
| E | mailto:/Google-Form paste | many | yes | none | S |

### A. One-tap upload — the recommended v2 default path
Add a **"Send to class"** button next to Export that `fetch`-POSTs the CSV text to a collection endpoint over HTTPS. Two good serverless homes:

- **Google Apps Script web app** (recommended first): a ~30-line `doPost` bound to Dan's Google account that writes each submission into a Drive folder (or appends to a Sheet). Free, no server, no keys in the app. CORS note: send the body as `text/plain` with no custom headers — that keeps it a "simple request" and avoids the preflight Apps Script can't answer.
- **Cloudflare Worker + R2/KV**: slightly more setup, cleaner CORS, and it can also serve a `GET /status` the dashboard polls ("12 of 25 groups received"). Free tier is far beyond class scale.

App-side UX that makes it actually reliable:
- Button state persists: "Sent ✓ 2:31 PM · 12 readings" (and re-enables if new readings are added since last send).
- On failure (no signal), clear message + automatic retry; **keep Export & Share as the fallback**, never remove it.
- Sends are idempotent — rows carry UIDs, so duplicate submissions are harmless, exactly like CSV import today.

Privacy note: readings (GPS + group code, no names) transit a cloud service. Acceptable as designed, but worth one line in the README; option C keeps data in-room if a school partner ever requires it.

### B. Web Share API — the scalable baseline; ship first *(detailed)*

**Key finding: this is almost entirely already built.** `share_plus: ^10.1.4` is already a dependency (the mobile path uses it), and its **web** implementation (`share_plus_web.dart`) already does exactly the proposed design: build a `File`, probe `navigator.canShare(...)`, call `navigator.share(...)`, and **fall back to an anchor download** when Web Share is unavailable or fails (`Share.downloadFallbackEnabled` defaults to `true`). Its web plugin auto-registers (declared in share_plus's pubspec), and `share_plus.dart` itself imports only `dart:async`/`dart:ui`/the platform interface — **no `dart:io`**, so it's safe in the web build and the existing conditional-import seam still holds. `XFile` is re-exported, so **no new dependency**.

In other words `csv_export_platform_web.dart` is hand-rolling a download that duplicates the plugin's *fallback* path while skipping its *primary* path. The fix is to stop bypassing it.

#### Two buttons, not one *(decided 2026-07-16 — supersedes "replace the download")*

Keep the file save; **add** sending as a separate action. The Data screen becomes:

```
┌──────────────────────────────────────┐
│  ➦  Send to instructor                │   filled / primary
└──────────────────────────────────────┘
     Opens your share sheet — AirDrop or Mail.
     Send to: dan.weaver@utoronto.ca  ⧉ copy      (from app_config; hidden if blank)

┌──────────────────────────────────────┐
│  ⤓  Save CSV to my phone              │   outlined / secondary  — web only
└──────────────────────────────────────┘
     Keeps your own copy, and your backup if sending fails.

┌──────────────────────────────────────┐
│  ⤒  Import CSVs from other groups     │   unchanged
└──────────────────────────────────────┘
```

Three reasons this beats replacing:
- **The save is genuinely useful** — a student's own copy of their data, and the thing to fall back on when a send fails in the field.
- **It makes the silent-fallback problem (gotcha 2 below) disappear.** With a real `saveCsv` function to call, `sendCsv` can set `Share.downloadFallbackEnabled = false`, catch the failure itself, save, and *say so*: "This browser can't share files — saved the CSV to your phone instead; attach it to an email." Replacing the download would have left share_plus quietly degrading to v1 behaviour with no way to tell.
- **The label survives the v2 upgrade.** "Send to instructor" means share sheet today and one-tap upload once an endpoint is configured (§1 A/C) — same button, same handout wording, no relearning.

It also fixes a small honesty bug: today's button reads "Export & Share CSV" but on web it only ever downloads.

#### The change (two small platform files)
The seam grows from one function to two, plus a capability flag:

```dart
// csv_export_platform.dart (stub — the io/web variants replace it)
/// True only where saving is a distinct, user-visible action (browsers). On
/// iOS/Android the native share sheet already contains "Save to Files", so the
/// app shows one button there, not two identical ones.
const bool kHasSeparateSave = false;

enum SendOutcome { shared, cancelled, savedInstead }

Future<void> saveCsv(String csvText, String filename) => throw UnsupportedError(…);
Future<SendOutcome> sendCsv(String csvText, String filename, {Rect? shareOrigin})
    => throw UnsupportedError(…);
```

```dart
// csv_export_platform_web.dart
const bool kHasSeparateSave = true;

/// Browser download — the v1 behaviour, kept deliberately. Lands in Downloads
/// (Android) or the Files app (iOS).
Future<void> saveCsv(String csvText, String filename) async { …today's anchor code… }

/// The share sheet (AirDrop, Mail, Drive…), falling back to [saveCsv] *with an
/// explanation* where the browser has no Web Share for files.
Future<SendOutcome> sendCsv(String csvText, String filename,
    {Rect? shareOrigin}) async {
  Share.downloadFallbackEnabled = false; // we handle it, so we can explain it
  final file = XFile.fromData(utf8.encode(csvText),
      mimeType: 'text/csv', name: filename);
  try {
    final r = await Share.shareXFiles(
      [file],
      subject: 'Air Quality Measurements',
      // XFile.fromData loses the name on web; this is how share_plus restores it.
      fileNameOverrides: [filename],
      sharePositionOrigin: shareOrigin,
    );
    return r.status == ShareResultStatus.dismissed
        ? SendOutcome.cancelled
        : SendOutcome.shared;
  } catch (_) {
    await saveCsv(csvText, filename);
    return SendOutcome.savedInstead;
  }
}
```

`csv_export_platform_io.dart` keeps today's temp-file + `Share.shareXFiles` body as `sendCsv`, sets `kHasSeparateSave = false`, and points `saveCsv` at `sendCsv` so no path can throw. `CsvExportService` grows a matching `save()` alongside `exportAndShare()` (rename → `send()`), both still built on the unit-tested `buildCsv`.

`SendOutcome` then drives honest feedback: `savedInstead` explains the fallback, `cancelled` avoids claiming "Sent ✓" when a student dismissed the sheet, `shared` is optimistic (web can't confirm delivery — only the §1 A endpoint can).

*Note:* `Share.downloadFallbackEnabled` is a global static; set it once at startup rather than per-call if that reads cleaner.

#### Gotchas that decide whether it works in the field
1. **Secure context — the testing trap.** Web Share needs HTTPS. `localhost` counts, so desktop testing works; serving `build/web` over `http://192.168.x.x` to a real phone **does not** — `navigator.share` is simply absent, you silently get the download fallback, and you'd wrongly conclude the feature is broken. Test on the deployed Pages URL or through a tunnel (`cloudflared tunnel --url http://localhost:8080`).
2. **User activation.** `navigator.share()` needs transient activation (~5 s). share_plus's internal `readAsBytes()` await is a microtask (fine), but `data_screen.dart` currently awaits `_sessionService.deviceId` inside the tap handler *before* export. Almost certainly fine, but iOS Safari has historically thrown `NotAllowedError` when a slow await precedes `share()`. Cheap insurance: cache `deviceId` in state during `_loadMeasurements()` so the handler has no slow awaits. Note the failure mode is *silent* — share_plus treats a non-`AbortError` `DOMException` as "fall back to download", i.e. v1 behaviour — so log it rather than letting it hide.
3. **`fileNameOverrides` is mandatory**, per the sketch above. Without it the device-prefixed filename (`aq_UTSC-AQMS-07_….csv`) — the thing that tells groups' files apart — is lost.
4. **Don't pass `text` alongside `files`.** Some Android targets then drop the attachment or take only the text. `subject` alone is safe and becomes the subject line in iOS Mail.
5. **File-type allowlist.** Chrome restricts shareable types; `text/csv` is on the allowlist, and Safari is permissive. Fine today, but check before ever sharing e.g. `.db`.
6. **share_plus 11** deprecates `Share.shareXFiles` in favour of `SharePlus.instance.share(ShareParams(...))`. Not urgent; when it happens, the io and web variants move together.

#### Support and degradation
iOS Safari 15+ (so *all* iOS browsers — they're all WebKit) and Android Chrome get the share sheet; desktop Chrome is patchy by OS and Firefox has no file sharing — all of which land on the download fallback, i.e. exactly today's behaviour. Nothing regresses anywhere. *(Confirm current versions on caniuse.com/web-share at write-up time.)*

#### The recipient can't be pre-filled — plan around it
Web Share has no "to" field: the student picks the app and addresses it themselves. **AirDrop needs no address at all** (iOS group → instructor's Mac, instant, offline) — that's the happy path worth teaching in the handout. For Mail, put `instructorEmail` in `app_config.dart` and show it under the Send button with a copy button (hidden when blank, so adopters aren't forced to hard-code an address). `mailto:` *can* pre-address but cannot attach a file, so there's no way to have both — until the §1 A endpoint makes the question moot.

#### Optional polish: probe capability for the label
Both a successful share and share_plus's own fallback return `ShareResult.unavailable`, so the return value alone can't tell them apart — which is exactly why `sendCsv` above disables that fallback and does its own. If you'd also like the *button* to read differently on a browser with no Web Share ("Save CSV" only, no Send), probe once at screen load with a dummy 1-byte `File` through `navigator.canShare` (`package:web` is already a dep; wrap in try/catch, since `canShare` may be absent entirely). Nice-to-have — `SendOutcome.savedInstead` already explains itself after the fact.

#### Testing
No existing test touches `deliverCsv` — the 45 tests only exercise the pure `buildCsv` — so this cannot break the suite, and the suite cannot validate it. Keep that split deliberately (pure logic unit-tested; the platform shim thin and manually verified) and say so in the README. The `DataScreen` widget test can grow to assert both buttons render and disable correctly while `_isSending`, since that's pure widget state. Manual matrix: iPhone Safari, iPhone **home-screen PWA (standalone mode)**, Android Chrome, desktop Chrome + Firefox (expect `savedInstead`).

**Effort:** ~40 lines across the two platform files, ~20 in `data_screen.dart`, plus handout wording. Still half a day, nearly all of it device testing over HTTPS.

#### Why this is the right default for adopters
Zero infrastructure: no endpoint, no account, no keys, no CORS, no bill, nothing to rot — someone forking the repo deploys to their own Pages and it works. And the data path stays phone → student's own share sheet → instructor, never transiting a server the project operates. For an activity involving minors at someone else's school, that's a feature worth stating in the article.

Its honest limit: it removes the two steps that broke (find the file, attach it) but each group must still *complete* a send, and it gives no "12 of 25 received" visibility. That's what option A/C buy — which is why they stay on the roadmap as an **opt-in** for the live dashboard rather than the default.

### C. Home-base LAN receiver — fold into the dashboard (§2)
The Phase-2 plan from CLAUDE.md: the dashboard app (Python/Flask-based) exposes `POST /upload`; phones on the instructor's hotspot hit it via a projected QR code URL. Strengths: zero internet dependency, data never leaves the room, and the projected map fills in live as groups return — a great classroom moment. Caveats: campus wifi client-isolation usually blocks phone→laptop, so it needs the hotspot; phone hotspots cap concurrent clients (~5–10), which is fine because each upload takes seconds — groups connect, send, disconnect. Best positioned as the **offline deployment mode of the same dashboard**, with A as the internet mode (same app-side button, configurable endpoint URL).

### D. QR handoff — emergency fallback, nice teaching prop
The app renders its CSV as QR code(s) (a 15-reading export is ~2–3 KB; gzip+base64 fits in one or two codes); home base scans them with the laptop webcam. Zero infrastructure, fully offline, but serial-scanning 25 groups is slow. Worth having only if A/B/C prove flaky in some venue.

### E. Rejected for the record
`mailto:` can't attach files, and pasting CSV text into an email body or Google Form survives transport but is fragile and clunky. Not worth building around.

**Recommendation (revised 2026-07-16):** **B is the baseline and ships first** (v1.1) — it costs ~15 lines, adds no dependency and no infrastructure, and is the only option an adopter inherits for free. **A/C become opt-in**, enabled by an endpoint URL in `app_config.dart`: left blank (the default, and what a forker gets), the app just shares; set to a cloud endpoint or the laptop's LAN address, the "Send to class" button appears and home base gains its live group checklist. Same button, same idempotent UID-keyed payload, one config line apart. Success metric for the next run: 25/25 datasets received — with B, counted by hand as they arrive; with A/C, visible on the dashboard before students sit down.

---

## 2. "Home base" — one dashboard instead of four windows

### Option A — single tabbed HTML (recommended first step)
`build_map.py` already builds all four figures; instead of four `write_html` calls, emit **one self-contained `classroom_dashboard.html`**:
- Tab bar: **Map · Interpolated · Heatmap · Stats**, each tab holding one existing figure (`plotly.io.to_html(fig, full_html=False, include_plotlyjs=False)` + Plotly.js inlined once + a few lines of tab JS, calling `Plotly.Plots.resize` on tab switch).
- Header strip: event title, points, groups, indoor/outdoor counts, "built from N files at HH:MM".
- **Group checklist**: expected roster (Group 01…25) vs received — makes the missing-data problem visible *during* class, not after.
- Keeps everything that works today: double-click to open, no server, emailable to students afterward. Bonus: ~4–5 MB total instead of today's ~14 MB across four files (Plotly.js is currently inlined four times).

Effort: small. This is enough for the article's screenshots and the next class run.

### Option B — live "Home Base" app (v2 flagship, enables Phase 2)
A **Plotly Dash** app (Dash = Flask underneath, all Python, reuses the existing figure code nearly as-is):
- One browser window with the same tabs, auto-refreshing as data arrives.
- Ingest three ways, same pipeline: watch `csvs/` for dropped files (emailed attachments), drag-and-drop upload zone, and `POST /upload` from the phones (§1 A/C).
- Live group checklist + "presentation mode" (big fonts, hides controls).
- One-click "export static dashboard HTML" so the shareable-file workflow survives.

Why Dash over Streamlit/Voila/Panel: the four figures are already Plotly `go.Figure`s (zero rework), it stays a single Python file an instructor can read, and its Flask core is exactly where the upload endpoint belongs.

**Versioning per your "keep copies" preference:** leave `build_map.py` untouched as the v1 reference and add `home_base.py` (or `dashboard/`) alongside — plus git tags (`v1.0.0` already preserves today's state exactly).

---

## 3. App improvements from field experience

- **GPS accuracy guard** *(seen in June testing: a coarse cell-tower fix ~1.4 km off)*: `geolocator` reports `Position.accuracy`; warn at save time when it's poor ("Location accurate to ±950 m — move outside / enable Precise Location?") and record an `ACCURACY_M` CSV column so home base can flag or filter suspect points. Note: new column ⇒ **DB schema v3 + migration + ffi migration test** (house rule), and the hub must tolerate the column's absence in old files.
- **Group-code picker** ("Group 01"…"Group 25" + Other): free-text group names sort badly in the hub (`Group 10` before `Group 2`) and invite personal names (privacy). Zero-padded codes fix both.
- **Export/send status nudge**: a chip on Home/Data — "Not sent yet" / "Sent ✓ 2:31 PM" — complementing the existing amber banner.
- **Handout update** (`student_handout/make_handout.py`): add "turn ON Precise Location" line (the pending mitigation from June), and, once §1A exists, replace the email instructions with "tap Send to class".
- *(Optional)* Simplified-Chinese strings for visiting cohorts; a `flutter_localizations` pass is mechanical since UI text is centralized in widgets.

---

## 4. Hub hardening (`classroom_map/`)

Real-world CSV handling — emailed files get opened and resaved in Excel:
- Read with `encoding="utf-8-sig"` (BOM), wrap **per-file** try/except so one bad file reports and skips instead of killing the whole build (mirror the app's per-file failure reporting), tolerate missing columns from older app versions.
- **Pin dependencies for readers**: `plotly>=5.18,<6` (Plotly 6 deprecates the `*mapbox` trace family this script uses) — or migrate to `go.Scattermap` in v2. An unpinned fresh install on a reader's machine should not behave differently from yours.
- Structure for readers: `main()` + `argparse` (`--csv-dir --out --roster`), one function per figure, type hints. It can stay a single instructor-readable file.
- **Single source of truth for colour bands**: today `VARS` (Python) mirrors `map_variable.dart` by hand. Either generate both from one `shared/variables.json`, or minimally add a cross-check test that parses both and fails CI on drift.

---

## 5. Article/repo readiness (professional polish, mostly docs)

- **Screenshots + a 20-second demo GIF** in the root README (app entry → map → dashboard). Highest-value single addition for an article audience. Regenerate figures from `sample_csvs/` so nothing student-derived is published.
- **Architecture/data-flow diagram** (mermaid in README): sensor → phone entry → CSV/send → home base → projector.
- **"Run the whole lab in 10 minutes" quickstart**: live app URL + `make_sample_data.py` + hub build — a reader can experience the full loop with zero hardware.
- **CITATION.cff + Zenodo DOI** on the next release — lets the article cite an archived version; GitHub then shows "Cite this repository".
- **CI**: add a workflow running `flutter analyze` + `flutter test` + a hub smoke test (`make_sample_data.py && build_map.py sample_csvs`) on PRs/pushes; badges in README. (Deploy workflow already exists and pins Flutter 3.41.4 — good.)
- **Privacy/ethics section** in README: no accounts, no names, group codes only, data on-device until shared; guidance for adopters working with minors.
- Housekeeping: strip Flutter-boilerplate comments from `pubspec.yaml`; single-source the version (`package_info_plus` reads pubspec's `version:` on all platforms, replacing the hand-maintained `appVersion`); move root `QR-code_image.pdf` into `student_handout/`; delete `classroom_map/diag_basemap_z16.png` (debug artifact); fix the `…Day - outine.docx` filename typo; consider moving the 44 MB Temtop PDF to a GitHub Release asset so clones stay light; add repo About text + topics (`air-quality`, `flutter`, `citizen-science`, `physics-education`).

---

## 6. One-file institution setup (`deploy.config.json`) — planned 2026-07-17

**Goal:** an adopting instructor forks the repo, edits **one JSON file in the
GitHub web editor** (no local tooling), enables Pages, and gets a fully
rebranded deployment: their campus as the map home, their institution name in
the app and PWA install banner, their email under "Send to instructor", their
sensor-ID scheme in the dropdown, and a handout QR pointing at their URL.

### Where institution values live today (the problem)

| File | Values |
|---|---|
| `lib/app_config.dart` | app title, map centre, instructor email, version |
| `lib/screens/session_setup_screen.dart` | device-ID scheme (`UTSC-AQMS-01…25`), "Temtop" wording |
| `web/index.html` + `web/manifest.json` | PWA name, description ("…the UTSC lab"), theme colour |
| `tool/download_campus_tiles.py` | offline-tile bounding box + contact string |
| `student_handout/make_handout.py` | hard-coded `APP_URL` for the QR code |
| `classroom_map/home_base.py` | `--title` default "UTSC Air Quality" |
| `classroom_map/make_sample_data.py` | synthetic-data campus coordinates + device names |

Seven files; a fork today means hunting all of them.

### Design: one flat JSON at repo root, consumed three ways

**`deploy.config.json`** (committed; Dan's values are the reference deployment):

```json
{
  "APP_TITLE": "Air Quality Mapper",
  "INSTITUTION": "University of Toronto Scarborough",
  "EVENT_TITLE": "UTSC Air Quality",
  "INSTRUCTOR_EMAIL": "dan.weaver@utoronto.ca",
  "CAMPUS_LAT": "43.7841",
  "CAMPUS_LON": "-79.1873",
  "DEVICE_ID_PREFIX": "UTSC-AQMS-",
  "DEVICE_COUNT": "25",
  "SENSOR_NAME": "Temtop",
  "APP_URL": "https://danweaver-ca.github.io/aq-mapper/",
  "TILES_BBOX": "43.776,43.793,-79.198,-79.176"
}
```

Flat ALL-CAPS string keys on purpose — that is exactly the shape Flutter's
`--dart-define-from-file` consumes.

1. **Flutter app — compile-time defines** (the standard mechanism, Flutter
   ≥3.7; we're on 3.41): `app_config.dart` keeps every constant but sources it
   from `String.fromEnvironment('APP_TITLE', defaultValue: 'Air Quality
   Mapper')` etc.; the deploy workflow adds
   `--dart-define-from-file=../deploy.config.json` to `flutter build web`.
   Plain `flutter run` without the file still works on the UTSC defaults.
   Gotchas: there is no `double.fromEnvironment` — lat/lon arrive as strings
   and are parsed once into a `final` (not `const`) `LatLng`; `DEVICE_COUNT`
   via `int.fromEnvironment`. The device dropdown builds from
   `DEVICE_ID_PREFIX` + count; "Other…" free-text stays. `SENSOR_NAME` feeds
   the session-setup wording ("the ID printed on your Temtop sensor").
2. **Web shell — a patch step in the workflow**: `index.html`/`manifest.json`
   can't read dart-defines, so a ~10-line Python step in `deploy-web.yml`
   (before `flutter build web`) rewrites title/name/description on the runner
   from the same JSON. Nothing committed changes; forks never touch the web/
   folder.
3. **Python tools — read the JSON directly**: `make_handout.py` takes
   `APP_URL` (QR + link line), `home_base.py`'s `--title` default becomes
   `EVENT_TITLE` when the file is found (CLI flag still wins),
   `make_sample_data.py` centres its synthetic route on `CAMPUS_LAT/LON` and
   uses `DEVICE_ID_PREFIX`, `download_campus_tiles.py` reads `TILES_BBOX`.
   Each is a ~5-line `json.load` with the current value as fallback — the
   hub stays copyable to a laptop without the repo.

### What deliberately stays fixed

- **CSV column names** (Temtop-branded headers in `measurement.dart`): they
  are the file-format contract between app, hub, and the device's own
  exports. Renaming them per-institution would fork the data format —
  explicitly out of scope, with a comment saying so.
- **Colour bands / thresholds**: health guidance, not branding.
- **App icon + theme colour**: generic cloud, institution-neutral; swapping
  is documented as an optional step (`tool/icon/make_icon.py`), not config.

### Offline tiles are optional by design

`offline_first_tile_provider.dart` is asset-first with network fallback, so a
fork that never regenerates tiles still works everywhere with connectivity —
the bundled UTSC tiles simply never match their map view. `SETUP.md` documents
tile regeneration (run `download_campus_tiles.py` locally, commit the new
PNGs) as the one optional local-tooling step, for field sites with poor
signal. The tool's OSM user-agent contact string should also come from the
config (tile-server policy asks for a real contact).

### `SETUP.md` (repo root) — the adopter's front door

Fork → edit `deploy.config.json` in the GitHub editor → Settings → Pages →
"GitHub Actions" → wait for the green check → open your URL. Then: print the
handout (`make_handout.py`, now pointing at your URL), set up the hub laptop
(`classroom_map/GETTING_STARTED.md`), optional tiles/icon. Ends with a
**verification checklist**: home screen shows your title + version; map
centres on your campus with GPS off; device dropdown shows your IDs; your
email sits under Send to instructor. The article points readers here.

### Guardrails

- **CI validation step**: parse the JSON, require all keys, `float()` the
  coordinates, sanity-check the bbox — a typo fails the build in seconds
  with a readable message instead of deploying a broken app.
- **Config is public by design**: the email and coordinates end up in the
  repo and the built JS bundle (they already do today). `SETUP.md` says so —
  use a role/department address if that matters.
- One new test: device-ID list derives correctly from prefix+count.

### Phases & effort

- **Phase 1 (v1.2, ~half a day + a deploy test):** the JSON, `app_config.dart`
  + session-setup wiring, workflow define + patch step + validation, the four
  Python readers, `SETUP.md`, README/CLAUDE.md pointers.
- **Phase 2 (optional polish):** `tool/setup_wizard.py` — interactive Q&A
  that writes the JSON and regenerates handout/QR (and tiles if asked); a
  `THEME_COLOR` key patched into manifest + Material seed; institution name
  shown on the session-setup screen as visible confirmation the config took.

## 7. Suggested milestones

**v1.1 — "article-ready"** (docs + small fixes, ~a day):
- [ ] Commit the two pending `classroom_map/` tweaks
- [x] "Send to instructor" button via Web Share, **alongside** the kept file save (§1 B); `instructorEmail` in `app_config.dart` — *implemented 2026-07-17 (app v1.1.0); device matrix still to run on the deployed URL*
- [x] Tabbed single-file dashboard (§2 A) — *implemented 2026-07-17 as `home_base.py` → `classroom_dashboard.html`, incl. group checklist (`--expect`/`--roster`), per-file error tolerance, utf-8-sig, argparse, and the §4 MapLibre migration (`plotly>=5.24,<7`); `build_map.py` frozen as v1 reference*
- [ ] README screenshots/GIF, diagram, quickstart, privacy note, CITATION.cff, CI + badges (§5)
- [ ] Handout: Precise Location line (§3)
- [ ] Hub: utf-8-sig + per-file error handling + pinned deps (§4)

**v1.2 — "adopt-me" (§6) — implemented & tested 2026-07-17**:
- [x] `deploy.config.json` + dart-defines in `app_config.dart` / session setup
- [x] Workflow: `--dart-define-from-file`, web-shell patch step, JSON validation
- [x] Python readers: handout QR, hub title, sample data, tiles bbox (`AQ_CONFIG` env override for testing)
- [x] `SETUP.md` with verification checklist; README/CLAUDE.md pointers
- [x] End-to-end test with a fictional school config (Northview/Ottawa): all values verified in the built app + all four python outputs
- [x] Two deployments per push: UTSC at site root + generic demo at `/demo/` (`deploy.config.demo.json`); optional `STORAGE_KEY` namespaces on-device storage because all project pages of one GitHub account share a browser origin — isolation verified locally (session in /demo/ invisible at root)
- [ ] *(optional, later)* setup wizard, theme colour, config echo on session screen

**v2.0 — "one-tap data + live home base"**:
- [ ] "Send to class" upload + endpoint (§1 A), configurable for LAN mode (§1 C)
- [ ] Dash Home Base with live refresh, uploads, group checklist (§2 B)
- [ ] Accuracy column + schema v3 + migration test; group-code picker (§3)
- [ ] Band-spec single source of truth (§4)

*Everything above preserves the current files: new code goes in new files/copies, v1 remains at tag `v1.0.0` for reference.*
