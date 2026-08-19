import { useEffect, useState } from "react";
import * as PDFJS from "pdfjs-dist";

// Set the pdf.js worker source using import.meta.url so Vite resolves the
// worker from the pdfjs-dist package correctly.
PDFJS.globalWorkerOptions.workerSrc = new URL(
  new URL("./node_modules/pdfjs-dist/build/pdf.worker.mjs", import.meta.url).pathname,
  import.meta.url
).href;

/**
 * Canvas-based PDF renderer using pdfjs-dist.
 * Pages are scaled by window.devicePixelRatio for crisp rendering
 * on high-DPI displays across all browsers.
 */
export default function PdfCanvasViewer({ src }: { src: string }) {
  const [pages, setPages] = useState<(HTMLCanvasElement | null)[]>([]);
  const [pageCount, setPageCount] = useState(0);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setLoaded(false);
      try {
        const pdf = await PDFJS.getDocument(src).promise;
        setPageCount(pdf.numPages);
        const rendered: HTMLCanvasElement[] = [];

        for (let i = 1; i <= pdf.numPages; i++) {
          const page = await pdf.getPage(i);
          const scale = window.devicePixelRatio || 1;
          const viewport = page.getViewport({ scale });

          const canvas = document.createElement("canvas");
          canvas.height = viewport.height;
          canvas.width = viewport.width;
          const ctx = canvas.getContext("2d");

          if (ctx) {
            await page.render({
              canvasContext: ctx,
              viewport: viewport,
              background: null,
              transform: null,
            }).promise;
          }

          rendered.push(canvas);
        }

        if (!cancelled) setPages(rendered);
        setLoaded(true);
      } catch (e) {
        console.error("PDF rendering error:", e);
        if (!cancelled) setLoaded(true);
      }
    }

    void load();

    return () => {
      cancelled = true;
    };
  }, [src]);

  if (!loaded || !src) {
    return (
      <div className="h-full flex items-center justify-center text-sm text-[var(--muted)]">
        {loaded ? "Loaded" : "Loading PDF…"}
      </div>
    );
  }

  return (
    <div className="h-full min-h-[600px] overflow-auto">
      {pages.map((canvas, idx) => {
        if (!canvas) return null;
        return (
          <div key={idx} className="p-3 border-b border-[var(--border)] last:border-0">
            <div className="relative">
              <canvas
                className="border rounded-md"
                style={{ width: `${canvas.width}px`, height: `${canvas.height}px` }}
              />
            </div>
          </div>
        );
      })}
      {pageCount > 0 && (
        <div className="p-2 text-xs text-[var(--muted)]">
          {pageCount}{" "}({pageCount > 1 ? "pages" : "page"}){" "}
        </div>
      )}
    </div>
  );
}