import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {resolve,dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');

// Ship the test Studio without a web deployment or a local server requirement.
export function offlineBackgroundStudio() {
    const core=readFileSync(join(root,'Website/background-studio-core.mjs'),'utf8').replace(/^export /gm,'');
    const studio=readFileSync(join(root,'Website/background-studio.js'),'utf8')
        .replace(/^import \{[\s\S]*?\} from "\.\/background-studio-core\.mjs[^"\n]*";\s*/, '');
    if (/^\s*(import|export)\s/m.test(core+'\n'+studio)) throw new Error('Unbundled module dependency.');
    const script='\n"use strict";\n(()=>{\n'+core+'\n'+studio+'\n})();\n';
    if (/<\/script/i.test(script)) throw new Error('Unsafe inline script delimiter.');
    const digest=createHash('sha256').update(script).digest('base64');
    const css=['style.css','background-studio.css'].map(name=>readFileSync(join(root,'Website',name),'utf8')
        .replace(/^@import[^;]+;\s*/gm,'')).join('\n');
    let html=readFileSync(join(root,'Website/background-studio.html'),'utf8');
    html=html.replace(/<meta http-equiv="Content-Security-Policy"[^>]+>/,
        `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; connect-src 'none'; form-action 'none'; object-src 'none'; base-uri 'none'; frame-src 'none'; worker-src 'none'; media-src 'none'; script-src 'sha256-${digest}'; style-src 'unsafe-inline'; img-src data: blob:">`);
    html=html.replace(/\s*<link rel="stylesheet"[^>]+>/g,'').replace('</head>',`<style>\n${css}\n</style>\n</head>`);
    html=html.replace(/(src|href)="(assets\/[^"?]+)"/g,(_,attribute,path)=>{
        const bytes=readFileSync(join(root,'Website',path));
        const mime=path.endsWith('.svg')?'image/svg+xml':'image/png';
        return `${attribute}="data:${mime};base64,${bytes.toString('base64')}"`;
    });
    html=html.replace(/href="(?!https:|data:|#)([^"?]+\.html)([^"#]*)?(#[^"]*)?"/g,(_,path,_query,anchor)=>
        `href="https://offhand-wow.onrender.com/${path}${anchor||''}"`);
    html=html.replace('<div class="hero-badge">LOCAL BROWSER TOOL</div>',
        '<div class="hero-badge">UNOFFICIAL TEST STUDIO · OFFLINE</div>');
    html=html.replace(/<script type="module" src="background-studio\.js[^"\n]*"><\/script>/,
        ()=>`<script>${script}</script>`);
    if (/<script[^>]+src=|<link rel="stylesheet"|@import/.test(html)) throw new Error('External code or style dependency.');
    return html;
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
    const output=resolve(process.argv[2]||'Offhand-Background-Studio.html');
    if(existsSync(output)) throw new Error('Use a fresh Studio output path.');
    writeFileSync(output,offlineBackgroundStudio());
    console.log(`Offline Studio created: ${output}`);
}
