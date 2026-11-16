// How it works: RoomScanner's capture, live views, saving and export, written from the Swift source with line links.
import { route, app } from './core.js';
import { cite as c, resolveCites } from './cite.js';

const DIAGRAM = `<svg class="diagram" viewBox="0 0 760 400" role="img" aria-labelledby="dgt dgd">
<title id="dgt">RoomScanner data flow</title>
<desc id="dgd">RoomCaptureSession updates a CapturedRoom that the 3D and 2D views draw; on save ScanManager writes USD, USDZ and JSON files.</desc>
<defs><marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10z" class="dg-arrow"/></marker></defs>
<g class="dg-box s"><rect x="10" y="20" width="160" height="58" rx="6"/><text x="90" y="44">LiDAR + camera</text><text x="90" y="62" class="dg-sub">RoomCaptureSession</text></g>
<g class="dg-box a"><rect x="230" y="20" width="230" height="100" rx="6"/><text x="345" y="44">RoomCaptureController</text><text x="345" y="66" class="dg-sub">didUpdate → capturedRoom</text><text x="345" y="84" class="dg-sub">"camera" = mean of wall centres</text><text x="345" y="102" class="dg-sub">history every 0.2 s, last 200</text></g>
<g class="dg-box s"><rect x="10" y="150" width="160" height="58" rx="6"/><text x="90" y="174">Compass</text><text x="90" y="192" class="dg-sub">LocationManager</text></g>
<g class="dg-box c"><rect x="530" y="20" width="220" height="80" rx="6"/><text x="640" y="44">Room3DVisualizationView</text><text x="640" y="66" class="dg-sub">SceneKit boxes per surface,</text><text x="640" y="84" class="dg-sub">objects coloured by category</text></g>
<g class="dg-box c"><rect x="530" y="120" width="220" height="80" rx="6"/><text x="640" y="144">MappingFloorPlanView</text><text x="640" y="166" class="dg-sub">Canvas: walls, doors, windows,</text><text x="640" y="184" class="dg-sub">objects, trail, north arrow</text></g>
<g class="dg-box b"><rect x="230" y="230" width="230" height="80" rx="6"/><text x="345" y="254">ScanManager.addScan</text><text x="345" y="276" class="dg-sub">name from SaveScanView,</text><text x="345" y="294" class="dg-sub">files named by a new UUID</text></g>
<g class="dg-box s"><rect x="530" y="220" width="220" height="100" rx="6"/><text x="640" y="244">Documents/&lt;uuid&gt;.usd</text><text x="640" y="266" class="dg-sub">.usdz (CapturedRoom.export)</text><text x="640" y="284" class="dg-sub">.json (exportToJSON)</text><text x="640" y="306" class="dg-sub">list in UserDefaults</text></g>
<g class="dg-box b"><rect x="230" y="340" width="230" height="50" rx="6"/><text x="345" y="362">ContentView / ScanDetailView</text><text x="345" y="380" class="dg-sub">list, share sheet, delete</text></g>
<g class="dg-lines"><path d="M170 49H228" marker-end="url(#ar)"/><path d="M460 60H528" marker-end="url(#ar)"/><path d="M460 100H495V160H528" marker-end="url(#ar)"/>
<path d="M170 179H495" /><path d="M345 120V228" marker-end="url(#ar)"/><path d="M460 270H528" marker-end="url(#ar)"/><path d="M640 320V365H462" marker-end="url(#ar)"/></g></svg>`;

