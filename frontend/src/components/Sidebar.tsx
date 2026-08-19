import FileTree, { type OpenTarget } from "./FileTree";
import type { FileTreeNode } from "../types";

type SidebarProps = {
  width: number;
  onResizeStart: (e: React.MouseEvent) => void;
  onOpenNode: (node: FileTreeNode, target?: OpenTarget) => void;
  selectedId?: string;
  collapsed: boolean;
  onToggleCollapse: () => void;
  nodes: FileTreeNode[];
  loading?: boolean;
  backendOk: boolean;
  onRefresh: () => void;
  /** Open Windows Explorer at the storage root (create folder/file there). */
  onOpenExplorer: () => void;
  onRevealNode: (node: FileTreeNode) => void;
};

function Sidebar({
  width,
  onResizeStart,
  onOpenNode,
  selectedId,
  collapsed,
  onToggleCollapse,
  nodes,
  loading,
  backendOk,
  onRefresh,
  onOpenExplorer,
  onRevealNode,
}: SidebarProps) {
  if (collapsed) {
    return (
      <div className="relative shrink-0 w-10 border-r border-[var(--border)] bg-[var(--panel)] flex flex-col items-center py-2 gap-1">
        <button
          type="button"
          title="Show file tree"
          onClick={onToggleCollapse}
          className="w-8 h-8 rounded flex items-center justify-center text-[var(--muted)] hover:bg-[var(--hover)]"
        >
          ☰
        </button>
        <button
          type="button"
          title="Open storage in Explorer"
          onClick={onOpenExplorer}
          disabled={!backendOk}
          className="w-8 h-8 rounded flex items-center justify-center text-[var(--muted)] hover:bg-[var(--hover)] disabled:opacity-40"
        >
          📂
        </button>
      </div>
    );
  }

  return (
    <aside
      className="relative shrink-0 flex flex-col border-r border-[var(--border)] bg-[var(--panel)]"
      style={{ width }}
    >
      <div className="flex items-center justify-between px-3 h-9 border-b border-[var(--border)] shrink-0">
        <span className="text-xs font-semibold uppercase tracking-wide text-[var(--muted)]">
          Explorer
        </span>
        <div className="flex items-center gap-1">
          <button
            type="button"
            title="Open storage folder in Windows Explorer (create folder/file there)"
            onClick={onOpenExplorer}
            disabled={!backendOk}
            className="w-6 h-6 rounded text-[var(--muted)] hover:bg-[var(--hover)] text-sm disabled:opacity-40"
          >
            📂
          </button>
          <button
            type="button"
            title="Refresh tree"
            onClick={onRefresh}
            disabled={!backendOk || loading}
            className="w-6 h-6 rounded text-[var(--muted)] hover:bg-[var(--hover)] text-sm disabled:opacity-40"
          >
            ↻
          </button>
          <button
            type="button"
            title="Collapse sidebar"
            onClick={onToggleCollapse}
            className="w-6 h-6 rounded text-[var(--muted)] hover:bg-[var(--hover)] text-sm"
          >
            «
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-auto py-1">
        {!backendOk && (
          <p className="px-3 py-2 text-sm text-[var(--muted)]">
            Backend offline. Start FastAPI to load D: storage.
          </p>
        )}
        {backendOk && loading && (
          <p className="px-3 py-2 text-sm text-[var(--muted)]">Loading…</p>
        )}
        {backendOk && !loading && (
          <FileTree
            nodes={nodes}
            onOpen={onOpenNode}
            selectedId={selectedId}
            onReveal={onRevealNode}
          />
        )}
      </div>

      <div
        onMouseDown={onResizeStart}
        className="absolute top-0 right-0 w-1 h-full cursor-col-resize hover:bg-[var(--accent)] transition-colors"
        title="Drag to resize"
      />
    </aside>
  );
}

export default Sidebar;
