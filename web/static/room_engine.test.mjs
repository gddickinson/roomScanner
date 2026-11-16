// Node test: the JS export writer and floor-plan geometry against the original Swift functions run on test rooms
// (tests/fixtures/swift_reference.json from scripts/make_swift_fixture.py). Run: node web/static/room_engine.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import * as R from './room_engine.js';

const ref = JSON.parse(readFileSync(new URL('../../tests/fixtures/swift_reference.json', import.meta.url), 'utf8'));
let n = 0;
function same(a, b, path) {
  if (typeof b === 'number') { assert.ok(Math.abs(a - b) <= 1e-6 * Math.max(1, Math.abs(b)), `${path}: ${a} vs ${b}`); n++; return; }
  if (Array.isArray(b)) { assert.equal(a.length, b.length, path); b.forEach((x, i) => same(a[i], x, `${path}[${i}]`)); return; }
  if (b && typeof b === 'object') { assert.deepEqual(Object.keys(a).sort(), Object.keys(b).sort(), path); for (const k in b) same(a[k], b[k], `${path}.${k}`); return; }
  assert.equal(a, b, path);
}
const uuid = (kind, i) => `00000000-0000-0000-0000-${String(i).padStart(12, '0')}`;
ref.rooms.forEach((room, k) => {
  const r = { walls: room.walls.map(w => ({ transform: w.transform, dims: w.dims })), doors: room.doors.map(w => ({ transform: w.transform, dims: w.dims })),
    windows: room.windows.map(w => ({ transform: w.transform, dims: w.dims })),
    objects: room.objects.map(o => ({ transform: o.transform, dims: o.dims, category: o.category, confidence: o.confidence })) };
  same(R.exportRoom(r, uuid), ref.exports[k], `export ${k}`);
  const b = R.calculateBounds(r.walls);
  same(b, ref.plans[k].bounds, `bounds ${k}`);
  for (const [w, h] of [[390, 600], [800, 500]]) {
    const s = R.calculateScale(b, w, h);
    same([s, ...R.calculateOffset(b, w, h, s)], ref.plans[k][`${w}x${h}`], `plan ${k} ${w}x${h}`);
  }
  // Re-reading the export rebuilds the same walls, and objects with the same yaw (the floor plan's inputs).
  const back = R.roomFromExport(JSON.parse(R.prettyJSON(ref.exports[k])));
  same(R.calculateBounds(back.walls), ref.plans[k].bounds, `bounds from export ${k}`);
  back.objects.forEach((o, i) => same(R.yawOf(o.transform), ref.exports[k].objects[i].transform.rotation.yaw_radians, 'yaw'));
});
for (const [h, d] of ref.compass) assert.equal(R.compassDirection(h), d, `compass ${h}`);
// The test rooms in the fixture are the ones rectRoom builds (same construction as the Python generator).
same(R.rectRoom(4, 6, 2.5), ref.rooms[0].walls.map(w => ({ transform: w.transform, dims: w.dims })), 'rectRoom');
// Hand-traced from drawWalls: the north wall of the 4 x 6 room runs from (-2, -3) to (2, -3).
same(R.wallEndpoints(ref.rooms[0].walls[0]), [[-2, -3], [2, -3]], 'endpoints');
assert.ok(R.prettyJSON({ a: 1 }).includes('"a" : 1'));
console.log(`room_engine: ok (${n} numbers from ${ref.rooms.length} test rooms match Swift)`);
// The old formula reproduces the bug the regression test caught: the 4 x 6 m room came out 10 m wide.
assert.deepEqual(R.calculateDimensionsBefore(R.rectRoom(4, 6, 2.5)).map(v => +v.toFixed(4)), [10, 2.5, 6]);
