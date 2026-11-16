"""Project constants for the web interface (title, description from the README/GitHub, port, files to leave out)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TITLE = "RoomScanner"
REPO = "roomScanner"
PORT = 8266
DESCRIPTION = ("A native iOS app for scanning rooms using iPhone's LiDAR sensor and exporting 3D data for Python "
               "analysis.")
# Web-interface files (not part of the iOS app) left out of the code explorer: top-level names or relative paths.
EXCLUDE = {"web", "scripts", "tests", "docs", "site", "run_web.py", "requirements-web.txt", "INTERFACE.md",
           "SESSION_LOG.md", "CLAUDE.md"}
