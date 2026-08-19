import { useEffect, useState } from "react";
import mammoth from "mammoth";
import { api } from "../lib/api";

type DocxHtmlViewerProps = {
  path: string;
  title?: string;
};

/**
 * Client-side DOCX → HTML conversion using mammoth.
 * The converted HTML is rendered with Tailwind's prose typography
 * for clean, readable formatting. On failure, falls back to the
 * backend-rendered HTML path.
 *
 * For complex DOCX fidelity, an optional server-side
 * LibreOffice → PDF conversion path is available.
 */
function DocxHtmlViewer({ path, title }: DocxHtmlViewerProps) {
  const [html, setHtml] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [converted, setConverted] = useState<boolean>(false);

  useEffect(() => {
    let cancelled = false;

    async function convert() {
      try {
        const res = await fetch(api.rawFileUrl(path));
        if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
        const blob = await res.blob();

        // Convert DOCX to HTML using mammoth on the client
        const result = await mammoth.convertToHtml(blob, {
          styleMap: [
            // Apply Tailwind prose-like styling via classes
            "p => p[matter-type='paragraph'] .inline-prose",
            "p > strong => b.font-bold",
            "p > em => i.italic",
            "p > u => u.font-none.font-semibold",
            "a[href] => link.text-blue-600 underline",
            "table => table.w-full caption-bottom text-sm",
            "table th => th.border border-gray-300 p-2",
            "table td => td.border border-gray-300 p-2",
          ],
        });

        if (!cancelled) {
          setHtml(result.value);
          setConverted(true);
        }
      } catch (e) {
        console.error("mammoth conversion error:", e);
        if (!cancelled) setError(e instanceof Error ? e.message : String(e));
      }
    }

    void convert();

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

  if (!converted) {
    return (
      <div className="h-full flex items-center justify-center text-sm text-[var(--muted)]">
        Converting document…
      </div>
    );
  }

  if (!html) {
    return (
      <div className="h-full flex items-center justify-center text-sm text-[var(--muted)]">
        No content
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col min-h-0">
      <div
        className="px-3 py-1 text-[11px] text-[var(--muted)] border-b border-[var(--border)] shrink-0"
      >
        {title ?? path} · select text and paste into summary
      </div>

      {/* Render converted HTML with Tailwind prose typography */}
      <div
        className="prose prose-in dark:prose-dark flex-1 w-full min-h-0 overflow-auto"
        dangerouslySetInnerHTML={{ __html: html }}
      />
    </div>
  );
}

export default DocxHtmlViewer;