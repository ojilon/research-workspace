import { useState } from "react";

type BrowserTabProps = {
  initialUrl?: string;
  onUrlChange?: (url: string) => void;
  /** Save current URL as a bookmark into the local storage root. */
  onSaveLink?: (url: string) => void;
};

/**
 * Browser tab skeleton.
 * Real embedded Chromium comes later; for now URL bar + open external + save link.
 */
function BrowserTab({
  initialUrl = "https://scholar.google.com",
  onUrlChange,
  onSaveLink,
}: BrowserTabProps) {
  const [url, setUrl] = useState(initialUrl);
  const [input, setInput] = useState(initialUrl);

  function go(e?: React.FormEvent) {
    e?.preventDefault();
    let next = input.trim();
    if (!next) return;
    if (!/^https?:\/\//i.test(next)) {
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
          title="Open in system browser (Cloudflare / login support)"
        >
          Open external
        </button>
        {onSaveLink && (
          <button
            type="button"
            onClick={() => onSaveLink(url)}
            className="px-3 py-1.5 rounded-md text-sm border border-[var(--border)] text-[var(--text)] hover:bg-[var(--hover)]"
            title="Save this link into the local storage folder"
          >
            Save link
          </button>
        )}
      </form>

      <div className="flex-1 flex flex-col items-center justify-center gap-3 p-8 text-center text-[var(--muted)]">
        <p className="text-sm max-w-md">
          Embedded browser will be added later. Use "Open external" for full
          Cloudflare / JWT support, then "Save link" to keep the URL in your
          local folder.
        </p>
        <p className="text-xs">
          Current URL: <span className="text-[var(--text)]">{url}</span>
        </p>
        <div className="flex gap-2 mt-2">
          <button
            type="button"
            onClick={openExternal}
            className="px-4 py-2 rounded-md bg-[var(--accent-muted)] text-[var(--accent)] text-sm font-medium"
          >
            Open in Edge / Chrome
          </button>
          {onSaveLink && (
            <button
              type="button"
              onClick={() => onSaveLink(url)}
              className="px-4 py-2 rounded-md border border-[var(--border)] text-sm"
            >
              Save link to folder
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

export default BrowserTab;
