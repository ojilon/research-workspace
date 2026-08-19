/**
 * Shared types for Research Workspace.
 * Keep these small and explicit so the UI stays predictable.
 */

/** One content block inside a section (paragraph for now). */
export type ContentBlock = {
  type: "paragraph";
  text: string;
};

/** A section inside a topic (e.g. "Introduction", "Osmosis"). */
export type Section = {
  id: string;
  title: string;
  content: ContentBlock[];
};

/** A research topic (shown in the left sidebar list for now). */
export type Topic = {
  id: string;
  name: string;
  description: string;
  sections: Section[];
};

/**
 * Tab kinds:
 * - document  → demo topic or loaded file (read-oriented for now)
 * - browser   → URL bar + open external
 * - note      → editable text (default new tab on the summary side)
 */
export type TabKind = "document" | "browser" | "note";

/** One open tab in the centre or right pane. */
export type Tab = {
  id: string;
  title: string;
  kind: TabKind;
  /** For document tabs: topic id. */
  resourceId?: string;
  /** Relative path under storage root (saved notes / files). */
  path?: string;
  /** For browser tabs: current URL. */
  url?: string;
  /** Editable body for note tabs (Markdown / plain text). */
  content?: string;
  /** Dirty flag – true when content changed since last save. */
  dirty?: boolean;
};

/** Node in the local file tree (folder, document, or bookmark/link). */
export type FileTreeNode = {
  id: string;
  name: string;
  kind: "folder" | "document" | "link";
  /** Relative path under the storage root. */
  path?: string;
  /** For links: the URL to open. */
  url?: string;
  children?: FileTreeNode[];
};

/** Theme preference. */
export type ThemeMode = "light" | "dark";
