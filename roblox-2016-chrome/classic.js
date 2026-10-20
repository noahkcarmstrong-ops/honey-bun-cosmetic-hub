(() => {
  'use strict';
  if (globalThis.LarpbloxAppearance?.get?.() === 'modern') return;
  // Keep Roblox's own controls, account information, and navigation intact.
  document.documentElement.classList.add('rbx2016');
  const labels = new Map([
    ['/discover', 'Games'], ['/charts', 'Games'], ['/games', 'Games'],
    ['/catalog', 'Catalog'], ['/communities', 'Groups'],
    ['/groups', 'Groups'], ['/develop', 'Develop'],
    ['/plus', 'Builders Club'], ['/premium/membership', 'Builders Club']
  ]);
  function restyle(root) {
    const links = root.querySelectorAll('#header a[href], #navigation a[href], .rbx-header a[href], #left-navigation-container a[href], .rbx-left-col a[href]');
    for (const link of links) {
      const url = new URL(link.href, location.origin);
      const isCreateLink = url.origin === 'https://create.roblox.com' && link.id?.startsWith('header-develop-');
      if (url.origin !== location.origin && !isCreateLink) continue;
      const oldLabels = new Map([['Roblox Plus', 'Builders Club'], ['Communities', 'Groups']]);
      const label = isCreateLink ? 'Develop' : labels.get(url.pathname.replace(/\/$/, '')) || oldLabels.get(link.textContent?.trim());
      if (!label) continue;
      // Change only a plain navigation label, never counters or nested controls.
      const node = [...link.childNodes].find(n => n.nodeType === Node.TEXT_NODE && n.textContent.trim());
      if (node && node.textContent.trim() !== label) node.textContent = label;
      for (const span of link.querySelectorAll('.font-header-2, .font-header-3, .text-nav, span, div')) {
        if (span.children.length === 0 && span.textContent !== label &&
          ['Roblox Plus', 'Communities', 'Discover', 'Charts', 'Games', 'Catalog', 'Create', 'Develop', 'Groups', 'Premium', 'Builders Club'].includes(span.textContent.trim())) span.textContent = label;
      }
    }
  }
  function decorate(root) {
    const logo = root.querySelector('#nav-logo-link');
    if (logo) {
      logo.setAttribute('aria-label', 'LARPBLOX — Home');
      logo.setAttribute('title', 'LARPBLOX');
    }
    // Decorate the real name only, without changing React's text nodes.
    const meta = root.querySelector('meta[name="user-data"]');
    const heading = root.querySelector('#HomeContainer .home-header h1, #HomeContainer > .section > div > h1, .home-header-content h1');
    if (meta && heading) {
      const name = heading.textContent.trim();
      if (name && [meta.getAttribute('data-name'), meta.getAttribute('data-displayname')].includes(name)) {
        heading.classList.add('rbx2016-greeting');
      }
    }
  }
  function start() {
    restyle(document);
    decorate(document);
    let scheduled = false;
    // React replaces navigation on page changes; batch updates once per frame.
    new MutationObserver(records => {
      if (scheduled || !records.some(r => r.addedNodes.length)) return;
      scheduled = true;
      requestAnimationFrame(() => { scheduled = false; restyle(document); decorate(document); });
    }).observe(document.body, { childList: true, subtree: true });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true });
  else start();
})();
