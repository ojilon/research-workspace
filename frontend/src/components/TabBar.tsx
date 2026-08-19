import type { Tab } from "../types";

type TabBarProps = {
  tabs: Tab[];
  activeTabId: string | null;
  onSelect: (id: string) => void;
  onClose: (id: string) => void;
  onNewTab: () => void;
};

/**
 * Horizontal tab strip (VS Code / Sublime style).
 * Supports document, browser and summary tabs.
 */
function TabBar({
  tabs,
  activeTabId,
  onSelect,
  onClose,
  onNewTab,
}: TabBarProps) {
  return (
    <div className="flex items-center h-9 border-b border-[var(--border)] bg-[var(--panel)] overflow-x-auto shrink-0">
      <div className="flex items-stretch min-w-0 flex-1">
        {tabs.map((tab) => {
          const isActive = tab.id === activeTabId;
          return (
            <div
              key={tab.id}
              className={
                "group flex items-center gap-1.5 px-3 border-r border-[var(--border)] cursor-pointer text-sm max-w-[200px] " +
                (isActive
                  ? "bg-[var(--bg)] text-[var(--text-h)] border-b-2 border-b-[var(--accent)]"
                  : "text-[var(--muted)] hover:bg-[var(--hover)]")
              }
              onClick={() => onSelect(tab.id)}
            >
              <span className="truncate">{tab.title}</span>
              <button
                type="button"
                title="Close tab"
                onClick={(e) => {
                  e.stopPropagation();
                  onClose(tab.id);
                }}
                className="opacity-0 group-hover:opacity-100 ml-1 w-4 h-4 flex items-center justify-center rounded hover:bg-[var(--hover-strong)] text-xs"
              >
                ×
              </button>
            </div>
          );
        })}
      </div>

      <button
        type="button"
        title="New browser tab"
        onClick={onNewTab}
        className="px-3 h-full text-[var(--muted)] hover:text-[var(--text)] hover:bg-[var(--hover)] text-lg leading-none"
      >
        +
      </button>
    </div>
  );
}

export default TabBar;
