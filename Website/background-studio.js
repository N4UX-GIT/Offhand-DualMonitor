import {
    PACKAGE_LIMITS,
    PACKAGE_FILES,
    GENERATOR_VERSION,
    LEGACY_MEDIA_SCHEMA,
    MEDIA_SCHEMA,
    buildStoredZip,
    calculateFillCrop,
    chooseTextureDimensions,
    containDimensions,
    createMediaToc,
    decodeJson,
    decodeTga32,
    encodeTga32,
    formatBytes,
    inspectGeneratedZip,
    inspectImageHeader,
} from "./background-studio-core.mjs?v=20261020-2";

const MAX_IMAGE_BYTES = 25 * 1024 * 1024;
const MAX_IMAGE_PIXELS = 40 * 1000 * 1000;
const elements = {
    imageInput: document.querySelector("#image-input"),
    packageInput: document.querySelector("#package-input"),
    imageDrop: document.querySelector("#image-drop-zone"),
    packageDrop: document.querySelector("#package-drop-zone"),
    imageTab: document.querySelector("#tab-image"),
    packageTab: document.querySelector("#tab-package"),
    imagePanel: document.querySelector("#source-image"),
    packagePanel: document.querySelector("#source-package"),
    sourceSummary: document.querySelector("#source-summary"),
    controls: document.querySelector("#studio-controls"),
    preset: document.querySelector("#workspace-preset"),
    customDimensions: document.querySelector("#custom-dimensions"),
    width: document.querySelector("#workspace-width"),
    height: document.querySelector("#workspace-height"),
    zoom: document.querySelector("#image-zoom"),
    zoomValue: document.querySelector("#image-zoom-value"),
    zoomControl: document.querySelector("#zoom-control"),
    focusX: document.querySelector("#focus-x"),
    focusY: document.querySelector("#focus-y"),
    focusXValue: document.querySelector("#focus-x-value"),
    focusYValue: document.querySelector("#focus-y-value"),
    focusXControl: document.querySelector("#focus-x-control"),
    focusYControl: document.querySelector("#focus-y-control"),
    focusGuidance: document.querySelector("#focus-guidance"),
    opacity: document.querySelector("#image-opacity"),
    opacityValue: document.querySelector("#image-opacity-value"),
    dim: document.querySelector("#image-dim"),
    dimValue: document.querySelector("#image-dim-value"),
    matte: document.querySelector("#matte-color"),
    matteValue: document.querySelector("#matte-color-value"),
    canvas: document.querySelector("#preview-canvas"),
    overviewCanvas: document.querySelector("#overview-canvas"),
    overviewScreen: document.querySelector("#overview-offhand-screen"),
    overviewEmpty: document.querySelector("#overview-empty"),
    previewEmpty: document.querySelector("#preview-empty"),
    previewViewport: document.querySelector("#preview-viewport"),
    stage: document.querySelector(".workspace-stage"),
    sourceFact: document.querySelector("#fact-source"),
    textureFact: document.querySelector("#fact-texture"),
    packageFact: document.querySelector("#fact-package"),
    status: document.querySelector("#studio-status"),
    generate: document.querySelector("#generate-button"),
};

const state = {
    sourceCanvas: null,
    sourceLabel: "",
    packageRecipe: null,
    busy: false,
};

function setStatus(message, kind = "") {
    elements.status.textContent = message;
    elements.status.className = `studio-alert${kind ? ` studio-alert-${kind}` : ""}`;
}

function setBusy(busy) {
    state.busy = busy;
    elements.generate.disabled = busy || !state.sourceCanvas;
    elements.generate.textContent = busy ? "Generating package…" : "Generate media package";
}

function switchSource(kind) {
    const imageMode = kind === "image";
    elements.imageTab.classList.toggle("is-active", imageMode);
    elements.packageTab.classList.toggle("is-active", !imageMode);
    elements.imageTab.setAttribute("aria-selected", String(imageMode));
    elements.packageTab.setAttribute("aria-selected", String(!imageMode));
    elements.imagePanel.hidden = !imageMode;
    elements.packagePanel.hidden = imageMode;
}

