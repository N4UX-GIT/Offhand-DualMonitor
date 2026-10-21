const TEXT_ENCODER = new TextEncoder();
const TEXT_DECODER = new TextDecoder("utf-8", { fatal: true });

export const PACKAGE_LIMITS = Object.freeze({
    maxCompressedBytes: 12 * 1024 * 1024,
    maxUncompressedBytes: 16 * 1024 * 1024,
    maxEntries: 8,
    maxEntryBytes: 10 * 1024 * 1024,
});

export const MEDIA_SCHEMA = 2;
export const LEGACY_MEDIA_SCHEMA = 1;
export const GENERATOR_VERSION = 3;
export const SUPPORTED_INTERFACES = "30300, 120105, 120100, 120007, 120005, 16001, 50504, 40402, 30405, 38000, 20506, 11508, 11509";

export const PACKAGE_FILES = Object.freeze({
    toc: "Offhand_UserMedia/Offhand_UserMedia.toc",
    recipe: "Offhand_UserMedia/BackgroundRecipe.json",
    readme: "Offhand_UserMedia/README.txt",
    texture: "Offhand_UserMedia/Textures/Background.tga",
});

export const PACKAGE_PATHS = Object.freeze(Object.values(PACKAGE_FILES));
export const LEGACY_PACKAGE_PATHS = Object.freeze([
    PACKAGE_FILES.toc,
    "Offhand_UserMedia/Background.lua",
    PACKAGE_FILES.recipe,
    PACKAGE_FILES.readme,
    PACKAGE_FILES.texture,
]);

