"""Plain-text markers and DOCX paragraphs, both ways.

The bottom editor holds plain text with light markers:

    "# "      Heading 1
    "## "     Heading 2
    "### "    Heading 3
    "- "      List Bullet
    "**x**"   bold
    "*x*"     italic

A literal backslash, asterisk or hash at the start of a line is escaped with
a backslash, so converting DOCX -> markers -> DOCX keeps the text.  Only
these styles and runs survive a round trip; everything else is written as a
normal paragraph (the app is a revision tool, not a word processor).
"""

from __future__ import annotations

HEADING_PREFIXES = [
    ("### ", "Heading 3"),
    ("## ", "Heading 2"),
    ("# ", "Heading 1"),
]
BULLET_PREFIXES = [("- ", "List Bullet")]

STYLE_TO_PREFIX = {
    "Heading 1": "# ",
    "Heading 2": "## ",
    "Heading 3": "### ",
    "List Bullet": "- ",
}

MARKER_STYLES = {"Heading 1", "Heading 2", "Heading 3", "List Bullet", "Normal"}


def escape_inline(text: str) -> str:
    return text.replace("\\", "\\\\").replace("*", "\\*")


def escape_line_start(text: str) -> str:
    if text.startswith("#") or text.startswith("- "):
        return "\\" + text
    return text


def unescape(text: str) -> str:
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            out.append(text[i + 1])
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def style_of_runs(runs) -> str:
    """The simplest style that holds `runs` ([(text, bold, italic)])."""
    padded = [r for r in runs if r[0]]
    if not padded:
        return ""
    if any(b for _, b, _ in padded):
        return "**"
    if any(i for _, _, i in padded):
        return "*"
    return ""


def runs_to_markers(runs) -> str:
    """[(text, bold, italic)] -> "plain **bold** *italic*"."""
    parts = []
    for text, bold, italic in runs:
        if not text:
            continue
        # Emphasis only where there is a word to hold it.
        lead = text[: len(text) - len(text.lstrip())]
        trail = text[len(text.rstrip()) :]
        core = text.strip()
        if not core:
            parts.append(escape_inline(text))
            continue
        marker = "**" if bold else ("*" if italic else "")
        if marker and marker in core:
            # Asterisks inside emphasised text would close it early.
            marker = ""
        inner = core if marker else escape_inline(core)
        parts.append(escape_inline(lead) + marker + inner + marker + escape_inline(trail))
    return "".join(parts)


def markers_to_runs(text: str):
    """Inverse of runs_to_markers: [(text, bold, italic)]."""
    runs = []
    buf = []
    bold = False
    italic = False
    i = 0
    n = len(text)

    def flush():
        if buf:
            runs.append(("".join(buf), bold, italic))
            buf.clear()

    while i < n:
        c = text[i]
        if c == "\\" and i + 1 < n:
            buf.append(text[i + 1])
            i += 2
            continue
        if c == "*":
            double = i + 1 < n and text[i + 1] == "*"
            marker = "**" if double else "*"
            closing = (bold if double else italic)
            if closing:
                # A closing marker must follow a word, not a space.
                if buf and not buf[-1].isspace():
                    flush()
                    if double:
                        bold = False
                    else:
                        italic = False
                    i += len(marker)
                    continue
            else:
                # An opening marker must lead into a word, and be closed later.
                after = i + len(marker)
                if after < n and not text[after].isspace() and marker in text[after:]:
                    flush()
                    if double:
                        bold = True
                    else:
                        italic = True
                    i += len(marker)
                    continue
            buf.append(marker)
            i += len(marker)
            continue
        buf.append(c)
        i += 1
    flush()
    return runs


def paragraph_marker(style: str, runs) -> str:
    prefix = STYLE_TO_PREFIX.get(style, "")
    body = runs_to_markers(runs)
    if not prefix:
        return escape_line_start(body)
    return prefix + body


def marker_paragraph(line: str):
    """One line of marker text -> (style, runs)."""
    style = "Normal"
    body = line
    if body.startswith("\\") and len(body) > 1 and body[1] in "#-":
        body = body[1:]
    else:
        matched = False
        for prefix, name in HEADING_PREFIXES:
            if body.startswith(prefix):
                style = name
                body = body[len(prefix) :]
                matched = True
                break
        if not matched:
            for prefix, name in BULLET_PREFIXES:
                if body.startswith(prefix):
                    style = name
                    body = body[len(prefix) :]
                    break
    return style, markers_to_runs(body)


def markers_to_paragraphs(text: str):
    """Marker text -> [{"style": ..., "text": ..., "runs": [...]}]."""
    lines = text.split("\n")
    while lines and lines[-1] == "":
        lines.pop()
    out = []
    for line in lines:
        style, runs = marker_paragraph(line)
        out.append(
            {
                "style": style,
                "text": "".join(r[0] for r in runs),
                "runs": [[r[0], r[1], r[2]] for r in runs],
            }
        )
    return out


def marker_text_of_paragraph(style: str, runs) -> str:
    return paragraph_marker(style if style in STYLE_TO_PREFIX else "Normal", runs)