function workspaceDimensions() {
    if (elements.preset.value === "landscape") return { width: 2560, height: 1440 };
    if (elements.preset.value === "square") return { width: 1600, height: 1600 };
    if (elements.preset.value === "custom") {
        return {
            width: Math.min(8192, Math.max(320, Number(elements.width.value) || 1440)),
            height: Math.min(8192, Math.max(320, Number(elements.height.value) || 2560)),
        };
    }
    return { width: 1440, height: 2560 };
}

function selectedFitMode() {
    return document.querySelector('input[name="fit-mode"]:checked')?.value || "FILL";
}

function recipeFromControls(texture) {
    const workspace = workspaceDimensions();
    return {
        schema: MEDIA_SCHEMA,
        generatorVersion: GENERATOR_VERSION,
        imageWidth: texture.contentWidth,
        imageHeight: texture.contentHeight,
        textureWidth: texture.textureWidth,
        textureHeight: texture.textureHeight,
        suggestedFit: selectedFitMode(),
        zoom: Number(elements.zoom.value) / 100,
        focalX: Number(elements.focusX.value) / 100,
        focalY: Number(elements.focusY.value) / 100,
        opacity: Number(elements.opacity.value) / 100,
        dim: Number(elements.dim.value) / 100,
        matte: elements.matte.value.toUpperCase(),
        previewWorkspaceWidth: workspace.width,
        previewWorkspaceHeight: workspace.height,
    };
}

function namedFocusValue(value, start, end) {
    const number = Number(value);
    const position = number < 34 ? start : number > 66 ? end : "Center";
    return `${position}, ${number}%`;
}

function updateFocusControls(width, height) {
    const mode = selectedFitMode();
    const zoomAvailable = mode === "FILL";
    elements.zoom.disabled = !zoomAvailable;
    elements.zoomControl.classList.toggle("is-disabled", !zoomAvailable);

    let horizontal = false;
    let vertical = false;
    if (state.sourceCanvas && mode === "FILL") {
        const crop = calculateFillCrop(
            state.sourceCanvas.width,
            state.sourceCanvas.height,
            width,
            height,
            Number(elements.zoom.value) / 100,
        );
        horizontal = crop.horizontal;
        vertical = crop.vertical;
    }

    elements.focusX.disabled = !horizontal;
    elements.focusY.disabled = !vertical;
    elements.focusXControl.classList.toggle("is-disabled", !horizontal);
    elements.focusYControl.classList.toggle("is-disabled", !vertical);

    if (!state.sourceCanvas) {
        elements.focusGuidance.textContent = "Focus becomes available when Fill needs to crop the image.";
    } else if (mode === "FIT") {
        elements.focusGuidance.textContent = "Fit shows the whole image, so crop focus does not change the preview.";
    } else if (mode === "STRETCH") {
        elements.focusGuidance.textContent = "Stretch uses the whole image, so crop focus does not change the preview.";
    } else if (horizontal && vertical) {
        elements.focusGuidance.textContent = "Zoom crops both axes. Use both focus controls to choose the area that stays visible.";
    } else if (horizontal) {
        elements.focusGuidance.textContent = "This image is wider than the Offhand background. Horizontal focus chooses which left-to-right area stays visible.";
    } else if (vertical) {
        elements.focusGuidance.textContent = "This image is taller than the Offhand background. Vertical focus chooses which top-to-bottom area stays visible.";
    } else {
        elements.focusGuidance.textContent = "The image and Offhand background have the same shape, so Fill does not crop either axis.";
    }
}

function updateOutputs() {
    elements.zoomValue.textContent = `${elements.zoom.value}%`;
    elements.focusXValue.textContent = namedFocusValue(elements.focusX.value, "Left", "Right");
    elements.focusYValue.textContent = namedFocusValue(elements.focusY.value, "Top", "Bottom");
    elements.opacityValue.textContent = `${elements.opacity.value}%`;
    elements.dimValue.textContent = `${elements.dim.value}%`;
    elements.matteValue.textContent = elements.matte.value.toUpperCase();
}