function validatedMediaRecipe(recipe) {
    const integer = (name, maximum) => {
        const value = Number(recipe?.[name]);
        if (!Number.isInteger(value) || value < 1 || value > maximum) throw new Error(`Invalid ${name}.`);
        return value;
    };
    const decimal = (name, minimum, maximum) => {
        const value = Number(recipe?.[name]);
        if (!Number.isFinite(value) || value < minimum || value > maximum) throw new Error(`Invalid ${name}.`);
        return value;
    };
    const imageWidth = integer("imageWidth", 4096);
    const imageHeight = integer("imageHeight", 4096);
    const textureWidth = integer("textureWidth", 4096);
    const textureHeight = integer("textureHeight", 4096);
    if (imageWidth > textureWidth || imageHeight > textureHeight) throw new Error("Image dimensions exceed the texture.");
    const suggestedFit = String(recipe?.suggestedFit || "").toUpperCase();
    if (!["FILL", "FIT", "STRETCH"].includes(suggestedFit)) throw new Error("Invalid suggestedFit.");
    const matte = String(recipe?.matte || "").toUpperCase();
    if (!/^#[0-9A-F]{6}$/.test(matte)) throw new Error("Invalid matte colour.");
    return {
        imageWidth,
        imageHeight,
        textureWidth,
        textureHeight,
        suggestedFit,
        zoom: decimal("zoom", 1, 2),
        focalX: decimal("focalX", 0, 1),
        focalY: decimal("focalY", 0, 1),
        opacity: decimal("opacity", 0.1, 1),
        dim: decimal("dim", 0, 0.8),
        matte,
    };
}

export function createMediaToc(recipe) {
    const media = validatedMediaRecipe(recipe);
    return `## Interface: ${SUPPORTED_INTERFACES}\r\n## Title: |cffffbd0aOffhand|r |cffffffff[User Media]|r\r\n## Notes: Your code-free custom Offhand canvas background, generated locally by the Offhand Background Studio.\r\n## Author: Offhand Background Studio\r\n## Version: ${MEDIA_SCHEMA}\r\n## X-Offhand-Media-Schema: ${MEDIA_SCHEMA}\r\n## X-Offhand-Generator-Version: ${GENERATOR_VERSION}\r\n## X-Offhand-Image-Width: ${media.imageWidth}\r\n## X-Offhand-Image-Height: ${media.imageHeight}\r\n## X-Offhand-Texture-Width: ${media.textureWidth}\r\n## X-Offhand-Texture-Height: ${media.textureHeight}\r\n## X-Offhand-Suggested-Fit: ${media.suggestedFit}\r\n## X-Offhand-Zoom: ${media.zoom.toFixed(4)}\r\n## X-Offhand-Focal-X: ${media.focalX.toFixed(4)}\r\n## X-Offhand-Focal-Y: ${media.focalY.toFixed(4)}\r\n## X-Offhand-Opacity: ${media.opacity.toFixed(4)}\r\n## X-Offhand-Dim: ${media.dim.toFixed(4)}\r\n## X-Offhand-Matte: ${media.matte}\r\n## X-Website: https://offhand-wow.onrender.com/background-studio.html\r\n## IconTexture: Interface\\AddOns\\Offhand\\Media\\OffhandLogo64x64.blp\r\n## LoadOnDemand: 1\r\n## Dependencies: Offhand\r\n\r\n`;
}

const CRC_TABLE = (() => {
    const table = new Uint32Array(256);
    for (let n = 0; n < 256; n += 1) {
        let c = n;
        for (let k = 0; k < 8; k += 1) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
        table[n] = c >>> 0;
    }
    return table;
})();

export function crc32(bytes) {
    let crc = 0xffffffff;
    for (let i = 0; i < bytes.length; i += 1) crc = CRC_TABLE[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
    return (crc ^ 0xffffffff) >>> 0;
}

export function nextPowerOfTwo(value) {
    let result = 1;
    const target = Math.max(1, Math.ceil(Number(value) || 1));
    while (result < target) result *= 2;
    return result;
}

export function cropFocusAxis(sourceWidth, sourceHeight, targetWidth, targetHeight, fitMode) {
    const dimensions = [sourceWidth, sourceHeight, targetWidth, targetHeight].map(Number);
    if (dimensions.some((value) => !Number.isFinite(value) || value <= 0)) return "none";
    if (fitMode !== "FILL") return "none";

    const sourceAspect = dimensions[0] / dimensions[1];
    const targetAspect = dimensions[2] / dimensions[3];
    if (Math.abs(sourceAspect - targetAspect) < 0.000001) return "none";
    return sourceAspect > targetAspect ? "horizontal" : "vertical";
}

export function calculateFillCrop(sourceWidth, sourceHeight, targetWidth, targetHeight,
    zoom = 1, focusX = 0.5, focusY = 0.5) {
    const dimensions = [sourceWidth, sourceHeight, targetWidth, targetHeight].map(Number);
    if (dimensions.some((value) => !Number.isFinite(value) || value <= 0)) {
        throw new Error("Fill crop dimensions must be positive numbers.");
    }

    const safeZoom = Math.min(2, Math.max(1, Number(zoom) || 1));
    const safeFocusX = Math.min(1, Math.max(0, Number(focusX) || 0));
    const safeFocusY = Math.min(1, Math.max(0, Number(focusY) || 0));
    const sourceAspect = dimensions[0] / dimensions[1];
    const targetAspect = dimensions[2] / dimensions[3];
    let cropWidth = dimensions[0];
    let cropHeight = dimensions[1];

    if (sourceAspect > targetAspect) cropWidth = dimensions[1] * targetAspect;
    else if (sourceAspect < targetAspect) cropHeight = dimensions[0] / targetAspect;

    cropWidth /= safeZoom;
    cropHeight /= safeZoom;
    const horizontal = dimensions[0] - cropWidth > 0.000001;
    const vertical = dimensions[1] - cropHeight > 0.000001;
    return {
        sx: horizontal ? (dimensions[0] - cropWidth) * safeFocusX : 0,
        sy: vertical ? (dimensions[1] - cropHeight) * safeFocusY : 0,
        sw: cropWidth,
        sh: cropHeight,
        horizontal,
        vertical,
        zoom: safeZoom,
    };
}

export function containDimensions(contentWidth, contentHeight, availableWidth, availableHeight) {
    const dimensions = [contentWidth, contentHeight, availableWidth, availableHeight].map(Number);
    if (dimensions.some((value) => !Number.isFinite(value) || value <= 0)) return { width: 1, height: 1 };
    const scale = Math.min(dimensions[2] / dimensions[0], dimensions[3] / dimensions[1]);
    return {
        width: Math.max(1, Math.round(dimensions[0] * scale)),
        height: Math.max(1, Math.round(dimensions[1] * scale)),
    };
}

function readUint24LE(bytes, offset) {
    return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
}

function validImageDimensions(width, height) {
    if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1) {
        throw new Error("The image header contains invalid dimensions.");
    }
    return { width, height };
}

export function inspectImageHeader(bytes, mimeType) {
    if (!(bytes instanceof Uint8Array)) throw new Error("Image header must be binary data.");
    if (mimeType === "image/png") {
        const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
        if (bytes.length < 24 || !pngSignature.every((value, index) => bytes[index] === value)
            || String.fromCharCode(...bytes.subarray(12, 16)) !== "IHDR") {
            throw new Error("The selected file is not a valid PNG image.");
        }
        const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
        return validImageDimensions(view.getUint32(16), view.getUint32(20));
    }

    if (mimeType === "image/jpeg") {
        if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) {
            throw new Error("The selected file is not a valid JPEG image.");
        }
        const startOfFrame = new Set([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf]);
        let cursor = 2;
        while (cursor + 3 < bytes.length) {
            while (cursor < bytes.length && bytes[cursor] !== 0xff) cursor += 1;
            while (cursor < bytes.length && bytes[cursor] === 0xff) cursor += 1;
            if (cursor >= bytes.length) break;
            const marker = bytes[cursor];
            cursor += 1;
            if (marker === 0xd8 || marker === 0xd9 || (marker >= 0xd0 && marker <= 0xd7)) continue;
            if (cursor + 2 > bytes.length) break;
            const segmentLength = (bytes[cursor] << 8) | bytes[cursor + 1];
            if (segmentLength < 2 || cursor + segmentLength > bytes.length) break;
            if (startOfFrame.has(marker)) {
                if (segmentLength < 7) break;
                return validImageDimensions(
                    (bytes[cursor + 5] << 8) | bytes[cursor + 6],
                    (bytes[cursor + 3] << 8) | bytes[cursor + 4],
                );
            }
            cursor += segmentLength;
        }
        throw new Error("The JPEG dimensions could not be verified within the inspected header.");
    }

    if (mimeType === "image/webp") {
        if (bytes.length < 30 || String.fromCharCode(...bytes.subarray(0, 4)) !== "RIFF"
            || String.fromCharCode(...bytes.subarray(8, 12)) !== "WEBP") {
            throw new Error("The selected file is not a valid WebP image.");
        }
        let cursor = 12;
        while (cursor + 8 <= bytes.length) {
            const type = String.fromCharCode(...bytes.subarray(cursor, cursor + 4));
            const view = new DataView(bytes.buffer, bytes.byteOffset + cursor + 4, 4);
            const chunkLength = view.getUint32(0, true);
            const data = cursor + 8;
            if (data + chunkLength > bytes.length) break;
            if (type === "VP8X" && chunkLength >= 10) {
                return validImageDimensions(1 + readUint24LE(bytes, data + 4), 1 + readUint24LE(bytes, data + 7));
            }
            if (type === "VP8L" && chunkLength >= 5 && bytes[data] === 0x2f) {
                const width = 1 + (((bytes[data + 2] & 0x3f) << 8) | bytes[data + 1]);
                const height = 1 + (((bytes[data + 4] & 0x0f) << 10) | (bytes[data + 3] << 2)
                    | ((bytes[data + 2] & 0xc0) >>> 6));
                return validImageDimensions(width, height);
            }
            if (type === "VP8 " && chunkLength >= 10 && bytes[data + 3] === 0x9d
                && bytes[data + 4] === 0x01 && bytes[data + 5] === 0x2a) {
                return validImageDimensions(
                    (bytes[data + 6] | (bytes[data + 7] << 8)) & 0x3fff,
                    (bytes[data + 8] | (bytes[data + 9] << 8)) & 0x3fff,
                );
            }
            cursor = data + chunkLength + (chunkLength & 1);
        }
        throw new Error("The WebP dimensions could not be verified.");
    }
    throw new Error("Choose a PNG, JPEG, or WebP image.");
}

