(() => {
  'use strict';
  if (globalThis.LarpbloxAppearance?.get?.() === 'modern') return;
  const creatorImages = new Map();
  function update() {
    const root = document.querySelector('#item-details-container');
    const thumb = root?.querySelector('#item-thumbnail-container-frontend');
    const info = root?.querySelector('#item-info-container-frontend');
    if (!root || !thumb || !info || thumb.parentElement !== info.parentElement) return;
    const layout = thumb.parentElement;
    layout.classList.add('rbx2016-item-layout');
    root.classList.add('rbx2016-item-page');
    const creator = info.querySelector('.item-details-creator-container');
    const creatorId = creator?.querySelector('a.text-name')?.getAttribute('href')?.match(/\/users\/(\d+)\//)?.[1];
    if (creatorId && !creator.querySelector('.rbx2016-item-creator-avatar')) {
      const avatar = document.createElement('img'); avatar.className = 'rbx2016-item-creator-avatar'; avatar.alt = ''; avatar.hidden = true; creator.prepend(avatar);
      if (!creatorImages.has(creatorId)) creatorImages.set(creatorId, fetch(`https://thumbnails.roblox.com/v1/users/avatar?userIds=${creatorId}&size=100x100&format=Png&isCircular=false`)
        .then(response => response.ok ? response.json() : null).then(result => result?.data?.[0]?.imageUrl).catch(() => null));
      creatorImages.get(creatorId).then(url => { if (url) { avatar.src = url; avatar.hidden = false; } });
    }
    let subtitle = layout.querySelector('.rbx2016-item-subtitle');
    if (!subtitle) { subtitle = document.createElement('div'); subtitle.className = 'rbx2016-item-subtitle'; layout.append(subtitle); }
    const type = info.querySelector('#type-content')?.textContent.trim() || 'Avatar Item';
    const limited = thumb.querySelector('.icon-limited-label, .icon-limited-unique-label');
    const text = `${type}${limited ? ' / Collectible Item / Limited Edition' : ''}`;
    if (subtitle.textContent !== text) subtitle.textContent = text;
    const details = info.querySelector('#item-details');
    if (!details) return;
    for (const button of details.querySelectorAll('.btn-growth-lg')) {
      button.classList.toggle('rbx2016-buy-action', button.textContent.trim() === 'Buy');
    }
    let rowNumber = 5;
    for (const row of details.children) {
      if (!row.classList.contains('item-info-row-container')) continue;
      row.classList.add('rbx2016-item-metadata');
      const rowValue = row.querySelector('#item-details-description') ? '4' : String(rowNumber++);
      if (row.style.getPropertyValue('--rbx2016-item-row') !== rowValue) row.style.setProperty('--rbx2016-item-row', rowValue);
    }
  }
  function start() {
    update(); let queued = false;
    new MutationObserver(() => {
      if (queued) return;
      queued = true; requestAnimationFrame(() => { queued = false; update(); });
    }).observe(document.body, {childList: true, subtree: true});
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true}); else start();
})();
