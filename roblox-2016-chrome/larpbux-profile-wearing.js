// Keep the profile's existing heading and native cards available for real mode.
(() => {
  'use strict';
  let cache, record, retryTimer;
  const names = new Map();
  function restore() {
    if (!record) return;
    record.host.remove();
    if (record.display) record.source.style.setProperty('display', record.display, record.priority);
    else record.source.style.removeProperty('display');
    record = undefined;
  }
  function itemName(id, known, signal) {
    if (known.has(id)) return Promise.resolve(known.get(id));
    if (names.has(id)) return Promise.resolve(names.get(id));
    return fetch(`https://economy.roblox.com/v2/assets/${id}/details`, {signal})
      .then(response => response.ok ? response.json() : null)
      .then(data => { if (data?.Name) names.set(id, data.Name); return data?.Name || `Item ${id}`; })
      .catch(() => `Item ${id}`);
  }
  function card(item, width, thumbnail) {
    const root = document.createElement('div'); root.className = 'item-card profile-item-card';
    root.style.cssText = `flex:0 0 ${width}px;width:${width}px`;
    root.dataset.larpAssetId = String(item.id);
    const container = document.createElement('div'); container.className = 'item-card-container';
    const holder = document.createElement('div'); holder.className = 'item-card-thumb-container';
    const link = document.createElement('a'); link.className = 'item-card-link'; link.href = `/catalog/${item.id}`;
    const thumb = document.createElement('span'); thumb.className = 'thumbnail-2d-container';
    const image = document.createElement('img'); image.alt = item.name; thumbnail(image, item);
    thumb.append(image); link.append(thumb); holder.append(link);
    const caption = document.createElement('div'); caption.className = 'item-card-caption';
    const title = document.createElement('a'); title.className = 'item-card-name'; title.href = link.href;
    title.textContent = item.name; title.title = item.name; caption.append(title);
    container.append(holder, caption); root.append(container); return root;
  }
  async function update(options = {}) {
    const {userId, active, signature, items = [], loadDefinition, thumbnail} = options;
    const owner = location.pathname.match(/^\/users\/(\d+)\/profile\/?$/i)?.[1];
    const ownProfile = owner === String(userId) || /^\/users\/profile\/?$/.test(location.pathname);
    const source = ownProfile && active && document.querySelector('.profile-currently-wearing .profile-carousel:not(.larpbux-currently-wearing)');
    if (!source) { restore(); clearTimeout(retryTimer); cache?.controller.abort(); cache = undefined; return; }
    const key = `${userId}:${signature}`;
    if (record && (record.source !== source || record.key !== key || !record.host.isConnected)) restore();
    if (record) return;
    if (cache?.key === key && cache.retryAt > Date.now()) return;
    if (!cache || cache.key !== key || cache.retryAt) {
      clearTimeout(retryTimer);
      cache?.controller.abort();
      const controller = new AbortController(), known = new Map(items.map(item => [Number(item.id), item.name]));
      for (const native of source.querySelectorAll('.item-card')) {
        const id = native.querySelector('a[href*="/catalog/"]')?.getAttribute('href')?.match(/\/catalog\/(\d+)/)?.[1];
        const name = native.querySelector('.item-card-name')?.textContent?.trim();
        if (id && name && !known.has(Number(id))) known.set(Number(id), name);
      }
      const entry = {key, controller}; cache = entry;
      entry.promise = Promise.resolve().then(() => loadDefinition(controller.signal)).then(definition => Promise.all(
        [...new Set(definition.assets.map(asset => Number(asset.id)).filter(id => Number.isSafeInteger(id) && id > 0))]
          .map(async id => ({id, name: await itemName(id, known, controller.signal), itemType: 'Asset'}))));
    }
    const entry = cache;
    try {
      const wearing = await entry.promise;
      if (cache !== entry || entry.controller.signal.aborted || !source.isConnected || record) return;
      const host = source.cloneNode(false); host.removeAttribute('id'); host.classList.add('larpbux-currently-wearing');
      host.style.cssText = 'display:flex;gap:16px;overflow-x:auto;align-items:flex-start;padding-bottom:8px';
      const width = source.querySelector('.item-card')?.getBoundingClientRect().width || 150;
      for (const item of wearing) host.append(card(item, width, thumbnail));
      if (!wearing.length) host.textContent = 'No avatar items equipped.';
      record = {key, source, host, display: source.style.getPropertyValue('display'), priority: source.style.getPropertyPriority('display')};
      source.after(host); source.style.setProperty('display', 'none', 'important');
    } catch (_) {
      if (cache !== entry) return;
      entry.retryAt = Date.now() + 5000;
      clearTimeout(retryTimer);
      retryTimer = setTimeout(() => { if (cache === entry) update(options); }, 5001);
    }
  }
  globalThis.LarpbloxProfileWearing = {update};
})();
