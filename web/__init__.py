"""Web interface (showcase + code explorer) for the RoomScanner iOS app.

Contents:
- app.py         FastAPI app: front end in static/ and the JSON API (/api/info, /api/tree, /api/source)
- repo_index.py  reads the app's own files: languages, line counts, header summaries, Swift outline
- project.py     title, description, port and the web-interface files left out of the explorer
- static/        ES-module front end (home, code explorer, how it works, floor-plan lab, about) and the JS geometry port
"""
