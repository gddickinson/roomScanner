"""Index of the app's own source files for the code explorer: languages, line counts, header summaries, Swift outline.

Everything is read from the repository at request time (nothing is hand-entered): the per-file summary is the file's
header comment (Swift) or first paragraph (Markdown), and the outline lists `// MARK:` sections and the
struct/class/enum/protocol/extension/func declarations with their line numbers.
"""
import re
from pathlib import Path

from .project import EXCLUDE, ROOT

MAX_BYTES = 200_000
LANG = {".swift": "Swift", ".md": "Markdown", ".plist": "Property list", ".json": "JSON", ".py": "Python",
         ".sh": "Shell", ".txt": "Text"}
DECL = re.compile(r"^(\s*)(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:private|fileprivate|public|internal|open|final|static|"
                  r"override|nonisolated|mutating|required|convenience|lazy|class)\s+)*"
                  r"(struct|class|enum|protocol|extension|func)\s+([A-Za-z_][\w.]*)")
NAMED = {"LICENSE": "Text"}  # files without an extension that belong in the explorer
MARK = re.compile(r"^\s*// MARK: -?\s*(.+?)\s*$")


def lang_of(p: Path) -> str | None:
    return LANG.get(p.suffix) or NAMED.get(p.name)


def app_files() -> list[Path]:
    """Text files of the app (repo root and sub-folders), excluding the web interface, binaries and large files."""
    out = []
    for p in sorted(ROOT.rglob("*")):
        rel = p.relative_to(ROOT)
        if not p.is_file() or any(part.startswith(".") for part in rel.parts):
            continue
        if rel.parts[0] in EXCLUDE or str(rel) in EXCLUDE or lang_of(p) is None or p.stat().st_size > MAX_BYTES:
            continue
        out.append(p)
    return out


def summary(text: str, suffix: str) -> str:
    """Header comment of a Swift file (minus the file/project name lines), or the first paragraph of Markdown."""
    lines = text.splitlines()
    if suffix == ".swift":
        head = []
        for ln in lines:
            if not ln.startswith("//"):
                break
            head.append(ln[2:].strip())
        # Xcode header: "", "Name.swift", "Project", "", "Summary..."
        body = [h for h in head[3:] if h] if len(head) > 3 else [h for h in head if h]
        return " ".join(body)
    if suffix == ".md":
        para = []
        for ln in lines:
            if ln.startswith("#") or ln.startswith("```"):
                if para:
                    break
                continue
            if not ln.strip():
                if para:
                    break
                continue
            para.append(ln.strip())
        text = re.sub(r"\*\*|__|`", "", " ".join(para))
        return re.sub(r"^[-*] ", "", text)[:300]
    if suffix == ".plist":
        keys = re.findall(r"<key>(NS\w+UsageDescription|UIRequiredDeviceCapabilities)</key>", text)
        return "App configuration" + (": " + ", ".join(keys) if keys else "")
    return ""


def outline(text: str) -> list[dict]:
    """MARK sections and type/function declarations, with 1-based line numbers and nesting depth (by indentation)."""
    out = []
    for i, ln in enumerate(text.splitlines(), 1):
        m = MARK.match(ln)
        if m:
            out.append({"kind": "mark", "name": m.group(1), "line": i, "depth": 0})
            continue
        m = DECL.match(ln)
        if m and not ln.lstrip().startswith("//"):
            out.append({"kind": m.group(2), "name": m.group(3), "line": i, "depth": len(m.group(1).expandtabs(4)) // 4})
    return out


def file_entry(p: Path) -> dict:
    text = p.read_text(errors="replace")
    rel = p.relative_to(ROOT).as_posix()
    entry = {"path": rel, "lang": lang_of(p), "lines": len(text.splitlines()), "bytes": p.stat().st_size,
             "summary": summary(text, p.suffix)}
    if p.suffix == ".swift":
        entry["outline"] = outline(text)
        entry["imports"] = re.findall(r"^import (\w+)", text, re.M)
    return entry


def tree() -> list[dict]:
    return [file_entry(p) for p in app_files()]


def sources() -> dict:
    return {p.relative_to(ROOT).as_posix(): p.read_text(errors="replace") for p in app_files()}


def counts() -> dict:
    files = tree()
    langs: dict[str, dict] = {}
    for f in files:
        d = langs.setdefault(f["lang"], {"lang": f["lang"], "files": 0, "lines": 0})
        d["files"] += 1
        d["lines"] += f["lines"]
    swift = [f for f in files if f["lang"] == "Swift"]
    kinds = [o["kind"] for f in swift for o in f["outline"]]
    frameworks = sorted({i for f in swift for i in f["imports"]})
    return {"files": len(files), "languages": sorted(langs.values(), key=lambda d: -d["lines"]),
            "swift_files": len(swift), "swift_lines": sum(f["lines"] for f in swift),
            "types": sum(k in ("struct", "class", "enum", "protocol") for k in kinds),
            "extensions": kinds.count("extension"), "functions": kinds.count("func"), "frameworks": frameworks}
