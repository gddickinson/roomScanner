"""Run pieces of the app's real Swift source on this Mac, so tests and the JS ports can be checked against the original.

The iOS app itself cannot run here (ARKit, camera, GPS), but many of its functions are plain maths. `extract()` copies a
declaration (func / computed var) verbatim out of a source file by brace matching; a harness wraps the copies in small
stub types and a `main`, `run()` compiles it with `xcrun swiftc` (macOS, or Mac Catalyst for UIKit drawing code) and
returns stdout. `typecheck_ios()` type-checks the whole app against the iOS SDK.

Only works on macOS with Xcode; callers skip otherwise (see `available()`).
"""
import platform
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


def _sdk(name: str) -> str | None:
    if platform.system() != "Darwin" or not shutil.which("xcrun"):
        return None
    r = subprocess.run(["xcrun", "--sdk", name, "--show-sdk-path"], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None


def available(sdk: str = "macosx") -> bool:
    """True when xcrun and the given SDK ('macosx' or 'iphoneos') are installed."""
    return _sdk(sdk) is not None


def _block_end(text: str, start: int) -> int:
    """Index just past the brace that closes the first '{' at or after start (skips strings and comments)."""
    depth, i, n = 0, text.index("{", start), len(text)
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            i = text.index("\n", i)
            continue
        if text.startswith("/*", i):
            i = text.index("*/", i) + 2
            continue
        if c == '"':
            i += 1
            while text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("unbalanced braces")


def extract(path: Path, header: str, public: bool = True, nth: int = 0) -> str:
    """Return the declaration whose first line matches the regex `header` (anchored at line start, after indentation).

    nth picks a later match when a declaration occurs more than once. With public=True, a leading `private ` is
    dropped so the harness can call the copy.
    """
    text = Path(path).read_text()
    found = list(re.finditer(r"^[ \t]*" + header, text, re.M))
    if len(found) <= nth:
        raise LookupError(f"{header!r} (match {nth}) not found in {path}")
    m = found[nth]
    code = text[m.start():_block_end(text, m.start())]
    if public:
        code = re.sub(r"^([ \t]*)(?:private|fileprivate) ", r"\1", code, count=1)
    return code


def run(source: str, catalyst: bool = False, timeout: int = 300) -> str:
    """Compile one Swift file (macOS, or Mac Catalyst for UIKit) and return its stdout."""
    sdk = _sdk("macosx")
    if sdk is None:
        raise RuntimeError("xcrun / macOS SDK not available")
    with tempfile.TemporaryDirectory() as d:
        src, exe = Path(d) / "main.swift", Path(d) / "harness"
        src.write_text(source)
        cmd = ["xcrun", "swiftc", "-O", "-sdk", sdk, str(src), "-o", str(exe)]
        if catalyst:
            ios = f"{sdk}/System/iOSSupport"
            cmd += ["-target", f"{platform.machine()}-apple-ios17.0-macabi",
                    "-Fsystem", f"{ios}/System/Library/Frameworks", "-I", f"{ios}/usr/lib/swift",
                    "-L", f"{ios}/usr/lib/swift"]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if r.returncode:
            raise RuntimeError("swiftc failed:\n" + r.stderr[-3000:])
        r = subprocess.run([str(exe)], capture_output=True, text=True, timeout=timeout, cwd=d)
        if r.returncode:
            raise RuntimeError("harness failed:\n" + r.stderr[-3000:])
        return r.stdout


def typecheck_ios(files: list[Path], ios: str) -> list[str]:
    """Type-check the app's Swift files against the iOS SDK for deployment target `ios`; return the error lines."""
    sdk = _sdk("iphoneos")
    if sdk is None:
        raise RuntimeError("iOS SDK not available")
    cmd = ["xcrun", "swiftc", "-typecheck", "-sdk", sdk, "-target", f"arm64-apple-ios{ios}", *map(str, files)]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    return [ln for ln in (r.stdout + r.stderr).splitlines() if ": error:" in ln]
