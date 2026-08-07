# One-tap uploads: set up "Send to class" (~5 minutes, free)

By default students send you their CSV file by email or AirDrop. That fails
for students **without an email account** or whose phone opened the app
**inside WeChat's browser** (which can neither share nor save files). This
optional endpoint fixes both: the app gets a **"Send to class"** button that
uploads every reading straight to a Google Sheet on your account — no email,
no share sheet, and it works inside WeChat too, because it's a plain web
request. The CSV/email path stays available as a fallback.

You need: a free Google account. Nothing to install, nothing to pay.

## 1. Create the receiving spreadsheet

1. Go to [sheets.new](https://sheets.new) and name the spreadsheet, e.g.
   **AQ Mapper uploads**.
2. **Extensions → Apps Script**. Delete the placeholder code, paste the
   entire contents of [`Code.gs`](Code.gs) (in this folder), and save
   (Ctrl/Cmd-S).

## 2. Deploy it as a web app

1. Click **Deploy → New deployment**.
2. Gear icon → type **Web app**.
3. Set **Execute as: Me** and **Who has access: Anyone** — "Anyone" is what
   lets student phones POST without signing in. (The spreadsheet itself
   stays private to your account; "Anyone" only exposes the upload URL.)
4. **Deploy**, authorize when asked, then copy the **Web app URL**
   (ends in `/exec`).
5. Sanity check: open that URL in a browser tab. You should see
   `{"ok":true,"service":"aq-mapper-upload","rows":0}`.

## 3. Tell the app about it

In the repo, edit `deploy.config.json` and set:

```json
"UPLOAD_URL": "https://script.google.com/macros/s/…your-id…/exec"
```

Commit and push — GitHub Pages redeploys, and the Data screen now shows
**"Send to class"** above the email/CSV options. Leave `UPLOAD_URL` empty
(`""`) to hide the button again; nothing else changes either way.

## 4. Lab day

- **"Send to class" is the primary path; email/AirDrop is the backup.**
  Brief the class in one line: *tap Send to class whenever you like; if it
  fails, use Send to instructor; after editing a reading, just re-send.*
- The app sends *all* readings every time and reports what the server said
  ("42 readings received"). Re-sending is harmless: unchanged rows are
  skipped, and an **edited reading overwrites its earlier copy** (last
  write wins), so corrections propagate. The app's confirmation counts
  *new* rows — a re-send after an edit may say "already all there", but the
  sheet has the corrected values (its RECEIVED_AT column shows when each
  row last arrived).
- **Wifi first:** phones roaming on foreign SIMs route data through the
  home carrier — for Chinese SIMs, Google can be unreachable even on
  campus. Get everyone onto campus wifi before they send; anyone still
  stuck uses the email backup.
- Watch the rows arrive in the sheet live during the lab — chase missing
  groups while everyone is still on campus.
- For the debrief: **File → Download → Comma Separated Values (.csv)** on
  the `readings` sheet, drop that file into `classroom_map/csvs/` alongside
  any emailed CSVs, and run Home Base as usual — **any filename is fine**.
  Home Base recognises the sheet download by its RECEIVED_AT column and,
  where an uploaded and an emailed copy of the same reading differ, lets
  the emailed export win (it is the end-of-lab snapshot).
- **Afterwards: transit, not storage.** Once the CSV is downloaded, delete
  the rows (or the whole spreadsheet). Nothing about the class needs to
  persist on the Google account past the debrief.

## Rollback

Three independent fallback layers, cheapest first:

1. **Turn the feature off:** set `"UPLOAD_URL": ""` in `deploy.config.json`
   and push. The site rebuilds to exactly the lab-2 behaviour — no "Send to
   class" button, the sterner WeChat warning — and nothing else changes.
   Data already on student phones is unaffected.
2. **Home Base:** `home_base_v2.py` (beside `home_base.py`) is the frozen
   lab-2 dashboard tool — run it the same way if the new one misbehaves.
3. **Whole repo:** git tag `v2.0-lab2` is the complete lab-2 code state.

## Notes

- **Updating the script later:** edit the code, then **Deploy → Manage
  deployments → ✏️ → New version → Deploy**. (A plain save does NOT update
  the live URL — versions are pinned.)
- **Privacy:** the sheet holds GPS tracks and student-typed group names.
  It lives on your Google account, visible only to you; treat it like the
  `csvs/` folder (keep it off shared drives, and delete it once the debrief
  CSV is downloaded — see Lab day above). The
  upload URL is public-but-unguessable; anyone who has it could add rows,
  which for classroom purposes is an acceptable trade for zero-friction
  uploads — clear obviously-junk rows in the sheet if they ever appear.
- **Quotas:** Google's free limits are far above classroom scale
  (a class of 25 groups re-sending all day is a few hundred small requests).
- **Why text/plain?** The app deliberately posts `text/plain` JSON so
  browsers skip the CORS preflight that Apps Script can't answer. Don't
  "fix" the content type.
