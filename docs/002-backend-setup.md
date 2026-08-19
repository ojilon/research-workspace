# Backend setup (Windows)

The backend is a small FastAPI server that owns the **local storage root**
(folder on disk), the file tree, saving notes, and bookmarks.

## Storage root – D: first, C: fallback

On startup the server picks a folder like this:

1. `STORAGE_ROOT` environment variable (if you set one)
2. **`D:\ResearchWorkspace`** – preferred when the D: drive exists and is writable  
   (keeps papers and notes off a full C: drive)
3. **`%USERPROFILE%\ResearchWorkspace`** – fallback (usually on C:)

You can still change it at any time:

```http
POST /api/settings/storage-root
{ "path": "D:\\MyResearch" }
```

or reset to the automatic choice:

```http
POST /api/settings/storage-root/reset-default
```

Check the active path:

```http
GET /api/settings/storage-root
```

The frontend status strip shows this path when the backend is connected.

## 1. Create and activate a virtual environment

From the project root (`D:\projects\research-workspace`):

```powershell
cd D:\projects\research-workspace\backend

# Create .venv (only once)
python -m venv .venv

# Activate (PowerShell)
.\venv\Scripts\Activate.ps1

# If blocked by execution policy:
# Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# Or Command Prompt:
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

Open http://127.0.0.1:8000/docs for Swagger.

Health: http://127.0.0.1:8000/api/health  
Storage: http://127.0.0.1:8000/api/settings/storage-root

## 4. Run frontend + backend together

**Terminal 1 – backend**

```powershell
cd D:\projects\research-workspace\backend
.\venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

**Terminal 2 – frontend**

```powershell
cd D:\projects\research-workspace\frontend
npm run dev
```

## Endpoints (current)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/health` | Liveness |
| GET | `/api/settings/storage-root` | Current folder + drive letter |
| POST | `/api/settings/storage-root` | Set folder manually |
| POST | `/api/settings/storage-root/reset-default` | Re-run D:-first detection |
| GET | `/api/tree` | Nested file tree |
| POST | `/api/files/save` | Save text note |
| GET | `/api/files/read` | Read a text file |
| POST | `/api/bookmarks` | Save a `.url` shortcut |

PDF / DOCX extraction will use `pypdf` and `python-docx` in a later step.
