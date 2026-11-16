# RoomScanner: navigation map

An iOS (SwiftUI + RoomPlan) app, plus a Python/JS web showcase. The Swift files sit at the repository root; they are
added to an Xcode project by hand (there is no .xcodeproj or Info.plist in the repo).

## iOS app (Swift, repo root)
| File | Contents |
|------|----------|
| RoomScannerApp.swift | `@main RoomScannerApp`: ContentView with a shared ScanManager environment object |
| ContentView.swift | `ContentView` (scan list), `ScanRow`, `ScanDetailView` (export/share/delete), `ShareSheet` |
| ScanningView.swift | `ScanningView` (3D / floor-plan modes, start/done, save dialog), `StatBadge`, `LocationManager` (compass), `RoomCaptureController` (RoomCaptureSession delegate, estimated position + history), `SaveScanView` |
| ScanManager.swift | `ScanManager`: addScan/deleteScan, saveRoomData (USD, USDZ, JSON), exportToJSON + calculateDimensions + create*Dict, persistence in UserDefaults |
| Models.swift | `RoomScan`, `ExportFormat`, `exportFormats`, `surfaceHalfExtents` (box extent along world axes) |
| MappingFloorPlanView.swift | live 2D floor plan: bounds/scale/offset, grid, trail, walls, doors, windows, objects, phone marker; `LegendItem` |
| RoomVisualization3DView.swift | `RoomScene3DManager` (SceneKit nodes per surface/object), `RoomVisualization3DView`, `Room3DVisualizationView` |
| FloorPlanPreview.swift | earlier 2D preview (not used by the current screens) |

## Web showcase (Python + plain ES modules)
| Path | Contents |
|------|----------|
| run_web.py | starts uvicorn on 127.0.0.1:8266 |
| web/app.py | FastAPI: `/api/info`, `/api/tree`, `/api/source`; `STATIC_ENDPOINTS` |
| web/repo_index.py | `app_files`, `summary`, `outline`, `tree`, `sources`, `counts` (reads the Swift files) |
| web/project.py | title, description, port, EXCLUDE (web files left out of the explorer) |
| web/static/core.js, style.css | shared kit (router, api, helpers; theme) |
| web/static/main.js, static_api.js, site.js | entry, static-site data layer, repo-specific home text |
| web/static/home.js, code.js, how.js, demo.js, about.js | pages |
| web/static/swift_highlight.js (+ .test.mjs) | Swift / plist / Markdown highlighter |
| web/static/cite.js | `cite(file, needle)` links resolved to live line numbers |
| web/static/room_engine.js (+ .test.mjs) | JS port: surfaceHalfExtents, calculateDimensions, export dicts, bounds/scale/offset, wall endpoints, compass; test-room builder; reading an exported JSON |
| web/static/plan_draw.js | canvas floor plan following MappingFloorPlanView |
| scripts/swift_ref.py | extract Swift declarations verbatim, compile/run them on macOS, type-check for iOS |
| scripts/make_swift_fixture.py | runs the real Swift export/plan code on test rooms (RoomPlan stand-ins) -> tests/fixtures/swift_reference.json |
| scripts/build_static.py, screenshots.py | static site export; smoke test + README images |
| tests/test_web.py | API, static build, citations, node tests |
| tests/test_swift.py | iOS type-check, dimensions regression test, fixture currency (macOS + Xcode only) |