export function chooseTextureDimensions(sourceWidth, sourceHeight, options = {}) {
    const maxDimension = Math.min(4096, Math.max(64, options.maxDimension || 2048));
    const maxTexturePixels = Math.min(maxDimension * maxDimension,
        Math.max(64 * 64, options.maxTexturePixels || (2048 * 1024)));
    if (!Number.isFinite(sourceWidth) || !Number.isFinite(sourceHeight)
        || sourceWidth < 1 || sourceHeight < 1) throw new Error("Invalid source dimensions.");

    let scale = Math.min(1, maxDimension / Math.max(sourceWidth, sourceHeight));
    let contentWidth;
    let contentHeight;
    let textureWidth;
    let textureHeight;
    for (let attempt = 0; attempt < 200; attempt += 1) {
        contentWidth = Math.max(1, Math.round(sourceWidth * scale));
        contentHeight = Math.max(1, Math.round(sourceHeight * scale));
        textureWidth = nextPowerOfTwo(contentWidth);
        textureHeight = nextPowerOfTwo(contentHeight);
        if (textureWidth <= maxDimension && textureHeight <= maxDimension
            && textureWidth * textureHeight <= maxTexturePixels) break;
        scale *= 0.975;
    }
    if (textureWidth * textureHeight > maxTexturePixels) throw new Error("The image cannot be normalized within the texture budget.");
    return { contentWidth, contentHeight, textureWidth, textureHeight, scale };
}

