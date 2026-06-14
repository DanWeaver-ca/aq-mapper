# AQ Mapper

A small, offline-friendly toolkit for a UTSC air-quality lab. Visiting students
carry Temtop M2000+ sensors around campus, log readings into a phone app that
auto-captures GPS, and then the class data is merged and projected on a map for
the debrief.

**▶ Live student app: https://danweaver-ca.github.io/aq-mapper/**
(Open on a phone, then *Add to Home Screen*. Works on iOS and Android — no app
store, no install.)

## Two parts

### 1. The student app (`aq_mapping_app/`)
A Flutter app — shipped as a **web app / PWA** so students just open a URL — for
entering readings (PM2.5, PM10, particles, CO₂, HCHO, temperature, humidity)
with GPS, mean ± variability, and indoor/outdoor tagging. Data is stored on the
device, shown on a colour-coded OpenStreetMap with a legend and heatmap, and
exported as CSV. The campus map tiles are pre-bundled so the map works offline
in the field. The same codebase also builds native iOS/Android.

### 2. The classroom map (`aq_mapping_app/tool/classroom_map/`)
A standalone **Python/Plotly** tool the instructor runs on a laptop (Windows or
Mac). It merges every group's exported CSV and produces:
- an interactive map filtered by group / indoor / outdoor and coloured by any
  variable (colours match the phone app exactly),
- a PM2.5 density heatmap,
- a summary-stats panel (indoor-vs-outdoor averages + per-group table).

See `aq_mapping_app/tool/classroom_map/README.md` and the step-by-step
`Classroom_Map_Guide.docx` for setup.

## Tech
Flutter (web + mobile), OpenStreetMap via `flutter_map`, SQLite (`sqflite` on
mobile, `sqflite_common_ffi_web` on web), `geolocator`. Classroom hub: Python +
pandas + Plotly. Hosting: GitHub Pages via the workflow in `.github/workflows/`.

## Development
```bash
cd aq_mapping_app
flutter pub get
flutter analyze        # clean
flutter test           # 45 tests
flutter run            # mobile
flutter build web      # web/PWA (deployed automatically on push to main)
```
Project notes and design decisions live in `CLAUDE.md`.

## License
MIT — see [LICENSE](LICENSE). Reuse and adapt for your own outreach or campus.
