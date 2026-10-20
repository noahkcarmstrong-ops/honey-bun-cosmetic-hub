(() => {
  'use strict';
  if (globalThis.LarpbloxAppearance?.get?.() === 'modern') return;
  const headshots = new Map();
  function loadHeadshot(userId) {
    if (!headshots.has(userId)) {
      headshots.set(userId, fetch(`https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${userId}&size=150x150&format=Png&isCircular=false`)
        .then(response => response.ok ? response.json() : null)
        .then(result => result?.data?.find(item => String(item.targetId) === userId)?.imageUrl || null)
        .catch(() => null));
    }
    return headshots.get(userId);
  }
  function update() {
    const home = document.querySelector('#HomeContainer');
    const meta = document.querySelector('meta[name="user-data"]');
    const name = document.documentElement?.dataset?.larpbloxName || meta?.getAttribute('data-name');
    if (!home || !name) return;
    let welcome = home.querySelector('.rbx2016-welcome');
    if (!welcome) {
      welcome = document.createElement('section');
      welcome.className = 'rbx2016-welcome';
      const avatar = document.createElement('img');
      avatar.className = 'rbx2016-welcome-avatar';
      avatar.hidden = true;
      const details = document.createElement('div');
      details.className = 'rbx2016-welcome-details';
      const heading = document.createElement('h1');
      const badge = document.createElement('span');
      badge.className = 'rbx2016-welcome-bc';
      badge.setAttribute('role', 'img');
      badge.setAttribute('aria-label', 'Builders Club style badge — Roblox Plus subscriber');
      details.append(heading, badge);
      welcome.append(avatar, details);
      home.prepend(welcome);
    }
    const heading = welcome.querySelector('h1');
    const greeting = `Hello, ${name}!`;
    if (heading.textContent !== greeting) heading.textContent = greeting;
    const avatar = welcome.querySelector('.rbx2016-welcome-avatar');
    const userId = meta.getAttribute('data-userid');
    avatar.alt = `${name}'s avatar`;
    if (avatar.dataset.userId !== userId && /^\d+$/.test(userId || '')) {
      avatar.dataset.userId = userId;
      avatar.hidden = true;
      loadHeadshot(userId).then(url => {
        if (!url || avatar.dataset.userId !== userId) return;
        avatar.src = url;
        avatar.hidden = false;
      });
    }
    // The header renders this badge only for the signed-in Plus subscriber.
    // Do not infer membership from the Subscribe/Roblox Plus navigation links.
    welcome.querySelector('.rbx2016-welcome-bc').hidden = !document.querySelector(
      '#header .age-bracket-label-plus-badge, #header [aria-label="Roblox Plus subscriber"]'
    );
    home.classList.add('rbx2016-has-welcome');
  }
  function start() {
    update();
    let queued = false;
    new MutationObserver(() => {
      if (queued) return;
      queued = true;
      requestAnimationFrame(() => { queued = false; update(); });
    }).observe(document.body, {childList: true, subtree: true});
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true});
  else start();
})();
