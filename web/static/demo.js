// Floor-plan lab: build a test room (or load a JSON file exported by the app), see the app's floor-plan geometry and
// the JSON its export writer produces. Both are JS ports checked against the Swift code (room_engine.test.mjs).
import { route, app, esc, list, slider, download } from './core.js';
import * as R from './room_engine.js';
import { drawPlan, COLORS } from './plan_draw.js';
import { cite, resolveCites } from './cite.js';

const W = 640, H = 460;
const CATS = ['table', 'sofa', 'chair', 'bed', 'storage', 'refrigerator', 'stove', 'sink', 'television'];
const fmt = v => (+v).toFixed(2);

route('demo', async () => {
  // Starting room = the first test room of scripts/make_swift_fixture.py (test inputs, not a scan).
  const st = { w: 4, l: 6, h: 2.5, turn: 0,
    doors: [{ x: 0.5, z: 3, width: 0.9 }], windows: [{ x: 2, z: -1, width: 1.2 }],
    objects: [{ category: 'table', x: -0.5, z: 1, width: 1.5, depth: 0.8, height: 0.75, yaw: 30 }], loaded: null };
  app().innerHTML = `<p class="kicker">Interactive port</p><h1>Floor-plan lab</h1>
  <p class="lead">RoomPlan turns a LiDAR scan into walls, doors, windows and objects, each a box with a 4 × 4 transform.
  Build a test room here (or open a <code>.json</code> file exported by the app) and see the floor plan the app draws
  and the JSON its export writer produces, using the app's geometry ported from Swift.</p>
  <div class="lab">
    <div><div class="stage"><canvas id="plan" width="${W * 2}" height="${H * 2}" role="img" aria-label="Floor plan of the room"></canvas></div>
      <p class="small">${list([['Walls', COLORS.wall], ['Corners', COLORS.corner], ['Doors', COLORS.door], ['Windows', COLORS.window], ['Objects', COLORS.object]],
        ([t, c]) => `<span class="dot" style="background:${c}"></span>${t}`, ' &nbsp; ')}</p>
      <div class="panel"><h3>Room dimensions in the export</h3><div id="dims"></div></div></div>
    <div>
      <div class="panel" id="ctl"><h3>Test room (you set these)</h3></div>
      <div class="panel"><h3>Openings and objects</h3><div id="items"></div>
        <form id="addobj" class="row"><div><label for="oc">Object</label><select id="oc">${list(CATS, c => `<option>${c}</option>`)}</select></div>
          <div><label for="ox">x m</label><input id="ox" type="number" step="0.1" value="1"></div>
          <div><label for="oz">z m</label><input id="oz" type="number" step="0.1" value="-1.5"></div>
          <div><label for="oy">yaw °</label><input id="oy" type="number" step="5" value="0"></div>
          <div><button type="submit">Add</button></div></form>
      </div>
      <div class="panel"><h3>Open an exported scan</h3>
        <label for="file">JSON file from the app's "JSON (Custom)" export</label><input id="file" type="file" accept=".json,application/json">
        <p class="small mute" id="fileinfo">Read in your browser only; nothing is uploaded.</p></div>
    </div>
  </div>
  <div class="panel"><h3>Export (JSON)</h3>
    <p class="small mute">As written by ${cite('ScanManager.swift', 'func exportToJSON')}: numbers are 32-bit floats, wall "matrix" rows are the
    transform's columns, ids are random UUIDs in the app (placeholders here), and key order varies in the app's files.</p>
    <button class="alt" id="dl" type="button">Download JSON</button><pre id="json" class="jsonout"></pre></div>`;

  const canvas = app().querySelector('#plan'), ctx = canvas.getContext('2d'); ctx.scale(2, 2);
  const build = () => {
    if (st.loaded) return st.loaded;
    const t = st.turn * Math.PI / 180, c = Math.cos(t), s = Math.sin(t);
    const place = (x, z) => [c * x + s * z, -s * x + c * z];
    const box = (it, y, dims, yaw = 0) => { const [x, z] = place(it.x, it.z); return { transform: R.yawMatrix(yaw * Math.PI / 180 + t, x, y, z), dims }; };
    return { walls: R.rectRoom(st.w, st.l, st.h, t),
      doors: st.doors.map(d => box(d, 1.0, [d.width, 2.0, 0])), windows: st.windows.map(d => box(d, 1.5, [d.width, 1.0, 0])),
      objects: st.objects.map(o => ({ ...box(o, o.height / 2, [o.width, o.height, o.depth], o.yaw), category: o.category, confidence: 'high' })) };
  };
  let lastExport = null;
  const draw = () => {
    const room = build();
    drawPlan(ctx, W, H, room);
    const now = R.calculateDimensions(room.walls), before = R.calculateDimensionsBefore(room.walls);
    app().querySelector('#dims').innerHTML = `<table class="small"><thead><tr><th></th><th>width (x)</th><th>length (z)</th><th>height (y)</th></tr></thead><tbody>
      <tr><td>App (fixed 2026-11-16)</td><td>${fmt(now[0])} m</td><td>${fmt(now[2])} m</td><td>${fmt(now[1])} m</td></tr>
      <tr><td class="mute">Before the fix</td><td class="mute">${fmt(before[0])} m</td><td class="mute">${fmt(before[2])} m</td><td class="mute">${fmt(before[1])} m</td></tr></tbody></table>
      <p class="small mute">Extents along the world x and z axes (${cite('Models.swift', 'func surfaceHalfExtents')}); a room turned
      against those axes reports its bounding box, not its side lengths.</p>`;
    lastExport = st.loadedJSON || R.exportRoom(room, (k, i) => `${k.toUpperCase()}-${i + 1}`);
    app().querySelector('#json').textContent = R.prettyJSON(lastExport);
    app().querySelector('#items').innerHTML = st.loaded ? '<p class="small mute">Showing the opened file.</p>' : `<table class="small"><tbody>${
      list(st.doors, d => `<tr><td>door</td><td>x ${d.x}, z ${d.z}, ${d.width} m wide</td><td></td></tr>`)}${
      list(st.windows, d => `<tr><td>window</td><td>x ${d.x}, z ${d.z}, ${d.width} m wide</td><td></td></tr>`)}${
      list(st.objects, (o, i) => `<tr><td>${esc(o.category)}</td><td>x ${o.x}, z ${o.z}, ${o.width} × ${o.depth} m, yaw ${o.yaw}°</td>
        <td><button class="alt mini" data-del="${i}" aria-label="Remove ${esc(o.category)}">×</button></td></tr>`)}</tbody></table>`;
    resolveCites(app());
  };
  const ctl = app().querySelector('#ctl');
  const reset = () => { st.loaded = null; st.loadedJSON = null; app().querySelector('#fileinfo').textContent = 'Read in your browser only; nothing is uploaded.'; };
  slider(ctl, { id: 'w', label: 'Width (x)', min: 2, max: 10, step: 0.1, value: st.w, unit: ' m' }, v => { st.w = v; reset(); draw(); });
  slider(ctl, { id: 'l', label: 'Length (z)', min: 2, max: 10, step: 0.1, value: st.l, unit: ' m' }, v => { st.l = v; reset(); draw(); });
  slider(ctl, { id: 'h', label: 'Height', min: 2, max: 4, step: 0.1, value: st.h, unit: ' m' }, v => { st.h = v; reset(); draw(); });
  slider(ctl, { id: 't', label: 'Turn against the world axes', min: 0, max: 90, value: 0, unit: '°' }, v => { st.turn = v; reset(); draw(); });
  app().querySelector('#items').addEventListener('click', e => {
    if (e.target.dataset.del !== undefined) { st.objects.splice(+e.target.dataset.del, 1); draw(); }
  });
  app().querySelector('#addobj').addEventListener('submit', e => {
    e.preventDefault(); reset();
    const v = id => +app().querySelector(id).value;
    st.objects.push({ category: app().querySelector('#oc').value, x: v('#ox'), z: v('#oz'), width: 1, depth: 0.6, height: 0.8, yaw: v('#oy') });
    draw();
  });
  app().querySelector('#file').addEventListener('change', async e => {
    const file = e.target.files[0]; if (!file) return;
    const info = app().querySelector('#fileinfo');
    try {
      const j = JSON.parse(await file.text());
      if (!Array.isArray(j.walls)) throw new Error('no "walls" list: not a RoomScanner JSON export');
      st.loaded = R.roomFromExport(j); st.loadedJSON = j;
      info.textContent = `${file.name}: ${j.walls.length} walls, ${(j.doors || []).length} doors, ${(j.windows || []).length} windows, ${(j.objects || []).length} objects. Move a slider to go back to the test room.`;
      draw();
    } catch (err) { info.textContent = `Could not read ${file.name}: ${err.message}`; }
  });
  app().querySelector('#dl').addEventListener('click', () => download('room_scan.json', R.prettyJSON(lastExport), 'application/json'));
  draw();
  await resolveCites(app());
});
