"""Web interface tests: every exported endpoint answers, the static build is complete, and the JS engine tests pass.

Run: python -m pytest -q tests/test_web.py
"""
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from web.app import STATIC, STATIC_ENDPOINTS, app  # noqa: E402

client = TestClient(app)


def test_index_served():
    r = client.get("/")
    assert r.status_code == 200 and "static/main.js" in r.text


@pytest.mark.parametrize("path", STATIC_ENDPOINTS)
def test_endpoint(path):
    r = client.get("/api" + path)
    assert r.status_code == 200, r.text
    assert r.json() is not None


def test_static_build(tmp_path):
    sys.path.insert(0, str(ROOT / "scripts"))
    import build_static
    build_static.build(tmp_path / "site")
    assert (tmp_path / "site" / "index.html").read_text().count("APP_STATIC") == 1
    for path in STATIC_ENDPOINTS:
        assert (tmp_path / "site" / "api" / (path.strip("/") + ".json")).exists()


def test_static_assets_referenced_exist():
    html = (STATIC / "index.html").read_text()
    for name in ("style.css", "main.js"):
        assert f"static/{name}" in html and (STATIC / name).exists()


@pytest.mark.skipif(not shutil.which("node"), reason="node not installed")
def test_js_engine():
    tests = sorted(STATIC.glob("*.test.mjs"))
    for t in tests:
        r = subprocess.run(["node", str(t)], capture_output=True, text=True)
        assert r.returncode == 0, r.stdout + r.stderr


# --- showcase-specific checks ----------------------------------------------------------------------------------------
import re  # noqa: E402

CITE = re.compile(r"\b(?:c|cite)\('([^']+)',\s*'((?:[^'\\]|\\.)*)'\)")


def _cites():
    for js in sorted(STATIC.glob("*.js")):
        for f, q in CITE.findall(js.read_text()):
            yield js.name, f, q.replace("\\\\", "\\").replace("\\'", "'")


def test_every_citation_is_in_its_source_file():
    src = client.get("/api/source").json()
    found = list(_cites())
    assert len(found) >= 10
    for page, f, q in found:
        assert f in src, f"{page}: no file {f}"
        assert q in src[f], f"{page}: {q!r} not found in {f}"


def test_tree_lists_only_app_files_with_real_counts():
    tree = client.get("/api/tree").json()
    paths = {f["path"] for f in tree}
    swift = sorted(p.name for p in ROOT.glob("*.swift"))
    assert sorted(p for p in paths if p.endswith(".swift")) == swift
    assert not any(p.startswith(("web/", "tests/", "scripts/")) for p in paths)
    info = client.get("/api/info").json()
    assert info["swift_files"] == len(swift)
    assert info["swift_lines"] == sum(len((ROOT / s).read_text().splitlines()) for s in swift)
    for f in tree:
        if f["lang"] == "Swift":
            assert f["summary"], f"{f['path']} has no header summary"
            assert all(o["line"] >= 1 for o in f["outline"])


def test_source_matches_files():
    src = client.get("/api/source").json()
    for path, text in src.items():
        assert (ROOT / path).read_text(errors="replace") == text
