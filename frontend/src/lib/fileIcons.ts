/** Map file kind or filename → icon glyph for the explorer. */

export function iconForFile(name: string, fileKind?: string): string {
  const kind = (fileKind || "").toLowerCase();
  const ext = name.includes(".") ? name.split(".").pop()!.toLowerCase() : "";

  if (kind === "folder") return "📁";
  if (kind === "pdf" || ext === "pdf") return "📕";
  if (kind === "docx" || ext === "docx") return "📘";
  if (kind === "doc" || ext === "doc") return "📙";
  if (kind === "link" || ext === "url") return "🔗";
  if (kind === "code" || isCodeExt(ext)) return "💻";
  if (kind === "text" || ext === "md" || ext === "txt" || ext === "markdown")
    return "📝";
  if (["png", "jpg", "jpeg", "gif", "webp", "svg"].includes(ext)) return "🖼️";
  return "📄";
}

function isCodeExt(ext: string): boolean {
  return [
    "py",
    "ts",
    "tsx",
    "js",
    "jsx",
    "json",
    "css",
    "html",
    "rs",
    "go",
    "java",
    "c",
    "cpp",
    "h",
    "sh",
    "yml",
    "yaml",
    "toml",
    "sql",
  ].includes(ext);
}
