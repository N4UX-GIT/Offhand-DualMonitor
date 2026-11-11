import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {GENERATOR_VERSION,MEDIA_SCHEMA,createMediaToc,calculateFillCrop,recipeControlValues} from '../Website/background-studio-core.mjs';

const directory=mkdtempSync(join(tmpdir(),'offhand-region-crop-'));
let checks=0;
try {
    for (const [imageWidth,imageHeight,textureWidth,textureHeight] of [[200,100,256,128],[100,200,128,256]]) {
        for (const focal of [0,.5,1]) {
            const recipe={schema:MEDIA_SCHEMA,generatorVersion:GENERATOR_VERSION,imageWidth,imageHeight,textureWidth,textureHeight,
                suggestedFit:'FILL',zoom:1.5,focalX:focal,focalY:focal,opacity:.8,dim:.2,matte:'#161922'};
            // Include the same JSON restoration path used by Update package.
            const controls=recipeControlValues(JSON.parse(JSON.stringify(recipe)));
            assert.equal(controls.focalX,focal);assert.equal(controls.focalY,focal);
            const path=join(directory,'Offhand_UserMedia.toc');writeFileSync(path,createMediaToc(recipe));
            for(const [width,height] of [[480,600],[1440,2560],[1920,480],[960,960]]) {
                for(const fit of ['PACKAGE','FILL','FIT','STRETCH']) {
                    const run=spawnSync('lua',['tests/support/background-studio-regions.lua',path,width,height,fit],{encoding:'utf8'});
                    assert.equal(run.status,0,run.stderr);
                    const actual=run.stdout.trim().split(/\s+/).map(Number);
                    let expected=[0,imageWidth/textureWidth,0,imageHeight/textureHeight,0,0];
                    if(fit==='FILL'||fit==='PACKAGE') {
                        const c=calculateFillCrop(imageWidth,imageHeight,width,height,recipe.zoom,focal,focal);
                        expected=[c.sx/textureWidth,(c.sx+c.sw)/textureWidth,c.sy/textureHeight,(c.sy+c.sh)/textureHeight,0,0];
                    } else if(fit==='FIT') {
                        const scale=Math.min(width/imageWidth,height/imageHeight);
                        expected[4]=imageWidth*scale;expected[5]=imageHeight*scale;
                    }
                    actual.forEach((value,i)=>assert.ok(Math.abs(value-expected[i])<1e-8,`${fit} ${width}x${height} component ${i}: ${value} != ${expected[i]}`));
                    checks++;
                }
            }
        }
    }
} finally { rmSync(directory,{recursive:true,force:true}); }
console.log(`PASS: ${checks} website-to-Lua region crop/fit comparisons, including edge focal points and padded textures.`);
