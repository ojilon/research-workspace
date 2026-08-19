import { useEffect, useState } from "react";
import type { FileTreeNode } from "../types";

export type OpenTarget = "center" | "summary";

type FileTreeProps = {
  nodes: FileTreeNode[];
  /** Left-click default open (centre pane). */
  onOpen: (node: FileTreeNode, target?: OpenTarget) => void;
  selectedId?: string;
  onReveal?: (node: FileTreeNode) => void;
};

type MenuState = {
  x: number;
  y: number;
  node: FileTreeNode;
} | null;

function TreeNode({
  node,
  depth,
  onOpen,
  selectedId,
  onContextMenu,
}: {
  node: FileTreeNode;
  depth: number;
  onOpen: (node: FileTreeNode, target?: OpenTarget) => void;
  selectedId?: string;
  onContextMenu: (e: React.MouseEvent, node: FileTreeNode) => void;
}) {
  const [open, setOpen] = useState(true);
  const isSelected = selectedId === node.id;
  const hasChildren = node.kind === "folder" && (node.children?.length ?? 0) > 0;

  const icon =
    node.kind === "folder"
      ? open
        ? "📂"
        : "📁"
      : node.kind === "link"
        ? "🔗"
        : "📄";

  return (
    <div>
      <button
        type="button"
        onClick={() => {
          if (node.kind === "folder") {
            setOpen((v) => !v);
          } else {
            // Default: open in the middle (centre) pane
            onOpen(node, "center");
          }
        }}
        onContextMenu={(e) => onContextMenu(e, node)}
        className={
          "w-full flex items-center gap-2 px-2 py-1 rounded text-sm text-left transition-colors " +
          (isSelected
            ? "bg-[var(--accent-muted)] text-[var(--accent)]"
            : "text-[var(--text)] hover:bg-[var(--hover)]")
        }
        style={{ paddingLeft: 8 + depth * 14 }}
      >
        <span className="shrink-0 w-5 text-center">{icon}</span>
        <span className="truncate">{node.name}</span>
      </button>

      {hasChildren && open && (
        <div>
          {node.children!.map((child) => (
            <TreeNode
              key={child.id}
              node={child}
              depth={depth + 1}
              onOpen={onOpen}
              selectedId={selectedId}
              onContextMenu={onContextMenu}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function FileTree({ nodes, onOpen, selectedId, onReveal }: FileTreeProps) {
  const [menu, setMenu] = useState<MenuState>(null);

  useEffect(() => {
    function close() {
      setMenu(null);
    }
    window.addEventListener("click", close);
    window.addEventListener("scroll", close, true);
    return () => {
      window.removeEventListener("click", close);
      window.removeEventListener("scroll", close, true);
    };
  }, []);

  function handleContextMenu(e: React.MouseEvent, node: FileTreeNode) {
    e.preventDefault();
    e.stopPropagation();
    setMenu({ x: e.clientX, y: e.clientY, node });
  }

  if (nodes.length === 0) {
    return (
      <p className="px-3 py-2 text-sm text-[var(--muted)]">
        No files yet. Use 📂 in the header to open Explorer, create folders/files,
        then press ↻.
      </p>
    );
  }

  return (
    <div className="py-1 relative">
      {nodes.map((node) => (
        <TreeNode
          key={node.id}
          node={node}
          depth={0}
          onOpen={onOpen}
          selectedId={selectedId}
          onContextMenu={handleContextMenu}
        />
      ))}

      {menu && (
        <div
          className="fixed z-50 min-w-[180px] rounded-md border border-[var(--border)] bg-[var(--panel)] shadow-lg py-1 text-sm"
          style={{ left: menu.x, top: menu.y }}
          onClick={(e) => e.stopPropagation()}
        >
          <div className="px-3 py-1 text-xs text-[var(--muted)] truncate max-w-[220px]">
            {menu.node.name}
          </div>
          {menu.node.kind !== "folder" && (
            <>
              <button
                type="button"
                className="w-full text-left px-3 py-1.5 hover:bg-[var(--hover)] text-[var(--text)]"
                onClick={() => {
                  onOpen(menu.node, "center");
                  setMenu(null);
                }}
              >
                Open in centre
              </button>
              <button
                type="button"
                className="w-full text-left px-3 py-1.5 hover:bg-[var(--hover)] text-[var(--text)]"
                onClick={() => {
                  onOpen(menu.node, "summary");
                  setMenu(null);
                }}
              >
                Open in summary
              </button>
            </>
          )}
          {onReveal && menu.node.path && (
            <button
              type="button"
              className="w-full text-left px-3 py-1.5 hover:bg-[var(--hover)] text-[var(--text)]"
              onClick={() => {
                onReveal(menu.node);
                setMenu(null);
              }}
            >
              Show in Explorer
            </button>
          )}
        </div>
      )}
    </div>
  );
}

export default FileTree;
