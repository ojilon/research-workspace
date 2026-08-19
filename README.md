# Research Workspace

Local-first research tool for reading papers, collecting sources, and writing summaries — without juggling a dozen browser tabs and Word windows.

**Stack:** React + TypeScript + Tailwind (Vite) · Python FastAPI · local disk on **D:\ResearchWorkspace** (falls back if needed).

---

## What it does today

| Area | Features |
|------|----------|
| **Layout** | VS Code-style: file tree · centre tabs · summary pane · light/dark · resizable |
| **Files** | Live tree from disk · folders · bookmarks (`.url`) · Create via Windows Save As |
| **PDF** | Page view (Edge engine via blob) · text selection · block tree · → to summary |
| **DOCX** | HTML page view · block extract · selectable text |
| **Notes** | Markdown editor + toolbar · Ctrl+S in place · insert at caret |
| **Code** | Line-numbered viewer |
| **Start** | **One click** – no two terminals (see below) |

Not included yet: AI, OCR for scanned PDFs, full Word WYSIWYG, native desktop shell (Tauri/pywebview optional later).

---

## Quick start (one click)

### First time only

```powershell
cd D:\projects\research-workspace

# Backend
cd backend
python -m venv .venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
cd ..

# Frontend build (packaged UI)
cd frontend
npm install
npm run build
cd ..
```

### Every day

**Double-click** `Start-Research-Workspace.bat`

Or:

```powershell
.\backend\.venv\Scripts\python.exe run_app.py
```

Browser opens at `http://127.0.0.1:8000/` — API and UI in **one process**.

---

## Development (two processes)

When changing UI code often:

```powershell
# Terminal 1
cd backend
.\venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

# Terminal 2
cd frontend
npm run dev
```

Open `http://localhost:5173` (Vite proxies API calls to :8000).

After UI changes you care about packaging, run `npm run build` again so the bat launcher stays current.

---

## Documentation map

| Doc | Topic |
|-----|--------|
| [docs/000-roadmap.md](docs/000-roadmap.md) | Phases and goals |
| [docs/001-architecture.md](docs/001-architecture.md) | How pieces fit |
| [docs/002-backend-setup.md](docs/002-backend-setup.md) | `.venv`, storage root, API |
| [docs/003-documents.md](docs/003-documents.md) | PDF / DOCX / blocks |
| [docs/004-packaging.md](docs/004-packaging.md) | One-click start |
| [docs/005-user-guide.md](docs/005-user-guide.md) | Day-to-day workflow |
| [backend/README.md](backend/README.md) | Backend folder |
| [frontend/README.md](frontend/README.md) | Frontend folder |

---

## Storage

Files live under **`D:\ResearchWorkspace`** when D: is writable; otherwise the user home folder.

Typical layout:

```text
D:\ResearchWorkspace\
  papers\          PDFs, DOCX
  summaries\       your notes (.md)
  bookmarks\       .url shortcuts
```

---

## Branch

Active work: **`restructure`**.

```powershell
git checkout restructure
git pull origin restructure
```

---

## Philosophy

Small steps · usable software first · local and offline-friendly · deterministic tools before AI.
