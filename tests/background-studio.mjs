import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
    GENERATOR_VERSION,
    LEGACY_MEDIA_SCHEMA,
    LEGACY_PACKAGE_PATHS,
    MEDIA_SCHEMA,
    PACKAGE_FILES,
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

const tocRecipe = {
    schema: MEDIA_SCHEMA,
    generatorVersion: GENERATOR_VERSION,
    imageWidth: 1440,
    imageHeight: 2560,
    textureWidth: 2048,
    textureHeight: 4096,
    suggestedFit: "FILL",
    zoom: 1.25,
    focalX: 0.4,
    focalY: 0.6,
    opacity: 0.9,
    dim: 0.15,
    matte: "#161922",
};
const mediaToc = createMediaToc(tocRecipe);
assert.match(mediaToc, /^## Interface: 30300, .*120105.*11509\r\n/);
assert.match(mediaToc, /## Title: \|cffffbd0aOffhand\|r \|cffffffff\[User Media\]\|r/);
assert.match(mediaToc, /## Notes: Your code-free custom Offhand canvas background, generated locally by the Offhand Background Studio\./);
assert.match(mediaToc, /## Author: Offhand Background Studio/);
assert.match(mediaToc, new RegExp(`## Version: ${MEDIA_SCHEMA}\\r\\n`));
assert.match(mediaToc, new RegExp(`## X-Offhand-Media-Schema: ${MEDIA_SCHEMA}\\r\\n`));
assert.match(mediaToc, new RegExp(`## X-Offhand-Generator-Version: ${GENERATOR_VERSION}\\r\\n`));
assert.match(mediaToc, /## X-Offhand-Image-Width: 1440\r\n/);
assert.match(mediaToc, /## X-Offhand-Texture-Height: 4096\r\n/);
assert.match(mediaToc, /## X-Offhand-Suggested-Fit: FILL\r\n/);
assert.match(mediaToc, /## X-Offhand-Zoom: 1\.2500\r\n/);
assert.match(mediaToc, /## X-Offhand-Matte: #161922\r\n/);
assert.match(mediaToc, /## X-Website: https:\/\/offhand-wow\.onrender\.com\/background-studio\.html/);
assert.match(mediaToc, /## IconTexture: Interface\\AddOns\\Offhand\\Media\\OffhandLogo64x64\.blp/);
assert.match(mediaToc, /## LoadOnDemand: 1\r\n## Dependencies: Offhand\r\n\r\n$/);
assert.doesNotMatch(mediaToc, /\.lua|SavedVariables|Companion|X-Offhand-Release/);
assert.equal(PACKAGE_PATHS.includes("Offhand_UserMedia/Background.lua"), false);
assert.throws(() => createMediaToc({ ...tocRecipe, suggestedFit: "FILL\nBackground.lua" }), /suggestedFit/);
assert.throws(() => createMediaToc({ ...tocRecipe, matte: "#161922\nBackground.lua" }), /matte/i);

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

const recipe = {
    schema: MEDIA_SCHEMA,
    generatorVersion: GENERATOR_VERSION,
    textureWidth: 2,
    textureHeight: 2,
    imageWidth: 2,
    imageHeight: 2,
    suggestedFit: "FIT",
    zoom: 1.5,
    focalX: 0.5,
    focalY: 0.5,
    opacity: 1,
    dim: 0.15,
    matte: "#161922",
};
const entries = [
    { name: PACKAGE_FILES.toc, data: createMediaToc(recipe) },
    { name: PACKAGE_FILES.recipe, data: `${JSON.stringify(recipe)}\n` },
    { name: PACKAGE_FILES.readme, data: "README\n" },
    { name: PACKAGE_FILES.texture, data: tga },
];
const zip = buildStoredZip(entries);
const inspected = inspectGeneratedZip(zip);
assert.deepEqual(decodeJson(inspected.get(PACKAGE_FILES.recipe)), recipe);
assert.deepEqual(Array.from(inspected.get(PACKAGE_FILES.texture)), Array.from(tga));
assert.equal(crc32(inspected.get(PACKAGE_FILES.texture)), crc32(tga));
assert.equal(inspected.has("Offhand_UserMedia/Background.lua"), false);

const legacyRecipe = { ...recipe, schema: LEGACY_MEDIA_SCHEMA, generatorVersion: 2 };
const legacyZip = buildStoredZip([
    { name: LEGACY_PACKAGE_PATHS[0], data: "## X-Offhand-Media-Schema: 1\nBackground.lua\n" },
    { name: LEGACY_PACKAGE_PATHS[1], data: "OffhandUserBackground = {}\n" },
    { name: LEGACY_PACKAGE_PATHS[2], data: `${JSON.stringify(legacyRecipe)}\n` },
    { name: LEGACY_PACKAGE_PATHS[3], data: "README\n" },
    { name: LEGACY_PACKAGE_PATHS[4], data: tga },
]);
const inspectedLegacy = inspectGeneratedZip(legacyZip);
assert.equal(inspectedLegacy.has("Offhand_UserMedia/Background.lua"), true,
    "legacy packages should be accepted only for safe local regeneration");

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

function centralOffset(bytes) {
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    return view.getUint32(bytes.length - 22 + 16, true);
}

const encrypted = zip.slice();
new DataView(encrypted.buffer).setUint16(centralOffset(encrypted) + 8, 0x0801, true);
assert.throws(() => inspectGeneratedZip(encrypted), /unsupported|encrypted/i);

const compressed = zip.slice();
new DataView(compressed.buffer).setUint16(centralOffset(compressed) + 10, 8, true);
assert.throws(() => inspectGeneratedZip(compressed), /unsupported|compressed/i);

const linked = zip.slice();
new DataView(linked.buffer).setUint32(centralOffset(linked) + 38, 0xa0000000, true);
assert.throws(() => inspectGeneratedZip(linked), /unsupported|linked/i);

const oldCentralOffset = centralOffset(zip);
const hiddenLocalData = new Uint8Array(zip.length + 1);
hiddenLocalData.set(zip.subarray(0, oldCentralOffset), 0);
hiddenLocalData[oldCentralOffset] = 0x41;
hiddenLocalData.set(zip.subarray(oldCentralOffset), oldCentralOffset + 1);
new DataView(hiddenLocalData.buffer).setUint32(hiddenLocalData.length - 22 + 16, oldCentralOffset + 1, true);
assert.throws(() => inspectGeneratedZip(hiddenLocalData), /hidden|unreferenced|incomplete/i);

const studioHtml = readFileSync(new URL("../Website/background-studio.html", import.meta.url), "utf8");
assert.match(studioHtml, /connect-src 'none'/);
assert.match(studioHtml, /contains no Lua, EXE, DLL, installer, macro, or network code/);
assert.match(studioHtml, /Do not install a media ZIP received from another person directly/);
const renderBlueprint = readFileSync(new URL("../render.yaml", import.meta.url), "utf8");
assert.match(renderBlueprint, /path: \/background-studio\.html[\s\S]*name: Content-Security-Policy/);
assert.match(renderBlueprint, /name: X-Content-Type-Options\s+value: nosniff/);
assert.match(renderBlueprint, /name: X-Frame-Options\s+value: DENY/);
const securityContact = readFileSync(new URL("../Website/.well-known/security.txt", import.meta.url), "utf8");
assert.match(securityContact, /^Contact: https:\/\/github\.com\/N4UX-GIT\/Offhand-DualMonitor\/security\/advisories\/new$/m);
assert.match(securityContact, /^Expires: 2027-10-20T23:59:59Z$/m);

console.log("PASS: Background Studio texture normalization, TGA, ZIP, CRC, and path safety verified.");
