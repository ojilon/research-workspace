/**
 * Parse a Windows Internet Shortcut (.url) file body.
 * Format is roughly:
 *   [InternetShortcut]
 *   URL=https://example.com
 */
export function parseUrlFile(content: string): string | null {
  const match = content.match(/^\s*URL\s*=\s*(.+)$/im);
  if (!match) return null;
  const url = match[1].trim();
  return url || null;
}
