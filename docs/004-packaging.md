# Packaging & one-click start

## Goal

One process, one window (browser), no juggling two terminals.

## How it works

1. `npm run build` writes static files to `frontend/dist/`.
2. FastAPI mounts that dist (see `backend/app/static_ui.py`).
3. `run_app.py` starts uvicorn on `127.0.0.1:8000` and opens the browser.
4. `Start-Research-Workspace.bat` builds if needed, then runs `run_app.py` with the venv Python.

API routes stay under `/api/*`. The UI is same-origin, so no CORS issues in packaged mode.

## First-time checklist

```powershell
cd D:\projects\research-workspace\backend
python -m venv .venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt

cd ..\frontend
npm install
npm run build
```

Then double-click `Start-Research-Workspace.bat`.

## Daily use

Double-click the bat file. Close the console window (or Ctrl+C) to stop the server.

## Rebuild UI after frontend changes

```powershell
cd frontend
npm run build
```

Or let the bat rebuild when `frontend\dist\index.html` is missing.

## Dev vs packaged

| Mode | UI | API | How to start |
|------|----|-----|----------------|
| Dev | Vite :5173 | :8000 | Two terminals |
| Packaged | Served by FastAPI :8000 | same | Bat / `run_app.py` |

## Optional later

- Shortcut on Desktop pointing at the bat file
- `pywebview` or Tauri for a frameless window (not required for school use)
- PyInstaller single exe (heavier; only if you need zero Python install on another PC)

## Environment

| Variable | Default | Meaning |
|----------|---------|---------|
| `RW_HOST` | `127.0.0.1` | Bind address |
| `RW_PORT` | `8000` | Port |
