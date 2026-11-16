"""FastAPI web app for the RoomScanner showcase: serves the front end in static/ and the JSON API under /api.

Run with `python run_web.py` (http://127.0.0.1:8266, local only). `scripts/build_static.py` exports every path in
STATIC_ENDPOINTS to JSON for the GitHub Pages site, so keep that list in step with the GET routes below.
The iOS app itself cannot run in a browser: the API serves its source files, and the export and floor-plan geometry run as a JS port.
"""
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from . import repo_index
from .project import DESCRIPTION, REPO, ROOT, TITLE

STATIC = ROOT / "web" / "static"

app = FastAPI(title=TITLE)
app.mount("/static", StaticFiles(directory=STATIC), name="static")


@app.get("/", include_in_schema=False)
def index():
    return FileResponse(STATIC / "index.html")


@app.get("/api/info")
def info():
    """Project summary and real counts for the home page."""
    return {"title": TITLE, "repo": REPO, "description": DESCRIPTION, **repo_index.counts()}


@app.get("/api/tree")
def tree():
    """Every app file with language, line count, header summary and (Swift) outline."""
    return repo_index.tree()


@app.get("/api/source")
def source():
    """Full text of every app file (small repo), for the source viewer, search and the citation links."""
    return repo_index.sources()


# GET paths (without the /api prefix) written to the static site as api/<path>.json.
STATIC_ENDPOINTS = ["/info", "/tree", "/source"]
