"""Validate /deploy.config.json — fail fast with a readable message.

The deploy workflow runs this before building, so a typo in the config fails
in seconds instead of deploying a broken app. Run locally from
aq_mapping_app/ with:  python3 tool/check_config.py ../deploy.config.json
"""
import json
import os
import re
import sys

REQUIRED = [
    "APP_TITLE", "APP_SHORT_NAME", "INSTITUTION", "EVENT_TITLE",
    "INSTRUCTOR_EMAIL", "CAMPUS_LAT", "CAMPUS_LON", "DEVICE_ID_PREFIX",
    "DEVICE_COUNT", "SENSOR_NAME", "APP_URL", "TILES_BBOX",
]

path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..",
    "deploy.config.json")

try:
    with open(path, encoding="utf-8") as fh:
        cfg = json.load(fh)
except FileNotFoundError:
    sys.exit(f"deploy.config.json not found at {path}")
except json.JSONDecodeError as e:
    sys.exit(f"deploy.config.json is not valid JSON: {e}")

missing = [k for k in REQUIRED if str(cfg.get(k, "")).strip() == ""]
if missing:
    sys.exit("deploy.config.json is missing: " + ", ".join(missing))

errs = []
lat = lon = None
try:
    lat, lon = float(cfg["CAMPUS_LAT"]), float(cfg["CAMPUS_LON"])
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        errs.append("CAMPUS_LAT/CAMPUS_LON out of range")
except ValueError:
    errs.append("CAMPUS_LAT/CAMPUS_LON must be numbers")
try:
    if int(cfg["DEVICE_COUNT"]) < 1:
        errs.append("DEVICE_COUNT must be at least 1")
except ValueError:
    errs.append("DEVICE_COUNT must be a whole number")
try:
    la0, la1, lo0, lo1 = [float(v) for v in cfg["TILES_BBOX"].split(",")]
    if not (la0 < la1 and lo0 < lo1):
        errs.append("TILES_BBOX must be latMin,latMax,lonMin,lonMax (min<max)")
except Exception:
    errs.append("TILES_BBOX must be four comma-separated numbers")
if "@" not in cfg["INSTRUCTOR_EMAIL"]:
    errs.append("INSTRUCTOR_EMAIL does not look like an email address")
if not str(cfg["APP_URL"]).startswith("https://"):
    errs.append("APP_URL must start with https://")
# Optional: namespaces on-device storage for same-origin multi-deployments.
sk = str(cfg.get("STORAGE_KEY", ""))
if sk and not re.fullmatch(r"[a-z0-9_-]{1,16}", sk):
    errs.append("STORAGE_KEY must be 1-16 chars of a-z 0-9 _ - (or absent)")
# Optional: one-tap "Send to class" endpoint (see
# classroom_map/upload_endpoint/SETUP_UPLOAD.md). Empty/absent = feature off.
up = str(cfg.get("UPLOAD_URL", "")).strip()
if up and not up.startswith("https://"):
    errs.append("UPLOAD_URL must start with https:// (or be empty)")

if errs:
    sys.exit("deploy.config.json: " + "; ".join(errs))
print(f"deploy.config.json OK — {cfg['INSTITUTION']} ({lat}, {lon}), "
      f"{cfg['DEVICE_COUNT']} devices, {cfg['APP_URL']}, "
      f"class upload {'ON' if up else 'off'}")
