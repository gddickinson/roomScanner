// Canvas drawing of a floor plan, following MappingFloorPlanView.swift (grid, walls with corner dots, doors, windows,
// rotated objects with a "front" line, legend colours). Geometry comes from room_engine.js. Drawn without the phone
// marker and trail: an exported file has no camera positions.
import * as R from './room_engine.js';

export const COLORS = { wall: '#30d158', corner: '#ffd60a', door: '#ac8e68', window: '#64d2ff', object: '#ff9f0a', grid: 'rgba(255,255,255,.1)' };

export function drawPlan(ctx, W, H, room) {
  ctx.save();
  ctx.fillStyle = 'rgba(0,0,0,.9)'; ctx.fillRect(0, 0, W, H);
  if (!room.walls.length) {
    ctx.fillStyle = '#fff'; ctx.font = '13px system-ui'; ctx.textAlign = 'center'; ctx.fillText('No walls', W / 2, H / 2);
    ctx.restore(); return null;
  }
  const b = R.calculateBounds(room.walls), s = R.calculateScale(b, W, H), [ox, oy] = R.calculateOffset(b, W, H, s);
  const X = x => ox + x * s, Y = z => oy + z * s;
  // 1 m grid, starting at the canvas corner as in drawGrid
  ctx.strokeStyle = COLORS.grid; ctx.lineWidth = 0.5; ctx.beginPath();
  for (let x = 0; x < W; x += s) { ctx.moveTo(x, 0); ctx.lineTo(x, H); }
  for (let y = 0; y < H; y += s) { ctx.moveTo(0, y); ctx.lineTo(W, y); }
  ctx.stroke();
  for (const w of room.walls) {
    const [[x1, z1], [x2, z2]] = R.wallEndpoints(w);
    ctx.strokeStyle = COLORS.wall; ctx.lineWidth = 6; ctx.beginPath(); ctx.moveTo(X(x1), Y(z1)); ctx.lineTo(X(x2), Y(z2)); ctx.stroke();
    ctx.fillStyle = COLORS.corner;
    for (const [x, z] of [[x1, z1], [x2, z2]]) { ctx.beginPath(); ctx.arc(X(x), Y(z), 5, 0, 2 * Math.PI); ctx.fill(); }
  }
  for (const d of room.doors || []) { // axis-aligned 6-px bar, as drawDoors does
    const p = d.transform[3], hw = d.dims[0] / 2 * s;
    ctx.fillStyle = COLORS.door; ctx.globalAlpha = 0.8; ctx.beginPath(); ctx.roundRect(X(p[0]) - hw, Y(p[2]) - 3, hw * 2, 6, 2); ctx.fill(); ctx.globalAlpha = 1;
  }
  for (const wn of room.windows || []) {
    const p = wn.transform[3], hw = wn.dims[0] / 2 * s;
    ctx.fillStyle = COLORS.window; ctx.globalAlpha = 0.6; ctx.fillRect(X(p[0]) - hw, Y(p[2]) - 3, hw * 2, 6); ctx.globalAlpha = 1;
    ctx.strokeStyle = COLORS.window; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(X(p[0]) - hw, Y(p[2])); ctx.lineTo(X(p[0]) + hw, Y(p[2])); ctx.stroke();
  }
  for (const o of room.objects || []) {
    const p = o.transform[3], hw = o.dims[0] / 2 * s, hd = o.dims[2] / 2 * s;
    ctx.save(); ctx.translate(X(p[0]), Y(p[2])); ctx.rotate(R.yawOf(o.transform));
    ctx.beginPath(); ctx.roundRect(-hw, -hd, hw * 2, hd * 2, 3);
    ctx.fillStyle = 'rgba(255,159,10,.4)'; ctx.fill(); ctx.strokeStyle = COLORS.object; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.lineWidth = 2; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(0, -hd * 1.3); ctx.stroke();
    ctx.rotate(-R.yawOf(o.transform)); ctx.fillStyle = '#fff'; ctx.font = '11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(o.category || '', 0, 4);
    ctx.restore();
  }
  ctx.restore();
  return { bounds: b, scale: s, offset: [ox, oy] };
}
