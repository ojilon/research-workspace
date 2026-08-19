import { useCallback, useEffect, useState } from "react";
import Header from "./components/Header";
import Sidebar from "./components/Sidebar";
import SummaryPanel from "./components/SummaryPanel";
import TabBar from "./components/TabBar";
import MainPanel from "./components/MainPanel";
import BrowserTab from "./components/BrowserTab";
import NoteEditor from "./components/NoteEditor";
import { useTheme } from "./hooks/useTheme";
import { useResizable } from "./hooks/useResizable";
import { api } from "./lib/api";
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

function defaultNoteContent() {
  return "# Summary\n\n";
}

/**
 * Root application shell.
 *
 * Centre pane  → document / browser / note tabs
 * Right pane   → independent tab strip; new tab = editable note (draft doc)
 * Ctrl+S       → save active note via FastAPI into the local storage root
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
    initialWidth: 320,
    minWidth: 220,
    maxWidth: 560,
    side: "right",
  });

  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [summaryCollapsed, setSummaryCollapsed] = useState(false);
  const [storageRoot, setStorageRoot] = useState<string | null>(null);
  const [backendOk, setBackendOk] = useState(false);

  // ---- Centre pane tabs ----
  const [centerTabs, setCenterTabs] = useState<Tab[]>([
    {
      id: "tab-welcome",
      title: "Growth",
      kind: "document",
      resourceId: "growth",
    },
  ]);
  const [activeCenterId, setActiveCenterId] = useState<string | null>(
    "tab-welcome"
  );

  // ---- Right (summary) pane tabs ----
  const [summaryTabs, setSummaryTabs] = useState<Tab[]>([
    {
      id: "note-1",
      title: "Untitled summary",
      kind: "note",
      content: defaultNoteContent(),
      dirty: false,
    },
  ]);
  const [activeSummaryId, setActiveSummaryId] = useState<string | null>(
    "note-1"
  );

  const [selectedTreeId, setSelectedTreeId] = useState<string | undefined>();

  const activeCenter = centerTabs.find((t) => t.id === activeCenterId) ?? null;
  const activeSummary =
    summaryTabs.find((t) => t.id === activeSummaryId) ?? null;

  // Probe backend once on mount
  useEffect(() => {
    api
      .health()
      .then(() => {
        setBackendOk(true);
        return api.getStorageRoot();
      })
      .then((r) => setStorageRoot(r.path))
      .catch(() => setBackendOk(false));
  }, []);

  // Ctrl+S → save the focused note (prefer summary pane if it has a note)
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s") {
        e.preventDefault();
        void handleSave();
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeSummary, activeCenter, backendOk]);

  const openOrFocusCenter = useCallback((tab: Tab) => {
    setCenterTabs((prev) => {
      const existing = prev.find(
        (t) =>
          t.kind === tab.kind &&
          t.resourceId === tab.resourceId &&
          t.url === tab.url &&
          t.path === tab.path
      );
      if (existing) {
        setActiveCenterId(existing.id);
        return prev;
      }
      setActiveCenterId(tab.id);
      return [...prev, tab];
    });
  }, []);

  function handleOpenNode(node: FileTreeNode) {
    setSelectedTreeId(node.id);

    if (node.kind === "document") {
      const topicMap: Record<string, string> = {
        "doc-growth": "growth",
        "doc-photosynthesis": "photosynthesis",
        "doc-notes-1": "water-relations",
      };
      const resourceId = topicMap[node.id] ?? "growth";
      openOrFocusCenter({
        id: createId("tab"),
        title: node.name.replace(/\.md$/i, ""),
        kind: "document",
        resourceId,
        path: node.path,
      });
    } else if (node.kind === "link") {
      openOrFocusCenter({
        id: createId("tab"),
        title: node.name,
        kind: "browser",
        url: node.url,
      });
    }
  }

  function handleNewBrowserTab() {
    openOrFocusCenter({
      id: createId("tab"),
      title: "New tab",
      kind: "browser",
      url: "https://scholar.google.com",
    });
  }

  function handleNewSummaryNote() {
    const id = createId("note");
    const tab: Tab = {
      id,
      title: "Untitled summary",
      kind: "note",
      content: defaultNoteContent(),
      dirty: false,
    };
    setSummaryTabs((prev) => [...prev, tab]);
    setActiveSummaryId(id);
  }

  function closeCenterTab(id: string) {
    setCenterTabs((prev) => {
      const next = prev.filter((t) => t.id !== id);
      if (activeCenterId === id) {
        setActiveCenterId(next.length ? next[next.length - 1].id : null);
      }
      return next;
    });
  }

  function closeSummaryTab(id: string) {
    setSummaryTabs((prev) => {
      const next = prev.filter((t) => t.id !== id);
      if (activeSummaryId === id) {
        setActiveSummaryId(next.length ? next[next.length - 1].id : null);
      }
      return next;
    });
  }

  function updateSummaryTab(id: string, patch: Partial<Tab>) {
    setSummaryTabs((prev) =>
      prev.map((t) => (t.id === id ? { ...t, ...patch } : t))
    );
  }

  function updateCenterTab(id: string, patch: Partial<Tab>) {
    setCenterTabs((prev) =>
      prev.map((t) => (t.id === id ? { ...t, ...patch } : t))
    );
  }

  /**
   * Save the active note.
   * Preference: summary-pane note → centre-pane note.
   * Uses FastAPI /api/files/save into the storage root.
   * Filename is derived from the tab title (sanitised) + .md
   */
  async function handleSave() {
    const target =
      activeSummary?.kind === "note"
        ? { pane: "summary" as const, tab: activeSummary }
        : activeCenter?.kind === "note"
          ? { pane: "center" as const, tab: activeCenter }
          : null;

    if (!target) {
      window.alert("Nothing to save – focus a note tab first.");
      return;
    }
    if (!backendOk) {
      window.alert(
        "Backend is not running.\nStart it with:\n  cd backend\n  .\\.venv\\Scripts\\Activate.ps1\n  uvicorn app.main:app --reload"
      );
      return;
    }

    const tab = target.tab;
    const safeTitle =
      (tab.title || "untitled")
        .replace(/[<>:"/\\|?*]/g, "")
        .trim() || "untitled";
    const relative =
      tab.path ?? `summaries/${safeTitle}.md`;

    try {
      const res = await api.saveFile(relative, tab.content ?? "");
      if (target.pane === "summary") {
        updateSummaryTab(tab.id, { path: res.path, dirty: false });
      } else {
        updateCenterTab(tab.id, { path: res.path, dirty: false });
      }
    } catch (err) {
      window.alert(`Save failed: ${err instanceof Error ? err.message : err}`);
    }
  }

  async function handleSaveLinkFromBrowser(url: string, title: string) {
    if (!backendOk) {
      window.alert("Backend is not running – cannot save bookmark.");
      return;
    }
    try {
      await api.saveBookmark("bookmarks", title || hostnameFromUrl(url), url);
      window.alert(`Saved link to storage root /bookmarks`);
    } catch (err) {
      window.alert(`Save link failed: ${err instanceof Error ? err.message : err}`);
    }
  }

  return (
    <div className="h-screen flex flex-col bg-[var(--bg)] text-[var(--text)] overflow-hidden">
      <Header theme={theme} onToggleTheme={toggleTheme} />

      {/* Status strip */}
      <div className="px-3 py-0.5 text-[11px] border-b border-[var(--border)] bg-[var(--panel)] text-[var(--muted)] flex gap-4 shrink-0">
        <span>
          Backend:{" "}
          <span className={backendOk ? "text-green-500" : "text-red-400"}>
            {backendOk ? "connected" : "offline"}
          </span>
        </span>
        {storageRoot && (
          <span className="truncate" title={storageRoot}>
            Storage: {storageRoot}
          </span>
        )}
        <span className="ml-auto">Ctrl+S = save active note</span>
      </div>

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
            tabs={centerTabs}
            activeTabId={activeCenterId}
            onSelect={setActiveCenterId}
            onClose={closeCenterTab}
            onNewTab={handleNewBrowserTab}
          />

          <div className="flex-1 min-h-0 overflow-hidden">
            {activeCenter?.kind === "document" && activeCenter.resourceId && (
              <MainPanel selectedTopicId={activeCenter.resourceId} />
            )}
            {activeCenter?.kind === "browser" && (
              <BrowserTab
                initialUrl={activeCenter.url}
                onUrlChange={(url) => {
                  updateCenterTab(activeCenter.id, {
                    url,
                    title: hostnameFromUrl(url),
                  });
                }}
                onSaveLink={(url) =>
                  handleSaveLinkFromBrowser(
                    url,
                    activeCenter.title || hostnameFromUrl(url)
                  )
                }
              />
            )}
            {activeCenter?.kind === "note" && (
              <NoteEditor
                title={activeCenter.title}
                content={activeCenter.content ?? ""}
                status={activeCenter.dirty ? "unsaved" : activeCenter.path ?? "draft"}
                onTitleChange={(title) =>
                  updateCenterTab(activeCenter.id, { title, dirty: true })
                }
                onChange={(content) =>
                  updateCenterTab(activeCenter.id, { content, dirty: true })
                }
              />
            )}
            {!activeCenter && (
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
          tabs={summaryTabs}
          activeTabId={activeSummaryId}
          onSelectTab={setActiveSummaryId}
          onCloseTab={closeSummaryTab}
          onNewNoteTab={handleNewSummaryNote}
          onUpdateTab={updateSummaryTab}
        />
      </div>
    </div>
  );
}

export default App;
