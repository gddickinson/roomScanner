// Small dependency-free syntax highlighter for the code explorer: Swift, XML property lists and Markdown.
// highlightLines(text, lang) returns one HTML string per source line (spans are closed and reopened at line breaks,
// so a block comment or multi-line string keeps its colour on every line).

const SWIFT_KW = new Set(('associatedtype class deinit enum extension fileprivate func import init inout internal let ' +
  'open operator private protocol public rethrows static struct subscript typealias var break case continue default ' +
  'defer do else fallthrough for guard if in repeat return switch where while as catch false is nil super self Self ' +
  'throw throws true try async await some any weak unowned lazy override mutating nonmutating final required ' +
  'convenience dynamic optional get set willSet didSet nonisolated').split(' '));

const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' };
const esc = s => s.replace(/[&<>"]/g, c => ESC[c]);

// Ordered token rules for Swift: [class, sticky regex]. The first rule that matches at the cursor wins.
const SWIFT_RULES = [
  ['com', /\/\*[\s\S]*?(?:\*\/|$)/y],
  ['com', /\/\/[^\n]*/y],
  ['str', /"""[\s\S]*?(?:"""|$)/y],
  ['str', /"(?:\\.|[^"\\\n])*"?/y],
  ['num', /0x[0-9a-fA-F_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?/y],
  ['attr', /@[A-Za-z_]\w*/y],
  ['dir', /#[A-Za-z_]\w*/y],
  ['id', /[A-Za-z_]\w*/y],
  ['ws', /\s+/y],
  ['op', /[^\sA-Za-z0-9_"@#/]+|\//y],
];
const XML_RULES = [
  ['com', /<!--[\s\S]*?(?:-->|$)/y],
  ['tag', /<\/?[A-Za-z!?][^>]*>?/y],
  ['txt', /[^<]+/y],
];

export function tokenize(text, lang = 'Swift') {
  if (lang === 'Markdown') return mdTokens(text);
  const rules = lang === 'Swift' ? SWIFT_RULES : lang === 'Property list' ? XML_RULES : null;
  if (!rules) return [['txt', text]];
  const out = [];
  let i = 0;
  while (i < text.length) {
    let hit = null;
    for (const [cls, re] of rules) {
      re.lastIndex = i;
      const m = re.exec(text);
      if (m && m[0].length) { hit = [cls, m[0]]; break; }
    }
    if (!hit) hit = ['txt', text[i]];
    if (hit[0] === 'id') {
      const w = hit[1];
      hit[0] = SWIFT_KW.has(w) ? 'kw' : /^[A-Z]/.test(w) ? 'type' : text[i + w.length] === '(' ? 'fn' : 'txt';
    }
    if (hit[0] === 'ws' || hit[0] === 'op') hit[0] = 'txt';
    out.push(hit);
    i += hit[1].length;
  }
  return out;
}

function mdTokens(text) {
  const out = [];
  let fence = false;
  for (const line of text.split('\n')) {
    const isFence = line.startsWith('```');
    const cls = fence || isFence ? 'str' : /^#{1,6} /.test(line) ? 'kw' : /^\s*([-*]|\d+\.) /.test(line) ? 'txt' : 'txt';
    if (isFence) fence = !fence;
    out.push([cls, line], ['txt', '\n']);
  }
  out.pop();
  return out;
}

// Merge tokens into per-line HTML.
export function highlightLines(text, lang = 'Swift') {
  const lines = [''];
  for (const [cls, s] of tokenize(text, lang)) {
    s.split('\n').forEach((piece, k) => {
      if (k) lines.push('');
      if (piece) lines[lines.length - 1] += cls === 'txt' ? esc(piece) : `<span class="hl-${cls}">${esc(piece)}</span>`;
    });
  }
  return lines;
}
