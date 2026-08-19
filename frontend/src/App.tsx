import { useCallback, useEffect, useRef, useState } from "react";
import Header from "./components/Header";
import Sidebar from "./components/Sidebar";
import SummaryPanel from "./components/SummaryPanel";
import TabBar from "./components/TabBar";
import MainPanel from "./components/MainPanel";
import BrowserTab from "./components/BrowserTab";
import NoteEditor, { type NoteEditorHandle } from "./components/NoteEditor";
import ResearchViewer from "./components/ResearchViewer";
import CodeViewer from "./components/CodeViewer";
import type { OpenTarget } from "./components/FileTree";
import { useTheme } from "./hooks/useTheme";
import { useResizable } from "./hooks/useResizable";
import { api } from "./lib/api";
import { parseUrlFile } from "./lib/urlFile";
import type { DocBlock, FileTreeNode, Tab } from "./types";

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

function isTextNotePath(path: string): boolean {
  const lower = path.toLowerCase();
  return (
    lower.endsWith(".md") ||
    lower.endsWith(".txt") ||
    lower.endsWith(".markdown")
  );
}

function isUrlShortcut(path: string): boolean {
  return path.toLowerCase().endsWith(".url");
}

function isResearchPath(path: string, fileKind?: string): boolean {
  const k = (fileKind || "").toLowerCase();
  if (["pdf", "docx", "doc", "code"].includes(k)) return true;
  const lower = path.toLowerCase();
  return (
    lower.endsWith(".pdf") ||
    lower.endsWith(".docx") ||
    lower.endsWith(".doc") ||
    /\.(py|ts|tsx|js|jsx|json|css|html|rs|go|java|c|cpp|h|sh|yml|yaml|toml|sql)$/i.test(
      lower
    )
  );
}

