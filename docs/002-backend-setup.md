# Backend setup (Windows)

The backend is a small FastAPI server that owns the **local storage root**
(folder on disk), the file tree, saving notes, and bookmarks.

## 1. Create and activate a virtual environment

From the project root (`D:\projects\research-workspace`):

```powershell
cd D:\projects\research-workspace\backend

# Create .venv (only once)
python -m venv .venv

# Activate (PowerShell)
.\venv\Scripts\Activate.ps1

# If the above is blocked by execution policy:
# Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
# then try Activate again

# Or use Command Prompt instead:
# .venv\Scripts\activate.bat
```

You should see `(.venv)` at the start of the prompt.

## 2. Install dependencies

```powershell
pip install -r requirements.txt
```

## 3. Run the API

```powershell
# Still inside backend/ with .venv active
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Open http://127.0.0.1:8000/docs for the interactive Swagger UI.

Health check: http://127.0.0.1:8000/api/health

## 4. Default storage root

On first run the server creates:

```text
C:\Users\<you>\ResearchWorkspace
```

You can change it later from the frontend (or `POST /api/settings/storage-root`).

## 5. Run frontend + backend together

Terminal 1 – backend:

```powershell
cd D:\projects\research-workspace\backend
.\venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Terminal 2 – frontend:

```powershell
cd D:\projects\research-workspace\frontend
npm run dev
```

## Endpoints (current)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/health` | Liveness |
| GET | `/api/settings/storage-root` | Current storage folder |
| POST | `/api/settings/storage-root` | Set storage folder |
| GET | `/api/tree` | Nested file tree |
| POST | `/api/files/save` | Save text note under root |
| GET | `/api/files/read` | Read a text file |
| POST | `/api/bookmarks` | Save a `.url` shortcut |

PDF / DOCX extraction will be added in a later step using `pypdf` and `python-docx`.
