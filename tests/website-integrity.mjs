import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, extname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../Website');
const pages = readdirSync(root).filter(name => name.endsWith('.html'));
const attributes = text => Object.fromEntries([...text.matchAll(/([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g)]
    .map(match => [match[1].toLowerCase(), match[2] ?? match[3]]));
const idsByPage = new Map();
for (const page of pages) {
    const html = readFileSync(resolve(root, page), 'utf8');
    const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
    assert.equal(new Set(ids).size, ids.length, `${page}: duplicate static IDs`);
    idsByPage.set(page, new Set(ids));
    assert.equal((html.match(/<h1\b/gi) || []).length, 1, `${page}: expected one H1`);
}
let checked = 0;
for (const page of pages) {
    const html = readFileSync(resolve(root, page), 'utf8');
    for (const match of html.matchAll(/<(a|img|script|link|source|video)\b([^>]*)>/gi)) {
        const tag = match[1].toLowerCase();
        const attrs = attributes(match[2]);
        if (tag === 'img') assert.ok('alt' in attrs, `${page}: image missing alt`);
        for (const key of ['href', 'src', 'poster']) {
            const ref = attrs[key];
            if (!ref || /^(?:[a-z][\w+.-]*:|\/\/)/i.test(ref)) continue;
            const url = new URL(ref.replaceAll('&amp;', '&'), `https://local.test/${page}`);
            const target = decodeURIComponent(url.pathname).replace(/^\//, '');
            const path = resolve(root, target);
            assert.ok(path.startsWith(root), `${page}: reference escapes website: ${ref}`);
            assert.ok(existsSync(path), `${page}: missing local target ${ref}`);
            if (url.hash && extname(target) === '.html') {
                assert.ok(idsByPage.get(target)?.has(decodeURIComponent(url.hash.slice(1))),
                    `${page}: missing fragment ${ref}`);
            }
            checked++;
        }
    }
}
console.log(`Website integrity: ${pages.length} pages, ${checked} local references checked; static IDs, H1s, and image alt attributes passed.`);
