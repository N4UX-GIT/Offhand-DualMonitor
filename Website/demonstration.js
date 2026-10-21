/* Code-rendered concept scene. Coordinates describe the physical displays,
   not the combined native WoW canvas or any game APIs. */
(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    const gameplayVideo = $('gameplay-recording');
    const gameplayWatch = $('gameplay-watch');
    gameplayWatch.hidden = false;
    gameplayWatch.addEventListener('click', async () => {
        gameplayWatch.disabled = true;
        try {
            await gameplayVideo.play();
            gameplayVideo.focus({ preventScroll: true });
        } catch {
            // Leave the native controls and retry button usable if play is rejected.
            gameplayWatch.hidden = false;
        } finally { gameplayWatch.disabled = false; }
    });
    gameplayVideo.addEventListener('play', () => { gameplayWatch.hidden = true; });
    gameplayVideo.addEventListener('ended', () => {
        gameplayWatch.querySelector('span').textContent = 'Replay · 30 seconds';
        gameplayWatch.setAttribute('aria-label', 'Replay the 30-second in-game demonstration');
        gameplayWatch.hidden = false;
    });
    const layoutExplorer = $('layout-explorer');
    const layoutPreferenceKey = 'offhand.demo.layouts-expanded';
    try { layoutExplorer.open = localStorage.getItem(layoutPreferenceKey) === 'true'; }
    catch { /* Keep the disclosure usable when browser storage is unavailable. */ }
    layoutExplorer.addEventListener('toggle', () => {
        try { localStorage.setItem(layoutPreferenceKey, String(layoutExplorer.open)); }
        catch { /* Remembering the choice is optional; navigation still works. */ }
    });
    const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
    // One rate keeps intro UI, captions, camera and reveal choreography in sync.
    const introSpeed = .5;
    const playbackSpeed = 1.1;
    document.body.style.setProperty('--tour-speed',String(playbackSpeed));
    const endingTiming = { bagLift: 2100, click: 6200, brand: 7200, brandFade: 1000 };
    const layouts = [
        { name: 'One crowded screen', mode: 'crowded', duration: 9000, kicker: 'BEFORE OFFHAND · ONE DISPLAY', title: 'Open the map. Lose sight of the world.', description: 'Watch the player open the map, return to the game, inspect Character and Bags, then reopen the map. Each window competes with the world for the same screen space.', caption: 'One screen · Open, close, and reopen the UI', workspace: [425, 220, 750, 421.875], game: [425, 220, 750, 421.875], workspaceVisible: false },
        { name: 'Conventional span', mode: 'unmanaged', duration: 6500, kicker: 'BEFORE OFFHAND · CONVENTIONAL SPANNING', title: 'More width. The same interruption.', description: 'The camera pulls back to reveal two screens sharing one game canvas. Watch the centre of play and the map cross the bezel, while HUD elements sit at opposite outer edges.', caption: 'Conventional span · Game and centred UI cross the bezel', workspace: [235, 322, 550, 309.375], game: [805, 322, 550, 309.375] },
        { name: 'Offhand reveal', key: 'offhand-pair', duration: 6200, kicker: 'WITH OFFHAND · A DEDICATED WORKSPACE', title: 'Keep the map open. Keep the game visible.', description: 'The game and HUD settle onto Mainhand. The map moves into its own workspace, which grows into a portrait display with Character, Bags, and Chat accessible beside the game.', caption: 'With Offhand · Always-accessible workspace beside the game', workspace: [340, 165, 270, 480], game: [628, 375, 480, 270] },
        { name: 'Landscape pair', kicker: 'WITH OFFHAND · DUAL LANDSCAPE', title: 'Two wide screens, two clear roles', description: 'The same separation also works with a landscape workspace. Keep the game viewport and protected HUD together on Mainhand.', caption: 'With Offhand · Landscape workspace and Mainhand', workspace: [235, 322, 550, 309.375], game: [805, 322, 550, 309.375] },
        { name: 'Portrait right', kicker: 'LANDSCAPE + PORTRAIT', title: 'Put your workspace on either side', description: 'The same separation works with Mainhand on the left and a portrait workspace on the right.', caption: 'Mainhand on the left · Portrait workspace', workspace: [990, 165, 270, 480], game: [492, 375, 480, 270] },
        { name: 'Game above', kicker: 'STACKED DISPLAYS', title: 'Keep the game above your workspace', description: 'A workspace below Mainhand keeps maps and ordinary panels accessible in a vertical monitor arrangement.', caption: 'Mainhand above · Workspace below', workspace: [560, 382, 480, 270], game: [560, 94, 480, 270] },
        { name: 'Game below', kicker: 'STACKED DISPLAYS', title: 'Or keep your workspace above the game', description: 'Reverse the roles to suit your desk. Calibrate the seam and Mainhand region for the arrangement you actually use.', caption: 'Workspace above · Mainhand below', workspace: [560, 94, 480, 270], game: [560, 382, 480, 270] },
        { name: 'Ultrawide', kicker: 'ONE ULTRAWIDE DISPLAY', title: 'Make room within a single wide display', description: 'Divide one ultrawide into a workspace and a Mainhand game region. The illustrated divider represents the logical split, rather than a physical bezel.', caption: 'One display · Two regions', workspace: [250, 320, 1100 * .32, 1100 * 9 / 32], game: [250 + 1100 * .32, 320, 1100 * .68, 1100 * 9 / 32], single: true },
        { name: 'Three monitors', kicker: 'THREE-MONITOR DESK', title: 'Choose your pair. Keep another screen free.', description: 'Use one display for Mainhand and one for the Offhand workspace. The third stays outside the WoW span for your browser, voice chat, or other desktop apps. In Companion, select only the two displays you want WoW to use.', caption: 'Offhand + Mainhand selected · Third display outside WoW', workspace: [260, 240, 225, 400], game: [503, 415, 400, 225], desktop1: [921, 415, 400, 225] },
        { name: 'Four monitors', kicker: 'FOUR OR MORE CONNECTED DISPLAYS', title: 'More screens around the same two-display span', description: 'Offhand still uses a Mainhand and workspace pair. Leave additional displays outside the WoW span for other desktop apps. Companion supports two selected displays, not a WoW workspace spread across three or more.', caption: 'Two selected displays · Additional screens outside WoW', workspace: [200, 385, 380, 213.75], game: [610, 385, 380, 213.75], desktop1: [1020, 385, 380, 213.75], desktop2: [610, 150, 380, 213.75] },
        { name: 'Equip your Offhand.', mode: 'ending', duration: 10200, kicker: 'EQUIP YOUR OFFHAND', title: 'Dual-wield your monitors.', description: 'Your game on Mainhand. Your workspace on Offhand. Follow the setup guide to create your own arrangement.', caption: 'Offhand · Dual-wield your monitors', workspace: [340, 165, 270, 480], game: [628, 375, 480, 270] }
    ];
    const NS = 'http://www.w3.org/2000/svg';
    const svg = (tag, attrs, parent) => {
        const el = document.createElementNS(NS, tag);
        for (const [key, value] of Object.entries(attrs)) el.setAttribute(key, value);
        parent.append(el);
        return el;
    };
    const groups = {};
    const singleFrame = svg('rect', { x: 250, y: 320, width: 1100, height: 1100 * 9 / 32, rx: 7, fill: 'url(#metal)', stroke: '#5a4e3b', 'stroke-width': 1.5, opacity: 0 }, $('monitors'));
    const roles = ['workspace', 'game', 'desktop1', 'desktop2'];
    for (const role of roles) {
        const stand = svg('g', {}, $('stands'));
        const post = svg('rect', { fill: 'url(#metal)', rx: 5 }, stand);
        const foot = svg('ellipse', { fill: '#0b0d10', stroke: '#4a4133' }, stand);
        const monitor = svg('g', {}, $('monitors'));
        const frame = svg('rect', { fill: 'url(#metal)', stroke: '#5a4e3b', 'stroke-width': 1.5, rx: 7 }, monitor);
        const screen = svg('svg', { x: 9, y: 9, overflow: 'hidden' }, monitor);
        groups[role] = { stand, post, foot, monitor, frame, screen };
    }
    const seamNote = svg('g', { opacity: 0 }, $('monitors'));
    svg('text', { x: 795, y: 285, 'text-anchor': 'middle', 'font-size': 14, 'letter-spacing': 2, style: 'fill:#dfaa76' }, seamNote).textContent = 'BEZEL THROUGH THE CENTRE';
    svg('path', { d: 'M795 294V319', stroke: '#dfaa76', 'stroke-width': 1.5 }, seamNote);
    const singleStand = svg('g', { opacity: 0 }, $('stands'));
    svg('rect', { x: 786, y: 570, width: 28, height: 184, fill: 'url(#metal)' }, singleStand);
    svg('ellipse', { cx: 800, cy: 753, rx: 105, ry: 12, fill: '#0b0d10', stroke: '#4a4133' }, singleStand);
    for (let row = 0; row < 4; row++) {
        for (let col = 0; col < 16; col++) {
            svg('path', { d: `M${487 + col * 35 - row * 6} ${825 + row * 16}h27l2 10h-29Z` }, $('keys'));
        }
    }
    svg('path', { d: 'M607 889H914L918 898H603Z' }, $('keys'));

    // All labels and schematic windows stay vector based at every display size.
    const rect = (x, y, w, h, extra = '') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="2" ${extra}/>`;
    const text = (x, y, label, size = 10, extra = '') => `<text x="${x}" y="${y}" font-size="${size}" letter-spacing="1.7" ${extra}>${label}</text>`;
    const outline = 'fill="#171e20" stroke="#d5b875" stroke-width="1"';
    function workspaceGeometry(w, h) {
        const gap = 10, pad = 14, top = 37, available = h - top - pad;
        // Reflow continuously as the reveal grows from landscape to portrait.
        const wide = smooth((w/h-.95)/.40);
        const mixBox = (a,b) => a.map((value,i) => value+(b[i]-value)*wide);
        const tallMap = [pad,top,w-2*pad,available*.36];
        const wideMap = [pad,top,w*.52-pad,available*.58+gap];
        const tallChar = [pad,top+tallMap[3]+gap,(w-2*pad-gap)/2,available*.35];
        const wideChar = [w*.52+gap,top,w*.48-gap-pad,available*.29];
        const map = mixBox(tallMap,wideMap);
        const char = mixBox(tallChar,wideChar);
        const bags = mixBox([pad+tallChar[2]+gap,tallChar[1],tallChar[2],tallChar[3]], [wideChar[0],top+wideChar[3]+gap,wideChar[2],wideChar[3]]);
        const tallChatY = tallChar[1]+tallChar[3]+gap;
        const wideChatY = top+wideMap[3]+gap;
        const chat = mixBox([pad,tallChatY,w-2*pad,h-pad-tallChatY], [pad,wideChatY,w-2*pad,h-pad-wideChatY]);
        return { pad, sideW: char[2], sideH: char[3], map, char, bags, chat };
    }
    function workspaceMap(map) {
        return rect(...map, outline) + text(map[0]+8,map[1]+17,'MAP',9) + `<svg x="${map[0] + 12}" y="${map[1] + 28}" width="${map[2] - 24}" height="${map[3] - 36}" viewBox="0 0 240 110" preserveAspectRatio="xMidYMid meet"><path d="M15 47L38 18 72 25 97 6 125 21 118 48 96 62 84 91 49 99 23 77ZM149 26L177 15 201 31 193 53 215 68 191 94 152 86 140 59Z" fill="#303c3d" stroke="#d5b875" stroke-width="1.5"/></svg>`;
    }
    function itemSlotFrame() {
        return rect(1,1,38,38,'fill="#222c2b" stroke="#b39762" stroke-width="1.4"') + '<path d="M3 27L27 3H37V15L15 37H3Z" fill="#6d6447" opacity=".25"/><path d="M3 12V3H12M28 37H37V28" fill="none" stroke="#d1ba80" opacity=".7"/>';
    }
    function itemArtwork(kind) {
        // Shared small illustrations give equipped and bag items the same finish.
        const art = {
            helm: '<path d="M9 28V16L14 8 25 6 32 16V29L24 25V17H17V26Z" fill="#7a8882"/><path d="M13 15L20 10 28 15M20 10V22M11 29L16 31M26 29L30 31" fill="none"/>',
            necklace: '<path d="M10 8Q5 27 20 29Q35 27 30 8" fill="none" stroke-width="2"/><path d="M20 23L26 29 20 36 14 29Z" fill="#7e9184"/><path d="M17 29H23M20 26V33" fill="none"/>',
            shoulders: '<path d="M4 15L11 9 18 13 16 23 6 25 3 21ZM22 13L29 9 36 15 37 21 34 25 24 23Z" fill="#78867c"/><path d="M5 17L12 13 17 16M23 16L28 13 35 17M7 21L14 19M26 19L33 21" fill="none"/>',
            cloak: '<path d="M14 7Q20 12 26 7L34 34Q20 30 6 34Z" fill="#63797b"/><path d="M14 7L12 29M20 13V28M26 7L28 29M12 32L20 29 28 32" fill="none"/>',
            shirt: '<path d="M13 7L5 13 9 21 14 18V33H26V18L31 21 35 13 27 7Q20 15 13 7Z" fill="#9c9274"/><path d="M14 11Q20 18 26 11M17 20V30M23 20V30" fill="none"/>',
            tabard: '<path d="M12 7L17 11H23L28 7 30 16 26 19V34L20 31 14 34V19L10 16Z" fill="#5f7870"/><path d="M20 16L24 22 20 27 16 22Z" fill="#ae9765"/><path d="M15 12H25M15 30H25" fill="none"/>',
            bracers: '<path d="M7 9L17 7 21 29 11 32ZM23 11L32 8 36 29 27 32Z" fill="#8c7d60"/><path d="M9 14L18 12M12 26L20 24M25 16L33 13M27 27L35 24" fill="none" stroke-width="2"/>',
            legs: '<path d="M11 7H29L31 32 23 34 20 20 17 34 9 32Z" fill="#72817a"/><path d="M12 12H28M20 12V20M12 27L17 28M23 28L29 27" fill="none"/>',
            trinket: '<path d="M17 9V5H23V9" fill="none"/><circle cx="20" cy="22" r="13" fill="#807353"/><circle cx="20" cy="22" r="9" fill="#415c60"/><path d="M20 14L23 20 29 22 23 25 20 31 17 25 11 22 17 20Z" fill="#b29d70"/><circle cx="20" cy="22" r="2" fill="#8aaba0"/>',
            chest: '<path d="M13 7L7 12 4 23 11 26 14 20 12 33H28L26 20 29 26 36 23 33 12 27 7 24 12H16Z" fill="#687975"/><path d="M14 16L20 20 26 16M15 27H25M20 20V30" fill="none"/>',
            boots: '<path d="M11 7H20L18 25 22 29V33H6V28L10 24ZM24 9H32L30 25 35 29V33H23V27Z" fill="#927650"/><path d="M11 15H19M24 17H31M8 29H18M25 29H32" fill="none"/>',
            gloves: '<path d="M10 9L19 11 17 19 21 23 18 32 9 29 7 20ZM25 9L33 12 31 19 34 24 29 32 23 28 22 19Z" fill="#8c7756"/><path d="M9 17L17 19M23 17L31 19M11 23L16 25M25 23L30 25" fill="none"/>',
            ring: '<circle cx="20" cy="23" r="10" fill="none" stroke-width="4"/><path d="M13 12L20 6 27 12 20 19Z" fill="#84917e"/><path d="M17 12H23M20 9V16" fill="none"/>',
            belt: '<path d="M5 15H35V27H5Z" fill="#776049"/><path d="M15 13H25V29H15Z" fill="#b39966"/><path d="M18 17H22V25H18Z" fill="#3d4846"/>',
            potion: '<path d="M15 7H25V15L31 24V32L27 35H13L9 32V24L15 15Z" fill="#526e69"/><path d="M12 25H28V31L25 33H15L12 30Z" fill="#9b8554" stroke="none"/><path d="M15 8H25M17 18L14 23" fill="none" stroke-width="3"/>',
            book: '<path d="M9 7L29 5 33 31 13 35 8 31Z" fill="#86694b"/><path d="M13 9L27 8 30 29 16 32Z" fill="#4c6060"/><path d="M20 14L26 20 21 26 16 20ZM11 12L14 29" fill="none"/>',
            gem: '<path d="M12 9H28L35 19 20 35 5 19Z" fill="#647f83"/><path d="M12 9L15 19 20 35 25 19 28 9M5 19H35M15 19L20 9 25 19" fill="none"/>',
            sword: '<path d="M13 26L28 6 33 7 33 12 18 29Z" fill="#9da69a"/><path d="M11 24L21 32M15 29L9 35M8 33L11 36M18 24L30 10" fill="none" stroke-width="3"/>',
            bow: '<path d="M12 5Q37 20 12 35L12 5M9 28L31 12M26 12H31V17" fill="none" stroke-width="2"/>'
        };
        return itemSlotFrame() + `<g stroke="#c4ae7e" stroke-width="1.2" stroke-linejoin="round">${art[kind] || art.book}</g>`;
    }
    function characterSheet(iconOpacity = 0, glow = 0, equippedAge = 0) {
        // The same vector frame is used on the monitor and in the close-up.
        // The reference informs the three-slot arrangement, not its pixels.
        let content = '<path d="M12 2H408L418 12V530L406 542H14L2 530V12Z" fill="#191c1e" stroke="#958365" stroke-width="3"/>';
        content += '<path d="M17 10H403L410 17V522L399 532H22L10 520V18Z" fill="#202527" stroke="#4b4c45" stroke-width="4"/>';
        content += rect(15,15,390,29,'fill="#303128" stroke="#9a865d"');
        content += text(210,35,'CHARACTER',16,'text-anchor="middle"');
        content += '<circle cx="30" cy="29" r="16" fill="#263336" stroke="#b49a61" stroke-width="2"/>';
        content += '<path d="M24 29L29 23 36 29 29 35Z" fill="#b9aa7c"/>';
        content += rect(382,20,16,16,'fill="#4a2927" stroke="#a48c5a"') + text(390,33,'×',14,'text-anchor="middle"');
        content += rect(78,60,264,314,'fill="#172125" stroke="#665f4a"');
        content += '<path d="M80 370L210 64 340 370" fill="#273537" opacity=".55"/>';
        content += '<circle cx="210" cy="132" r="33" fill="#6b7e7c" stroke="#b0a47c" stroke-width="2"/>';
        content += '<path d="M178 127L187 100 210 87 233 100 242 127 226 119 210 125 194 119Z" fill="#465c60" stroke="#a7a17f" stroke-width="2"/>';
        content += '<path d="M167 179L138 193 130 228 166 235 178 213 186 273 174 321 191 362 206 362 210 291 214 362 229 362 246 321 234 273 242 213 254 235 290 228 282 193 253 179 231 190 189 190Z" fill="#435b5c" stroke="#a49e7a" stroke-width="2"/>';
        content += '<path d="M177 207L210 226 243 207 235 265 210 281 185 265Z" fill="#65716a" stroke="#b5a675" stroke-width="2"/>';
        const equipmentColumns = [
            [22,[['head','helm'],['neck','necklace'],['shoulder','shoulders'],['back','cloak'],['chest','chest'],['shirt','shirt'],['tabard','tabard'],['wrist','bracers']]],
            [352,[['hands','gloves'],['waist','belt'],['legs','legs'],['feet','boots'],['finger-1','ring'],['finger-2','ring'],['trinket-1','trinket'],['trinket-2','trinket']]]
        ];
        for (const [x,slots] of equipmentColumns) for (const [row,[position,kind]] of slots.entries()) {
            const y = 62+row*39;
            content += rect(x,y,38,38,'fill="url(#metal)" stroke="#9a8760" stroke-width="1.5"');
            content += `<g data-equipment-position="${position}" data-equipped-item="${kind}" transform="translate(${x+2} ${y+2}) scale(.85)">${itemArtwork(kind)}</g>`;
        }
        for (const [x,label] of [[22,'ATTRIBUTES'],[218,'DEFENCE']]) {
            content += rect(x,386,180,51,'fill="#1a2225" stroke="#6c644d"');
            content += text(x+9,402,label,9);
            for (let row=0;row<3;row++) content += rect(x+10,411+row*7,150-row*28,3,`fill="${row === 0 ? '#9aab79' : '#586e70'}"`);
        }
        for (const [x,role] of [[116,'mainhand'],[184,'offhand'],[252,'ranged']]) {
            content += `<g data-equipment-slot="${role}">${rect(x,456,52,52,`fill="url(#metal)" stroke="${role === 'offhand' ? '#d5b875' : '#8c8064'}" stroke-width="2"`)}${rect(x+5,461,42,42,'fill="#202b2e" stroke="#53594d"')}</g>`;
        }
        content += `<g transform="translate(121 461) scale(1.05)">${itemArtwork('sword')}</g>`;
        content += `<g transform="translate(257 461) scale(1.05)">${itemArtwork('bow')}</g>`;
        content += text(142,523,'MAINHAND',8,'text-anchor="middle"') + text(210,523,'OFFHAND',8,'text-anchor="middle"') + text(278,523,'RANGED',8,'text-anchor="middle"');
        for (const [x,width,label] of [[20,125,'Character'],[151,125,'Reputation'],[282,118,'Skills']]) content += rect(x,539,width,19,'fill="#222729" stroke="#867650"') + text(x+width/2,552,label,9,'text-anchor="middle"');
        if (iconOpacity > 0) {
            // Soft light spreads from behind the icon, without outlining the slot.
            content += `<ellipse data-equipped-glow="true" cx="210" cy="482" rx="47" ry="44" fill="url(#equipped-icon-glow)" opacity="${iconOpacity}" style="animation-delay:-${equippedAge}s"/>`;
            content += `<g data-equipped-item-frame="offhand" transform="translate(189 461) scale(1.05)" opacity="${iconOpacity}" style="animation-delay:-${equippedAge}s">${itemSlotFrame()}<image data-equipped-slot="offhand-centre" href="assets/offhand-logo-borderless.png" x="4" y="4" width="32" height="32" style="filter:saturate(.65) brightness(.88)"/></g>`;
        }
        if (glow > 0) content += rect(180,452,60,60,`fill="none" stroke="#f6d486" stroke-width="2" opacity="${glow}"`);
        return content;
    }
    function inventoryGeometry(box) {
        const gap = 4;
        const header = Math.min(30,box[3]*.45);
        const cell = Math.max(1,Math.min((box[2]-20-3*gap)/4,(box[3]-header-3-2*gap)/3));
        const x = box[0]+(box[2]-(4*cell+3*gap))/2, y = box[1]+header;
        const slot = index => [x+(index%4)*(cell+gap),y+Math.floor(index/4)*(cell+gap),cell,cell];
        return { cell, slot };
    }
    function inventoryContents(box, hasOffhand = false, highlight = 0, detailed = true) {
        const { slot } = inventoryGeometry(box);
        let content = '';
        for (let i=0;i<12;i++) {
            const [x,y,size] = slot(i), unit = size/40;
            content += `<g data-bag-slot="${i}">${rect(x,y,size,size,'fill="#263539" stroke="#8e805a" stroke-width=".9"')}`;
            if (!detailed) {
                content += '</g>';
                continue;
            }
            if (i === 5) {
                content += `<g data-offhand-item-frame="true" transform="translate(${x} ${y}) scale(${unit})">${itemSlotFrame()}`;
                if (hasOffhand) content += '<image data-bag-item="offhand" href="assets/offhand-logo-borderless.png" x="4" y="4" width="32" height="32" style="filter:saturate(.65) brightness(.88)"/>';
                content += '</g>';
                if (highlight > 0) content += rect(x-2,y-2,size+4,size+4,`fill="none" stroke="#f4d58f" stroke-width="2" opacity="${highlight}"`);
            } else {
                const kinds = ['potion','book','gem','sword','helm','ring','gloves','chest','boots','belt','bow','potion'];
                content += `<g transform="translate(${x} ${y}) scale(${unit})">${itemArtwork(kinds[i])}</g>`;
            }
            content += '</g>';
        }
        return content;
    }
    function inventoryPanel(box, hasOffhand = false, highlight = 0, detailed = true) {
        return `<g data-inventory-panel="true" data-detail="${detailed ? 'full' : 'simple'}">${rect(...box,outline)}${text(box[0]+8,box[1]+17,'BAGS',Math.max(5,Math.min(13,box[2]*.085)))}${inventoryContents(box,hasOffhand,highlight,detailed)}</g>`;
    }
    function schematicCharacter(box) {
        return `<g data-character-detail="simple">${rect(...box,outline)}${text(box[0]+8,box[1]+17,'CHARACTER',Math.max(4,Math.min(8,box[2]/14)))}<svg x="${box[0]+5}" y="${box[1]+25}" width="${Math.max(1,box[2]-10)}" height="${Math.max(1,box[3]-30)}" viewBox="0 0 100 120" preserveAspectRatio="xMidYMid meet"><circle cx="50" cy="28" r="14" fill="#657778" stroke="#b5aa85"/><path d="M30 50L50 44 70 50 77 75 65 79 62 66 60 95 40 95 38 66 35 79 23 75Z" fill="#3e5455" stroke="#a49e7a"/>${[12,37,62,87].map(y=>rect(5,y,13,17,'fill="#2b393a" stroke="#8f845f"')+rect(82,y,13,17,'fill="#2b393a" stroke="#8f845f"')).join('')}</svg></g>`;
    }
    function workspaceContent(w, h, omitMap = false) {
        const { pad, map, char, bags, chat } = workspaceGeometry(w,h);
        const panel = (box, label) => rect(...box, outline) + text(box[0] + 8, box[1] + 17, label, Math.max(5, Math.min(9, (box[2] - 16 - label.length * 1.7) / (label.length * .65))));
        let content = rect(0, 0, w, h, 'fill="#141b1e"') + text(pad, 22, 'OFFHAND', 11);
        const ending = layouts[active].mode === 'ending';
        // Transfer the existing panel into the close-up layer, never leave a copy.
        const bagLifted = ending && (reducedMotion.matches || elapsed >= endingTiming.bagLift);
        content += (omitMap ? '' : workspaceMap(map)) + panel(chat, 'CHAT');
        if (!bagLifted) content += inventoryPanel(bags,ending && elapsed < endingTiming.click,0,ending);
        content += ending ? `<svg data-character-detail="full" x="${char[0]}" y="${char[1]}" width="${char[2]}" height="${char[3]}" viewBox="0 0 420 560" preserveAspectRatio="xMidYMid meet">${characterSheet()}</svg>` : schematicCharacter(char);
        const lineStep = Math.max(1, (chat[3] - 32) / 4);
        const lineH = Math.min(7, lineStep * .6);
        for (let i = 0; i < 4; i++) content += rect(chat[0] + 10, chat[1] + 28 + i * lineStep, (chat[2] - 24) * [.65, .52, .84, .6][i], lineH, `fill="${['#4d6c76', '#6e794d', '#8b7149', '#4d6c76'][i]}"`);
        return content;
    }
    function gameContent(w, h, label = 'MAINHAND') {
        let content = rect(0, 0, w, h, 'fill="url(#game)"');
        const polygon = (points, fill) => `<polygon points="${points.map(([x,y]) => `${x*w},${y*h}`).join(' ')}" fill="${fill}"/>`;
        content += polygon([[0,.48],[.19,.31],[.48,.37],[.73,.22],[1,.42],[1,1],[0,1]], '#3b4936');
        content += polygon([[0,.59],[.28,.43],[.68,.58],[1,.43],[1,1],[0,1]], '#2c3c2e');
        content += polygon([[.04,.39],[.28,.32],[1,.48],[1,.63],[.38,.43]], '#74654b');
        for (const x of [.11,.29,.79,.94]) content += polygon([[x-.027,0],[x+.025,0],[x+.04,.37],[x-.05,.36]], '#27332c');
        content += polygon([[0,.83],[.24,.72],[.51,.89],[.8,.72],[1,.81],[1,1],[0,1]], '#21332b');
        content += text(14, 22, label, 11);
        content += `<circle cx="26" cy="47" r="11" fill="#263839" stroke="#e0bf77"/>` + rect(42, 37, 54, 9, 'fill="#80914e" stroke="#c6b074"') + rect(42, 50, 42, 6, 'fill="#3e6a7c" stroke="#c6b074"');
        content += `<circle cx="${w-35}" cy="45" r="23" fill="#293c39" stroke="#d5b875"/>`;
        for (let i = 0; i < 3; i++) content += rect(w-57, 77+i*9, 43-i*6, 4, 'fill="#9b8658"');
        content += text(w/2, h*.48, 'GAME', Math.min(w*.05, 26), 'text-anchor="middle"');
        content += `<path d="M${w*.5} ${h*.64-7}l7 7-7 7-7-7Z" fill="none" stroke="#efd18a" stroke-width="1.6"/>`;
        const cell = Math.min(19, (w*.61)/10), start = (w - cell*10) / 2;
        for (let i = 0; i < 10; i++) content += rect(start+i*cell, h-37, cell-3, 17, 'fill="#23332f" stroke="#d5b875"');
        content += rect(start+20, h-14, cell*10-43, 4, 'fill="#64809a" stroke="#d5b875" stroke-width=".6"');
        return content;
    }

    function floatingPanel(x, y, w, h, label, kind) {
        let content = rect(x, y, w, h, 'fill="#1b2226" stroke="#d5b875" stroke-width="1.4"');
        content += rect(x, y, w, 23, 'fill="#34352d"');
        content += text(x+9, y+16, label, 10);
        if (kind === 'map') {
            content += `<svg x="${x+10}" y="${y+32}" width="${w-20}" height="${h-43}" viewBox="0 0 240 110"><path d="M15 47L38 18 72 25 97 6 125 21 118 48 96 62 84 91 49 99 23 77ZM149 26L177 15 201 31 193 53 215 68 191 94 152 86 140 59Z" fill="#3e4a45" stroke="#d5b875" stroke-width="1.5"/></svg>`;
        } else if (kind === 'character') {
            content += `<circle cx="${x+w/2}" cy="${y+h*.4}" r="${h*.085}" fill="#516364" stroke="#d5b875"/>`;
            content += rect(x+w*.3,y+h*.52,w*.4,h*.31,'fill="#3b4c4e" stroke="#d5b875"');
        } else if (kind === 'bags') {
            const size = Math.min((w-24)/4,(h-38)/4);
            for (let r=0;r<4;r++) for (let c=0;c<4;c++) content += rect(x+10+c*size,y+30+r*size,size-4,size-4,'fill="#354442" stroke="#b79d65"');
        } else {
            for (let r=0;r<4;r++) content += rect(x+9,y+30+r*7,(w-24)*[.7,.9,.55,.8][r],3,'fill="#839484"');
        }
        return content;
    }
    const uiActions = [
        { start: 0, end: 1600, panel: 'map', message: 'Open the map. The world is covered.' },
        { start: 1600, end: 2600, panel: null, message: 'Close the map to see the world.' },
        { start: 2600, end: 3900, panel: 'character', message: 'Inspect your character. Cover the game again.' },
        { start: 3900, end: 5200, panel: 'bags', message: 'Check your bags. Another window to manage.' },
        { start: 5200, end: 6800, panel: 'map', message: 'Need directions? Open the map again.' },
        { start: 6800, end: 7600, panel: null, message: 'Close it again to return to the game.' },
        { start: 7600, end: 9000, panel: 'map', message: 'Open. Close. Reopen.' }
    ];
    function uiActionAt(age) {
        return uiActions.find(action => age < action.end) || uiActions[uiActions.length-1];
    }
    function crowdedContent(w, h) {
        let content = gameContent(w,h,'ONE SCREEN');
        const age = storyTime();
        const boxes = { map:[w*.24,h*.17,w*.46,h*.52], character:[w*.045,h*.30,w*.24,h*.49], bags:[w*.70,h*.32,w*.27,h*.49] };
        if (reducedMotion.matches) {
            for (const [kind,box] of Object.entries(boxes)) content += floatingPanel(...box,kind.toUpperCase(),kind);
        } else {
            const action = uiActionAt(age);
            if (action.panel) {
                const box = boxes[action.panel];
                const appear = smooth((age-action.start)/180);
                const disappear = smooth((action.end-age)/160);
                const scale = .96+.04*appear;
                content += `<g data-active-panel="${action.panel}" opacity="${appear*disappear}" transform="translate(${box[0]+box[2]/2} ${box[1]+box[3]/2}) scale(${scale}) translate(${-box[0]-box[2]/2} ${-box[1]-box[3]/2})">${floatingPanel(...box,action.panel.toUpperCase(),action.panel)}${text(box[0]+box[2]-17,box[1]+17,'×',16)}</g>`;
            }
            const target = action.panel ? boxes[action.panel] : boxes.map;
            const cx = target[0]+target[2]-14, cy = target[1]+12;
            const click = smooth((age-action.start)/260);
            content += `<g transform="translate(${cx} ${cy})"><circle r="${3+14*click}" fill="none" stroke="#ecd49b" opacity="${1-click}"/><path d="M0 0L0 16 4 12 8 20 11 18 7 10 13 10Z" fill="#f4e6c5" stroke="#352f24" stroke-width="1"/></g>`;
        }
        content += floatingPanel(w*.035,h*.78,w*.30,h*.18,'CHAT','chat');
        return content;
    }
    function spanContent(w,h) {
        const animated = playing && !reducedMotion.matches;
        const age = storyTime();
        const mapOpen = !animated || age >= 3400;
        const alpha = animated ? smooth((age-3400)/220) : 1;
        let content = gameContent(w,h,'SPANNED GAME');
        if (mapOpen) content += `<g opacity="${alpha}">${floatingPanel(w*.40,h*.21,w*.20,h*.45,'MAP','map')}</g>`;
        if (animated && age >= 1900 && age < 3400) content += `<circle cx="${w/2}" cy="${h*.64}" r="22" fill="none" stroke="#dfaa76" stroke-width="2" opacity="${.5+.3*Math.sin(age/180)}"/>`;
        return content;
    }

    const clamp = value => Math.max(0, Math.min(1,value));
    const smooth = value => { const t = clamp(value); return t*t*(3-2*t); };
    function separatingContent(leftW, rightW, h, progress) {
        const totalW = leftW + rightW;
        const gameProgress = smooth(progress / .82);
        const mapProgress = smooth((progress - .10) / .80);
        const panelProgress = smooth((progress - .30) / .70);
        const finish = smooth((progress - .78) / .22);
        const gameX = leftW * gameProgress;
        const gameW = totalW - gameX;
        const initialMap = [totalW*.40,h*.21,totalW*.20,h*.45];
        const finalMap = workspaceGeometry(leftW,h).map;
        const movingMap = initialMap.map((value,i) => value+(finalMap[i]-value)*mapProgress);
        let content = rect(0,0,totalW,h,'fill="#141b1e"');
        // Resize one game viewport so its centre, HUD and outer anchors all
        // travel continuously onto Mainhand, rather than crossfading screenshots.
        content += `<svg x="${gameX}" width="${gameW}" height="${h}" viewBox="0 0 ${gameW} ${h}">${gameContent(gameW,h,'')}</svg>`;
        content += `<g opacity="${1-gameProgress}">${text(14,22,'SPANNED GAME',11)}</g>`;
        content += `<g opacity="${gameProgress}">${text(gameX+14,22,'MAINHAND',11)}</g>`;
        // This is the original bezel-crossing map, moving into its final slot.
        // Its frame styling settles only after the move is nearly complete.
        content += `<g opacity="${panelProgress}">${workspaceContent(leftW,h,true)}</g>`;
        content += `<g opacity="${1-finish}">${floatingPanel(...movingMap,'MAP','map')}</g>`;
        content += `<g opacity="${finish}">${workspaceMap(movingMap)}</g>`;
        return content;
    }

    function desktopContent(w, h) {
        let content = rect(0, 0, w, h, 'fill="#1b2631"');
        content += text(14, 22, 'DESKTOP', 11, 'style="fill:#a3bbce"');
        content += rect(15, 40, w-30, h-83, 'fill="#243443" stroke="#61798d"');
        content += rect(15, 40, w-30, 18, 'fill="#34495a"');
        for (let i = 0; i < 3; i++) content += `<circle cx="${26+i*9}" cy="49" r="2" fill="#a0b2be"/>`;
        content += rect(27, 71, w*.23, Math.max(12,h-130), 'fill="#3c5364"');
        for (let i = 0; i < 4; i++) content += rect(w*.35, 72+i*14, w*(i%2 ? .38 : .47), 5, 'fill="#617b8e"');
        content += text(w/2, h-20, 'OUTSIDE WOW', 10, 'text-anchor="middle" style="fill:#a3bbce"');
        return content;
    }

    let endingHeld = false;
    function endingPose() {
        const age = reducedMotion.matches ? layouts[active].duration : elapsed;
        const focus = smooth((age-1300)/2200);
        const geometry = workspaceGeometry(current.workspace[2]-18,current.workspace[3]-18);
        const char = geometry.char;
        const scale = Math.min(char[2]/420,char[3]/560);
        const source = [current.workspace[0]+9+char[0]+(char[2]-420*scale)/2,current.workspace[1]+9+char[1]+(char[3]-560*scale)/2,420*scale,560*scale];
        const zoom = current.zoom+(Math.min(480/source[2],640/source[3])-current.zoom)*focus;
        const sourceX = source[0]+source[2]/2, sourceY = source[1]+source[3]/2;
        const startX = 800+(sourceX-800)*current.zoom;
        const startY = 470+(sourceY-470)*current.zoom;
        // Interpolate the projected centre, not a moving transform origin.
        // This gives the dolly a straight path with no upward/rightward arc.
        const viewX = startX+(610-startX)*focus, viewY = startY+(455-startY)*focus;
        const dx = viewX-sourceX*zoom, dy = viewY-sourceY*zoom;
        const bag = geometry.bags;
        const bagWorld = [current.workspace[0]+9+bag[0],current.workspace[1]+9+bag[1],bag[2],bag[3]];
        return { age, focus, transform: `translate(${dx} ${dy}) scale(${zoom})`, box: [source[0]*zoom+dx,source[1]*zoom+dy,source[2]*zoom,source[3]*zoom], bag: [bagWorld[0]*zoom+dx,bagWorld[1]*zoom+dy,bagWorld[2]*zoom,bagWorld[3]*zoom], bagSource: [0,0,bag[2],bag[3]] };
    }
    function drawEnding() {
        const layer = $('ending-scene');
        const ending = layouts[active].mode === 'ending';
        layer.setAttribute('opacity',ending ? 1 : 0);
        if (!ending) {
            endingHeld = false;
            $('ending-setup').hidden = true;
            if (layer.innerHTML) layer.innerHTML = '';
            $('scene-brand').setAttribute('opacity',1);
            return;
        }
        const { age, box, bag, bagSource } = endingPose();
        // Keep the completed link node intact so keyboard focus survives the hold.
        if (endingHeld && age >= endingTiming.brand+endingTiming.brandFade) return;
        endingHeld = false;
        const fade = smooth((age-2000)/1500);
        const equipped = age >= endingTiming.click;
        const brand = smooth((age-endingTiming.brand)/endingTiming.brandFade);
        // The SVG is exposed as one image; provide a native link for assistive
        // technology and keyboard users alongside its illustrated button.
        $('ending-setup').hidden = brand < 1;
        $('scene-brand').setAttribute('opacity',1-fade);
        layer.setAttribute('data-ending-phase',age < 1300 ? 'setup' : age < 3500 ? 'character' : age < endingTiming.click ? 'bag' : age < endingTiming.brand ? 'equipping' : 'ready');
        const glow = equipped && age < endingTiming.click+700 ? Math.sin(clamp((age-endingTiming.click)/700)*Math.PI) : 0;
        const sheet = characterSheet(equipped ? 1 : 0,glow,Math.max(0,(age-endingTiming.click)/1000/playbackSpeed));
        let content = rect(0,0,1600,1000,`fill="#0c1016" opacity="${fade}"`);
        // Match the camera-projected position of the in-monitor frame exactly.
        // Only its surroundings fade; the character sheet keeps its identity.
        content += `<svg data-character-closeup="true" x="${box[0]}" y="${box[1]}" width="${box[2]}" height="${box[3]}" viewBox="0 0 420 560" overflow="visible" opacity="${smooth((age-1900)/700)}">${sheet}</svg>`;
        const bagOpacity = age >= endingTiming.bagLift ? 1-brand : 0;
        // Preserve the original panel's coordinates and contents under the same
        // camera transform as Character. No separate bag reflow or resizing.
        if (bagOpacity > 0) content += `<svg data-ending-bag="true" x="${bag[0]}" y="${bag[1]}" width="${bag[2]}" height="${bag[3]}" viewBox="0 0 ${bagSource[2]} ${bagSource[3]}" overflow="visible" opacity="${bagOpacity}">${inventoryPanel(bagSource,!equipped,glow)}</svg>`;
        if (age >= 4200 && age < endingTiming.brand) {
            const slot = inventoryGeometry(bagSource).slot(5);
            const bagScale = bag[2]/bagSource[2];
            const settle = smooth((age-4200)/1100);
            const x = bag[0]+(slot[0]+slot[2]/2)*bagScale+65*(1-settle), y = bag[1]+(slot[1]+slot[3]/2)*bagScale+80*(1-settle);
            const click = smooth((age-endingTiming.click)/500);
            content += `<g data-bag-click="true" transform="translate(${x} ${y})" opacity="${bagOpacity}">`;
            if (equipped) content += `<circle r="${4+20*click}" fill="none" stroke="#f4d58f" stroke-width="2" opacity="${1-click}"/>`;
            content += '<path d="M0 0L0 23 6 17 12 29 16 27 10 14 20 14Z" fill="#f4e6c5" stroke="#352f24" stroke-width="1.5"/></g>';
        }
        content += `<g opacity="${brand}"><image data-ending-logo="true" href="assets/offhand-logo-borderless.png" x="1005" y="240" width="170" height="145"/>${text(1090,440,'OFFHAND',48,'text-anchor="middle" style="font-family:Georgia,serif;letter-spacing:5px"')}${text(1090,493,'Dual-wield your monitors.',20,'text-anchor="middle"')}`;
        if (brand === 1) content += `<a class="ending-cta" href="in-game-setup.html" tabindex="0" aria-label="Get started with Offhand">${rect(965,540,250,58)}${text(1090,577,'GET STARTED',17,'text-anchor="middle"')}</a>`;
        content += '</g>';
        layer.innerHTML = content;
        if (age >= endingTiming.brand+endingTiming.brandFade) endingHeld = true;
    }

    function layoutState(layout) {
        return {
            workspace: [...layout.workspace], game: [...layout.game],
            desktop1: [...(layout.desktop1 || [921,415,400,225])],
            desktop2: [...(layout.desktop2 || [610,150,380,213.75])],
            desktop1Visible: layout.desktop1 ? 1 : 0,
            desktop2Visible: layout.desktop2 ? 1 : 0,
            workspaceVisible: layout.workspaceVisible === false ? 0 : 1,
            separation: layout.mode === 'unmanaged' ? 0 : 1,
            zoom: layout.mode === 'crowded' ? 1.65 : 1,
            blend: layout.single ? 1 : 0
        };
    }

    let active = 0, current = layoutState(layouts[0]);
    let transition = null, playing = false, elapsed = 0, lastTime = null, raf = 0;
    let coverDismissed = false;
    function dismissCover() {
        if (coverDismissed) return;
        coverDismissed = true;
        if ($('tour-cover').contains(document.activeElement)) $('play').focus({ preventScroll: true });
        $('tour-cover').classList.add('is-dismissed');
        $('tour-cover').setAttribute('aria-hidden', 'true');
        $('scene').removeAttribute('aria-hidden');
        $('tour-start').disabled = true;
        updateCopy();
    }
    const duration = 4500;
    const transitionDuration = 1100;
    const separationDuration = 4200;
    function storyTime() { return active < 3 ? elapsed*introSpeed : elapsed; }
    function storyMessage() {
        if (reducedMotion.matches) return layouts[active].caption;
        const age = storyTime();
        if (active === 0) return uiActionAt(age).message;
        if (active === 1) return age < 1900 ? 'Try more screen space. Pull back to see the span.' : age < 3400 ? 'The centre of play sits on the bezel.' : age < 5000 ? 'Open the map. It crosses the bezel too.' : 'More width. Still no separate workspace.';
        return age < 2600 ? 'Keep the game and HUD together on Mainhand.' : age < 4200 ? 'Grow a dedicated workspace beside the game.' : 'Keep the map open. Keep the game visible.';
    }
    function draw() {
        const blend = current.blend;
        const mode = layouts[active].mode;
        const separating = transition && transition.separating && current.separation < .999999;
        const sharedCanvas = separating || (mode === 'unmanaged' && !(transition && transition.separating));
        const zoom = reducedMotion.matches ? 1 : current.zoom;
        $('camera').setAttribute('transform',mode === 'ending' ? endingPose().transform : `translate(800 470) scale(${zoom}) translate(-800 -470)`);
        $('story-overlay').setAttribute('opacity',active < 3 ? 1 : 0);
        const message = storyMessage();
        if ($('story-beat').textContent !== message) $('story-beat').textContent = message;
        seamNote.setAttribute('opacity', sharedCanvas ? 1-current.separation : 0);
        singleStand.setAttribute('opacity', blend);
        singleFrame.setAttribute('opacity', blend);
        for (const role of roles) {
            const [x,y,w,h] = current[role];
            const g = groups[role];
            const desktop = role.startsWith('desktop');
            const visibility = desktop ? current[`${role}Visible`] : role === 'workspace' ? current.workspaceVisible : 1;
            g.monitor.setAttribute('opacity', visibility);
            g.monitor.setAttribute('transform', `translate(${x} ${y})`);
            g.frame.setAttribute('width', w);
            g.frame.setAttribute('height', h);
            g.frame.setAttribute('opacity', desktop ? 1 : 1-blend);
            g.stand.setAttribute('opacity', visibility*(1-blend));
            g.post.setAttribute('x', x+w/2-10);
            g.post.setAttribute('y', y+h-4);
            g.post.setAttribute('width', 20);
            g.post.setAttribute('height', Math.max(0, 754-y-h));
            g.foot.setAttribute('cx', x+w/2);
            g.foot.setAttribute('cy', 754);
            g.foot.setAttribute('rx', 60);
            g.foot.setAttribute('ry', 8);
            const innerW = Math.max(10, w-18+(desktop ? 0 : 9*blend)), innerH = Math.max(10,h-18);
            g.screen.setAttribute('x', role === 'game' ? 9*(1-blend) : 9);
            g.screen.setAttribute('width', innerW);
            g.screen.setAttribute('height', innerH);
            g.screen.setAttribute('viewBox', `0 0 ${innerW} ${innerH}`);
            if (sharedCanvas && !desktop) {
                // Both physical screens sample the SAME game canvas. Do not draw
                // two independent scenes, which would hide the bezel problem.
                const leftW = current.workspace[2]-18;
                const rightW = current.game[2]-18;
                const spanH = Math.min(current.workspace[3],current.game[3])-18;
                const offset = role === 'workspace' ? 0 : leftW;
                const content = separating ? separatingContent(leftW,rightW,spanH,current.separation) : spanContent(leftW+rightW,spanH);
                g.screen.innerHTML = `<svg width="${innerW}" height="${innerH}" viewBox="${offset} 0 ${innerW} ${spanH}" preserveAspectRatio="none">${content}</svg>`;
            } else {
                g.screen.innerHTML = role === 'workspace' ? workspaceContent(innerW,innerH) : desktop ? desktopContent(innerW,innerH) : mode === 'crowded' ? crowdedContent(innerW,innerH) : gameContent(innerW,innerH);
            }
        }
        drawEnding();
    }
    const buttons = layouts.map((layout,index) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = layout.name;
        if (layout.mode === 'crowded' || layout.mode === 'unmanaged') button.dataset.comparison = 'true';
        if (layout.mode === 'ending') button.dataset.ending = 'true';
        button.addEventListener('click', () => { setPlaying(false); select(index); if (layout.mode === 'ending') setPlaying(true); });
        $('layouts').append(button);
        return button;
    });
    function updateCopy() {
        const layout = layouts[active];
        $('layout-kicker').textContent = layout.kicker;
        $('layout-title').textContent = layout.title;
        $('layout-description').textContent = layout.description;
        $('stage-caption').textContent = layout.caption;
        $('scene-title').textContent = layout.caption;
        $('counter').textContent = `${String(active+1).padStart(2,'0')} / ${String(layouts.length).padStart(2,'0')}`;
        buttons.forEach((button,index) => button.setAttribute('aria-pressed', String(index === active)));
    }
    function select(index) {
        dismissCover();
        const previous = layouts[active];
        const wasSeparating = transition && transition.separating;
        active = index;
        elapsed = 0;
        $('progress').style.width = '0%';
        const layout = layouts[index];
        const separating = (previous.mode === 'unmanaged' && layout.key === 'offhand-pair') ||
            (previous.key === 'offhand-pair' && layout.mode === 'unmanaged') ||
            (wasSeparating && (layout.mode === 'unmanaged' || layout.key === 'offhand-pair'));
        const target = layoutState(layout);
        if (reducedMotion.matches) { current = target; transition = null; draw(); }
        else {
            const baseDuration = separating ? separationDuration : previous.mode === 'crowded' && layout.mode === 'unmanaged' ? 1900 : transitionDuration;
            transition = { from: { ...current, ...Object.fromEntries(roles.map(role => [role, [...current[role]]])) }, to: target, elapsed: 0, separating, forward: layout.key === 'offhand-pair', duration: baseDuration/(index < 3 ? introSpeed : 1) };
        }
        updateCopy();
        schedule();
    }
    function schedule() { if (!raf && !document.hidden) raf = requestAnimationFrame(tick); }
    function tick(now) {
        raf = 0;
        const delta = lastTime === null ? 0 : Math.min(now-lastTime,100)*playbackSpeed;
        lastTime = now;
        let needsDraw = false;
        if (transition) {
            transition.elapsed += delta;
            const t = Math.min(1,transition.elapsed/transition.duration), eased = smooth(t);
            const hardware = transition.separating ? transition.forward ? smooth((t-.62)/.38) : smooth(t/.38) : eased;
            const separation = transition.separating ? transition.forward ? smooth(t/.62) : smooth((t-.38)/.62) : eased;
            for (const role of roles) current[role] = transition.from[role].map((value,i) => value+(transition.to[role][i]-value)*hardware);
            for (const key of ['blend', 'desktop1Visible', 'desktop2Visible', 'workspaceVisible', 'zoom']) current[key] = transition.from[key]+(transition.to[key]-transition.from[key])*eased;
            current.separation = transition.from.separation+(transition.to.separation-transition.from.separation)*separation;
            if (t === 1) transition = null;
            needsDraw = true;
        }
        if (playing) {
            elapsed += delta;
            const sceneDuration = (layouts[active].duration || duration)/(active < 3 ? introSpeed : 1);
            $('progress').style.width = `${Math.min(100,elapsed/sceneDuration*100)}%`;
            if (elapsed >= sceneDuration) {
                if (layouts[active].mode === 'ending') {
                    elapsed = sceneDuration;
                    setPlaying(false);
                    $('play').textContent = 'Replay tour';
                    $('play').setAttribute('aria-label','Replay layout tour');
                } else select(active+1);
            }
            if (active < 3 || layouts[active].mode === 'ending') needsDraw = true;
        }
        if (needsDraw) draw();
        if (transition || playing) schedule(); else lastTime = null;
    }
    function setPlaying(value) {
        playing = value;
        $('play').textContent = value ? 'Pause tour' : 'Play tour';
        $('play').setAttribute('aria-label', value ? 'Pause layout tour' : 'Play layout tour');
        schedule();
    }
    function replayIntro() {
        dismissCover();
        active = 0;
        elapsed = 0;
        current = layoutState(layouts[0]);
        transition = null;
        $('progress').style.width = '0%';
        updateCopy();
        draw();
        setPlaying(true);
    }
    $('play').addEventListener('click', () => {
        if (!coverDismissed) { replayIntro(); return; }
        if (!playing && layouts[active].mode === 'ending' && elapsed >= layouts[active].duration) replayIntro();
        else setPlaying(!playing);
    });
    $('replay-intro').addEventListener('click',replayIntro);
    $('tour-start').addEventListener('click', replayIntro);
    function presentation(value) {
        document.body.classList.toggle('presentation',value);
        $('presentation').textContent = value ? 'Exit expanded view' : 'Expand demo';
        $('presentation').setAttribute('aria-pressed',String(value));
    }
    $('presentation').addEventListener('click', () => presentation(!document.body.classList.contains('presentation')));
    document.addEventListener('keydown', event => {
        if (event.key === 'Escape') presentation(false);
    });
    document.addEventListener('visibilitychange', () => {
        if (document.hidden) { cancelAnimationFrame(raf); raf = 0; lastTime = null; }
        else schedule();
    });
    reducedMotion.addEventListener('change', () => { if (reducedMotion.matches) { setPlaying(false); select(active); } });
    updateCopy();
    draw();
    // Snapshot the existing finished layout as a static vector cover, not a
    // timed scene. Prefix IDs so its gradients and symbols remain independent.
    active = 2;
    current = layoutState(layouts[2]);
    elapsed = 12000;
    draw();
    const coverArt = $('scene').cloneNode(true);
    coverArt.removeAttribute('aria-labelledby');
    coverArt.setAttribute('aria-hidden', 'true');
    coverArt.querySelector('#story-overlay').remove();
    coverArt.querySelector('#scene-caption').remove();
    $('tour-cover-art').innerHTML = new XMLSerializer().serializeToString(coverArt)
        .replace(/\bid="([^"]+)"/g, 'id="cover-$1"')
        .replace(/url\(#([^)]+)\)/g, 'url(#cover-$1)')
        .replace(/href="#([^"]+)"/g, 'href="#cover-$1"');
    active = 0;
    elapsed = 0;
    current = layoutState(layouts[0]);
    updateCopy();
    draw();
    $('tour-cover').hidden = false;
    $('scene').setAttribute('aria-hidden', 'true');
    $('layout-kicker').textContent = 'ILLUSTRATED LAYOUT TOUR';
    $('layout-title').textContent = 'Explore the Mainhand and Offhand layout';
    $('layout-description').textContent = 'See the single-screen comparison, window separation, and supported monitor arrangements. Play the tour or open Explore layouts to jump to a scene.';
    if (new URLSearchParams(location.search).get('present') === '1') presentation(true);
})();
