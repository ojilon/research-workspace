# Backend

FastAPI app: local storage, file tree, PDF/DOCX extract, shell dialogs, optional static UI.

## Setup

```powershell
cd backend
python -m venv .venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Run (API only, dev)

```powershell
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Docs: http://127.0.0.1:8000/docs

## Modules

| File | Role |
|------|------|
| `app/main.py` | Routes |
| `app/storage.py` | D: preference, storage root |
| `app/documents.py` | PDF/DOCX/code → block tree |
| `app/render.py` | DOCX → HTML |
| `app/shell.py` | Explorer + Save As |
| `app/static_ui.py` | Serve `frontend/dist` |
| `app/config.py` | Settings / CORS |

## Key endpoints

- `GET /api/health`
- `GET /api/tree`
- `GET /api/documents/extract`
- `GET /api/documents/html`
- `GET /api/files/raw`
- `POST /api/files/save`
- `POST /api/shell/save-as`
- `POST /api/shell/open-folder`

See also `docs/002-backend-setup.md` and `docs/003-documents.md`.