function fitPreviewStage(width, height) {
    const availableWidth = Math.max(1, elements.previewViewport.clientWidth - 16);
    const viewportWidth = window.innerWidth;
    const heightLimit = viewportWidth <= 620
        ? Math.min(480, Math.max(300, window.innerHeight * 0.58))
        : viewportWidth <= 900
            ? Math.min(560, Math.max(340, window.innerHeight * 0.62))
            : Math.min(640, Math.max(360, window.innerHeight * 0.62));
    const availableHeight = Math.max(1, heightLimit - 16);
    const contained = containDimensions(width, height, availableWidth, availableHeight);
    elements.stage.style.width = `${contained.width}px`;
    elements.stage.style.height = `${contained.height}px`;
    elements.previewViewport.style.height = `${contained.height + 16}px`;
}

function updateMonitorOverview(width, height) {
    const size = containDimensions(width, height, 180, 148);
    elements.overviewScreen.style.width = `${size.width}px`;
    elements.overviewScreen.style.height = `${size.height}px`;
    elements.overviewCanvas.width = elements.canvas.width;
    elements.overviewCanvas.height = elements.canvas.height;
    elements.overviewCanvas.getContext("2d").drawImage(elements.canvas, 0, 0);
    elements.overviewEmpty.hidden = Boolean(state.sourceCanvas);
}

function drawPreview() {
    updateOutputs();
    const { width, height } = workspaceDimensions();
    updateFocusControls(width, height);
    const maxPreview = 1100;
    const scale = Math.min(1, maxPreview / Math.max(width, height));
    const previewWidth = Math.max(1, Math.round(width * scale));
    const previewHeight = Math.max(1, Math.round(height * scale));
    elements.canvas.width = previewWidth;
    elements.canvas.height = previewHeight;
    elements.stage.style.aspectRatio = `${width} / ${height}`;
    fitPreviewStage(width, height);
    const context = elements.canvas.getContext("2d", { alpha: false });
    context.fillStyle = elements.matte.value;
    context.fillRect(0, 0, previewWidth, previewHeight);

    if (!state.sourceCanvas) {
        elements.previewEmpty.hidden = false;
        updateMonitorOverview(width, height);
        return;
    }
    elements.previewEmpty.hidden = true;
    const sourceWidth = state.sourceCanvas.width;
    const sourceHeight = state.sourceCanvas.height;
    const mode = selectedFitMode();
    const focusX = Number(elements.focusX.value) / 100;
    const focusY = Number(elements.focusY.value) / 100;
    let sx = 0;
    let sy = 0;
    let sw = sourceWidth;
    let sh = sourceHeight;
    let dx = 0;
    let dy = 0;
    let dw = previewWidth;
    let dh = previewHeight;

    if (mode === "FILL") {
        const crop = calculateFillCrop(sourceWidth, sourceHeight, previewWidth, previewHeight,
            Number(elements.zoom.value) / 100, focusX, focusY);
        ({ sx, sy, sw, sh } = crop);
    } else if (mode === "FIT") {
        const fitScale = Math.min(previewWidth / sourceWidth, previewHeight / sourceHeight);
        dw = sourceWidth * fitScale;
        dh = sourceHeight * fitScale;
        dx = (previewWidth - dw) / 2;
        dy = (previewHeight - dh) / 2;
    }

    context.save();
    context.globalAlpha = Number(elements.opacity.value) / 100;
    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = "high";
    context.drawImage(state.sourceCanvas, sx, sy, sw, sh, dx, dy, dw, dh);
    context.restore();
    const dim = Number(elements.dim.value) / 100;
    if (dim > 0) {
        context.fillStyle = `rgba(0, 0, 0, ${dim})`;
        context.fillRect(0, 0, previewWidth, previewHeight);
    }
    updateMonitorOverview(width, height);
}

