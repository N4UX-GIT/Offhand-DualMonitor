import assert from "node:assert/strict";
import {
    GENERATOR_VERSION,
    MEDIA_SCHEMA,
    PACKAGE_PATHS,
    buildStoredZip,
    calculateFillCrop,
    chooseTextureDimensions,
    containDimensions,
    createMediaToc,
    cropFocusAxis,
    crc32,
    decodeJson,
    decodeTga32,
    encodeTga32,
    inspectGeneratedZip,
    inspectImageHeader,
    isSafePackagePath,
    nextPowerOfTwo,
} from "../Website/background-studio-core.mjs";

const mediaToc = createMediaToc();
assert.match(mediaToc, /^## Interface: 30300, .*120105.*11509\r\n/);
assert.match(mediaToc, /## Title: \|cffffbd0aOffhand\|r \|cffffffff\[User Media\]\|r/);
assert.match(mediaToc, /## Notes: Your custom Offhand canvas background, generated locally by the Offhand Background Studio\./);
assert.match(mediaToc, /## Author: Offhand Background Studio/);
assert.match(mediaToc, new RegExp(`## Version: ${MEDIA_SCHEMA}\\r\\n`));
assert.match(mediaToc, new RegExp(`## X-Offhand-Media-Schema: ${MEDIA_SCHEMA}\\r\\n`));
assert.match(mediaToc, new RegExp(`## X-Offhand-Generator-Version: ${GENERATOR_VERSION}\\r\\n`));
assert.match(mediaToc, /## X-Website: https:\/\/offhand-wow\.onrender\.com\/background-studio\.html/);
assert.match(mediaToc, /## IconTexture: Interface\\AddOns\\Offhand\\Media\\OffhandLogo64x64\.blp/);
assert.match(mediaToc, /## LoadOnDemand: 1\r\n## Dependencies: Offhand\r\n\r\nBackground\.lua\r\n$/);
assert.doesNotMatch(mediaToc, /SavedVariables|Companion|X-Offhand-Release/);

assert.equal(nextPowerOfTwo(1), 1);
assert.equal(nextPowerOfTwo(1025), 2048);

assert.equal(cropFocusAxis(2560, 1440, 2560, 1440, "FILL"), "none");
assert.equal(cropFocusAxis(2560, 1440, 1440, 2560, "FILL"), "horizontal");
assert.equal(cropFocusAxis(1440, 2560, 2560, 1440, "FILL"), "vertical");
assert.equal(cropFocusAxis(2560, 1440, 1440, 2560, "FIT"), "none");
assert.equal(cropFocusAxis(1440, 2560, 2560, 1440, "STRETCH"), "none");
const portraitFill = calculateFillCrop(989, 1020, 2560, 1440, 1, 0.5, 0.5);
assert.equal(portraitFill.horizontal, false);
assert.equal(portraitFill.vertical, true);
assert.ok(Math.abs((portraitFill.sw / portraitFill.sh) - (2560 / 1440)) < 0.000001);
const portraitZoom = calculateFillCrop(989, 1020, 2560, 1440, 1.5, 0.25, 0.75);
assert.equal(portraitZoom.horizontal, true);
assert.equal(portraitZoom.vertical, true);
assert.equal(portraitZoom.zoom, 1.5);
assert.ok(portraitZoom.sx > 0 && portraitZoom.sy > 0);
const defaultZoom = calculateFillCrop(1600, 1600, 1600, 1600);
assert.equal(defaultZoom.zoom, 1);
assert.equal(defaultZoom.horizontal, false);
assert.equal(defaultZoom.vertical, false);
assert.deepEqual(containDimensions(2560, 1440, 500, 640), { width: 500, height: 281 });
assert.deepEqual(containDimensions(1440, 2560, 500, 640), { width: 360, height: 640 });
assert.deepEqual(containDimensions(1600, 1600, 500, 640), { width: 500, height: 500 });

const pngHeader = new Uint8Array(24);
pngHeader.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], 0);
pngHeader.set([0x49, 0x48, 0x44, 0x52], 12);
new DataView(pngHeader.buffer).setUint32(16, 1440);
new DataView(pngHeader.buffer).setUint32(20, 2560);
assert.deepEqual(inspectImageHeader(pngHeader, "image/png"), { width: 1440, height: 2560 });

const jpegHeader = new Uint8Array([
    0xff, 0xd8,
    0xff, 0xc0, 0x00, 0x11, 0x08, 0x0a, 0x00, 0x05, 0xa0, 0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x00, 0x03, 0x11, 0x00,
]);
assert.deepEqual(inspectImageHeader(jpegHeader, "image/jpeg"), { width: 1440, height: 2560 });

const webpHeader = new Uint8Array(30);
webpHeader.set([0x52, 0x49, 0x46, 0x46, 0x16, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x58, 0x0a, 0, 0, 0], 0);
webpHeader.set([0x9f, 0x05, 0, 0xff, 0x09, 0], 24);
assert.deepEqual(inspectImageHeader(webpHeader, "image/webp"), { width: 1440, height: 2560 });

const portrait = chooseTextureDimensions(1440, 2560);
assert.ok(portrait.contentWidth <= 1024, "portrait image should stay within the two-megapixel texture budget");
assert.ok(portrait.textureWidth * portrait.textureHeight <= 2048 * 1024);
assert.ok((portrait.textureWidth & (portrait.textureWidth - 1)) === 0);
assert.ok((portrait.textureHeight & (portrait.textureHeight - 1)) === 0);

const rgba = new Uint8Array([
    255, 0, 0, 255,
    0, 255, 0, 128,
    0, 0, 255, 255,
    255, 255, 255, 0,
]);
const tga = encodeTga32(2, 2, rgba);
const decoded = decodeTga32(tga);
assert.equal(decoded.width, 2);
assert.equal(decoded.height, 2);
assert.deepEqual(Array.from(decoded.rgba), Array.from(rgba));

const recipe = { schema: 1, textureWidth: 2, textureHeight: 2, imageWidth: 2, imageHeight: 2, zoom: 1.5 };
const entries = [
    { name: PACKAGE_PATHS[0], data: mediaToc },
    { name: PACKAGE_PATHS[1], data: "OffhandUserBackground = {}\n" },
    { name: PACKAGE_PATHS[2], data: `${JSON.stringify(recipe)}\n` },
    { name: PACKAGE_PATHS[3], data: "README\n" },
    { name: PACKAGE_PATHS[4], data: tga },
];
const zip = buildStoredZip(entries);
const inspected = inspectGeneratedZip(zip);
assert.equal(new TextDecoder().decode(inspected.get(PACKAGE_PATHS[0])), mediaToc);
assert.deepEqual(decodeJson(inspected.get(PACKAGE_PATHS[2])), recipe);
assert.deepEqual(Array.from(inspected.get(PACKAGE_PATHS[4])), Array.from(tga));
assert.equal(crc32(inspected.get(PACKAGE_PATHS[4])), crc32(tga));

assert.equal(isSafePackagePath("Offhand_UserMedia/Textures/Background.tga"), true);
assert.equal(isSafePackagePath("../Background.tga"), false);
assert.equal(isSafePackagePath("C:/Background.tga"), false);
assert.equal(isSafePackagePath("Offhand_UserMedia\\Background.tga"), false);
assert.throws(() => buildStoredZip([{ name: "../evil.lua", data: "bad" }]), /Unsafe package path/);

function findSequence(haystack, needle) {
    outer: for (let offset = 0; offset <= haystack.length - needle.length; offset += 1) {
        for (let index = 0; index < needle.length; index += 1) {
            if (haystack[offset + index] !== needle[index]) continue outer;
        }
        return offset;
    }
    return -1;
}

const tampered = zip.slice();
const tgaOffset = findSequence(tampered, tga);
assert.ok(tgaOffset >= 0);
tampered[tgaOffset + 18] ^= 0xff;
assert.throws(() => inspectGeneratedZip(tampered), /CRC check failed|malformed|invalid/i);

const mismatchedLocalHeader = zip.slice();
const localNameOffset = 30;
mismatchedLocalHeader[localNameOffset] ^= 0x01;
assert.throws(() => inspectGeneratedZip(mismatchedLocalHeader), /local header does not match/i);

console.log("PASS: Background Studio texture normalization, TGA, ZIP, CRC, and path safety verified.");
