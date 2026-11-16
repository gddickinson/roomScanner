"""Checks on the iOS app's Swift code that can run on a Mac with Xcode (skipped elsewhere, e.g. on Linux CI).

- the whole app type-checks against the iOS SDK at its deployment target (catches build breaks);
- regression test for the exported room dimensions, run on the real Swift functions with RoomPlan stand-ins
  (scripts/make_swift_fixture.py, scripts/swift_ref.py);
- tests/fixtures/swift_reference.json (used by the JS port's node test) is still what the Swift code produces.

Run: python -m pytest -q tests/test_swift.py
"""
import json
import math
import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import swift_ref  # noqa: E402

IOS_TARGET = "17.0"  # lowest deployment target the code compiles for (CapturedRoom.floors)
needs_mac = pytest.mark.skipif(not swift_ref.available("macosx"), reason="needs macOS with Xcode")
needs_ios = pytest.mark.skipif(not swift_ref.available("iphoneos"), reason="needs Xcode with the iOS SDK")


@pytest.fixture(scope="module")
def swift_out():
    import make_swift_fixture
    return make_swift_fixture.generate()


@needs_ios
def test_app_typechecks_for_ios():
    errors = swift_ref.typecheck_ios(sorted(ROOT.glob("*.swift")), IOS_TARGET)
    assert errors == [], "\n".join(errors)


@needs_mac
def test_exported_dimensions_account_for_wall_rotation(swift_out):
    """A 4 x 6 m room must export width 4 and length 6 (walls along z were counted as 'width' along x: 10 m)."""
    d = [e["dimensions"] for e in swift_out["exports"]]
    assert math.isclose(d[0]["width"], 4, abs_tol=1e-4) and math.isclose(d[0]["length"], 6, abs_tol=1e-4)
    assert math.isclose(d[0]["height"], 2.5, abs_tol=1e-4)
    # turned rooms report their extent along the world x / z axes
    c, s = math.cos(math.radians(30)), math.sin(math.radians(30))
    assert math.isclose(d[1]["width"], 4 * c + 6 * s, abs_tol=1e-4)
    assert math.isclose(d[1]["length"], 4 * s + 6 * c, abs_tol=1e-4)
    assert math.isclose(d[2]["width"], 3.2 * math.sqrt(2), abs_tol=1e-4)
    # the floor-plan bounds (fit-to-screen) use the same extents, plus 0.5 m padding
    b = swift_out["plans"][0]["bounds"]
    assert all(math.isclose(a, e, abs_tol=1e-4) for a, e in zip(b, [-2.5, 2.5, -3.5, 3.5]))


def _close(a, b):
    if isinstance(a, list):
        return isinstance(b, list) and len(a) == len(b) and all(_close(x, y) for x, y in zip(a, b))
    if isinstance(a, dict):
        return isinstance(b, dict) and a.keys() == b.keys() and all(_close(a[k], b[k]) for k in a)
    if isinstance(a, float) or isinstance(b, float):
        return math.isclose(a, b, rel_tol=1e-6, abs_tol=1e-6)
    return a == b


@needs_mac
@pytest.mark.skipif(bool(os.environ.get("CI")), reason="fixture is regenerated on George's Mac only")
def test_fixture_is_current(swift_out):
    fixture = json.loads((ROOT / "tests" / "fixtures" / "swift_reference.json").read_text())
    assert _close(swift_out, fixture), "run: python scripts/make_swift_fixture.py"


def test_close_helper():
    assert _close({"a": [1.0, "x"]}, {"a": [1.0 + 1e-9, "x"]}) and not _close([1.0], [1.1])
