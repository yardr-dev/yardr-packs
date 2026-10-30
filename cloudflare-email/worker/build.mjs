// Bundles worker.js and postal-mime into one module for the yard to
// upload: Cloudflare's script upload takes a single module file, and
// postal-mime arrives as ten files with relative imports, so the pack
// ships the bundle as worker/dist/worker.js, committed. The bundle is
// byte-deterministic from its sources: the pack's test rebuilds it and
// fails when the committed copy differs.
//
// Only node runs this (node build.mjs [out], default dist/worker.js):
// no bundler dependency, nothing from the network. It understands the
// import and export lines this graph actually uses — default and named
// imports, `export default` of a class, function or bare identifier,
// `export` of a declaration, and `export {…}` of names already in the
// file — and refuses anything else, an unresolvable import, or two
// modules declaring the same top-level name, rather than emitting a
// bundle that reads differently than its sources.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, process.argv[2] ?? 'dist/worker.js');

function fail(msg) {
  console.error(`build: ${msg}`);
  process.exit(1);
}

// A bare import ('postal-mime') resolves through that package's own
// manifest, as node would for an ESM import; a relative one resolves
// against the importing file.
function resolveSpec(spec, from) {
  if (spec.startsWith('./') || spec.startsWith('../')) {
    return resolve(dirname(from), spec);
  }
  const pkgFile = join(here, 'node_modules', spec, 'package.json');
  let pkg;
  try {
    pkg = JSON.parse(readFileSync(pkgFile, 'utf8'));
  } catch {
    fail(`cannot read ${relative(here, pkgFile)} (cd worker && npm install): ${spec} from ${relative(here, from)}`);
  }
  const entry = pkg.exports?.['.']?.import ?? pkg.module ?? pkg.main;
  if (!entry) fail(`package ${spec} names no ESM entry in its package.json`);
  return resolve(dirname(pkgFile), entry);
}

const IMPORT = /^import\s+(?:([A-Za-z_$][\w$]*)\s+from\s+|(\{[^}]*\})\s+from\s+)['\"]([^'\"]+)['\"];?\s*$/;
const EXPORT_DEFAULT = /^export\s+default\s+(.*)$/;
const EXPORT_DECL = /^export\s+((?:async\s+)?(?:function|class|const|let|var)\s+[A-Za-z_$][\w$]*.*)$/;
const EXPORT_LIST = /^export\s*\{([^}]*)\};?\s*$/;
const BARE_IDENT = /^[A-Za-z_$][\w$]*;?$/;
const DECL_NAME = /^(?:async\s+)?(?:function|class|const|let|var)\s+([A-Za-z_$][\w$]*)/;

// One module: its imports stripped and recorded, its exports stripped
// with their declarations kept, its declared names gathered. The
// entry keeps its `export default`: the bundle is a module worker.
function load(path, entry) {
  const text = readFileSync(path, 'utf8');
  const names = new Set();
  const imports = [];
  let hasDefault = false;
  const body = [];
  for (const line of text.split('\n')) {
    let m = line.match(IMPORT);
    if (m) {
      const file = resolveSpec(m[3], path);
      if (m[1]) {
        imports.push({ file, def: m[1] });
      } else {
        for (const name of m[2].slice(1, -1).split(',')) {
          const id = name.trim().split(/\s+as\s+/);
          // `a as b` renames at the use site; the bundle keeps one
          // spelling, so a rename is refused rather than misread.
          if (id.length > 1) fail(`${relative(here, path)}: renamed import ${name.trim()} is beyond this bundler`);
          if (id[0]) imports.push({ file, named: id[0] });
        }
      }
      continue;
    }
    if (line.startsWith('export ')) {
      if (entry) {
        body.push(line);
        continue;
      }
      m = line.match(EXPORT_DEFAULT);
      if (m) {
        const rest = m[1].trim();
        if (BARE_IDENT.test(rest)) {
          // `export default name;` re-exports a declaration the file
          // keeps; the line itself goes.
          hasDefault = rest.replace(/;$/, '');
          continue;
        }
        const decl = rest.match(DECL_NAME);
        if (!decl) fail(`${relative(here, path)}: cannot bundle: ${line.trim()}`);
        names.add(decl[1]);
        hasDefault = decl[1];
        body.push(rest);
        continue;
      }
      m = line.match(EXPORT_DECL);
      if (m) {
        names.add(m[1].match(DECL_NAME)[1]);
        body.push(m[1]);
        continue;
      }
      m = line.match(EXPORT_LIST);
      if (m) {
        // A re-export of names the file imports or declares; the
        // bundle's single scope carries them without the line.
        for (const name of m[1].split(',')) {
          const id = name.trim();
          if (id && !names.has(id) && !imports.some((i) => i.def === id || i.named === id)) {
            fail(`${relative(here, path)}: re-exported ${id} is neither declared nor imported here`);
          }
        }
        continue;
      }
      fail(`${relative(here, path)}: cannot bundle: ${line.trim()}`);
    }
    const decl = line.match(DECL_NAME);
    if (decl) names.add(decl[1]);
    body.push(line);
  }
  return { path, text: body.join('\n'), names, imports, hasDefault };
}

// Post-order from the entry along its imports: dependencies first,
// each once, the entry last.
const seen = new Set();
const order = [];
function visit(path, entry) {
  const mod = load(path, entry);
  seen.add(path);
  for (const imp of mod.imports) {
    if (!seen.has(imp.file)) visit(imp.file, false);
  }
  order.push(mod);
}
visit(join(here, 'worker.js'), true);

const byPath = new Map(order.map((m) => [m.path, m]));
// Every import resolves to a name its file declares or itself
// imports; and no two files declare the same name, since the bundle
// holds them in one scope.
for (const mod of order) {
  for (const imp of mod.imports) {
    const src = byPath.get(imp.file);
    if (!src) fail(`${relative(here, mod.path)}: ${relative(here, imp.file)} is not in the bundle`);
    const want = imp.def ? `(default)` : imp.named;
    const ok = imp.def
      ? src.hasDefault
      : src.names.has(imp.named) || src.imports.some((i) => i.def === imp.named || i.named === imp.named);
    if (!ok) fail(`${relative(here, mod.path)}: ${want} is no export of ${relative(here, imp.file)}`);
  }
}
const declared = new Map();
for (const mod of order) {
  for (const name of mod.names) {
    if (declared.has(name)) {
      fail(`${name} is declared in both ${relative(here, declared.get(name))} and ${relative(here, mod.path)}`);
    }
    declared.set(name, mod.path);
  }
}

let postalVersion = 'unknown';
try {
  postalVersion = JSON.parse(readFileSync(join(here, 'node_modules', 'postal-mime', 'package.json'), 'utf8')).version;
} catch {
  // The resolve above already fails without the package; this is only
  // the header's version line.
}

const parts = [
  `// The mail hook's Worker as one module, built by build.mjs from worker.js`,
  `// and postal-mime ${postalVersion}: what the yard uploads to Cloudflare.`,
  `// Do not edit by hand; edit worker.js and rebuild.`,
  ...order.map((m) => `// ---- ${relative(here, m.path)} ----\n${m.text.trim()}`),
];
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, parts.join('\n\n') + '\n');
console.log(`build: ${relative(here, out)}: ${parts.join('\n\n').length + 1} bytes from ${order.length} files`);