export function encodeTga32(width, height, rgbaBytes) {
    if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1
        || width > 4096 || height > 4096) throw new Error("Invalid TGA dimensions.");
    if (!(rgbaBytes instanceof Uint8Array) && !(rgbaBytes instanceof Uint8ClampedArray)) {
        throw new Error("TGA pixels must be RGBA bytes.");
    }
    if (rgbaBytes.length !== width * height * 4) throw new Error("TGA pixel length does not match its dimensions.");

    const output = new Uint8Array(18 + rgbaBytes.length);
    const view = new DataView(output.buffer);
    output[2] = 2;
    view.setUint16(12, width, true);
    view.setUint16(14, height, true);
    output[16] = 32;
    output[17] = 0x28;
    for (let source = 0, target = 18; source < rgbaBytes.length; source += 4, target += 4) {
        output[target] = rgbaBytes[source + 2];
        output[target + 1] = rgbaBytes[source + 1];
        output[target + 2] = rgbaBytes[source];
        output[target + 3] = rgbaBytes[source + 3];
    }
    return output;
}

export function decodeTga32(bytes) {
    if (!(bytes instanceof Uint8Array) || bytes.length < 18) throw new Error("The TGA is truncated.");
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const idLength = bytes[0];
    const colorMapType = bytes[1];
    const imageType = bytes[2];
    const width = view.getUint16(12, true);
    const height = view.getUint16(14, true);
    const depth = bytes[16];
    const descriptor = bytes[17];
    if (colorMapType !== 0 || imageType !== 2 || depth !== 32 || width < 1 || height < 1) {
        throw new Error("Only uncompressed 32-bit TGA files generated by Offhand are supported.");
    }
    const offset = 18 + idLength;
    const required = width * height * 4;
    if (required > PACKAGE_LIMITS.maxEntryBytes || offset + required !== bytes.length) {
        throw new Error("The TGA dimensions or payload are invalid.");
    }
    const topOrigin = (descriptor & 0x20) !== 0;
    const rgba = new Uint8ClampedArray(required);
    for (let y = 0; y < height; y += 1) {
        const sourceY = topOrigin ? y : (height - 1 - y);
        for (let x = 0; x < width; x += 1) {
            const source = offset + (sourceY * width + x) * 4;
            const target = (y * width + x) * 4;
            rgba[target] = bytes[source + 2];
            rgba[target + 1] = bytes[source + 1];
            rgba[target + 2] = bytes[source];
            rgba[target + 3] = bytes[source + 3];
        }
    }
    return { width, height, rgba };
}

function writeUint16(target, offset, value) {
    new DataView(target.buffer, target.byteOffset, target.byteLength).setUint16(offset, value, true);
}

function writeUint32(target, offset, value) {
    new DataView(target.buffer, target.byteOffset, target.byteLength).setUint32(offset, value >>> 0, true);
}

function normalizedEntry(entry) {
    const name = String(entry.name || "");
    if (!isSafePackagePath(name)) throw new Error(`Unsafe package path: ${name || "(empty)"}`);
    const bytes = typeof entry.data === "string" ? TEXT_ENCODER.encode(entry.data) : entry.data;
    if (!(bytes instanceof Uint8Array)) throw new Error(`Invalid data for ${name}.`);
    if (bytes.length > PACKAGE_LIMITS.maxEntryBytes) throw new Error(`${name} exceeds the entry limit.`);
    return { name, nameBytes: TEXT_ENCODER.encode(name), bytes, crc: crc32(bytes) };
}

export function isSafePackagePath(name) {
    return typeof name === "string" && name.length > 0 && name.length <= 180
        && !name.includes("\\") && !name.includes("\0") && !name.startsWith("/")
        && !/^[A-Za-z]:/.test(name) && name.split("/").every((part) => part && part !== "." && part !== "..");
}

