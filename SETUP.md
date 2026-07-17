# Set up AQ Mapper for your institution

Everything institution-specific — names, campus location, instructor email,
sensor-ID scheme — lives in **one file: [`deploy.config.json`](deploy.config.json)**.
Adopting the app takes about 15 minutes and needs **no local tools**: you edit
one file on GitHub and the deployment rebuilds itself.

## 1. Fork the repository

GitHub → **Fork**. Keep the fork **public** (GitHub Pages is free only on
public repositories). Your app's address will be
`https://<your-username>.github.io/<repo-name>/` — GitHub adjusts the build to
the repo name automatically.

## 2. Edit `deploy.config.json`

Open the file on GitHub, click the pencil (Edit), change the values, commit.

| Key | What it controls |
|---|---|
| `APP_TITLE` | App name on the home screen and PWA install banner |
| `APP_SHORT_NAME` | Short name for the browser tab / home-screen icon (≤ ~12 chars) |
| `INSTITUTION` | Used in the app-store-style description text |
| `EVENT_TITLE` | Header title of the classroom Home Base dashboard |
| `INSTRUCTOR_EMAIL` | Shown under "Send to instructor" with a copy button |
| `CAMPUS_LAT` / `CAMPUS_LON` | Where the map centres before any data/GPS exists |
| `DEVICE_ID_PREFIX` / `DEVICE_COUNT` | Sensor dropdown: `PREFIX01` … `PREFIXnn` (an "Other…" free-text option always remains) |
| `SENSOR_NAME` | Sensor brand in the setup wording ("the ID printed on your … sensor") |
| `APP_URL` | Your deployed address — feeds the student-handout QR code |
| `TILES_BBOX` | `latMin,latMax,lonMin,lonMax` for the optional offline tile pack |

> **Public by design:** this file (and the built app) is public — the email
> and coordinates in it are visible to anyone. Use a role or department
> address if that matters.

## 3. Turn on GitHub Pages

Fork → **Settings → Pages → Source: "GitHub Actions"**. Then make any commit
(editing the config in step 2 counts) or run the *Deploy AQ Mapper web*
workflow from the Actions tab. The workflow **validates your config first** —
a typo (bad coordinate, missing key) fails the build in seconds with a
readable message instead of deploying a broken app.

## 4. Verify (2 minutes, on your phone)

Open your URL and check:

- [ ] Browser tab + home screen show **your** titles (and the version label).
- [ ] Session setup mentions **your sensor name** and the device dropdown
      lists **your IDs**.
- [ ] With location off and no data, the map centres on **your campus**.
- [ ] Data screen shows **your email** under "Send to instructor".

## 5. Print your handout

The student handout (QR code + instructions) points at `APP_URL`
automatically. On any machine with Python:

```
pip install qrcode python-docx pillow
python student_handout/make_handout.py
```

## Optional extras (need a computer, not required)

- **Offline campus tiles** — for field sites with poor signal. Set
  `TILES_BBOX`, then run `python aq_mapping_app/tool/download_campus_tiles.py`
  and commit the PNGs it writes to `aq_mapping_app/assets/tiles/`. Without
  this the map simply loads tiles from the internet — everything else works.
- **Your own app icon** — edit `aq_mapping_app/tool/icon/make_icon.py`, then
  `dart run flutter_launcher_icons` (see CLAUDE.md).
- **Native iOS/Android builds** — the same codebase builds both
  (`flutter build ios` / `apk`); the web/PWA path needs neither.
- **Classroom dashboard title** — Home Base reads `EVENT_TITLE` on its own;
  see `classroom_map/GETTING_STARTED.md` for the instructor-laptop setup.

## Two deployments from one repo (the built-in demo)

This repo deploys **twice from the same push**: the institution version at
the site root (students' URL) and a generic, clearly-marked demo at
**`/demo/`** (from [`deploy.config.demo.json`](deploy.config.demo.json)) —
useful as a shareable "try it" link that doesn't carry your branding.

One technical rule to know: **all GitHub project pages of one account share
a browser origin**, and the app stores data per origin. Any two deployments
under the same domain must therefore set different **`STORAGE_KEY`** values
(the demo uses `"demo"`; leave your main config's key absent/empty so
existing users keep their data). A wrong/missing key doesn't break the app —
it just makes the two deployments share on-device storage, which you don't
want during a lab. Forks inherit all of this automatically; if you don't
want a demo, delete the demo build step from the workflow.

## For developers

Plain `flutter run` uses the UTSC defaults baked into
`aq_mapping_app/lib/app_config.dart`. To run with your config locally:

```
cd aq_mapping_app
flutter run --dart-define-from-file=../deploy.config.json
```

The deploy workflow also stamps `web/index.html` / `web/manifest.json` from
the config (`tool/patch_web_shell.py`) since the web shell can't read
dart-defines. One thing is deliberately **not** configurable: the CSV column
names — they're the file-format contract between the app, the classroom hub,
and the Temtop sensor's own exports.
