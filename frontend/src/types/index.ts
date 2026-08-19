/**
 * Shared types for Research Workspace.
 */

export type ContentBlock = {
  type: "paragraph";
  text: string;
};

export type Section = {
  id: string;
  title: string;
  content: ContentBlock[];
};

export type Topic = {
  id: string;
  name: string;
  description: string;
  sections: Section[];
};

/**
 * Block inside an extracted research document (PDF / DOCX / text / code).
 * Click selects the whole block — no need to drag-select text.
 */
export type DocBlockType =
  | "paragraph"
  | "heading"
  | "list_item"
  | "table_cell"
  | "code_line";

export type DocBlock = {
  id: string;
  type: DocBlockType;
  text: string;
  meta?: Record<string, unknown>;
};

export type ExtractedDocument = {
  relative_path?: string;
  path?: string;
  kind: string;
  title: string;
  blocks: DocBlock[];
  warning?: string | null;
  page_count?: number;
  raw?: string;
  language?: string;
};

export type TabKind = "document" | "browser" | "note" | "research";

export type Tab = {
  id: string;
  title: string;
  kind: TabKind;
  resourceId?: string;
  path?: string;
  url?: string;
  content?: string;
  dirty?: boolean;
  /** Loaded PDF/DOCX/code payload for research tabs. */
  extracted?: ExtractedDocument;
  fileKind?: string;
};

export type FileTreeNode = {
  id: string;
  name: string;
  kind: "folder" | "document" | "link";
  /** pdf | docx | code | text | link | folder | ... from backend */
  fileKind?: string;
  path?: string;
  url?: string;
  children?: FileTreeNode[];
};

export type ThemeMode = "light" | "dark";