function App() {
  const { theme, toggleTheme } = useTheme();
  const summaryNoteRef = useRef<NoteEditorHandle | null>(null);

  const left = useResizable({
    initialWidth: 260,
    minWidth: 180,
    maxWidth: 420,
    side: "left",
  });
  const right = useResizable({
    initialWidth: 360,
    minWidth: 240,
    maxWidth: 900,
    side: "right",
  });

  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [summaryCollapsed, setSummaryCollapsed] = useState(false);
  const [storageRoot, setStorageRoot] = useState<string | null>(null);
  const [backendOk, setBackendOk] = useState(false);
  const [treeNodes, setTreeNodes] = useState<FileTreeNode[]>([]);
  const [treeLoading, setTreeLoading] = useState(false);

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

  const summaryFlexGrow = sidebarCollapsed && !summaryCollapsed;

  const refreshTree = useCallback(async () => {
    setTreeLoading(true);
    try {
      const data = await api.getTree();
      setTreeNodes(data.nodes);
      setStorageRoot(data.root);
    } catch {
      setTreeNodes([]);
    } finally {
      setTreeLoading(false);
    }
  }, []);

  useEffect(() => {
    api
      .health()
      .then(() => {
        setBackendOk(true);
        return api.getStorageRoot();
      })
      .then((r) => {
        setStorageRoot(r.path);
        return refreshTree();
      })
      .catch(() => setBackendOk(false));
  }, [refreshTree]);

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

  const openOrFocusSummary = useCallback((tab: Tab) => {
    setSummaryTabs((prev) => {
      const existing = prev.find(
        (t) => t.path && t.path === tab.path && t.kind === tab.kind
      );
      if (existing) {
        setActiveSummaryId(existing.id);
        return prev;
      }
      setActiveSummaryId(tab.id);
      return [...prev, tab];
    });
  }, []);

  async function openTextAsNote(node: FileTreeNode, target: OpenTarget) {
    if (!node.path) return;
    const file = await api.readFile(node.path);
    const tab: Tab = {
      id: createId("note"),
      title: node.name.replace(/\.(md|txt|markdown)$/i, ""),
      kind: "note",
      path: node.path,
      content: file.content,
      dirty: false,
    };
    if (target === "summary") openOrFocusSummary(tab);
    else openOrFocusCenter(tab);
  }

  async function openResearchDoc(node: FileTreeNode, target: OpenTarget) {
    if (!node.path) return;
    const extracted = await api.extractDocument(node.path);
    const tab: Tab = {
      id: createId("research"),
      title: extracted.title || node.name,
      kind: "research",
      path: node.path,
      extracted,
      fileKind: extracted.kind,
    };
    if (target === "summary") openOrFocusSummary(tab);
    else openOrFocusCenter(tab);
  }

  async function openLinkNode(node: FileTreeNode) {
    if (!node.path) return;
    let url = node.url;
    if (!url) {
      const file = await api.readFile(node.path);
      url = parseUrlFile(file.content) ?? undefined;
    }
    if (!url) {
      window.alert("Could not read URL from shortcut file.");
      return;
    }
    openOrFocusCenter({
      id: createId("tab"),
      title: node.name.replace(/\.url$/i, ""),
      kind: "browser",
      url,
      path: node.path,
    });
  }

  async function handleOpenNode(
    node: FileTreeNode,
    target: OpenTarget = "center"
  ) {
    setSelectedTreeId(node.id);
    if (!node.path) return;

    try {
      if (node.kind === "link" || isUrlShortcut(node.path)) {
        await openLinkNode(node);
        return;
      }

      if (isResearchPath(node.path, node.fileKind)) {
        await openResearchDoc(node, target);
        return;
      }

      if (node.kind === "document" && isTextNotePath(node.path)) {
        await openTextAsNote(node, target);
        return;
      }

      if (node.kind === "document") {
        try {
          await openResearchDoc(node, target);
        } catch {
          const tab: Tab = {
            id: createId("note"),
            title: node.name,
            kind: "note",
            path: node.path,
            content: `# ${node.name}\n\n_Could not extract this file type._\n`,
            dirty: false,
          };
          if (target === "summary") openOrFocusSummary(tab);
          else openOrFocusCenter(tab);
        }
      }
    } catch (err) {
      window.alert(
        `Failed to open: ${err instanceof Error ? err.message : err}`
      );
    }
  }

  /** Insert block text at the summary caret (between existing text). */
  function sendBlockToSummary(block: DocBlock) {
    if (!block.text.trim()) return;
    const addition = `\n\n${block.text.trim()}\n`;

    if (activeSummary?.kind === "note" && summaryNoteRef.current) {
      summaryNoteRef.current.insertAtCursor(addition);
      updateSummaryTab(activeSummary.id, { dirty: true });
      return;
    }

    // No active note editor – create one and append
    const id = createId("note");
    setSummaryTabs((prev) => [
      ...prev,
      {
        id,
        title: "Untitled summary",
        kind: "note",
        content: defaultNoteContent() + addition,
        dirty: true,
      },
    ]);
    setActiveSummaryId(id);
  }

  async function handleOpenExplorer() {
    if (!backendOk) {
      window.alert("Backend offline – cannot open Explorer.");
      return;
    }
    try {
      await api.openFolder("");
    } catch (err) {
      window.alert(
        `Could not open Explorer: ${err instanceof Error ? err.message : err}`
      );
    }
  }

  /** Windows Save As – pick name + extension under storage root. */
  async function handleCreateFile() {
    if (!backendOk) {
      window.alert("Backend offline.");
      return;
    }
    try {
      const res = await api.saveAs("Untitled.md", "summaries");
      if (res.cancelled) return;
      await refreshTree();
      if (res.under_root && res.path) {
        // Open the new markdown/text file as a note on the summary side
        if (isTextNotePath(res.path)) {
          const file = await api.readFile(res.path);
          openOrFocusSummary({
            id: createId("note"),
            title: res.name?.replace(/\.(md|txt|markdown)$/i, "") ?? "New",
            kind: "note",
            path: res.path,
            content: file.content,
            dirty: false,
          });
        }
      }
    } catch (err) {
      window.alert(
        `Create file failed: ${err instanceof Error ? err.message : err}`
      );
    }
  }

  async function handleRevealNode(node: FileTreeNode) {
    if (!node.path || !backendOk) return;
    try {
      await api.reveal(node.path);
    } catch (err) {
      window.alert(
        `Could not reveal: ${err instanceof Error ? err.message : err}`
      );
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
    setSummaryTabs((prev) => [
      ...prev,
      {
        id,
        title: "Untitled summary",
        kind: "note",
        content: defaultNoteContent(),
        dirty: false,
      },
    ]);
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
      window.alert("Backend is not running.");
      return;
    }

    const tab = target.tab;
    let relative = tab.path;

    if (!relative) {
      // First save → native Save As
      try {
        const res = await api.saveAs(
          `${(tab.title || "untitled").replace(/[<>:"/\\|?*]/g, "") || "untitled"}.md`,
          "summaries"
        );
        if (res.cancelled || !res.path) return;
        if (!res.under_root) {
          window.alert(
            "Please save under the storage root so the app can track the file."
          );
          return;
        }
        relative = res.path;
      } catch (err) {
        window.alert(
          `Save As failed: ${err instanceof Error ? err.message : err}`
        );
        return;
      }
    }

    try {
      const res = await api.saveFile(relative, tab.content ?? "");
      if (target.pane === "summary") {
        updateSummaryTab(tab.id, { path: res.path, dirty: false });
      } else {
        updateCenterTab(tab.id, { path: res.path, dirty: false });
      }
      await refreshTree();
    } catch (err) {
      window.alert(`Save failed: ${err instanceof Error ? err.message : err}`);
    }
  }

  async function handleSaveLinkFromBrowser(url: string, title: string) {
    if (!backendOk) {
      window.alert("Backend offline – cannot save bookmark.");
      return;
    }
    try {
      await api.saveBookmark("bookmarks", title || hostnameFromUrl(url), url);
      await refreshTree();
    } catch (err) {
      window.alert(
        `Save link failed: ${err instanceof Error ? err.message : err}`
      );
    }
  }

  function renderResearchTab(tab: Tab) {
    if (!tab.extracted) return null;
    if (tab.extracted.kind === "code" && tab.extracted.raw != null) {
      return (
        <CodeViewer
          title={tab.extracted.title}
          language={tab.extracted.language}
          raw={tab.extracted.raw}
        />
      );
    }
    return (
      <ResearchViewer
        extracted={tab.extracted}
        path={tab.path}
        onSendToSummary={sendBlockToSummary}
      />
    );
  }

  return (
    <div className="h-screen flex flex-col bg-[var(--bg)] text-[var(--text)] overflow-hidden">
      <Header theme={theme} onToggleTheme={toggleTheme} />

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
        <span className="ml-auto">
          PDF view: select text · copy/paste into summary · → inserts at caret
        </span>
      </div>

      <div className="flex flex-1 min-h-0">
        <Sidebar
          width={left.width}
          onResizeStart={left.onMouseDown}
          onOpenNode={handleOpenNode}
          selectedId={selectedTreeId}
          collapsed={sidebarCollapsed}
          onToggleCollapse={() => setSidebarCollapsed((v) => !v)}
          nodes={treeNodes}
          loading={treeLoading}
          backendOk={backendOk}
          onRefresh={() => void refreshTree()}
          onOpenExplorer={() => void handleOpenExplorer()}
          onRevealNode={(n) => void handleRevealNode(n)}
        />

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
                status={
                  activeCenter.dirty
                    ? "unsaved"
                    : activeCenter.path ?? "draft"
                }
                onTitleChange={(title) =>
                  updateCenterTab(activeCenter.id, { title, dirty: true })
                }
                onChange={(content) =>
                  updateCenterTab(activeCenter.id, { content, dirty: true })
                }
              />
            )}
            {activeCenter?.kind === "research" && renderResearchTab(activeCenter)}
            {!activeCenter && (
              <div className="h-full flex items-center justify-center text-[var(--muted)] text-sm">
                Open a PDF, DOCX, note, or code file from the explorer.
              </div>
            )}
          </div>
        </main>

        <SummaryPanel
          width={right.width}
          flexGrow={summaryFlexGrow}
          onResizeStart={right.onMouseDown}
          collapsed={summaryCollapsed}
          onToggleCollapse={() => setSummaryCollapsed((v) => !v)}
          tabs={summaryTabs}
          activeTabId={activeSummaryId}
          onSelectTab={setActiveSummaryId}
          onCloseTab={closeSummaryTab}
          onNewNoteTab={handleNewSummaryNote}
          onUpdateTab={updateSummaryTab}
          onOpenStorageExplorer={() => void handleOpenExplorer()}
          onCreateFile={() => void handleCreateFile()}
          backendOk={backendOk}
          onSendBlockToNote={sendBlockToSummary}
          noteEditorRef={summaryNoteRef}
        />
      </div>
    </div>
  );
}

export default App;
