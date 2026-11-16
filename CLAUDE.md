# RoomScanner

iOS SwiftUI/RoomPlan app (Swift files at the repo root) with a web showcase in `web/`.
@INTERFACE.md

- Web tests: `python -m pytest -q tests` and `node web/static/*.test.mjs`. Swift checks need macOS + Xcode.
- After changing export or floor-plan geometry in Swift, run `python scripts/make_swift_fixture.py` and update
  `web/static/room_engine.js`.
