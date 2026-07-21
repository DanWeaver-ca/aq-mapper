@echo off
REM Double-click launcher (Windows).
cd /d "%~dp0"
set DIR=csvs
REM Fall back to bundled sample data if the csvs\ folder has no CSVs yet.
if not exist "csvs\*.csv" (
  echo No CSVs in csvs\ - using sample data. Put real exports in csvs\ for class.
  set DIR=sample_csvs
)
REM Find a working Python: PATH, the py launcher, then standard Anaconda
REM installs (machine-wide first). Probing with --version skips the Microsoft
REM Store decoy python.exe, which exists on PATH but only prints an ad.
set PYCMD=
python --version >nul 2>nul && set PYCMD=python
if not defined PYCMD ( py --version >nul 2>nul && set PYCMD=py )
if not defined PYCMD if exist "C:\ProgramData\anaconda3\python.exe" set "PYCMD=C:\ProgramData\anaconda3\python.exe"
if not defined PYCMD if exist "%LOCALAPPDATA%\anaconda3\python.exe" set "PYCMD=%LOCALAPPDATA%\anaconda3\python.exe"
if not defined PYCMD if exist "%USERPROFILE%\anaconda3\python.exe" set "PYCMD=%USERPROFILE%\anaconda3\python.exe"
if not defined PYCMD (
  echo Python was not found. Install it - see GETTING_STARTED.md step 2.1.
  pause
  exit /b 1
)
echo Using %PYCMD%
"%PYCMD%" home_base.py %DIR%
if errorlevel 1 (
  echo.
  echo Build failed. Did you run:  pip install -r requirements.txt  ?
  pause
  exit /b 1
)
start "" classroom_dashboard.html