export function buildStoredZip(entries) {
    if (!Array.isArray(entries) || entries.length < 1 || entries.length > PACKAGE_LIMITS.maxEntries) {
        throw new Error("Invalid package entry count.");
    }
    const files = entries.map(normalizedEntry);
    const unique = new Set(files.map((file) => file.name));
    if (unique.size !== files.length) throw new Error("Duplicate package paths are not allowed.");
    const totalData = files.reduce((sum, file) => sum + file.bytes.length, 0);
    if (totalData > PACKAGE_LIMITS.maxUncompressedBytes) throw new Error("Package exceeds the uncompressed size limit.");

    const localParts = [];
    const centralParts = [];
    let localOffset = 0;
    for (const file of files) {
        const local = new Uint8Array(30 + file.nameBytes.length + file.bytes.length);
        writeUint32(local, 0, 0x04034b50);
        writeUint16(local, 4, 20);
        writeUint16(local, 6, 0x0800);
        writeUint16(local, 8, 0);
        writeUint32(local, 14, file.crc);
        writeUint32(local, 18, file.bytes.length);
        writeUint32(local, 22, file.bytes.length);
        writeUint16(local, 26, file.nameBytes.length);
        local.set(file.nameBytes, 30);
        local.set(file.bytes, 30 + file.nameBytes.length);
        localParts.push(local);

        const central = new Uint8Array(46 + file.nameBytes.length);
        writeUint32(central, 0, 0x02014b50);
        writeUint16(central, 4, 20);
        writeUint16(central, 6, 20);
        writeUint16(central, 8, 0x0800);
        writeUint16(central, 10, 0);
        writeUint32(central, 16, file.crc);
        writeUint32(central, 20, file.bytes.length);
        writeUint32(central, 24, file.bytes.length);
        writeUint16(central, 28, file.nameBytes.length);
        writeUint32(central, 42, localOffset);
        central.set(file.nameBytes, 46);
        centralParts.push(central);
        localOffset += local.length;
    }

    const centralLength = centralParts.reduce((sum, part) => sum + part.length, 0);
    const end = new Uint8Array(22);
    writeUint32(end, 0, 0x06054b50);
    writeUint16(end, 8, files.length);
    writeUint16(end, 10, files.length);
    writeUint32(end, 12, centralLength);
    writeUint32(end, 16, localOffset);

    const output = new Uint8Array(localOffset + centralLength + end.length);
    let offset = 0;
    for (const part of [...localParts, ...centralParts, end]) {
        output.set(part, offset);
        offset += part.length;
    }
    return output;
}

function findEndOfCentralDirectory(bytes) {
    const lowerBound = Math.max(0, bytes.length - 65557);
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    for (let offset = bytes.length - 22; offset >= lowerBound; offset -= 1) {
        if (view.getUint32(offset, true) === 0x06054b50) return offset;
    }
    throw new Error("The ZIP end record is missing.");
}

