// Room export and floor-plan geometry ported from the app's Swift (no DOM). Each function names its origin.
// room_engine.test.mjs checks it against tests/fixtures/swift_reference.json: the original Swift functions run on a
// Mac on test rooms (scripts/make_swift_fixture.py). Swift uses Float (32-bit): f() rounds like Float does.

export const f = Math.fround;
const col = (m, i) => m[i];                 // matrices are column-major arrays of 4 columns, like simd_float4x4

// Models.swift, surfaceHalfExtents: half-size of a box along world x, y, z.
export function surfaceHalfExtents(m, d) {
  return [0, 1, 2].map(a => f(f(Math.abs(m[0][a]) * f(d[0] / 2)) + f(Math.abs(m[1][a]) * f(d[1] / 2)) + f(Math.abs(m[2][a]) * f(d[2] / 2))));
}

// ScanManager.calculateDimensions -> [width (x), height (y), length (z)].
export function calculateDimensions(walls) {
  if (!walls.length) return [0, 0, 0];
  const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
  for (const w of walls) {
    const p = col(w.transform, 3), h = surfaceHalfExtents(w.transform, w.dims);
    for (let a = 0; a < 3; a++) { lo[a] = Math.min(lo[a], f(f(p[a]) - h[a])); hi[a] = Math.max(hi[a], f(f(p[a]) + h[a])); }
  }
  return [0, 1, 2].map(a => f(hi[a] - lo[a]));
}

// Yaw used for doors, windows and objects: atan2(right.z, right.x) of the transform's first column.
export const yawOf = m => f(Math.atan2(f(m[0][2]), f(m[0][0])));
const pos = m => ({ x: f(m[3][0]), y: f(m[3][1]), z: f(m[3][2]) });
const rot = m => { const r = yawOf(m); return { yaw_radians: r, yaw_degrees: f(f(r * 180) / f(Math.PI)) }; };

// ScanManager.createWallDict / createDoorDict / createWindowDict / createObjectDict and exportToJSON.
// The app writes the same keys; Swift dictionaries have no fixed key order, so the order in its files varies.
export function exportRoom(room, ids = (kind, i) => `${kind}-${i}`) {
  const [width, height, length] = calculateDimensions(room.walls);
  const opening = kind => (s, i) => ({
    id: ids(kind, i),
    dimensions: { width: f(s.dims[0]), height: f(s.dims[1]), depth: f(s.dims[2]) },
    transform: { position: pos(s.transform), rotation: rot(s.transform) },
  });
  return {
    dimensions: { width, height, length },
    walls: room.walls.map((w, i) => ({
      id: ids('wall', i),
      dimensions: { width: f(w.dims[0]), height: f(w.dims[1]), thickness: f(w.dims[2]) },
      transform: { position: pos(w.transform), matrix: w.transform.map(c => c.map(f)) }, // "row" i = column i
    })),
    doors: (room.doors || []).map(opening('door')),
    windows: (room.windows || []).map(opening('window')),
    objects: (room.objects || []).map((o, i) => ({ ...opening('object')(o, i), category: o.category, confidence: o.confidence }))
      .map(({ id, category, dimensions, transform, confidence }) => ({ id, category, dimensions, transform, confidence })),
  };
}

// JSONSerialization .prettyPrinted style: two-space indent and " : " after keys.
export const prettyJSON = obj => JSON.stringify(obj, null, 2).replace(/^(\s*"[^"]*"):/gm, '$1 :');

// MappingFloorPlanView.compassDirection.
export function compassDirection(heading) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[Math.trunc((heading + 22.5) / 45.0) % 8];
}

// MappingFloorPlanView.calculateBounds (walls + position history, 0.5 m padding) -> [minX, maxX, minZ, maxZ].
export function calculateBounds(walls, history = []) {
  let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
  for (const w of walls) {
    const p = col(w.transform, 3), h = surfaceHalfExtents(w.transform, w.dims);
    minX = Math.min(minX, f(f(p[0]) - h[0])); maxX = Math.max(maxX, f(f(p[0]) + h[0]));
    minZ = Math.min(minZ, f(f(p[2]) - h[2])); maxZ = Math.max(maxZ, f(f(p[2]) + h[2]));
  }
  for (const p of history) { minX = Math.min(minX, p[0]); maxX = Math.max(maxX, p[0]); minZ = Math.min(minZ, p[2]); maxZ = Math.max(maxZ, p[2]); }
  const pad = 0.5;
  return [f(minX - pad), f(maxX + pad), f(minZ - pad), f(maxZ + pad)];
}