function applyRecipe(recipe) {
    const fit = ["FILL", "FIT", "STRETCH"].includes(recipe.suggestedFit) ? recipe.suggestedFit : "FILL";
    const radio = document.querySelector(`input[name="fit-mode"][value="${fit}"]`);
    if (radio) radio.checked = true;
    const zoom = Number(recipe.zoom);
    elements.zoom.value = String(Math.round(Math.min(2, Math.max(1, Number.isFinite(zoom) ? zoom : 1)) * 100));
    elements.focusX.value = String(Math.round(Math.min(1, Math.max(0, Number(recipe.focalX) || 0.5)) * 100));
    elements.focusY.value = String(Math.round(Math.min(1, Math.max(0, Number(recipe.focalY) || 0.5)) * 100));
    elements.opacity.value = String(Math.round(Math.min(1, Math.max(0.1, Number(recipe.opacity) || 1)) * 100));
    elements.dim.value = String(Math.round(Math.min(0.8, Math.max(0, Number(recipe.dim) || 0)) * 100));
    if (/^#[0-9A-Fa-f]{6}$/.test(recipe.matte || "")) elements.matte.value = recipe.matte;
    const width = Number(recipe.previewWorkspaceWidth);
    const height = Number(recipe.previewWorkspaceHeight);
    if (width >= 320 && height >= 320 && width <= 8192 && height <= 8192) {
        elements.preset.value = "custom";
        elements.width.value = String(width);
        elements.height.value = String(height);
        elements.customDimensions.hidden = false;
    }
}

async function imageFileToCanvas(file) {
    if (!file || file.size < 1 || file.size > MAX_IMAGE_BYTES) throw new Error("Choose an image between 1 byte and 25 MiB.");
    if (!["image/png", "image/jpeg", "image/webp"].includes(file.type)) throw new Error("Choose a PNG, JPEG, or WebP image.");
    const headerLength = Math.min(file.size, 4 * 1024 * 1024);
    const header = new Uint8Array(await file.slice(0, headerLength).arrayBuffer());
    const dimensions = inspectImageHeader(header, file.type);
    if (dimensions.width * dimensions.height > MAX_IMAGE_PIXELS) {
        throw new Error("The image header exceeds the 40 megapixel safety limit.");
    }
    const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
    try {
        if (bitmap.width !== dimensions.width || bitmap.height !== dimensions.height) {
            throw new Error("The decoded image dimensions do not match its header.");
        }
        if (bitmap.width * bitmap.height > MAX_IMAGE_PIXELS) throw new Error("The decoded image exceeds the 40 megapixel safety limit.");
        const canvas = document.createElement("canvas");
        canvas.width = bitmap.width;
        canvas.height = bitmap.height;
        canvas.getContext("2d").drawImage(bitmap, 0, 0);
        return canvas;
    } finally {
        bitmap.close();
    }
}

async function loadImageFile(file) {
    try {
        setStatus("Decoding the selected image locally…", "working");
        const canvas = await imageFileToCanvas(file);
        state.sourceCanvas = canvas;
        state.sourceLabel = "New image";
        state.packageRecipe = null;
        elements.controls.disabled = false;
        elements.sourceSummary.textContent = `${file.name} · ${canvas.width}×${canvas.height} · ${formatBytes(file.size)}`;
        elements.sourceFact.textContent = `${canvas.width}×${canvas.height}`;
        const texture = chooseTextureDimensions(canvas.width, canvas.height);
        elements.textureFact.textContent = `${texture.textureWidth}×${texture.textureHeight} TGA`;
        elements.packageFact.textContent = `About ${formatBytes(texture.textureWidth * texture.textureHeight * 4)}`;
        setStatus("Image ready. Adjust the preview, then generate the package.", "success");
        setBusy(false);
        drawPreview();
    } catch (error) {
        state.sourceCanvas = null;
        elements.controls.disabled = true;
        setBusy(false);
        setStatus(error instanceof Error ? error.message : "The image could not be opened.", "error");
    }
}

function validateRecipe(recipe, tga) {
    if (!recipe || ![LEGACY_MEDIA_SCHEMA, MEDIA_SCHEMA].includes(Number(recipe.schema))) {
        throw new Error("The package recipe schema is unsupported.");
    }
    const contentWidth = Number(recipe.imageWidth);
    const contentHeight = Number(recipe.imageHeight);
    if (!Number.isInteger(contentWidth) || !Number.isInteger(contentHeight) || contentWidth < 1 || contentHeight < 1
        || contentWidth > tga.width || contentHeight > tga.height
        || Number(recipe.textureWidth) !== tga.width || Number(recipe.textureHeight) !== tga.height) {
        throw new Error("The package recipe does not match its texture.");
    }
    return { contentWidth, contentHeight };
}

async function loadExistingPackage(file) {
    try {
        if (!file || file.size < 1 || file.size > PACKAGE_LIMITS.maxCompressedBytes) throw new Error("Choose a package no larger than 12 MiB.");
        setStatus("Inspecting the package locally…", "working");
        const entries = inspectGeneratedZip(new Uint8Array(await file.arrayBuffer()));
        const recipe = decodeJson(entries.get(PACKAGE_FILES.recipe));
        const tga = decodeTga32(entries.get(PACKAGE_FILES.texture));
        const { contentWidth, contentHeight } = validateRecipe(recipe, tga);
        const textureCanvas = document.createElement("canvas");
        textureCanvas.width = tga.width;
        textureCanvas.height = tga.height;
        textureCanvas.getContext("2d").putImageData(new ImageData(tga.rgba, tga.width, tga.height), 0, 0);
        const sourceCanvas = document.createElement("canvas");
        sourceCanvas.width = contentWidth;
        sourceCanvas.height = contentHeight;
        sourceCanvas.getContext("2d").drawImage(textureCanvas, 0, 0, contentWidth, contentHeight, 0, 0, contentWidth, contentHeight);

        state.sourceCanvas = sourceCanvas;
        state.sourceLabel = "Existing package";
        state.packageRecipe = recipe;
        applyRecipe(recipe);
        elements.controls.disabled = false;
        elements.sourceSummary.textContent = `${file.name} · schema ${recipe.schema} · generator ${recipe.generatorVersion || "unknown"}`;
        elements.sourceFact.textContent = `${contentWidth}×${contentHeight} packaged image`;
        elements.textureFact.textContent = `${tga.width}×${tga.height} TGA`;
        elements.packageFact.textContent = formatBytes(file.size);
        if (Number(recipe.schema) === LEGACY_MEDIA_SCHEMA) {
            setStatus("Legacy package passed local safety checks. Generate a replacement to convert it to the current code-free format.", "success");
        } else {
            setStatus("Package passed structural, path, size, and CRC checks. You can repair or regenerate it.", "success");
        }
        setBusy(false);
        drawPreview();
    } catch (error) {
        state.sourceCanvas = null;
        elements.controls.disabled = true;
        setBusy(false);
        setStatus(error instanceof Error ? error.message : "The package could not be inspected.", "error");
    }
}

function createPackageText(recipe) {
    const toc = createMediaToc(recipe);
    const readme = `OFFHAND USER MEDIA\r\n==================\r\n\r\nThis package was generated locally in your browser by the Offhand Background Studio.\r\nYour source image was not uploaded.\r\n\r\nSECURITY\r\nThis package contains one TGA texture, declarative TOC metadata, a JSON recipe, and this text file.\r\nIt contains no Lua, executable, DLL, macro, installer, or network code.\r\nDo not install media packages received from other people directly. Open an existing package with the official Background Studio and generate a clean replacement instead.\r\n\r\nINSTALL\r\n1. Close World of Warcraft completely.\r\n2. Extract Offhand_UserMedia beside Offhand in the client's Interface\\AddOns folder.\r\n3. Start WoW and verify both Offhand and Offhand User Media are enabled.\r\n4. Open /offhand, select Themes, scroll to 4. Background Studio, and enable Use installed custom background.\r\n\r\nUPDATE\r\nReturn to the Background Studio and choose Update package, or create a new package.\r\nClose WoW before replacing this folder.\r\n\r\nREMOVE\r\nDisable the custom background, close WoW, then delete only Offhand_UserMedia.\r\n`;
    return { toc, readme };
}

async function generatePackage() {
    if (!state.sourceCanvas || state.busy) return;
    try {
        setBusy(true);
        setStatus("Normalizing the image and building the package locally…", "working");
        await new Promise((resolve) => requestAnimationFrame(resolve));
        const dimensions = chooseTextureDimensions(state.sourceCanvas.width, state.sourceCanvas.height);
        const textureCanvas = document.createElement("canvas");
        textureCanvas.width = dimensions.textureWidth;
        textureCanvas.height = dimensions.textureHeight;
        const context = textureCanvas.getContext("2d", { willReadFrequently: true });
        context.clearRect(0, 0, textureCanvas.width, textureCanvas.height);
        context.imageSmoothingEnabled = true;
        context.imageSmoothingQuality = "high";
        context.drawImage(state.sourceCanvas, 0, 0, state.sourceCanvas.width, state.sourceCanvas.height,
            0, 0, dimensions.contentWidth, dimensions.contentHeight);
        const pixels = context.getImageData(0, 0, textureCanvas.width, textureCanvas.height).data;
        const tga = encodeTga32(textureCanvas.width, textureCanvas.height, pixels);
        const recipe = recipeFromControls(dimensions);
        const recipeText = `${JSON.stringify(recipe, null, 2)}\n`;
        const text = createPackageText(recipe);
        const zip = buildStoredZip([
            { name: PACKAGE_FILES.toc, data: text.toc },
            { name: PACKAGE_FILES.recipe, data: recipeText },
            { name: PACKAGE_FILES.readme, data: text.readme },
            { name: PACKAGE_FILES.texture, data: tga },
        ]);
        const blob = new Blob([zip], { type: "application/zip" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = "Offhand_UserMedia.zip";
        link.rel = "noopener";
        document.body.appendChild(link);
        link.click();
        link.remove();
        setTimeout(() => URL.revokeObjectURL(url), 2000);
        elements.textureFact.textContent = `${dimensions.textureWidth}×${dimensions.textureHeight} TGA`;
        elements.packageFact.textContent = formatBytes(zip.length);
        setStatus("Package generated. Close WoW before extracting it beside the main Offhand addon.", "success");
    } catch (error) {
        setStatus(error instanceof Error ? error.message : "The package could not be generated.", "error");
    } finally {
        setBusy(false);
    }
}

function bindDropZone(zone, handler) {
    for (const eventName of ["dragenter", "dragover"]) {
        zone.addEventListener(eventName, (event) => {
            event.preventDefault();
            if (event.dataTransfer) event.dataTransfer.dropEffect = "copy";
            zone.classList.add("is-dragging");
        });
    }
    for (const eventName of ["dragleave", "drop"]) {
        zone.addEventListener(eventName, (event) => {
            event.preventDefault();
            zone.classList.remove("is-dragging");
        });
    }
    zone.addEventListener("drop", (event) => {
        const files = event.dataTransfer?.files;
        if (files?.length === 1) handler(files[0]);
        else setStatus("Drop exactly one file.", "error");
    });
}

elements.imageTab.addEventListener("click", () => switchSource("image"));
elements.packageTab.addEventListener("click", () => switchSource("package"));
elements.imageInput.addEventListener("change", () => loadImageFile(elements.imageInput.files?.[0]));
elements.packageInput.addEventListener("change", () => loadExistingPackage(elements.packageInput.files?.[0]));
bindDropZone(elements.imageDrop, loadImageFile);
bindDropZone(elements.packageDrop, loadExistingPackage);
elements.preset.addEventListener("change", () => {
    elements.customDimensions.hidden = elements.preset.value !== "custom";
    drawPreview();
});
for (const input of [elements.width, elements.height, elements.zoom, elements.focusX, elements.focusY,
    elements.opacity, elements.dim, elements.matte, ...document.querySelectorAll('input[name="fit-mode"]')]) {
    input.addEventListener("input", drawPreview);
    input.addEventListener("change", drawPreview);
}
elements.generate.addEventListener("click", generatePackage);
if ("ResizeObserver" in window) {
    new ResizeObserver(() => {
        const { width, height } = workspaceDimensions();
        fitPreviewStage(width, height);
    }).observe(elements.previewViewport);
} else {
    window.addEventListener("resize", () => {
        const { width, height } = workspaceDimensions();
        fitPreviewStage(width, height);
    });
}
drawPreview();
