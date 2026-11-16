# Session log

## 2026-11-16: web showcase (branch web-interface)
- Added a web showcase + code explorer (FastAPI app on port 8266, static GitHub Pages export): home with real counts,
  code explorer (Swift highlighter, outline, search), "How it works" with an SVG data-flow diagram and source links,
  Floor-plan lab (JS port of the export writer and floor-plan geometry; test-room builder; opens exported JSON), About.
- The JS port is checked against the original Swift functions, copied verbatim from ScanManager.swift,
  MappingFloorPlanView.swift and Models.swift and run on this Mac with stand-in RoomPlan types (429 numbers match).
- Fixed: exported `dimensions` (and both floor-plan fits) ignored wall rotation; a 4 x 6 m room exported 10 m wide.
  New `surfaceHalfExtents` in Models.swift. Regression test runs the real Swift.
- Docs: README lists all 8 Swift files, says Info.plist and room_scan_loader.py are not in the repo, iOS 17.
- For George: (1) the floor plan's "You" marker/trail is the mean of the wall centres, not the phone (could use
  `session.arSession.currentFrame?.camera.transform`); (2) doors/windows are drawn as horizontal bars even on walls
  running along z; (3) rotated rooms now export their world-axis extent; side lengths would need the room frame
  (e.g. the longest wall's direction); (4) the .usd and .usdz exports are the same call with different extensions
  (not checked on a device what the .usd file contains); (5) FloorPlanPreview.swift is unused.
