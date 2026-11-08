// Keep alternative methods separate while preserving direct links and browser Back.
(() => {
    const sections = {
        fancyzones: document.getElementById('fancyzones'),
        manual: document.getElementById('manual'),
    };
    const status = document.getElementById('selected-method-status');
    let selected = null;

    function render() {
        const target = location.hash.slice(1);
        if (Object.hasOwn(sections, target)) selected = target;
        else if (!target || target === 'choose-method') selected = null;

        for (const [method, section] of Object.entries(sections)) {
            section.hidden = method !== selected;
        }
        for (const link of document.querySelectorAll('[data-setup-method]')) {
            if (link.dataset.setupMethod === selected) link.setAttribute('aria-current', 'true');
            else link.removeAttribute('aria-current');
        }
        status.textContent = selected === 'fancyzones'
            ? 'FancyZones selected. Follow its steps, then confirm in WoW. Manual placement is not required.'
            : selected === 'manual'
                ? 'Manual placement selected. Follow its steps, then confirm in WoW. PowerToys and Companion are not required.'
                : 'Choose one method above. Only its placement instructions will be shown.';

        if (Object.hasOwn(sections, target)) sections[target].scrollIntoView({ block: 'start' });
    }

    addEventListener('hashchange', render);
    render();
})();
