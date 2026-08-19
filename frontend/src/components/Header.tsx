import type { ThemeMode } from "../types";

type HeaderProps = {
  theme: ThemeMode;
  onToggleTheme: () => void;
};

/**
 * Top application bar.
 * Theme toggle lives here; later we add storage-root picker and settings.
 */
function Header({ theme, onToggleTheme }: HeaderProps) {
  return (
    <header className="h-11 shrink-0 flex items-center justify-between px-4 border-b border-[var(--border)] bg-[var(--panel)]">
      <div className="flex items-center gap-3">
        <span className="font-semibold text-[var(--text-h)] tracking-tight">
          Research Workspace
        </span>
        <span className="text-xs text-[var(--muted)] hidden sm:inline">
          local · offline-first
        </span>
      </div>

      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={onToggleTheme}
          title={theme === "dark" ? "Switch to light mode" : "Switch to dark mode"}
          className="px-2.5 py-1 rounded-md text-sm border border-[var(--border)] text-[var(--text)] hover:bg-[var(--hover)]"
        >
          {theme === "dark" ? "☀ Light" : "☾ Dark"}
        </button>
      </div>
    </header>
  );
}

export default Header;
