import { useEffect, useState } from "react";
import { api } from "../lib/api";

type PdfBlobViewerProps = {
  path: string;
  title?: string;
};

/**
 * Loads the PDF as a blob from the API and shows it with the browser's
 * built-in viewer (same engine Edge uses). That allows text selection;
 * copy the selection and paste into the summary, or use Ctrl+Shift+S
 * (handled in App) to insert at the caret.
 */
function PdfBlobViewer({ path, title }: PdfBlobViewerProps) {
  const [url, setUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let objectUrl: string | null = null;
    let cancelled = false;

    async function load() {
      setError(null);
      setUrl(null);
      try {
        const res = await fetch(api.rawFileUrl(path));
        if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
        const blob = await res.blob();
        // Ensure PDF mime so the browser plugin engages
        const pdfBlob =
          blob.type === "application/pdf"
            ? blob
            : new Blob([blob], { type: "application/pdf" });
        objectUrl = URL.createObjectURL(pdfBlob);
        if (!cancelled) setUrl(objectUrl);
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : String(e));
        }
      }
    }

    void load();
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [path]);

  if (error) {
    return (
      <div className="h-full flex items-center justify-center text-sm text-red-400 p-4">
        Could not load PDF: {error}
      </div>
    );
  }

  if (!url) {
    return (
      <div className="h-full flex items-center justify-center text-sm text-[var(--muted)]">
        Loading PDF…
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col min-h-0">
      <div className="px-3 py-1 text-[11px] text-[var(--muted)] border-b border-[var(--border)] shrink-0">
        {title ?? path} · select text in the PDF, then paste into summary (or
        press <kbd className="px-1 rounded bg-[var(--hover)]">Ctrl+Shift+V</kbd>{
          " "
        }
        to insert selection at the caret)
      </div>
      <iframe
        title={title ?? path}
        src={url}
        className="flex-1 w-full border-0 bg-white"
      />
    </div>
  );
}

export default PdfBlobViewer;
