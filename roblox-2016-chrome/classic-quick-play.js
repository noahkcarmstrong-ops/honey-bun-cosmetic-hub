(() => {
  'use strict';
  if (globalThis.LarpbloxAppearance?.get?.() === 'modern') return;
  function positionPlay(host, card) {
    const details = card.querySelector('.game-card-info');
    if (!details) return;
    const bottom = details.getBoundingClientRect().bottom;
    const top = host.getBoundingClientRect().top;
    const value = `${Math.max(0, bottom - top + 3)}px`;
    if (host.style.getPropertyValue('--rbx2016-play-top') !== value) host.style.setProperty('--rbx2016-play-top', value);
  }
  function update() {
    for (const card of document.querySelectorAll('.game-card-container')) {
      const host = card.closest('a') ? card.closest('.game-card') : card;
      if (!host || host.tagName === 'A') continue;
      const link = [...card.querySelectorAll('a[href]')].find(node => {
        const url = new URL(node.href, location.origin);
        return url.origin === location.origin && /^\/games\/\d+(?:\/|$)/.test(url.pathname);
      });
      if (!link) continue;
      const placeId = new URL(link.href, location.origin).pathname.match(/^\/games\/(\d+)/)[1];
      let play = host.querySelector('.rbx2016-quick-play');
      if (!play) {
        play = document.createElement('a');
        play.className = 'rbx2016-quick-play';
        play.textContent = '▶ Play';
        // Keep native card click handlers from opening the details page instead.
        play.addEventListener('click', event => event.stopPropagation());
        host.append(play);
        const position = () => positionPlay(host, card);
        host.addEventListener('pointerenter', position);
        host.addEventListener('focusin', position);
        if (typeof ResizeObserver !== 'undefined') {
          const observer = new ResizeObserver(position);
          observer.observe(card);
          const details = card.querySelector('.game-card-info');
          if (details) observer.observe(details);
        }
      }
      play.href = `/games/start?placeId=${placeId}`;
      const name = card.querySelector('.game-card-name')?.textContent.trim() || 'game';
      play.setAttribute('aria-label', `Play ${name}`);
      host.classList.add('rbx2016-quick-play-card');
      positionPlay(host, card);
    }
  }
  function start() {
    update();
    let queued = false;
    new MutationObserver(() => {
      if (queued) return;
      queued = true; requestAnimationFrame(() => { queued = false; update(); });
    }).observe(document.body, {childList: true, subtree: true});
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true});
  else start();
})();