route('how', async () => {
  app().innerHTML = `<p class="kicker">From the source</p><h1>How it works</h1>
  <p class="lead">RoomScanner is a SwiftUI app around Apple's RoomPlan framework. RoomPlan does the hard part (LiDAR
  scanning and recognising walls, doors, windows and furniture); the app shows the result live, saves it and exports
  it. Each statement below links to the line of Swift it comes from.</p>
  ${DIAGRAM}

  <h2>1. Scan list</h2>
  <p>The app creates one <code>ScanManager</code> and passes it down as an environment object
  (${c('RoomScannerApp.swift', '.environmentObject(scanManager)')}). <code>ContentView</code> lists saved scans; + opens
  <code>ScanningView</code> as a sheet and tapping a scan opens <code>ScanDetailView</code> with the export formats
  (${c('ContentView.swift', 'ForEach(exportFormats) { format in')}), each shared through the iOS share sheet if its file exists.
  The list itself is stored as JSON in <code>UserDefaults</code> under "savedScans" (${c('ScanManager.swift', 'private let scansKey = "savedScans"')}).</p>

  <h2>2. Capturing a room</h2>
  <p><code>RoomCaptureController</code> creates a <code>RoomCaptureSession</code> with the default configuration and runs it
  (${c('ScanningView.swift', 'session.run(configuration: config)')}); there is no <code>RoomCaptureView</code>, so the app shows
  its own views rather than Apple's camera overlay. Every <code>didUpdate</code> stores the latest
  <code>CapturedRoom</code> (${c('ScanningView.swift', 'self.capturedRoom = room')}). The counts of walls, doors, windows and
  objects are shown as badges while scanning.</p>
  <p class="callout small">The floor plan's red "You" marker and blue trail are not the phone's position: the controller
  averages the centres of the walls found so far and records that point every 0.2 s, keeping the last 200
  (${c('ScanningView.swift', 'centerX += Float(wall.transform.columns.3.x)')}). Its transform has no rotation, so the
  direction cone does not follow the phone either.</p>

  <h2>3. Live views</h2>
  <ul>
    <li><b>3D</b>: <code>RoomScene3DManager</code> keeps one SceneKit box per wall, floor, door, window and object, keyed by
    RoomPlan's identifier, adding, moving and removing them as the room updates (${c('RoomVisualization3DView.swift', 'node.simdTransform = transform')}).
    Objects are coloured by category (${c('RoomVisualization3DView.swift', 'case .refrigerator:')}). Pinch and drag move the camera.</li>
    <li><b>Floor plan</b>: <code>MappingFloorPlanView</code> fits the walls and trail into 85% of the canvas
    (${c('MappingFloorPlanView.swift', 'return min(scaleX, scaleZ) * 0.85')}), maps world x → screen x and z → screen y, draws each wall
    from its centre ± half its width along the transform's right vector (${c('MappingFloorPlanView.swift', 'let x1 = posX - dirX * halfW')}),
    objects as rectangles turned by atan2(right.z, right.x), doors and windows as unrotated bars, a 1 m grid and a
    north arrow from the compass heading. The <a href="#/demo">Floor-plan lab</a> runs this geometry.</li>
  </ul>

  <h2>4. Saving and the export formats</h2>
  <p>"Done" stops the session and asks for a name; <code>addScan</code> writes three files named by a new UUID into the
  app's Documents folder (${c('ScanManager.swift', 'let fileName = "\\(UUID().uuidString)"')}):</p>
  <ul>
    <li><b>.usd</b> and <b>.usdz</b>: <code>CapturedRoom.export(to:exportOptions: .model)</code>, Apple's parametric room
    model (${c('ScanManager.swift', 'try capturedRoom.export(to: usdzURL, exportOptions: .model)')}). Both calls are the same
    apart from the file extension.</li>
    <li><b>.json</b>: the app's own format (${c('ScanManager.swift', 'func exportToJSON')}): <code>dimensions</code> (width x,
    height y, length z of the walls' extent), <code>walls</code> (id, width/height/thickness, position and the full 4 × 4
    transform as four columns), <code>doors</code>, <code>windows</code> and <code>objects</code> (id, size, position,
    yaw from atan2(right.z, right.x) in radians and degrees; objects also category and confidence). Pretty-printed by
    <code>JSONSerialization</code>; values are 32-bit floats in metres.</li>
  </ul>
  <p>Deleting a scan removes all three files and the list entry (${c('ScanManager.swift', 'for ext in ["usd", "usdz", "json"] {')}).</p>
  <p class="callout">Fixed while building this site (2026-11-16): the exported room <code>dimensions</code> ignored wall
  rotation, so a 4 × 6 m room was exported as 10 m wide; the floor-plan fit had the same error
  (${c('Models.swift', 'func surfaceHalfExtents')}).</p>`;
  await resolveCites(app());
});
