import { useCallback, useState } from "react";
import Header from "./components/Header";
import Sidebar from "./components/Sidebar";
import SummaryPanel from "./components/SummaryPanel";
import TabBar from "./components/TabBar";
import MainPanel from "./components/MainPanel";
import BrowserTab from "./components/BrowserTab";
import { useTheme } from "./hooks/useTheme";
import { useResizable } from "./hooks/useResizable";
import type { FileTreeNode, Tab } from "./types";

let tabCounter = 1;

function createId(prefix: string) {
  return `${prefix}-${Date.now().toString(36)}-${tabCounter++}`;
}

function hostnameFromUrl(url: string): string {
  try {
    return new URL(url).hostname || "Browser";
  } catch {
    return "Browser";
  }
}

/**
 * Root application shell.
 * - Left: resizable file tree (collapsible)
 * - Centre: tabbed area (documents + browser tabs)
 * - Right: resizable summary notes (collapsible)
 * - Top: theme toggle
 */
function App() {
  const { theme, toggleTheme } = useTheme();

  const left = useResizable({
    initialWidth: 260,
    minWidth: 180,
    maxWidth: 420,
    side: "left",
  });
  const right = useResizable({
    initialWidth: 300,
    minWidth: 200,
    maxWidth: 520,
    side: "right",
  });

  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [summaryCollapsed, setSummaryCollapsed] = useState(false);

  const [tabs, setTabs] = useState<Tab[]>([
    {
      id: "tab-welcome",
      title: "Growth",
      kind: "document",
      resourceId: "growth",
    },
  ]);
  const [activeTabId, setActiveTabId] = useState<string | null>("tab-welcome");
  const [selectedTreeId, setSelectedTreeId] = useState<string | undefined>();

  const activeTab = tabs.find((t) => t.id === activeTabId) ?? null;

  const openOrFocusTab = useCallback((tab: Tab) => {
    setTabs((prev) => {
      const existing = prev.find(
        (t) =>
          t.kind === tab.kind &&
          t.resourceId === tab.resourceId &&
          t.url === tab.url
      );
      if (existing) {
        setActiveTabId(existing.id);
        return prev;
      }
      setActiveTabId(tab.id);
      return [...prev, tab];
    });
  }, []);

  function handleOpenNode(node: FileTreeNode) {
    setSelectedTreeId(node.id);

    if (node.kind === "document") {
      // Map sample docs to the demo topics for now
      const topicMap: Record<string, string> = {
        "doc-growth": "growth",
        "doc-photosynthesis": "photosynthesis",
        "doc-notes-1": "water-relations",
      };
      const resourceId = topicMap[node.id] ?? "growth";
      openOrFocusTab({
        id: createId("tab"),
        title: node.name.replace(/\.md$/, ""),
        kind: "document",
        resourceId,
      });
    } else if (node.kind === "link") {
      openOrFocusTab({
        id: createId("tab"),
        title: node.name,
        kind: "browser",
        url: node.url,
      });
    }
  }

  function handleNewBrowserTab() {
    openOrFocusTab({
      id: createId("tab"),
      title: "New tab",
      kind: "browser",
      url: "https://scholar.google.com",
    });
  }

  function handleCloseTab(id: string) {
    setTabs((prev) => {
      const next = prev.filter((t) => t.id !== id);
      if (activeTabId === id) {
        setActiveTabId(next.length ? next[next.length - 1].id : null);
      }
      return next;
    });
  }

  return (
    <div className="h-screen flex flex-col bg-[var(--bg)] text-[var(--text)] overflow-hidden">
      <Header theme={theme} onToggleTheme={toggleTheme} />

      <div className="flex flex-1 min-h-0">
        <Sidebar
          width={left.width}
          onResizeStart={left.onMouseDown}
          onOpenNode={handleOpenNode}
          selectedId={selectedTreeId}
          collapsed={sidebarCollapsed}
          onToggleCollapse={() => setSidebarCollapsed((v) => !v)}
        />

        {/* Centre pane */}
        <main className="flex-1 flex flex-col min-w-0 bg-[var(--bg)]">
          <TabBar
            tabs={tabs}
            activeTabId={activeTabId}
            onSelect={setActiveTabId}
            onClose={handleCloseTab}
            onNewTab={handleNewBrowserTab}
          />

          <div className="flex-1 min-h-0 overflow-hidden">
            {activeTab?.kind === "document" && activeTab.resourceId && (
              <MainPanel selectedTopicId={activeTab.resourceId} />
            )}
            {activeTab?.kind === "browser" && (
              <BrowserTab
                initialUrl={activeTab.url}
                onUrlChange={(url) => {
                  setTabs((prev) =>
                    prev.map((t) =>
                      t.id === activeTab.id
                        ? { ...t, url, title: hostnameFromUrl(url) }
                        : t
                    )
                  );
                }}
              />
            )}
            {!activeTab && (
              <div className="h-full flex items-center justify-center text-[var(--muted)] text-sm">
                Open a document from the file tree or create a new browser tab.
              </div>
            )}
          </div>
        </main>

        <SummaryPanel
          width={right.width}
          onResizeStart={right.onMouseDown}
          collapsed={summaryCollapsed}
          onToggleCollapse={() => setSummaryCollapsed((v) => !v)}
        />
      </div>
    </div>
  );
}

export default App;
