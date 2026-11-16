"""Run the app's export and floor-plan geometry on test rooms and save the results as a JSON fixture.

RoomPlan only exists on iOS, so the harness defines small stand-ins for CapturedRoom, CapturedRoom.Surface and
CapturedRoom.Object (identifier, transform, dimensions, category, confidence: the fields the code reads) and copies
the real functions verbatim out of ScanManager.swift, MappingFloorPlanView.swift and Models.swift
(scripts/swift_ref.py). It runs them on macOS on the TEST_ROOMS below (test inputs you can rebuild in the Floor-plan
lab, not scans). web/static/room_engine.test.mjs checks the JS port against tests/fixtures/swift_reference.json.

Run (macOS with Xcode): python scripts/make_swift_fixture.py
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import swift_ref  # noqa: E402

FIXTURE = ROOT / "tests" / "fixtures" / "swift_reference.json"


def yaw_matrix(yaw, x, y, z):
    """Column-major 4x4 (as simd_float4x4 columns): rotation by yaw about +y, then translation."""
    c, s = math.cos(yaw), math.sin(yaw)
    return [[c, 0, -s, 0], [0, 1, 0, 0], [s, 0, c, 0], [x, y, z, 1]]


def rect_room(w, l, h, turn=0.0, cx=0.0, cz=0.0):
    """Four walls of a w x l room (x by z), height h, rotated by `turn` about the room centre (cx, cz)."""
    c, s = math.cos(turn), math.sin(turn)
    walls = []
    for (px, pz, yaw, width) in [(0, -l / 2, 0, w), (0, l / 2, math.pi, w), (w / 2, 0, -math.pi / 2, l),
                                 (-w / 2, 0, math.pi / 2, l)]:
        x, z = cx + c * px + s * pz, cz - s * px + c * pz
        walls.append({"transform": yaw_matrix(yaw + turn, x, h / 2, z), "dims": [width, h, 0]})
    return walls


TEST_ROOMS = [
    {"name": "4 x 6 m, axis-aligned", "walls": rect_room(4, 6, 2.5),
     "doors": [{"transform": yaw_matrix(math.pi, 0.5, 1.0, 3), "dims": [0.9, 2.0, 0]}],
     "windows": [{"transform": yaw_matrix(-math.pi / 2, 2, 1.5, -1), "dims": [1.2, 1.0, 0]}],
     "objects": [{"transform": yaw_matrix(math.radians(30), -0.5, 0.375, 1), "dims": [1.5, 0.75, 0.8],
                  "category": "table", "confidence": "high"}]},
    {"name": "4 x 6 m, turned 30 degrees", "walls": rect_room(4, 6, 2.5, math.radians(30), 1.0, -0.5),
     "doors": [], "windows": [], "objects": []},
    {"name": "3.2 x 3.2 m, turned 45 degrees", "walls": rect_room(3.2, 3.2, 2.4, math.radians(45)),
     "doors": [], "windows": [], "objects": [{"transform": yaw_matrix(0, 0, 0.45, 0), "dims": [2.0, 0.9, 0.8],
                                               "category": "sofa", "confidence": "medium"}]},
]
HEADINGS = [0.0, 10.0, 22.4, 22.5, 67.5, 180.0, 337.4, 337.5, 359.9]


def _surfaces(items, obj=False):
    out = []
    for i, it in enumerate(items):
        cols = ", ".join("SIMD4<Float>(" + ", ".join(f"{v!r}" for v in col) + ")" for col in it["transform"])
        extra = f", category: .{it['category']}, confidence: .{it['confidence']}" if obj else ""
        kind = "CapturedRoom.Object" if obj else "CapturedRoom.Surface"
        out.append(f'{kind}(identifier: UUID(uuidString: "00000000-0000-0000-0000-{i:012d}")!, '
                   f"transform: simd_float4x4({cols}), dimensions: SIMD3<Float>({', '.join(map(repr, it['dims']))}){extra})")
    return "[" + ", ".join(out) + "]"


def build_source() -> str:
    sm, fp, mo = ROOT / "ScanManager.swift", ROOT / "MappingFloorPlanView.swift", ROOT / "Models.swift"
    helper = ""
    try:
        helper = swift_ref.extract(mo, r"func surfaceHalfExtents")
    except LookupError:
        pass  # before the 2026-11-16 fix there was no helper
    funcs = "\n".join(swift_ref.extract(sm, rf"private func {n}") for n in
                      ["calculateDimensions", "createWallDict", "createDoorDict", "createWindowDict", "createObjectDict"])
    export = swift_ref.extract(sm, r"func exportToJSON")
    view = "\n".join(swift_ref.extract(fp, rf"private func {n}") for n in
                     ["compassDirection", "calculateBounds", "calculateScale", "calculateOffset"])
    rooms = ",\n".join(f"CapturedRoom(walls: {_surfaces(r['walls'])}, doors: {_surfaces(r['doors'])}, "
                       f"windows: {_surfaces(r['windows'])}, objects: {_surfaces(r['objects'], True)})" for r in TEST_ROOMS)
    return f"""
import Foundation
import CoreGraphics
import simd
typealias CLLocationDirection = Double

struct CapturedRoom {{
    struct Surface {{ let identifier: UUID; let transform: simd_float4x4; let dimensions: simd_float3 }}
    struct Object {{
        enum Category {{ case table, sofa, chair, bed, storage }}
        enum ConfidenceLevel {{ case high, medium, low }}
        let identifier: UUID; let transform: simd_float4x4; let dimensions: simd_float3
        let category: Category; let confidence: ConfidenceLevel
    }}
    let walls: [Surface]; let doors: [Surface]; let windows: [Surface]; let objects: [Object]
}}
{helper}
struct Exporter {{
{funcs}
{export}
}}
struct FloorPlan {{
{view}
}}

let rooms: [CapturedRoom] = [
{rooms}
]
var out: [String: Any] = [:]
out["exports"] = rooms.map {{ r -> Any in try! JSONSerialization.jsonObject(with: try! Exporter().exportToJSON(capturedRoom: r)) }}
out["plans"] = rooms.map {{ r -> [String: Any] in
    let b = FloorPlan().calculateBounds(room: r, history: [])
    var res: [String: Any] = ["bounds": [b.minX, b.maxX, b.minZ, b.maxZ]]
    for (w, h) in [(390.0, 600.0), (800.0, 500.0)] {{
        let size = CGSize(width: w, height: h)
        let s = FloorPlan().calculateScale(bounds: b, canvasSize: size)
        let o = FloorPlan().calculateOffset(bounds: b, canvasSize: size, scale: s)
        res["\\(Int(w))x\\(Int(h))"] = [Double(s), Double(o.x), Double(o.y)]
    }}
    return res
}}
out["compass"] = {json.dumps(HEADINGS)}.map {{ [$0, FloorPlan().compassDirection($0)] as [Any] }}
let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
print(String(data: data, encoding: .utf8)!)
"""


def generate() -> dict:
    data = json.loads(swift_ref.run(build_source()))
    data["rooms"] = TEST_ROOMS
    return data


def main():
    data = generate()
    FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    FIXTURE.write_text(json.dumps(data, indent=1) + "\n")
    print(f"wrote {FIXTURE.relative_to(ROOT)}: {len(data['exports'])} rooms")


if __name__ == "__main__":
    main()
