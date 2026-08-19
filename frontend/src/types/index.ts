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

/** Tab kinds the centre pane can hold. */
export type TabKind = "document" | "browser" | "summary";

/** One open tab in the centre (or right) pane. */
export type Tab = {
  id: string;
  title: string;
  kind: TabKind;
  /** For document tabs: topic id or file path. */
  resourceId?: string;
  /** For browser tabs: current URL. */
  url?: string;
};

/** Node in the local file tree (folder, document, or bookmark/link). */
export type FileTreeNode = {
  id: string;
  name: string;
  kind: "folder" | "document" | "link";
  /** Absolute or relative path on disk (local storage root). */
  path?: string;
  /** For links: the URL to open. */
  url?: string;
  children?: FileTreeNode[];
};

/** Theme preference. */
export type ThemeMode = "light" | "dark";
