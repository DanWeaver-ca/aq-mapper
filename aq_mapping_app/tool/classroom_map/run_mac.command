#!/bin/bash
# Double-click launcher (Mac). First time: right-click -> Open to bypass Gatekeeper.
cd "$(dirname "$0")" || exit 1
DIR="csvs"
# Fall back to bundled sample data if the csvs/ folder has no CSVs yet.
if ! ls csvs/*.csv >/dev/null 2>&1; then
  echo "No CSVs in csvs/ — using sample data. Put real exports in csvs/ for class."
  DIR="sample_csvs"
fi
python3 build_map.py "$DIR" || { echo "Build failed. Did you run: pip install -r requirements.txt ?"; read -r; exit 1; }
open classroom_map.html
