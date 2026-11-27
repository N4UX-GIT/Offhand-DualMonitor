// Keep the destination visible when a menu link jumps within the current page.
const siteMenu = document.querySelector('.site-menu');

window.addEventListener('click', event => {
    if (siteMenu.open && (!siteMenu.contains(event.target) || event.target.closest('a'))) {
        siteMenu.open = false;
    }
});

window.addEventListener('keydown', event => {
    if (event.key === 'Escape' && siteMenu.open) {
        siteMenu.open = false;
        siteMenu.querySelector('summary').focus();
    }
});
