@echo off
REM Research Workspace – one click start (API + UI in one process)
setlocal
cd /d "%~dp0"

if not exist "backend\.venv\Scripts\python.exe" (
  echo.
  echo [!] backend\.venv not found.
  echo     First-time setup:
  echo       cd backend
  echo       python -m venv .venv
  echo       .venv\Scripts\activate
  echo       pip install -r requirements.txt
  echo       cd ..\frontend
  echo       npm install
  echo       npm run build
  echo.
  pause
  exit /b 1
)

if not exist "frontend\dist\index.html" (
  echo Building frontend (one-time)...
  pushd frontend
  call npm.cmd run build
  if errorlevel 1 (
    echo npm build failed. Is Node.js installed?
    popd
    pause
    exit /b 1
  )
  popd
)

echo Starting Research Workspace...
"backend\.venv\Scripts\python.exe" run_app.py
pause
