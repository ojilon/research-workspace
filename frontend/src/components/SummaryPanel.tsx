import TabBar from "./TabBar";
import NoteEditor from "./NoteEditor";
import MainPanel from "./MainPanel";
import type { Tab } from "../types";

type SummaryPanelProps = {
  width: number;
  onResizeStart: (e: React.MouseEvent) => void;
  collapsed: boolean;
  onToggleCollapse: () => void;
  tabs: Tab[];
  activeTabId: string | null;
  onSelectTab: (id: string) => void;
  onCloseTab: (id: string) => void;
  onNewNoteTab: () => void;
  onUpdateTab: (id: string, patch: Partial<Tab>) => void;
};

/**
 * Right pane: independent tab strip.
 * New tabs default to an editable note (like a blank docx/md draft).
 * Document tabs can also open here so you can put a paper on the left
 * and a second document / summary on the right.
 */
function SummaryPanel({
  width,
  onResizeStart,
  collapsed,
  onToggleCollapse,
  tabs,
  activeTabId,
  onSelectTab,
  onCloseTab,
  onNewNoteTab,
  onUpdateTab,
}: SummaryPanelProps) {
  if (collapsed) {
    return (
      <div className="relative shrink-0 w-10 border-l border-[var(--border)] bg-[var(--panel)] flex flex-col items-center py-2">
        <button
          type="button"
          title="Show summary pane"
          onClick={onToggleCollapse}
          className="w-8 h-8 rounded flex items-center justify-center text-[var(--muted)] hover:bg-[var(--hover)]"
        >
          ≡
        </button>
      </div>
    );
  }

  const active = tabs.find((t) => t.id === activeTabId) ?? null;

  return (
    <aside
      className="relative shrink-0 flex flex-col border-l border-[var(--border)] bg-[var(--panel)]"
      style={{ width }}
    >
      {/* Drag handle */}
      <div
        onMouseDown={onResizeStart}
        className="absolute top-0 left-0 w-1 h-full cursor-col-resize hover:bg-[var(--accent)] transition-colors z-10"
        title="Drag to resize"
      />

      <div className="flex items-center justify-between px-2 h-9 border-b border-[var(--border)] shrink-0">
        <span className="text-xs font-semibold uppercase tracking-wide text-[var(--muted)] px-1">
          Summary
        </span>
        <button
          type="button"
          title="Collapse"
          onClick={onToggleCollapse}
          className="w-6 h-6 rounded text-[var(--muted)] hover:bg-[var(--hover)] text-sm"
        >
          »
        </button>
      </div>

      <TabBar
        tabs={tabs}
        activeTabId={activeTabId}
        onSelect={onSelectTab}
        onClose={onCloseTab}
        onNewTab={onNewNoteTab}
      />

      <div className="flex-1 min-h-0 overflow-hidden">
        {active?.kind === "note" && (
          <NoteEditor
            title={active.title}
            content={active.content ?? ""}
            status={active.dirty ? "unsaved" : active.path ?? "draft"}
            onTitleChange={(title) =>
              onUpdateTab(active.id, { title, dirty: true })
            }
            onChange={(content) =>
              onUpdateTab(active.id, { content, dirty: true })
            }
          />
        )}
        {active?.kind === "document" && active.resourceId && (
          <MainPanel selectedTopicId={active.resourceId} />
        )}
        {!active && (
          <div className="h-full flex items-center justify-center text-[var(--muted)] text-sm p-4 text-center">
            Press + to create a new summary note.
            <br />
            Ctrl+S saves into your local storage folder.
          </div>
        )}
      </div>
    </aside>
  );
}

export default SummaryPanel;
