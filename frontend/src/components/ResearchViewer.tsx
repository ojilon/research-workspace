import { useState } from "react";
import PdfBlobViewer from "./PdfBlobViewer";
import DocxHtmlViewer from "./DocxHtmlViewer";
import type { DocBlock, ExtractedDocument } from "../types";

type ResearchViewerProps = {
  extracted: ExtractedDocument;
  path?: string;
  onBlockSelect?: (block: DocBlock) => void;
  onSendToSummary?: (block: DocBlock) => void;
};

type ViewMode = "blocks" | "pages" | "split";

function ResearchViewer({
  extracted,
  path,
  onBlockSelect,
  onSendToSummary,
}: ResearchViewerProps) {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const canPages =
    !!path && (extracted.kind === "pdf" || extracted.kind === "docx");
  const [mode, setMode] = useState<ViewMode>(
    canPages ? "pages" : "blocks"
  );

  function selectBlock(block: DocBlock) {
    setSelectedId(block.id);
    onBlockSelect?.(block);
  }

  return (
    <div className="h-full flex flex-col min-h-0">
      <div className="flex items-center gap-2 px-3 py-2 border-b border-[var(--border)] bg-[var(--panel)] shrink-0 text-xs">
        <span className="font-medium text-[var(--text-h)] truncate">
          {extracted.title}
        </span>
        <span className="text-[var(--muted)] uppercase">{extracted.kind}</span>
        {extracted.page_count != null && (
          <span className="text-[var(--muted)]">{extracted.page_count} pages</span>
        )}
        {canPages && (
          <div className="ml-auto flex gap-1">
            {(["blocks", "pages", "split"] as const).map((m) => (
              <button
                key={m}
                type="button"
                onClick={() => setMode(m)}
                className={
                  "px-2 py-0.5 rounded " +
                  (mode === m
                    ? "bg-[var(--accent-muted)] text-[var(--accent)]"
                    : "text-[var(--muted)] hover:bg-[var(--hover)]")
                }
              >
                {m === "pages" ? "view" : m}
              </button>
            ))}
          </div>
        )}
      </div>

      {extracted.warning && (
        <div className="px-3 py-2 text-xs bg-amber-500/10 text-amber-700 dark:text-amber-300 border-b border-[var(--border)]">
          {extracted.warning}
        </div>
      )}

      <div className="flex-1 min-h-0 flex">
        {(mode === "blocks" || mode === "split") && (
          <div
            className={
              "overflow-auto p-3 space-y-1 " +
              (mode === "split" ? "w-1/2 border-r border-[var(--border)]" : "w-full")
            }
          >
            {extracted.blocks.length === 0 && (
              <p className="text-sm text-[var(--muted)]">No text blocks extracted.</p>
            )}
            {extracted.blocks.map((block) => {
              const isSel = selectedId === block.id;
              const page = block.meta?.page as number | undefined;
              return (
                <div
                  key={block.id}
                  role="button"
                  tabIndex={0}
                  onClick={() => selectBlock(block)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" || e.key === " ") selectBlock(block);
                  }}
                  className={
                    "group rounded-md px-3 py-2 text-sm cursor-pointer border transition-colors " +
                    (isSel
                      ? "border-[var(--accent)] bg-[var(--accent-muted)]"
                      : "border-transparent hover:bg-[var(--hover)]")
                  }
                >
                  <div className="flex items-start gap-2">
                    <div className="flex-1 min-w-0">
                      {block.type === "heading" && (
                        <p className="font-semibold text-[var(--text-h)]">
                          {block.text}
                        </p>
                      )}
                      {block.type === "list_item" && (
                        <p className="text-[var(--text)]">• {block.text}</p>
                      )}
                      {block.type === "table_cell" && (
                        <p className="text-[var(--text)] font-mono text-xs border border-[var(--border)] rounded px-2 py-1">
                          {block.text}
                        </p>
                      )}
                      {(block.type === "paragraph" ||
                        block.type === "code_line") && (
                        <p className="text-[var(--text)] whitespace-pre-wrap leading-relaxed">
                          {block.text || (
                            <span className="text-[var(--muted)] italic">
                              (empty)
                            </span>
                          )}
                        </p>
                      )}
                      {page != null && (
                        <span className="text-[10px] text-[var(--muted)]">
                          p.{page}
                        </span>
                      )}
                    </div>
                    {onSendToSummary && block.text && (
                      <button
                        type="button"
                        title="Append block to summary"
                        className="opacity-0 group-hover:opacity-100 text-xs px-1.5 py-0.5 rounded bg-[var(--accent)] text-white shrink-0"
                        onClick={(e) => {
                          e.stopPropagation();
                          onSendToSummary(block);
                        }}
                      >
                        →
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {(mode === "pages" || mode === "split") && path && extracted.kind === "pdf" && (
          <div className={mode === "split" ? "w-1/2 min-h-0" : "w-full min-h-0"}>
            <PdfBlobViewer path={path} title={extracted.title} />
          </div>
        )}

        {(mode === "pages" || mode === "split") && path && extracted.kind === "docx" && (
          <div className={mode === "split" ? "w-1/2 min-h-0" : "w-full min-h-0"}>
            <DocxHtmlViewer path={path} title={extracted.title} />
          </div>
        )}
      </div>
    </div>
  );
}

export default ResearchViewer;