// MappingFloorPlanView.calculateScale: fit to 85% of the canvas (20 px/m if the room is empty or flat).
export function calculateScale([minX, maxX, minZ, maxZ], w, h) {
  const rw = f(maxX - minX), rd = f(maxZ - minZ);
  if (!(rw > 0.001 && rd > 0.001)) return 20;
  return f(Math.min(f(f(w) / rw), f(f(h) / rd)) * f(0.85));
}

// MappingFloorPlanView.calculateOffset: centre the room; screen = offset + metres * scale (x -> x, z -> y).
export function calculateOffset([minX, maxX, minZ, maxZ], w, h, s) {
  const sw = f(f(maxX - minX) * s), sd = f(f(maxZ - minZ) * s);
  return [f(f(f(f(w) - sw) / 2) - f(minX * s)), f(f(f(f(h) - sd) / 2) - f(minZ * s))];
}

// MappingFloorPlanView.drawWalls: wall end points from the right vector (normalised in x-z) and half width.
export function wallEndpoints(w) {
  const m = w.transform, rx = f(m[0][0]), rz = f(m[0][2]), len = f(Math.sqrt(f(f(rx * rx) + f(rz * rz))));
  const dx = len > 0.001 ? f(rx / len) : 1, dz = len > 0.001 ? f(rz / len) : 0, hw = f(w.dims[0] / 2);
  const px = f(m[3][0]), pz = f(m[3][2]);
  return [[f(px - f(dx * hw)), f(pz - f(dz * hw))], [f(px + f(dx * hw)), f(pz + f(dz * hw))]];
}

// Rebuild the geometry the floor plan needs from the app's exported JSON (walls keep their full matrix; doors,
// windows and objects keep position and yaw, which is all the drawing code uses).
export function roomFromExport(j) {
  const fromYaw = (t, d) => {
    const r = t.rotation ? t.rotation.yaw_radians : 0, c = Math.cos(r), s = Math.sin(r), p = t.position;
    return { transform: [[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [p.x, p.y, p.z, 1]], dims: d };
  };
  return {
    walls: (j.walls || []).map(w => ({ transform: w.transform.matrix, dims: [w.dimensions.width, w.dimensions.height, w.dimensions.thickness] })),
    doors: (j.doors || []).map(o => fromYaw(o.transform, [o.dimensions.width, o.dimensions.height, o.dimensions.depth])),
    windows: (j.windows || []).map(o => fromYaw(o.transform, [o.dimensions.width, o.dimensions.height, o.dimensions.depth])),
    objects: (j.objects || []).map(o => ({ ...fromYaw(o.transform, [o.dimensions.width, o.dimensions.height, o.dimensions.depth]),
      category: o.category, confidence: o.confidence })),
  };
}

// --- building test rooms (the lab's inputs; the same construction as scripts/make_swift_fixture.py) -------------
// Column-major transform: rotation by yaw about +y, then translation (x, y, z).
export function yawMatrix(yaw, x, y, z) {
  const c = Math.cos(yaw), s = Math.sin(yaw);
  return [[c, 0, -s, 0], [0, 1, 0, 0], [s, 0, c, 0], [x, y, z, 1]];
}

// Four walls of a w x l room (x by z), height h, turned by `turn` radians about (cx, cz).
export function rectRoom(w, l, h, turn = 0, cx = 0, cz = 0) {
  const c = Math.cos(turn), s = Math.sin(turn);
  return [[0, -l / 2, 0, w], [0, l / 2, Math.PI, w], [w / 2, 0, -Math.PI / 2, l], [-w / 2, 0, Math.PI / 2, l]]
    .map(([px, pz, yaw, width]) => ({ transform: yawMatrix(yaw + turn, cx + c * px + s * pz, h / 2, cz - s * px + c * pz), dims: [width, h, 0] }));
}

// The pre-2026-11-16 calculateDimensions (half width always along x, half thickness along z), kept to show the bug.
export function calculateDimensionsBefore(walls) {
  if (!walls.length) return [0, 0, 0];
  const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
  for (const w of walls) {
    const p = col(w.transform, 3), h = w.dims.map(v => f(v / 2));
    for (let a = 0; a < 3; a++) { lo[a] = Math.min(lo[a], f(f(p[a]) - h[a])); hi[a] = Math.max(hi[a], f(f(p[a]) + h[a])); }
  }
  return [0, 1, 2].map(a => f(hi[a] - lo[a]));
}
