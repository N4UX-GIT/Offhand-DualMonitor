// DOM/canvas simulation. This verifies event wiring and exported bytes, not browser rendering.
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {webcrypto,createHash} from 'node:crypto';
import {offlineBackgroundStudio} from '../scripts/New-OfflineBackgroundStudio.mjs';
import {inspectGeneratedZip,readMediaPackage,PACKAGE_FILES,encodeTga32,createMediaToc,buildStoredZip} from '../Website/background-studio-core.mjs';
const html=offlineBackgroundStudio();
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
assert.ok(html.includes(`script-src 'sha256-${createHash('sha256').update(script).digest('base64')}'`));
assert.ok(html.includes("connect-src 'none'"));
assert.doesNotMatch(html,/<script[^>]+src=|@import|src="assets\//);
class Element {
    constructor(){this.value='';this.listeners={};this.style={};this.options=[];this.classList={toggle(){},add(){},remove(){}};this.clientWidth=700;}
    addEventListener(type,fn){this.listeners[type]=fn;}
    async emit(type){return this.listeners[type]?.({preventDefault(){}});}
    setAttribute(){} appendChild(el){this.options.push(el);} replaceChildren(){this.options=[];} click(){} remove(){}
    getContext(){return {fillRect(){},drawImage(){},save(){},restore(){},clearRect(){},putImageData(){},
        getImageData:(_x,_y,w,h)=>({data:new Uint8ClampedArray(w*h*4).fill(127)})};}
}
const elements=new Map();const radios=['FILL','FIT','STRETCH'].map(value=>Object.assign(new Element(),{value,checked:value==='FILL'}));
function el(id){if(!elements.has(id))elements.set(id,new Element());return elements.get(id);}
for(const [id,value] of Object.entries({'image-zoom':'100','focus-x':'50','focus-y':'50','image-opacity':'100','image-dim':'0',
    'matte-color':'#161922','workspace-preset':'portrait'}))el('#'+id).value=value;
const document={querySelector(selector){if(selector.includes('fit-mode')){
    const match=selector.match(/value="(\w+)"/);return match?radios.find(r=>r.value===match[1]):radios.find(r=>r.checked);
}return el(selector);},querySelectorAll:()=>radios,createElement:()=>new Element(),body:new Element()};
let download;
const context=vm.createContext({document,window:{innerWidth:1400,innerHeight:1000,addEventListener(){}},
    TextEncoder,TextDecoder,Uint8Array,Uint8ClampedArray,DataView,Blob,crypto:webcrypto,
    ImageData:class{constructor(data,w,h){this.data=data;this.width=w;this.height=h;}},
    URL:{createObjectURL(blob){download=blob;return 'blob:test';},revokeObjectURL(){}},setTimeout:()=>0,
    requestAnimationFrame:fn=>fn(),createImageBitmap:async()=>({width:200,height:100,close(){}})});
vm.runInContext(script,context,{timeout:1000});
const a={schema:2,generatorVersion:4,imageWidth:200,imageHeight:100,textureWidth:256,textureHeight:128,
    suggestedFit:'FILL',zoom:1,focalX:0,focalY:1,opacity:1,dim:0,matte:'#161922'};
const old=buildStoredZip([{name:PACKAGE_FILES.toc,data:createMediaToc(a)}, {name:PACKAGE_FILES.recipe,data:JSON.stringify(a)},
    {name:PACKAGE_FILES.readme,data:'Fixture'}, {name:PACKAGE_FILES.texture,data:encodeTga32(256,128,new Uint8Array(256*128*4))}]);
el('#package-input').files=[new Blob([old])];await el('#package-input').emit('change');
assert.equal(el('#focus-x').value,'0');assert.equal(el('#focus-y').value,'100');
await el('#generate-button').emit('click');
assert.equal(readMediaPackage(inspectGeneratedZip(new Uint8Array(await download.arrayBuffer()))).recipe.schema,2);
const png=new Uint8Array(24);png.set([137,80,78,71,13,10,26,10]);png.set([73,72,68,82],12);
new DataView(png.buffer).setUint32(16,200);new DataView(png.buffer).setUint32(20,100);
el('#library-image-input').files=[Object.assign(new Blob([png],{type:'image/png'}),{name:'Second.png'})];
await el('#library-image-input').emit('change');
assert.equal(el('#background-picker').options.length,2);assert.equal(el('#add-background').disabled,true);
el('#focus-x').value='100';el('#focus-y').value='0';
await el('#generate-button').emit('click');
const twoZip=new Uint8Array(await download.arrayBuffer());
const two=readMediaPackage(inspectGeneratedZip(twoZip));
assert.equal(two.recipe.schema,3);assert.equal(two.images[0].recipe.focalX,0);assert.equal(two.images[1].recipe.focalX,1);
const surviving=two.images[1].recipe.id;
el('#package-input').files=[new Blob([twoZip])];await el('#package-input').emit('change');
assert.equal(el('#background-picker').options.length,2);
await el('#remove-background').emit('click');await el('#generate-button').emit('click');
const one=readMediaPackage(inspectGeneratedZip(new Uint8Array(await download.arrayBuffer())));
assert.equal(one.recipe.schema,3);assert.equal(one.images[0].recipe.id,surviving);
// A rejected import must leave the existing library usable.
el('#package-input').files=[new Blob(['invalid'])];await el('#package-input').emit('change');
assert.equal(el('#generate-button').disabled,false);assert.equal(el('#background-picker').options.length,1);
assert.match(el('#studio-status').className,/error/);
console.log('PASS: offline Studio CSP/dependencies and simulated import, single export, add/edit, library roundtrip, remove, failed-import preservation');
