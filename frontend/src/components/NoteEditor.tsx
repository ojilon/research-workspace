type NoteEditorProps = {
  title: string;
  content: string;
  onChange: (content: string) => void;
  onTitleChange?: (title: string) => void;
  /** Shown in the status strip (e.g. path or "unsaved"). */
  status?: string;
};

/**
 * Simple full-height text editor for note / summary tabs.
 * New tabs on the summary side start as an empty note (treated like a draft docx/md).
 * Ctrl+S is handled by the parent (App) so it can talk to the backend / file picker.
 */
function NoteEditor({
  title,
  content,
  onChange,
  onTitleChange,
  status,
}: NoteEditorProps) {
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
      <textarea
        value={content}
        onChange={(e) => onChange(e.target.value)}
        className="flex-1 w-full resize-none p-4 text-sm leading-relaxed bg-transparent text-[var(--text)] outline-none font-mono"
        placeholder="Start writing your summary…\n\nTip: Ctrl+S saves into the local storage folder."
        spellCheck
      />
    </div>
  );
}

export default NoteEditor;
