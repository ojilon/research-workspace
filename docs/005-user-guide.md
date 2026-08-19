# User guide

## Open the app

Double-click **Start-Research-Workspace.bat** (or run `run_app.py`).  
Status strip should show **Backend: connected** and **Storage: D:\ResearchWorkspace** (or fallback).

## Layout

```text
┌──────────┬─────────────────────┬─────────────────┐
│ Explorer │ Centre tabs         │ Summary         │
│ file tree│ PDF / browser / note│ notes + extract │
└──────────┴─────────────────────┴─────────────────┘
```

- Drag the vertical edges to resize.
- Collapse the tree (☰) for a wider reading split.

## Put papers on disk

1. Click **📂** (or **Open file**) → Explorer opens on the storage root.
2. Copy PDFs/DOCX into e.g. `papers\`.
3. Press **↻** in the app tree.

## Read a PDF

1. Click the PDF in the tree (opens in the **centre**).
2. Modes: **blocks** · **view** · **split**.
3. **view** = real pages (select text, Ctrl+C).
4. Click in the summary note → **Ctrl+V** to paste at the caret.
5. Or hover a **block** → **→** to insert that paragraph at the caret.

## Read a DOCX

Same as PDF: **view** shows a page-like HTML layout; **blocks** for structured extract.

## Write a summary

1. Summary pane **+** for a new note, or **Create file** for Windows Save As.
2. Toolbar: bold, italic, heading, list, code (Markdown).
3. **Ctrl+S** saves in place if the note already has a path; otherwise Save As.

## Bookmarks

In a browser tab, open a URL → **Save link** → stored under `bookmarks\` as a `.url` file.  
Click it later to reopen.

## Tips

| Action | How |
|--------|-----|
| Open in summary pane | Right-click file → Open in summary |
| Show file on disk | Right-click → Show in Explorer |
| Theme | Header light/dark toggle |
| Stop app | Close the console or Ctrl+C |

## Limits to remember

- Scanned PDFs may have no selectable text (OCR later).
- Old `.doc` → save as `.docx` in Word.
- Browser tab is still an external Edge/Chrome window for hard sites (Cloudflare), not a full embedded Chromium yet.
