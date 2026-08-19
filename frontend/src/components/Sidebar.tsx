import FileTree from "./FileTree";
import { sampleTree } from "../data/sampleTree";
import type { FileTreeNode } from "../types";

type SidebarProps = {
  width: number;
  onResizeStart: (e: React.MouseEvent) => void;
  onOpenNode: (node: FileTreeNode) => void;
  selectedId?: string;
  collapsed: boolean;
  onToggleCollapse: () => void;
};

/**
 * Left sidebar: file tree + collapse control.
 * Width is controlled by the parent via useResizable.
 */
function Sidebar({
  width,
  onResizeStart,
  onOpenNode,
  selectedId,
  collapsed,
  onToggleCollapse,
}: SidebarProps) {
  if (collapsed) {
    return (
      <div className="relative shrink-0 w-10 border-r border-[var(--border)] bg-[var(--panel)] flex flex-col items-center py-2">
        <button
          type="button"
          title="Show file tree"
          onClick={onToggleCollapse}
          className="w-8 h-8 rounded flex items-center justify-center text-[var(--muted)] hover:bg-[var(--hover)]"
        >
          ☰
        </button>
      </div>
    );
  }

  return (
    <aside
      className="relative shrink-0 flex flex-col border-r border-[var(--border)] bg-[var(--panel)]"
      style={{ width }}
    >
      {/* Header row */}
      <div className="flex items-center justify-between px-3 h-9 border-b border-[var(--border)] shrink-0">
        <span className="text-xs font-semibold uppercase tracking-wide text-[var(--muted)]">
          Explorer
        </span>
        <div className="flex items-center gap-1">
          <button
            type="button"
            title="New folder (coming soon)"
            className="w-6 h-6 rounded text-[var(--muted)] hover:bg-[var(--hover)] text-sm"
          >
            +
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

      {/* Tree */}
      <div className="flex-1 overflow-auto py-1">
        <FileTree
          nodes={sampleTree}
          onOpen={onOpenNode}
          selectedId={selectedId}
        />
      </div>

      {/* Drag handle on the right edge */}
      <div
        onMouseDown={onResizeStart}
        className="absolute top-0 right-0 w-1 h-full cursor-col-resize hover:bg-[var(--accent)] transition-colors"
        title="Drag to resize"
      />
    </aside>
  );
}

export default Sidebar;
