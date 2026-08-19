import { forwardRef, useImperativeHandle, useRef } from "react";

type NoteEditorProps = {
  title: string;
  content: string;
  onChange: (content: string) => void;
  onTitleChange?: (title: string) => void;
  status?: string;
};

export type NoteEditorHandle = {
  /** Insert text at the current caret (or append if unfocused). */
  insertAtCursor: (text: string) => void;
  focus: () => void;
};

const NoteEditor = forwardRef<NoteEditorHandle, NoteEditorProps>(
  function NoteEditor(
    { title, content, onChange, onTitleChange, status },
    ref
  ) {
    const taRef = useRef<HTMLTextAreaElement>(null);

    useImperativeHandle(ref, () => ({
      insertAtCursor(text: string) {
        const el = taRef.current;
        if (!el) {
          onChange(content + text);
          return;
        }
        const start = el.selectionStart;
        const end = el.selectionEnd;
        const next = content.slice(0, start) + text + content.slice(end);
        onChange(next);
        requestAnimationFrame(() => {
          el.focus();
          const pos = start + text.length;
          el.setSelectionRange(pos, pos);
        });
      },
      focus() {
        taRef.current?.focus();
      },
    }));

    function wrapSelection(before: string, after: string = before) {
      const el = taRef.current;
      if (!el) {
        onChange(content + before + after);
        return;
      }
      const start = el.selectionStart;
      const end = el.selectionEnd;
      const selected = content.slice(start, end);
      const next =
        content.slice(0, start) +
        before +
        selected +
        after +
        content.slice(end);
      onChange(next);
      requestAnimationFrame(() => {
        el.focus();
        el.setSelectionRange(
          start + before.length,
          start + before.length + selected.length
        );
      });
    }

    function prefixLines(prefix: string) {
      const el = taRef.current;
      if (!el) return;
      const start = el.selectionStart;
      const end = el.selectionEnd;
      const before = content.slice(0, start);
      const selected = content.slice(start, end) || "";
      const after = content.slice(end);
      const lined = selected
        .split("\n")
        .map((l) => (l.startsWith(prefix) ? l : prefix + l))
        .join("\n");
      onChange(before + lined + after);
    }

    return (
      <div className="h-full flex flex-col">
        <div className="flex items-center gap-2 px-3 py-2 border-b border-[var(--border)] bg-[var(--panel)] shrink-0">
          <input
            type="text"
            value={title}
            onChange={(e) => onTitleChange?.(e.target.value)}
            className="flex-1 bg-transparent text-sm font-medium text-[var(--text-h)] outline-none"
            placeholder="Untitled note"
          />
          {status && (
            <span className="text-xs text-[var(--muted)] shrink-0">{status}</span>
          )}
        </div>

        <div className="flex items-center gap-1 px-2 py-1 border-b border-[var(--border)] bg-[var(--panel)] shrink-0 text-xs">
          <ToolBtn label="B" title="Bold" onClick={() => wrapSelection("**")} className="font-bold" />
          <ToolBtn label="I" title="Italic" onClick={() => wrapSelection("_")} className="italic" />
          <ToolBtn label="H" title="Heading" onClick={() => prefixLines("# ")} />
          <ToolBtn label="•" title="List" onClick={() => prefixLines("- ")} />
          <ToolBtn label="</>" title="Code" onClick={() => wrapSelection("`")} />
          <span className="text-[var(--muted)] ml-2">
            Markdown · paste between text at caret · Ctrl+S saves
          </span>
        </div>

        <textarea
          ref={taRef}
          value={content}
          onChange={(e) => onChange(e.target.value)}
          className="flex-1 w-full resize-none p-4 text-sm leading-relaxed bg-transparent text-[var(--text)] outline-none font-mono"
          placeholder="Start writing your summary…"
          spellCheck
        />
      </div>
    );
  }
);

function ToolBtn({
  label,
  title,
  onClick,
  className = "",
}: {
  label: string;
  title: string;
  onClick: () => void;
  className?: string;
}) {
  return (
    <button
      type="button"
      title={title}
      onClick={onClick}
      className={
        "w-7 h-7 rounded hover:bg-[var(--hover)] text-[var(--text)] " + className
      }
    >
      {label}
    </button>
  );
}

export default NoteEditor;
