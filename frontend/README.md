# Frontend

Vite + React + TypeScript + Tailwind v4 for Research Workspace.

## Setup

```powershell
cd frontend
npm install
```

## Dev server

```powershell
npm run dev
```

http://localhost:5173 — expects API at http://127.0.0.1:8000.

## Production build (one-click app)

```powershell
npm run build
```

Writes `dist/`. FastAPI serves it when you run `Start-Research-Workspace.bat`.

## Source map

| Path | Role |
|------|------|
| `src/App.tsx` | Shell: tabs, open/save, tree |
| `src/components/Sidebar.tsx` | Explorer |
| `src/components/FileTree.tsx` | Tree + context menu |
| `src/components/ResearchViewer.tsx` | PDF/DOCX modes |
| `src/components/PdfBlobViewer.tsx` | Selectable PDF pages |
| `src/components/DocxHtmlViewer.tsx` | DOCX HTML view |
| `src/components/NoteEditor.tsx` | Markdown + insert at caret |
| `src/components/SummaryPanel.tsx` | Right pane |
| `src/lib/api.ts` | FastAPI client |
| `src/types/index.ts` | Shared types |

## Theme

CSS variables + `useTheme` — light/dark toggle in the header.

See also root `README.md` and `docs/005-user-guide.md`.
