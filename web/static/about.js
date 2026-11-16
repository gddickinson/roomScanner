// About: what the app is, what you need to build and run it (from the README and the code), and this site.
import { route, app, api, esc, list } from './core.js';
import { cite as c, resolveCites } from './cite.js';

route('about', async () => {
  const info = await api('/info');
  app().innerHTML = `<p class="kicker">About</p><h1>${esc(info.title)}</h1>
  <p class="lead">${esc(info.description)}</p>
  <div class="two">
    <div class="panel"><h3>To run the real app</h3>
      <ul>
        <li>An iPhone or iPad with LiDAR (README: iPhone 12 Pro and later Pro models). RoomPlan does not run in the Simulator.</li>
        <li><b>iOS 17.0 or later</b>: the 3D view uses <code>CapturedRoom.floors</code>
        (${c('RoomVisualization3DView.swift', 'updateFloors(room.floors)')}). The whole app type-checks against the iOS SDK at
        that target (tests/test_swift.py).</li>
        <li>Xcode 15 or later and an Apple developer account for signing.</li>
        <li>Camera permission (<code>NSCameraUsageDescription</code>) and, for the floor plan's compass, location permission
        (<code>NSLocationWhenInUseUsageDescription</code>): the repository has no Info.plist, so add these keys.</li>
      </ul>
      <h3>Build in Xcode</h3>
      <ol>
        <li>Create a new iOS App project: interface SwiftUI, language Swift, minimum iOS 17.</li>
        <li>Add the ${info.swift_files} <code>.swift</code> files from the repository root (replacing the template's App and ContentView).</li>
        <li>Add the two usage descriptions, select your team, connect the device and run.</li>
      </ol>
      <p class="small mute">The README's Python loader (<code>room_scan_loader.py</code>) is not in this repository.</p>
    </div>
    <div class="panel"><h3>This site</h3>
      <p>A showcase and code explorer built only from the repository: the file list, line counts, summaries and outlines
      are read from the source by the web app (<code>web/repo_index.py</code>). The <a href="#/demo">Floor-plan lab</a>
      runs the export writer and floor-plan geometry ported to JavaScript; a node test checks it against the original
      Swift functions, which <code>scripts/make_swift_fixture.py</code> copies out of the source and runs on a Mac with
      small stand-ins for the RoomPlan types.</p>
      <h3>Run the web app locally</h3>
      <pre>pip install -r requirements-web.txt
python run_web.py        # http://127.0.0.1:8266</pre>
      <h3>Tests</h3>
      <pre>python -m pytest -q tests          # web + Swift checks (Swift ones need Xcode)
node web/static/room_engine.test.mjs</pre>
    </div>
  </div>
  <h2>Frameworks</h2>
  <p>${list(info.frameworks, f => `<span class="tag c">${esc(f)}</span>`)}</p>
  <h2>Credits and licence</h2>
  <p>RoomScanner by George Dickinson, MIT License (<a href="#/code/LICENSE">LICENSE</a>). Built with Apple's RoomPlan,
  ARKit and SwiftUI (README).</p>`;
  await resolveCites(app());
});
