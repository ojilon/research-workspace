import { useState } from "react";

type SummaryPanelProps = {
  width: number;
  onResizeStart: (e: React.MouseEvent) => void;
  collapsed: boolean;
  onToggleCollapse: () => void;
};

/**
 * Right-hand summary pane.
 * Simple editable textarea for now — later this becomes the structured tree view.
 * You can type while reading a paper on the left / centre.
 */
function SummaryPanel({
  width,
  onResizeStart,
  collapsed,
  onToggleCollapse,
}: SummaryPanelProps) {
  const [text, setText] = useState(
    "# Summary\n\nStart typing notes here while you read.\n\n- Key point 1\n- Key point 2\n"
  );

  if (collapsed) {
    return (
      <div className="relative shrink-0 w-10 border-l border-[var(--border)] bg-[var(--panel)] flex flex-col items-center py-2">
        <button
          type="button"
          title="Show summary"
          onClick={onToggleCollapse}
          className="w-8 h-8 rounded flex items-center justify-center text-[var(--muted)] hover:bg-[var(--hover)]"
        >
          ≡
        </button>
      </div>
    );
  }

  return (
    <aside
      className="relative shrink-0 flex flex-col border-l border-[var(--border)] bg-[var(--panel)]"
      style={{ width }}
    >
      {/* Drag handle on the left edge */}
      <div
        onMouseDown={onResizeStart}
        className="absolute top-0 left-0 w-1 h-full cursor-col-resize hover:bg-[var(--accent)] transition-colors z-10"
        title="Drag to resize"
      />

      <div className="flex items-center justify-between px-3 h-9 border-b border-[var(--border)] shrink-0">
        <span className="text-xs font-semibold uppercase tracking-wide text-[var(--muted)]">
          Summary
        </span>
        <button
          type="button"
          title="Collapse summary"
          onClick={onToggleCollapse}
          className="w-6 h-6 rounded text-[var(--muted)] hover:bg-[var(--hover)] text-sm"
        >
          »
        </button>
      </div>

      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        className="flex-1 w-full resize-none p-4 text-sm leading-relaxed bg-transparent text-[var(--text)] outline-none font-mono"
        placeholder="Type your summary notes here…"
        spellCheck
      />
    </aside>
  );
}

export default SummaryPanel;
