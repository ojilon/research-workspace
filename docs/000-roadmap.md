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

## Phase 1 — Foundation (done on `restructure`)

- [x] Frontend (Vite + React + TS + Tailwind)
- [x] Light / dark theme
- [x] Resizable file tree + dual panes with tabs
- [x] Summary pane: new tab = editable note
- [x] Ctrl+S → save note into storage root
- [x] FastAPI + `.venv` setup
- [x] Storage root prefers **D:\ResearchWorkspace**, falls back to C:/home
- [x] Save link as `.url` bookmark
- [x] **Live file tree** from `GET /api/tree`
- [x] Open `.md` / `.txt` from tree into summary note tabs
- [x] Open `.url` bookmarks into browser tabs
- [ ] UI control to change storage root path
- [ ] Create folder from the sidebar

## Phase 2 — Research Workspace (next)

- PDF open + text extraction (`pypdf`)
- DOCX open (`python-docx`)
- Simple frontend PDF viewer (later)
- Create folder / rename from UI
- Drag text from centre → summary (copy assist)

## Phase 3 — Documents

- Better Markdown rendering
- Images in notes
- References section
- DOCX / PDF export

## Phase 4 — Intelligent Assistance (later)

- Local text processing
- AI-assisted summary tree
- Diff review

## Phase 5 — Knowledge Organization

- Topics & source groups
- Search
- Cross-source summaries
- Version history

## Rule

Each phase must produce usable software before the next begins.
