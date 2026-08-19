# Documents – PDF, DOCX, code

## Backend

Ensure packages are installed in `.venv`:

```powershell
cd D:\projects\research-workspace\backend
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

(`pypdf` and `python-docx` are listed in requirements.txt.)

### Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/documents/extract?relative_path=...` | Block tree (paragraphs, headings, tables, code lines) |
| GET | `/api/files/raw?relative_path=...` | Stream original file (PDF iframe) |

### Block tree

Each document is split into **blocks** with stable ids:

- `paragraph`, `heading`, `list_item`, `table_cell`, `code_line`

This is the foundation for:

- click-to-select a whole paragraph (no drag required)
- **→** button to append into the summary note
- future drag-and-drop, search, and autocorrect

### Limits

- **PDF**: text layer only. Scanned PDFs need OCR later; you can still view pages in the PDF pane.
- **DOCX**: paragraphs + tables via `python-docx`.
- **DOC** (legacy): not supported — save as `.docx` in Word.
- **Code**: full file as lines with line numbers in the UI.

## Frontend

- Explorer icons differ by type (📕 PDF, 📘 DOCX, 💻 code, 📝 notes, …).
- Open PDF → **blocks / pdf / split** modes.
- Hover a block → **→** sends text into the active summary note.
- Notes have a Markdown toolbar (bold, italic, heading, list, code).

## Suggested workflow

1. Put papers under `D:\ResearchWorkspace\papers\`.
2. ↻ refresh explorer.
3. Open PDF in centre (split view).
4. Click useful paragraphs or use **→** into the summary pane.
5. Format the summary with the toolbar; Ctrl+S to save.
