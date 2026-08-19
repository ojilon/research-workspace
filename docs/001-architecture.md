# Architecture – Research Workspace (restructure branch)

## Goal of this branch

Produce a usable research shell quickly:

- Resizable left file tree (folders / documents / links)
- Centre tabbed area (document tabs + browser tabs)
- Right summary notes pane (editable, collapsible)
- Light / dark theme
- Clean TypeScript types
- No AI yet

You should be able to open the app, switch topics, type a summary while looking at a document, and open external research links.

## Stack (current)

| Layer | Choice | Notes |
|-------|--------|-------|
| Frontend | Vite + React 19 + TypeScript | Already present |
| Styling | Tailwind CSS v4 + CSS variables | Light/dark via `data-theme` |
| Backend | FastAPI (Python) – next | Local files, PDF text later |
| Desktop shell | Deferred | Start with browser; later pywebview or Tauri |

## Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Header (title + theme toggle)                               │
├──────────┬──────────────────────────────────┬───────────────┤
│ Sidebar  │ Tab bar                          │ Summary       │
│ (tree)   ├──────────────────────────────────┤ (notes)       │
│          │ Active tab content               │               │
│          │  – document (MainPanel)          │               │
│          │  – browser (URL bar + external)  │               │
└──────────┴──────────────────────────────────┴───────────────┘
```

- Left and right panels are independently resizable by dragging the edge.
- Both can be collapsed to a thin strip.
- Tabs behave like VS Code / Sublime: open, focus existing, close, new browser tab.

## Data for now

- `src/data/topics.ts` – demo plant-physiology documents
- `src/data/sampleTree.ts` – demo file tree (folders + links + docs)
- Later these come from the local storage root + a small SQLite / JSON store managed by FastAPI.

## Browser capability (honest status)

A full embedded Chromium that handles Cloudflare / JWTs needs a native shell (WebView2 / pywebview / Tauri).  
Until that lands, the Browser tab:

1. Lets you type a URL or search term
2. Opens the real system browser (Edge / Chrome) so logins and protected sites work
3. Keeps the URL associated with the tab so you can re-open it later

This is already useful for collecting links into the file tree.

## Next concrete steps (no AI)

1. FastAPI skeleton: list local folder, serve file tree, save bookmarks
2. Persist open tabs + summary text to local JSON
3. Simple “Save link to folder” from the browser tab
4. PDF text extraction (pypdf / pdfminer) when a local PDF is opened
5. Optional: wrap the whole UI in pywebview for a single-window desktop feel

## Running locally (Windows)

```bash
cd D:\projects\research-workspace\frontend
npm install
npm run dev
```

Then open the URL Vite prints (usually http://localhost:5173).