export function inspectGeneratedZip(bytes, limits = PACKAGE_LIMITS) {
    if (!(bytes instanceof Uint8Array)) throw new Error("Package must be binary data.");
    if (bytes.length > limits.maxCompressedBytes) throw new Error("The ZIP exceeds the compressed size limit.");
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const endOffset = findEndOfCentralDirectory(bytes);
    const disk = view.getUint16(endOffset + 4, true);
    const centralDisk = view.getUint16(endOffset + 6, true);
    const entriesOnDisk = view.getUint16(endOffset + 8, true);
    const entryCount = view.getUint16(endOffset + 10, true);
    const centralSize = view.getUint32(endOffset + 12, true);
    const centralOffset = view.getUint32(endOffset + 16, true);
    const commentLength = view.getUint16(endOffset + 20, true);
    if (disk !== 0 || centralDisk !== 0 || entriesOnDisk !== entryCount || entryCount < 1
        || entryCount > limits.maxEntries || commentLength !== 0
        || centralOffset + centralSize !== endOffset || endOffset + 22 !== bytes.length) {
        throw new Error("Unsupported or malformed ZIP structure.");
    }

    const acceptedPathSets = [PACKAGE_PATHS, LEGACY_PACKAGE_PATHS];
    const allowed = new Set(acceptedPathSets.flat());
    const entries = new Map();
    const localRanges = [];
    let totalUncompressed = 0;
    let cursor = centralOffset;
    for (let index = 0; index < entryCount; index += 1) {
        if (cursor + 46 > endOffset || view.getUint32(cursor, true) !== 0x02014b50) throw new Error("Malformed ZIP directory.");
        const flags = view.getUint16(cursor + 8, true);
        const method = view.getUint16(cursor + 10, true);
        const expectedCrc = view.getUint32(cursor + 16, true);
        const compressedSize = view.getUint32(cursor + 20, true);
        const uncompressedSize = view.getUint32(cursor + 24, true);
        const nameLength = view.getUint16(cursor + 28, true);
        const extraLength = view.getUint16(cursor + 30, true);
        const entryCommentLength = view.getUint16(cursor + 32, true);
        const diskNumberStart = view.getUint16(cursor + 34, true);
        const externalAttributes = view.getUint32(cursor + 38, true);
        const localHeaderOffset = view.getUint32(cursor + 42, true);
        const nameStart = cursor + 46;
        const next = nameStart + nameLength + extraLength + entryCommentLength;
        if (next > endOffset || method !== 0 || flags !== 0x0800 || compressedSize !== uncompressedSize
            || extraLength !== 0 || entryCommentLength !== 0 || diskNumberStart !== 0
            || uncompressedSize > limits.maxEntryBytes || (externalAttributes >>> 28) === 0x0a) {
            throw new Error("The ZIP contains an unsupported, encrypted, compressed, oversized, or linked entry.");
        }
        const name = TEXT_DECODER.decode(bytes.subarray(nameStart, nameStart + nameLength));
        if (!isSafePackagePath(name) || !allowed.has(name) || entries.has(name)) throw new Error(`Unexpected package entry: ${name}`);
        totalUncompressed += uncompressedSize;
        if (totalUncompressed > limits.maxUncompressedBytes) throw new Error("The ZIP exceeds the uncompressed size limit.");

        if (localHeaderOffset + 30 > centralOffset || view.getUint32(localHeaderOffset, true) !== 0x04034b50) {
            throw new Error("The ZIP local header is invalid.");
        }
        const localFlags = view.getUint16(localHeaderOffset + 6, true);
        const localMethod = view.getUint16(localHeaderOffset + 8, true);
        const localCrc = view.getUint32(localHeaderOffset + 14, true);
        const localCompressedSize = view.getUint32(localHeaderOffset + 18, true);
        const localUncompressedSize = view.getUint32(localHeaderOffset + 22, true);
        const localNameLength = view.getUint16(localHeaderOffset + 26, true);
        const localExtraLength = view.getUint16(localHeaderOffset + 28, true);
        const localNameStart = localHeaderOffset + 30;
        const dataStart = localNameStart + localNameLength + localExtraLength;
        const dataEnd = dataStart + compressedSize;
        if (dataStart > centralOffset || dataEnd > centralOffset) throw new Error("The ZIP entry payload is invalid.");
        const localName = TEXT_DECODER.decode(bytes.subarray(localNameStart, localNameStart + localNameLength));
        if (localFlags !== flags || localMethod !== method || localCrc !== expectedCrc
            || localCompressedSize !== compressedSize || localUncompressedSize !== uncompressedSize
            || localExtraLength !== 0 || localName !== name) {
            throw new Error("The ZIP local header does not match its directory entry.");
        }
        const data = bytes.slice(dataStart, dataEnd);
        if (crc32(data) !== expectedCrc) throw new Error(`CRC check failed for ${name}.`);
        entries.set(name, data);
        localRanges.push({ start: localHeaderOffset, end: dataEnd });
        cursor = next;
    }
    localRanges.sort((left, right) => left.start - right.start);
    let expectedLocalOffset = 0;
    for (const range of localRanges) {
        if (range.start !== expectedLocalOffset || range.end < range.start) {
            throw new Error("The ZIP contains hidden, overlapping, or unreferenced local data.");
        }
        expectedLocalOffset = range.end;
    }
    const matchesAcceptedLayout = acceptedPathSets.some((paths) =>
        entries.size === paths.length && paths.every((path) => entries.has(path)));
    if (cursor !== endOffset || expectedLocalOffset !== centralOffset || !matchesAcceptedLayout) {
        throw new Error("The ZIP is incomplete.");
    }
    return entries;
}

export function decodeJson(bytes) {
    return JSON.parse(TEXT_DECODER.decode(bytes));
}

export function formatBytes(value) {
    const bytes = Math.max(0, Number(value) || 0);
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KiB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MiB`;
}
