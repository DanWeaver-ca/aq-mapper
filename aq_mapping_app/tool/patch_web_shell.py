"""Stamp deploy.config.json values into web/index.html and web/manifest.json.

The web shell can't read dart-defines, so the deploy workflow runs this
before `flutter build web` — the PWA install banner and browser tab then
show the adopting institution's names. It edits the two files in place on
the CI runner (nothing is committed). For a local test build, run it the
same way, then restore with:  git checkout -- web/

Usage (from aq_mapping_app/):  python3 tool/patch_web_shell.py ../deploy.config.json
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, "..")
cfg_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    APP, "..", "deploy.config.json")
with open(cfg_path, encoding="utf-8") as fh:
    cfg = json.load(fh)

title = cfg["APP_TITLE"]
short = cfg["APP_SHORT_NAME"]
desc = f"Log air-quality readings with GPS during the {cfg['INSTITUTION']} lab."

man_path = os.path.join(APP, "web", "manifest.json")
with open(man_path, encoding="utf-8") as fh:
    man = json.load(fh)
man["name"] = title
man["short_name"] = short
man["description"] = desc
with open(man_path, "w", encoding="utf-8") as fh:
    json.dump(man, fh, indent=4)
    fh.write("\n")

idx_path = os.path.join(APP, "web", "index.html")
with open(idx_path, encoding="utf-8") as fh:
    idx = fh.read()
idx = re.sub(r"<title>.*?</title>", f"<title>{short}</title>", idx)
idx = re.sub(r'(<meta name="description" content=").*?(">)',
             rf"\g<1>{desc}\g<2>", idx)
idx = re.sub(r'(<meta name="apple-mobile-web-app-title" content=").*?(">)',
             rf"\g<1>{short}\g<2>", idx)
with open(idx_path, "w", encoding="utf-8") as fh:
    fh.write(idx)

print(f"stamped web shell: title={short!r}, name={title!r}")
