@echo off
REM Double-click launcher (Windows).
cd /d "%~dp0"
set DIR=csvs
REM Fall back to bundled sample data if the csvs\ folder has no CSVs yet.
if not exist "csvs\*.csv" (
  echo No CSVs in csvs\ - using sample data. Put real exports in csvs\ for class.
  set DIR=sample_csvs
)
python build_map.py %DIR%
if errorlevel 1 (
  echo.
  echo Build failed. Did you run:  pip install -r requirements.txt  ?
  pause
  exit /b 1
)
start "" classroom_map.html
