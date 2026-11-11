import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {LIBRARY_MEDIA_SCHEMA,PACKAGE_FILES,LIBRARY_TEXTURES,MAX_LIBRARY_PIXELS,chooseTextureDimensions,
    createLibraryToc,validateLibraryRecipe,readMediaPackage,buildStoredZip,inspectGeneratedZip,encodeTga32} from '../Website/background-studio-core.mjs';
const asset={id:'first',name:'First image',imageWidth:200,imageHeight:100,textureWidth:256,textureHeight:128,
    suggestedFit:'FILL',zoom:1.5,focalX:0,focalY:1,opacity:.8,dim:.2,matte:'#161922'};
const library={schema:LIBRARY_MEDIA_SCHEMA,assets:[asset,{...asset,id:'second',name:'Second image',imageWidth:100,
    imageHeight:200,textureWidth:128,textureHeight:256,suggestedFit:'FIT',opacity:.6}]};
function entries(recipe=library){return [
    {name:PACKAGE_FILES.toc,data:createLibraryToc(recipe)},
    {name:PACKAGE_FILES.recipe,data:JSON.stringify(recipe)},
    {name:PACKAGE_FILES.readme,data:'Code-free fixture'},
    ...recipe.assets.map((a,i)=>({name:LIBRARY_TEXTURES[i],data:encodeTga32(a.textureWidth,a.textureHeight,
        new Uint8Array(a.textureWidth*a.textureHeight*4).fill(127))}))];}
const imported=readMediaPackage(inspectGeneratedZip(buildStoredZip(entries())));
assert.equal(imported.library,true);assert.equal(imported.images[0].recipe.focalX,0);
assert.equal(imported.images[1].recipe.id,'second');assert.equal(imported.images[1].tga.height,256);
const roundtrip=readMediaPackage(inspectGeneratedZip(buildStoredZip(entries({...library,assets:imported.images.map(x=>x.recipe)}))));
assert.deepEqual(roundtrip.images.map(x=>x.recipe),imported.images.map(x=>x.recipe));
// Removing the first image keeps the surviving ID, even when its texture slot changes.
const one={schema:3,assets:[library.assets[1]]};
assert.equal(readMediaPackage(inspectGeneratedZip(buildStoredZip(entries(one)))).images[0].recipe.id,'second');
for(const change of [a=>{a.id='../escape'},a=>{a.name='bad\nBackground.lua'},a=>{a.name='|cFFFF0000markup'},
    a=>{a.textureWidth=255},a=>{a.opacity=2},a=>{a.focalX=NaN},a=>{a.imageWidth=300}]) {
    const bad=structuredClone(library);change(bad.assets[0]);assert.throws(()=>validateLibraryRecipe(bad));
}
assert.throws(()=>validateLibraryRecipe({...library,assets:[asset,asset]}),/duplicate/);
assert.throws(()=>validateLibraryRecipe({...library,assets:[asset,asset,asset]}));
assert.throws(()=>validateLibraryRecipe({...library,assets:[]}));
const tooBig=structuredClone(library);tooBig.assets[0].textureWidth=2048;tooBig.assets[0].textureHeight=1024;
assert.throws(()=>validateLibraryRecipe(tooBig),/aggregate/);
const mismatched=inspectGeneratedZip(buildStoredZip(entries()));
mismatched.set(PACKAGE_FILES.recipe,new TextEncoder().encode(JSON.stringify(one)));
assert.throws(()=>readMediaPackage(mismatched),/manifest/);
const wrong=inspectGeneratedZip(buildStoredZip(entries()));
wrong.set(LIBRARY_TEXTURES[1],wrong.get(LIBRARY_TEXTURES[0]));assert.throws(()=>readMediaPackage(wrong),/texture/);
for(const shape of [[4000,3000],[3000,4000],[12000,1000],[1000,12000]]) {
    const d=chooseTextureDimensions(...shape,{maxTexturePixels:MAX_LIBRARY_PIXELS/2});
    assert.ok(d.textureWidth*d.textureHeight*2<=MAX_LIBRARY_PIXELS);
}
const toc=createLibraryToc(library);assert.doesNotMatch(toc,/^\s*[^#\s]/m);
const directory=mkdtempSync(join(tmpdir(),'offhand-library-'));
try {const path=join(directory,'media.toc');writeFileSync(path,toc);
    const run=spawnSync('lua',['tests/support/background-studio-library.lua',path],{encoding:'utf8'});
    assert.equal(run.status,0,run.stdout+run.stderr);console.log(run.stdout.trim());
}finally{rmSync(directory,{recursive:true,force:true});}
console.log('PASS: library identity, re-export/removal, aggregate normalization, malformed recipes, file parity and code-free metadata');
