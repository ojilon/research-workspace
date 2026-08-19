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

## Phase 1 — Foundation (done)

- [x] Frontend (Vite + React + TS + Tailwind)
- [x] Light / dark theme
- [x] Resizable file tree + dual panes with tabs
- [x] Summary pane notes + Ctrl+S
- [x] FastAPI + `.venv`
- [x] Storage root prefers **D:\ResearchWorkspace**
- [x] Live file tree, bookmarks, Explorer / Save As
- [x] **One-click start** (`Start-Research-Workspace.bat`)

## Phase 2 — Documents (done for MVP)

- [x] PDF extract + page view (selectable text)
- [x] DOCX extract + HTML page view
- [x] Block tree + insert into summary at caret
- [x] Code viewer with line numbers
- [ ] OCR for scanned PDFs (later)
- [ ] Full DOCX export with images (later)

## Phase 3 — Documents polish (optional next)

- Better Markdown preview
- Images in notes
- References section
- DOCX / PDF export of summaries

## Phase 4 — Intelligent Assistance (later)

- Local text processing
- AI-assisted summary tree
- Diff review

## Phase 5 — Knowledge Organization

- Topics & source groups
- Search
- Cross-source summaries

## Rule

Each phase must produce usable software before the next begins.

**Current status:** usable foundation + documents + packaging. Ready for daily school reading sessions.
