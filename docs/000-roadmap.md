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

## Phase 1 — Foundation (in progress on `restructure`)

- [x] Frontend setup (Vite + React + TS)
- [x] Shared TypeScript types
- [x] Modern light / dark theme
- [x] Resizable left file tree
- [x] Centre tab bar (document + browser tabs)
- [x] Right summary notes pane (editable, collapsible)
- [x] Clean document rendering from sample topics
- [ ] FastAPI backend skeleton
- [ ] Local storage root selection

## Phase 2 — Research Workspace (next)

- Open websites via system browser (already possible) → later embedded WebView
- Manage multiple sources in the file tree
- Save links / bookmarks into folders
- Display local documents (Markdown first)
- Persist summary text and open tabs
- Basic “copy selection → paste into summary” workflow

## Phase 3 — Documents

- Markdown rendering improvements
- Local PDF open + text extraction (Python)
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
