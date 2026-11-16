// Node test for the highlighter: run `node web/static/swift_highlight.test.mjs`.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { tokenize, highlightLines } from './swift_highlight.js';

const kinds = (src, lang) => tokenize(src, lang).filter(([c]) => c !== 'txt').map(([c, s]) => `${c}:${s}`);

assert.deepEqual(kinds('let x = 42 // answer'), ['kw:let', 'num:42', 'com:// answer']);
assert.deepEqual(kinds('@Published var hudColor: Color = .cyan'), ['attr:@Published', 'kw:var', 'type:Color']);
assert.deepEqual(kinds('if #available(iOS 26.0, *) {'), ['kw:if', 'dir:#available', 'num:26.0']);
assert.deepEqual(kinds('Text("N \\(x) \\"q\\"")'), ['type:Text', 'str:"N \\(x) \\"q\\""']);
assert.deepEqual(kinds('calculateBearing(from: a)'), ['fn:calculateBearing']);
assert.deepEqual(kinds('<key>arkit</key><!-- c -->', 'Property list'), ['tag:<key>', 'tag:</key>', 'com:<!-- c -->']);

// A block comment spanning lines keeps its class on each line; HTML is escaped; line count is preserved.
const lines = highlightLines('/* a\n b */ x < y\n"s"');
assert.equal(lines.length, 3);
assert.equal(lines[0], '<span class="hl-com">/* a</span>');
assert.equal(lines[1], '<span class="hl-com"> b */</span> x &lt; y');
assert.equal(lines[2], '<span class="hl-str">&quot;s&quot;</span>');

// Every Swift file in the repo round-trips: stripping the tags gives back the source text, line for line.
const root = fileURLToPath(new URL('../../', import.meta.url));
const unesc = s => s.replace(/<[^>]+>/g, '').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&');
let n = 0;
for (const f of readdirSync(root).filter(f => f.endsWith('.swift'))) {
  const src = readFileSync(root + f, 'utf8');
  assert.deepEqual(highlightLines(src).map(unesc), src.split('\n'), f);
  n++;
}
assert.ok(n > 0, 'found Swift files');
console.log(`swift_highlight: ok (${n} Swift files round-trip)`);
