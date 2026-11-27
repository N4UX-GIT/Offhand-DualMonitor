const search = document.querySelector('#support-search');
const status = document.querySelector('#result-status');
const categories = document.querySelectorAll('.topic-card');

function normalize(text) {
    return text.toLowerCase().replace(/['’]/g, '').replace(/[^a-z0-9]+/g, ' ').trim();
}

function filterTopics() {
    const query = normalize(search.value);
    const terms = query.split(' ');
    document.querySelector('.help-start').hidden = Boolean(query);
    let total = 0;
    for (const category of categories) {
        let visible = 0;
        const heading = category.querySelector('h3').textContent;
        for (const topic of category.querySelectorAll('li')) {
            const text = normalize([heading, topic.textContent, topic.dataset.keywords].join(' '));
            topic.hidden = !terms.every(term => text.includes(term));
            if (!topic.hidden) visible++;
        }
        category.hidden = visible === 0;
        total += visible;
    }
    if (!query) status.textContent = '';
    else if (total === 0) status.textContent = 'No matching topics. Try another word or ask the community below.';
    else status.textContent = total === 1 ? '1 matching topic' : total + ' matching topics';
}

document.querySelector('#support-filter').hidden = false;
search.addEventListener('input', filterTopics);
search.addEventListener('keydown', event => {
    if (event.key !== 'Enter' || !normalize(search.value)) return;
    const links = document.querySelectorAll('.topic-card li:not([hidden]) a');
    if (links.length === 1) links[0].click();
    else if (links.length) links[0].focus();
});
window.addEventListener('pageshow', filterTopics);
