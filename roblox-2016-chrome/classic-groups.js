(() => {
  'use strict';
  if (globalThis.LarpbloxAppearance?.get?.() === 'modern') return;
  const labels = new Map([
    ['Communities', 'Groups'], ['My Communities', 'My Groups'],
    ['Search My Communities', 'Search My Groups'], ['Search Communities', 'Search Groups'],
    ['Search for Communities', 'Search for Groups'], ['Create Community', 'Create Group'],
    ['Create a Community', 'Create a Group'], ['Join Community', 'Join Group']
  ]);
  function update() {
    if (!/^\/(?:communities|groups)(?:\/|$)/.test(location.pathname)) return;
    for (const element of document.querySelectorAll('.container-main :is(h1,h2,h3,h4,span,div,label,button,a,input)')) {
      for (const node of element.childNodes) {
        if (node.nodeType !== 3) continue;
        const replacement = labels.get(node.textContent.trim());
        if (replacement) node.textContent = node.textContent.replace(node.textContent.trim(), replacement);
      }
      for (const attribute of ['placeholder', 'aria-label', 'title']) {
        const replacement = labels.get(element.getAttribute(attribute));
        if (replacement) element.setAttribute(attribute, replacement);
      }
    }
  }
  function start() {
    update(); let queued = false;
    new MutationObserver(() => {
      if (queued) return;
      queued = true; requestAnimationFrame(() => { queued = false; update(); });
    }).observe(document.body, {childList: true, subtree: true, characterData: true});
    window.addEventListener('popstate', update);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true}); else start();
})();
