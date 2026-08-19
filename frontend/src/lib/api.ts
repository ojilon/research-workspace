/**
 * Thin fetch wrapper for the Research Workspace FastAPI backend.
 */

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
  health: () => request<{ status: string }>("/api/health"),

  getStorageRoot: () =>
    request<{ path: string; drive?: string }>("/api/settings/storage-root"),

  setStorageRoot: (path: string) =>
    request<{ path: string }>("/api/settings/storage-root", {
      method: "POST",
      body: JSON.stringify({ path }),
    }),

  getTree: () =>
    request<{ root: string; nodes: import("../types").FileTreeNode[] }>(
      "/api/tree"
    ),

  saveFile: (relative_path: string, content: string) =>
    request<{ path: string }>("/api/files/save", {
      method: "POST",
      body: JSON.stringify({ relative_path, content }),
    }),

  readFile: (relative_path: string) =>
    request<{ path: string; content: string }>(
      `/api/files/read?relative_path=${encodeURIComponent(relative_path)}`
    ),

  saveBookmark: (folder: string, title: string, url: string) =>
    request<{ path: string }>("/api/bookmarks", {
      method: "POST",
      body: JSON.stringify({ folder, title, url }),
    }),

  /** Open Windows Explorer at storage root or a subfolder. */
  openFolder: (relative_path = "") =>
    request<{ opened: string }>("/api/shell/open-folder", {
      method: "POST",
      body: JSON.stringify({ relative_path }),
    }),

  /** Reveal a file/folder in Explorer. */
  reveal: (relative_path: string) =>
    request<{ opened: string }>("/api/shell/reveal", {
      method: "POST",
      body: JSON.stringify({ relative_path }),
    }),
};
