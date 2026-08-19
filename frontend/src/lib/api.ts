import type { ExtractedDocument, FileTreeNode } from "../types";

const BASE = import.meta.env.VITE_API_URL ?? "http://127.0.0.1:8000";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new Error(`${res.status} ${text}`);
  }
  return res.json() as Promise<T>;
}

export const api = {
  baseUrl: BASE,

  health: () => request<{ status: string }>("/api/health"),

  getStorageRoot: () =>
    request<{ path: string; drive?: string }>("/api/settings/storage-root"),

  setStorageRoot: (path: string) =>
    request<{ path: string }>("/api/settings/storage-root", {
      method: "POST",
      body: JSON.stringify({ path }),
    }),

  getTree: () => request<{ root: string; nodes: FileTreeNode[] }>("/api/tree"),

  saveFile: (relative_path: string, content: string) =>
    request<{ path: string }>("/api/files/save", {
      method: "POST",
      body: JSON.stringify({ relative_path, content }),
    }),

  readFile: (relative_path: string) =>
    request<{ path: string; content: string }>(
      `/api/files/read?relative_path=${encodeURIComponent(relative_path)}`
    ),

  extractDocument: (relative_path: string) =>
    request<ExtractedDocument>(
      `/api/documents/extract?relative_path=${encodeURIComponent(relative_path)}`
    ),

  rawFileUrl: (relative_path: string) =>
    `${BASE}/api/files/raw?relative_path=${encodeURIComponent(relative_path)}`,

  documentHtmlUrl: (relative_path: string) =>
    `${BASE}/api/documents/html?relative_path=${encodeURIComponent(relative_path)}`,

  saveBookmark: (folder: string, title: string, url: string) =>
    request<{ path: string }>("/api/bookmarks", {
      method: "POST",
      body: JSON.stringify({ folder, title, url }),
    }),

  openFolder: (relative_path = "") =>
    request<{ opened: string }>("/api/shell/open-folder", {
      method: "POST",
      body: JSON.stringify({ relative_path }),
    }),

  reveal: (relative_path: string) =>
    request<{ opened: string }>("/api/shell/reveal", {
      method: "POST",
      body: JSON.stringify({ relative_path }),
    }),

  /** Native Windows Save As (name + extension). */
  saveAs: (default_name = "Untitled.md", relative_dir = "") =>
    request<{
      cancelled: boolean;
      path?: string;
      absolute?: string;
      under_root?: boolean;
      name?: string;
    }>("/api/shell/save-as", {
      method: "POST",
      body: JSON.stringify({ default_name, relative_dir }),
    }),
};
