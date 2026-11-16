// Code explorer: file list (with header summaries), search by file name and text, and a highlighted source viewer
// with line numbers, an outline of MARK sections / types / functions, and ?line=N deep links.
import { route, api, app, esc, list, tags, go } from './core.js';
import { highlightLines } from './swift_highlight.js';

const GROUPS = [['Swift', 'Swift source'], ['Property list', 'Configuration'], ['Markdown', 'Documentation']];

function fileList(tree, current) {
  const known = new Set(GROUPS.map(g => g[0]));
  const groups = [...GROUPS, ['*', 'Other']];
  return list(groups, ([lang, title]) => {
    const files = tree.filter(f => lang === '*' ? !known.has(f.lang) : f.lang === lang);
    if (!files.length) return '';
    return `<h3>${esc(title)}</h3>` + list(files, f => `<a class="fl${f.path === current ? ' on' : ''}" href="#/code/${encodeURI(f.path)}">
      <b>${esc(f.path)}</b><small>${f.lines} lines${f.summary ? ' · ' + esc(f.summary) : ''}</small></a>`);
  });
}

function search(q, tree, src) {
  const ql = q.toLowerCase();
  const byName = tree.filter(f => f.path.toLowerCase().includes(ql));
  const hits = [];
  for (const f of tree) {
    (src[f.path] || '').split('\n').forEach((ln, i) => {
      if (hits.length < 200 && ln.toLowerCase().includes(ql)) hits.push({ path: f.path, line: i + 1, text: ln.trim() });
    });
  }
  return `<p class="mute small">${byName.length} file name match${byName.length === 1 ? '' : 'es'}, ${hits.length}${hits.length === 200 ? '+' : ''} line match${hits.length === 1 ? '' : 'es'} for <b>${esc(q)}</b></p>
    ${byName.length ? `<div class="tagrow">${list(byName, f => `<a class="tag a" href="#/code/${encodeURI(f.path)}">${esc(f.path)}</a>`)}</div>` : ''}
    <div class="hits">${list(hits, h => `<a class="hit" href="#/code/${encodeURI(h.path)}?line=${h.line}"><span class="mono">${esc(h.path)}:${h.line}</span><code>${esc(h.text.slice(0, 160))}</code></a>`)}</div>`;
}

function viewer(f, text, line, repo) {
  const html = highlightLines(text, f.lang);
  const outline = f.outline && f.outline.length ? `<details class="outline"${f.outline.length < 40 ? ' open' : ''}><summary>Outline (${f.outline.length})</summary>
    <ul>${list(f.outline, o => `<li class="d${Math.min(o.depth, 3)} k-${o.kind}"><a href="#/code/${encodeURI(f.path)}?line=${o.line}&keep=1">
    <span class="kind">${o.kind === 'mark' ? '§' : esc(o.kind)}</span> ${esc(o.name)}</a> <span class="mute">${o.line}</span></li>`)}</ul></details>` : '';
  return `<div class="filehead"><h2>${esc(f.path)}</h2>
    <p class="mute small">${esc(f.lang)} · ${f.lines} lines · ${(f.bytes / 1024).toFixed(1)} KB
    · <a href="https://github.com/gddickinson/${esc(repo)}/blob/main/${encodeURI(f.path)}" target="_blank" rel="noopener">on GitHub</a></p>
    ${f.summary ? `<p class="callout a">${esc(f.summary)}</p>` : ''}
    ${f.imports && f.imports.length ? `<p>${tags(f.imports, 'c')}</p>` : ''}</div>
    ${outline}
    <pre class="src" tabindex="0" aria-label="Source of ${esc(f.path)}">${html.map((h, i) =>
      `<span class="ln${i + 1 === line ? ' hot' : ''}" id="L${i + 1}"><a class="n" href="#/code/${encodeURI(f.path)}?line=${i + 1}&keep=1" aria-label="line ${i + 1}">${i + 1}</a>${h || ' '}</span>`).join('')}</pre>`;
}

route('code', async (args, query) => {
  const [tree, src, info] = await Promise.all([api('/tree'), api('/source'), api('/info')]);
  const path = args.join('/') || (tree.find(f => f.lang === 'Swift') || tree[0]).path;
  const f = tree.find(x => x.path === path);
  const line = +query.line || 0;
  const q = query.q || '';
  app().innerHTML = `<p class="kicker">Code explorer</p>
    <div class="side code-page">
      <aside class="panel files">
        <form class="searchbox" role="search"><label for="q">Search file names and text</label>
          <input id="q" type="search" value="${esc(q)}" placeholder="e.g. heading, ARKit, func"></form>
        ${fileList(tree, path)}
      </aside>
      <section class="viewer">${q ? search(q, tree, src) : f ? viewer(f, src[path], line, info.repo) : `<p class="err">No file ${esc(path)}</p>`}</section>
    </div>`;
  app().querySelector('form.searchbox').addEventListener('submit', e => {
    e.preventDefault();
    const v = app().querySelector('#q').value.trim();
    go(v ? `#/code/${encodeURI(path)}?q=${encodeURIComponent(v)}` : `#/code/${encodeURI(path)}`);
  });
  if (line) {
    const el = document.getElementById('L' + line);
    if (el) requestAnimationFrame(() => el.scrollIntoView({ block: 'center' }));
  }
});
