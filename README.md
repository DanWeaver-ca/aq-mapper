# AQ Mapper

A small, offline-friendly toolkit for a UTSC air-quality lab. Visiting students
carry Temtop M2000+ sensors around campus, log readings into a phone app that
auto-captures GPS, and then the class data is merged and projected on a map for
the debrief.

**▶ Live student app (UTSC): https://danweaver-ca.github.io/aq-mapper/**
(Open on a phone, then *Add to Home Screen*. Works on iOS and Android — no app
store, no install.)

**▶ Generic demo (try it / fork it): https://danweaver-ca.github.io/aq-mapper/demo/**
— the same app with placeholder branding and isolated storage, rebuilt from
[`deploy.config.demo.json`](deploy.config.demo.json) on every push.

## Two parts

### 1. The student app (`aq_mapping_app/`)
A Flutter app — shipped as a **web app / PWA** so students just open a URL — for
entering readings (PM2.5, PM10, particles, CO₂, HCHO, temperature, humidity)
with GPS, mean ± variability, and indoor/outdoor tagging. Data is stored on the
device, shown on a colour-coded OpenStreetMap with a legend and heatmap, and
exported as CSV. The campus map tiles are pre-bundled so the map works offline
in the field. The same codebase also builds native iOS/Android.

### 2. Home Base — the classroom dashboard (`classroom_map/`)
A standalone **Python/Plotly** tool the instructor runs on a laptop (Windows or
Mac). It merges every group's exported CSV into **one self-contained
dashboard** (`classroom_dashboard.html`) with four tabs — points map (filter by
group / indoor / outdoor, colours matching the phone app exactly), an
interpolated "estimated field" with a selectable smoothing radius, a PM2.5
density heatmap, and a summary-stats panel — plus a header checklist showing
which groups have reported and which are missing.

First time? Follow the walkthrough in `classroom_map/GETTING_STARTED.md`
(printable twin: `Home_Base_Guide.docx`); `classroom_map/README.md` is the
short reference.

## Tech
Flutter (web + mobile), OpenStreetMap via `flutter_map`, SQLite (`sqflite` on
mobile, `sqflite_common_ffi_web` on web), `geolocator`. Classroom hub: Python +
pandas + Plotly. Hosting: GitHub Pages via the workflow in `.github/workflows/`.

## Development
```bash
cd aq_mapping_app
flutter pub get
flutter analyze        # clean
flutter test           # 48 tests
flutter run            # mobile
flutter build web      # web/PWA (deployed automatically on push to main)
```
Project notes and design decisions live in `CLAUDE.md`.

## Adapt it for your institution
Everything institution-specific lives in one file: fork, edit
[`deploy.config.json`](deploy.config.json) (names, campus coordinates,
instructor email, sensor-ID scheme) in the GitHub editor, enable Pages —
**[SETUP.md](SETUP.md)** walks through it in ~15 minutes, no local tools
needed.

## License
MIT — see [LICENSE](LICENSE). Reuse and adapt for your own outreach or campus.
