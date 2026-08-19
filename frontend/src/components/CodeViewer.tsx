type CodeViewerProps = {
  title: string;
  language?: string;
  raw: string;
};

/**
 * Lightweight code viewer: line numbers + monospace.
 * Syntax colours can be layered later (e.g. highlight.js / Shiki).
 */
function CodeViewer({ title, language, raw }: CodeViewerProps) {
  const lines = raw.split("\n");

  return (
    <div className="h-full flex flex-col min-h-0">
      <div className="px-3 py-2 border-b border-[var(--border)] bg-[var(--panel)] text-xs flex gap-2 shrink-0">
        <span className="font-medium text-[var(--text-h)]">{title}</span>
        {language && (
          <span className="text-[var(--muted)] uppercase">{language}</span>
        )}
        <span className="text-[var(--muted)] ml-auto">{lines.length} lines</span>
      </div>
      <div className="flex-1 overflow-auto font-mono text-[13px] leading-5">
        <table className="w-full border-collapse">
          <tbody>
            {lines.map((line, i) => (
              <tr key={i} className="hover:bg-[var(--hover)]">
                <td className="select-none text-right pr-3 pl-3 text-[var(--muted)] w-12 align-top border-r border-[var(--border)]">
                  {i + 1}
                </td>
                <td className="pl-3 pr-3 whitespace-pre text-[var(--text)]">
                  {line || " "}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default CodeViewer;
