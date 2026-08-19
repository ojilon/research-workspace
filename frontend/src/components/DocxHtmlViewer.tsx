import { useEffect, useState } from "react";
import { api } from "../lib/api";

type DocxHtmlViewerProps = {
  path: string;
  title?: string;
};

/**
 * Renders DOCX as readable HTML from the backend (python-docx → HTML).
 * Text is selectable like a normal web page — copy/paste into summary.
 */
function DocxHtmlViewer({ path, title }: DocxHtmlViewerProps) {
  const [html, setHtml] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setHtml(null);
    setError(null);
    fetch(api.documentHtmlUrl(path))
      .then(async (res) => {
        if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
        return res.text();
      })
      .then((body) => {
        if (!cancelled) setHtml(body);
      })
      .catch((e) => {
        if (!cancelled) setError(e instanceof Error ? e.message : String(e));
      });
    return () => {
      cancelled = true;
    };
  }, [path]);

  if (error) {
    return (
      <div className="h-full flex items-center justify-center text-sm text-red-400 p-4">
        Could not render DOCX: {error}
      </div>
    );
  }

  if (!html) {
    return (
      <div className="h-full flex items-center justify-center text-sm text-[var(--muted)]">
        Rendering document…
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col min-h-0">
      <div className="px-3 py-1 text-[11px] text-[var(--muted)] border-b border-[var(--border)] shrink-0">
        {title ?? path} · select text and paste into summary
      </div>
      <iframe
        title={title ?? path}
        srcDoc={html}
        className="flex-1 w-full border-0 bg-white"
        sandbox="allow-same-origin"
      />
    </div>
  );
}

export default DocxHtmlViewer;
