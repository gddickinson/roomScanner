// Source citations for the explanatory pages. cite(file, needle) writes a placeholder; resolveCites(root) looks the
// needle up in the real source (api('/source')) and turns it into a "File.swift:123" link into the code explorer, so
// line numbers can never go stale. tests/test_web.py checks every cited needle exists in its file.
import { api, esc } from './core.js';

export const cite = (file, needle) =>
  `<a class="cite" data-f="${esc(file)}" data-q="${esc(needle)}" href="#/code/${encodeURI(file)}">${esc(file)}</a>`;

export function lineOf(text, needle) {
  const i = text.indexOf(needle);
  return i < 0 ? 0 : text.slice(0, i).split('\n').length;
}

export async function resolveCites(root) {
  const src = await api('/source');
  root.querySelectorAll('a.cite').forEach(a => {
    const text = src[a.dataset.f];
    const line = text ? lineOf(text, a.dataset.q) : 0;
    if (!line) { a.classList.add('missing'); return; }
    a.href = `#/code/${encodeURI(a.dataset.f)}?line=${line}`;
    a.textContent = `${a.dataset.f}:${line}`;
    a.title = a.dataset.q;
  });
}
