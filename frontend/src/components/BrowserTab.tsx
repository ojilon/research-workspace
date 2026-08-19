import { useState } from "react";

type BrowserTabProps = {
  initialUrl?: string;
  onUrlChange?: (url: string) => void;
};

/**
 * Placeholder browser tab.
 * Real embedded Chromium will come later (pywebview / WebView2).
 * For now: URL bar + "Open in system browser" so you can still collect links quickly.
 */
function BrowserTab({ initialUrl = "https://scholar.google.com", onUrlChange }: BrowserTabProps) {
  const [url, setUrl] = useState(initialUrl);
  const [input, setInput] = useState(initialUrl);

  function go(e?: React.FormEvent) {
    e?.preventDefault();
    let next = input.trim();
    if (!next) return;
    if (!/^https?:\/\//i.test(next)) {
      // Treat bare terms as a Google Scholar search for research convenience
      next = `https://scholar.google.com/scholar?q=${encodeURIComponent(next)}`;
    }
    setUrl(next);
    setInput(next);
    onUrlChange?.(next);
  }

  function openExternal() {
    window.open(url, "_blank", "noopener,noreferrer");
  }

  return (
    <div className="h-full flex flex-col">
      <form
        onSubmit={go}
        className="flex items-center gap-2 px-3 py-2 border-b border-[var(--border)] bg-[var(--panel)]"
      >
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Search Scholar or paste URL…"
          className="flex-1 px-3 py-1.5 rounded-md text-sm bg-[var(--bg)] border border-[var(--border)] text-[var(--text)] outline-none focus:border-[var(--accent)]"
        />
        <button
          type="submit"
          className="px-3 py-1.5 rounded-md text-sm bg-[var(--accent)] text-white hover:opacity-90"
        >
          Go
        </button>
        <button
          type="button"
          onClick={openExternal}
          className="px-3 py-1.5 rounded-md text-sm border border-[var(--border)] text-[var(--text)] hover:bg-[var(--hover)]"
          title="Open in system browser (full Cloudflare / login support)"
        >
          Open external
        </button>
      </form>

      <div className="flex-1 flex flex-col items-center justify-center gap-3 p-8 text-center text-[var(--muted)]">
        <p className="text-sm max-w-md">
          Embedded browser (real Chromium / WebView2) will be added in a later
          step so Cloudflare-protected sites and JWTs work inside the app.
        </p>
        <p className="text-xs">
          Current URL: <span className="text-[var(--text)]">{url}</span>
        </p>
        <button
          type="button"
          onClick={openExternal}
          className="mt-2 px-4 py-2 rounded-md bg-[var(--accent-muted)] text-[var(--accent)] text-sm font-medium"
        >
          Open this page in Edge / Chrome
        </button>
      </div>
    </div>
  );
}

export default BrowserTab;
