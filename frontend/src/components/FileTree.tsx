import { useState } from "react";
import type { FileTreeNode } from "../types";

type FileTreeProps = {
  nodes: FileTreeNode[];
  onOpen: (node: FileTreeNode) => void;
  selectedId?: string;
};

/**
 * Recursive file-tree row. Supports folder expand/collapse,
 * document open, and link (bookmark) open.
 */
function TreeNode({
  node,
  depth,
  onOpen,
  selectedId,
}: {
  node: FileTreeNode;
  depth: number;
  onOpen: (node: FileTreeNode) => void;
  selectedId?: string;
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
            onOpen(node);
          }
        }}
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
            />
          ))}
        </div>
      )}
    </div>
  );
}

/**
 * Left-sidebar file tree.
 * Later this will be driven by the local storage root + database of bookmarks.
 */
function FileTree({ nodes, onOpen, selectedId }: FileTreeProps) {
  if (nodes.length === 0) {
    return (
      <p className="px-3 py-2 text-sm text-[var(--muted)]">
        No files yet. Create a folder or save a link.
      </p>
    );
  }

  return (
    <div className="py-1">
      {nodes.map((node) => (
        <TreeNode
          key={node.id}
          node={node}
          depth={0}
          onOpen={onOpen}
          selectedId={selectedId}
        />
      ))}
    </div>
  );
}

export default FileTree;
