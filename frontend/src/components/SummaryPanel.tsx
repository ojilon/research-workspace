import TabBar from "./TabBar";
import NoteEditor from "./NoteEditor";
import MainPanel from "./MainPanel";
import type { Tab } from "../types";

type SummaryPanelProps = {
  /** Fixed width when not using flexGrow; ignored if flexGrow is true. */
  width: number;
  /** When true, pane grows with remaining space (sidebar collapsed → ~50%). */
  flexGrow?: boolean;
  onResizeStart: (e: React.MouseEvent) => void;
  collapsed: boolean;
  onToggleCollapse: () => void;
  tabs: Tab[];
  activeTabId: string | null;
  onSelectTab: (id: string) => void;
  onCloseTab: (id: string) => void;
  onNewNoteTab: () => void;
  onUpdateTab: (id: string, patch: Partial<Tab>) => void;
  onOpenStorageExplorer: () => void;
  backendOk: boolean;
};

function SummaryPanel({
  width,
  flexGrow,
  onResizeStart,
  collapsed,
  onToggleCollapse,
  tabs,
  activeTabId,
  onSelectTab,
  onCloseTab,
  onNewNoteTab,
  onUpdateTab,
  onOpenStorageExplorer,
  backendOk,
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
      className={
        "relative flex flex-col border-l border-[var(--border)] bg-[var(--panel)] min-w-0 " +
        (flexGrow ? "flex-1" : "shrink-0")
      }
      style={flexGrow ? undefined : { width }}
    >
      <div
        onMouseDown={onResizeStart}
        className="absolute top-0 left-0 w-1.5 h-full cursor-col-resize hover:bg-[var(--accent)] transition-colors z-10"
        title="Drag to resize"
      />

      <div className="flex items-center justify-between px-2 h-9 border-b border-[var(--border)] shrink-0 gap-1">
        <span className="text-xs font-semibold uppercase tracking-wide text-[var(--muted)] px-1">
          Summary
        </span>
        <div className="flex items-center gap-1">
          <button
            type="button"
            title="Open storage in Explorer (pick/open existing file)"
            onClick={onOpenStorageExplorer}
            disabled={!backendOk}
            className="px-2 h-6 rounded text-xs text-[var(--muted)] hover:bg-[var(--hover)] disabled:opacity-40"
          >
            Open file
          </button>
          <button
            type="button"
            title="Open storage in Explorer (create a new file there, then refresh)"
            onClick={onOpenStorageExplorer}
            disabled={!backendOk}
            className="px-2 h-6 rounded text-xs text-[var(--muted)] hover:bg-[var(--hover)] disabled:opacity-40"
          >
            Create file
          </button>
          <button
            type="button"
            title="Collapse"
            onClick={onToggleCollapse}
            className="w-6 h-6 rounded text-[var(--muted)] hover:bg-[var(--hover)] text-sm"
          >
            »
          </button>
        </div>
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
          <div className="h-full flex flex-col items-center justify-center gap-3 text-[var(--muted)] text-sm p-4 text-center">
            <p>
              Press <strong>+</strong> for a new note, or use Open / Create file
              to work in Windows Explorer on your storage drive.
            </p>
            <p className="text-xs">Ctrl+S saves the active note in place.</p>
          </div>
        )}
      </div>
    </aside>
  );
}

export default SummaryPanel;
