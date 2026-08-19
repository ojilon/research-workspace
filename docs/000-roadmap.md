# Research Workspace Roadmap

## Purpose

Make academic research faster by reducing repetitive work around papers, websites, notes, summaries, references, and documents.

## Core Workflow

```text
Research topic
    ↓
Collect sources (links / PDFs / bookmarks)
    ↓
Read (split view: source | notes)
    ↓
Select useful content
    ↓
Add to topic summary
    ↓
Organize references
    ↓
Export document
```

## Phase 1 — Foundation (mostly done on `restructure`)

- [x] Frontend setup (Vite + React + TS + Tailwind)
- [x] Shared TypeScript types
- [x] Modern light / dark theme
- [x] Resizable left file tree
- [x] Centre tab bar (document + browser tabs)
- [x] Right summary pane with **its own tabs** (new tab = editable note)
- [x] Both panes can show documents / notes
- [x] Ctrl+S saves active note via FastAPI into storage root
- [x] FastAPI skeleton + `.venv` instructions (`docs/002-backend-setup.md`)
- [x] Local storage root (default `~/ResearchWorkspace`)
- [x] Save link / bookmark into folder
- [ ] Live file tree from backend (currently still sample data)
- [ ] Pick storage root from the UI

## Phase 2 — Research Workspace (next)

- Load real tree from `GET /api/tree`
- Open local Markdown files into note tabs
- PDF open + text extraction (Python `pypdf`)
- DOCX open (`python-docx`)
- Frontend PDF viewer (later)
- Drag text from centre → summary (copy/paste assist)

## Phase 3 — Documents

- Better Markdown rendering
- Images in notes
- References section
- DOCX / PDF export

## Phase 4 — Intelligent Assistance (later)

- Local text processing
- AI-assisted placement into a summary tree
- Diff review (accept / reject)

## Phase 5 — Knowledge Organization

- Topics & source groups
- Search across notes
- Cross-source summaries
- Version history

## Rule

Each phase must produce **usable software** before the next phase begins.
No AI features until the reading + note-taking loop is comfortable.
