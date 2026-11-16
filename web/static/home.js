// Home page: hero, real counts from the repository (api('/info')), cards to the other pages and a file map.
import { route, api, app, list, esc } from './core.js';
import { SITE } from './site.js';

route('home', async () => {
  const [info, tree] = await Promise.all([api('/info'), api('/tree')]);
  const swift = tree.filter(f => f.lang === 'Swift');
  app().innerHTML = `
  <section class="hero">
    <p class="kicker">${esc(SITE.kicker)}</p>
    <h1 class="glow">${esc(info.title)}</h1>
    <p class="lead">${esc(SITE.lead)}</p>
    <a class="btn" href="#/demo">${esc(SITE.cards[2][1])}</a><a class="btn alt" href="#/code">Browse the code</a>
  </section>
  <div class="tiles">
    <div class="tile"><b>${info.swift_files}</b><span>Swift files</span></div>
    <div class="tile"><b>${info.swift_lines.toLocaleString('en')}</b><span>lines of Swift</span></div>
    <div class="tile"><b>${info.types}</b><span>types (struct / class / enum / protocol)</span></div>
    <div class="tile"><b>${info.functions}</b><span>functions</span></div>
    <div class="tile"><b>${info.frameworks.length}</b><span>Apple frameworks imported</span></div>
  </div>
  <div class="grid wide">${list(SITE.cards, ([href, t, d, c]) => `<a class="card door ${c}" href="${href}"><b>${esc(t)}</b><span>${esc(d)}</span></a>`)}</div>
  <h2>Files at a glance</h2>
  <div class="scroll"><table><thead><tr><th>File</th><th>Lines</th><th>What it does (from its header comment)</th></tr></thead><tbody>
  ${list(swift, f => `<tr class="click" data-href="#/code/${encodeURI(f.path)}"><td class="mono"><a href="#/code/${encodeURI(f.path)}">${esc(f.path)}</a></td><td>${f.lines}</td><td>${esc(f.summary)}</td></tr>`)}
  </tbody></table></div>
  <h2>Languages</h2>
  <div class="langbar" role="img" aria-label="Lines per language">${list(info.languages, l =>
    `<span style="flex:${l.lines}" title="${esc(l.lang)}: ${l.lines} lines"></span>`)}</div>
  <p class="small mute">${list(info.languages, l => `${esc(l.lang)}: ${l.files} file${l.files === 1 ? '' : 's'}, ${l.lines.toLocaleString('en')} lines`, ' · ')}
  · frameworks: ${list(info.frameworks, esc, ', ')}</p>`;
  app().querySelectorAll('tr.click').forEach(tr => tr.addEventListener('click', e => {
    if (e.target.tagName !== 'A') location.hash = tr.dataset.href;
  }));
});
