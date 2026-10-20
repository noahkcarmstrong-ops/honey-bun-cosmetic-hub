(() => {
  'use strict';
  const root = globalThis;
  const names = {salestypefilter:'salesTypeFilter',keyword:'keyword',creatorname:'creatorName',creatortype:'creatorType',creatortargetid:'creatorTargetId',pxmin:'minPrice',pxmax:'maxPrice',minprice:'minPrice',maxprice:'maxPrice',includenotforsale:'includeNotForSale',sorttype:'sortType',sortaggregation:'sortAggregation',category:'category',subcategory:'subcategory',assettypeids:'assetTypeIds',bundletypeids:'bundleTypeIds'};
  function queryFor(params, cursor = '') {
    const query = new URLSearchParams();
    params.forEach((value, key) => { const name = names[key.toLowerCase()] || (key.toLowerCase() === 'taxonomy' ? 'taxonomy' : null); if (name && value !== '') query.set(name, value); });
    if (!query.has('sortType')) query.set('sortType', '5');
    if (!query.has('salesTypeFilter')) query.set('salesTypeFilter', '1');
    if (cursor) query.set('cursor', cursor);
    query.set('limit', '30');
    return query;
  }
  function priceFor(item) {
    if (item.priceStatus === 'OffSale') return 'Off Sale';
    if (item.priceStatus === 'NoResellers') return 'No Resellers';
    const price = item.lowestResalePrice > 0 ? item.lowestResalePrice : item.price;
    if (price === 0 || item.priceStatus === 'Free') return 'Free';
    return Number.isFinite(price) ? `R$${price.toLocaleString('en-US')}` : 'See Item';
  }
  function itemId(href) { const match = String(href).match(/\/(?:catalog|bundles)\/(\d+)/); return match && Number(match[1]); }
  function limitedClass(item) {
    return item.itemRestrictions?.includes('LimitedUnique') ? 'restriction-icon icon-limited-unique-label' :
      item.itemRestrictions?.some(x => x === 'Limited' || x === 'Collectible') ? 'restriction-icon icon-limited-label' : '';
  }
  if (typeof module !== 'undefined' && module.exports) { module.exports = {queryFor, priceFor, itemId}; return; }
  if (root.LarpbloxAppearance?.get?.() !== 'modern') return;
  let generation = 0, controller, native, host, list, cursor = '', items = [], thumbnails = new Map(), nativeHidden, inFlight = false, checked = false, observedRoute = '', shown = false;
  const css = document.createElement('style');
  css.textContent = 'ul.organic-items-wrapper.larpblox-sort-recovery-hidden{display:none!important}.larpblox-modern-catalog-results{margin-top:16px}.larpblox-modern-catalog-results .larpblox-sort-recovery-status{padding:12px;color:#555}.larpblox-modern-catalog-results .larpblox-sort-recovery-more{margin:16px auto;display:block}';
  document.documentElement.append(css);
  const card = item => {
    const li = document.createElement('li'); li.className = 'catalog-item-container';
    const box = document.createElement('div'); box.className = 'item-card-container';
    const link = document.createElement('a'); link.className = 'item-card-link'; link.href = `/${item.itemType === 'Bundle' ? 'bundles' : 'catalog'}/${item.id}`; link.title = item.name;
    const thumb = document.createElement('div'); thumb.className = 'item-card-thumb-container';
    const imageWrap = document.createElement('span'); imageWrap.className = 'thumbnail-2d-container';
    const image = document.createElement('img'); image.alt = item.name; image.loading = 'lazy'; image.src = thumbnails.get(`${item.itemType}:${item.id}`) || '';
    const inner = document.createElement('div'); inner.className = 'item-card-thumb-container-inner';
    imageWrap.append(image); inner.append(imageWrap); thumb.append(inner);
    const badge = limitedClass(item); if (badge) { const icon = document.createElement('span'); icon.className = badge; thumb.append(icon); }
    link.append(thumb);
    const caption = document.createElement('div'); caption.className = 'item-card-caption';
    const name = document.createElement('div'); name.className = 'item-card-name'; name.textContent = item.name;
    const price = document.createElement('div'); price.className = 'text-overflow item-card-price font-header-2 text-subheader margin-top-none';
    if (/^R\$/.test(priceFor(item))) { const icon = document.createElement('span'); icon.className = 'icon-robux-16x16'; price.append(icon); }
    const value = document.createElement('span'); value.className = 'text-robux-tile'; value.textContent = priceFor(item).replace(/^R\$/, ''); price.append(value);
    caption.append(name, price); link.append(caption); box.append(link); li.append(box); return li;
  };
  async function loadThumbs(batch, signal) {
    await Promise.all(['Asset','Bundle'].map(async type => {
      const ids = batch.filter(x => x.itemType === type).map(x => x.id); if (!ids.length) return;
      const path = type === 'Asset' ? `assets?assetIds=${ids.join(',')}` : `bundles/thumbnails?bundleIds=${ids.join(',')}`;
      try { const response = await fetch(`https://thumbnails.roblox.com/v1/${path}&size=150x150&format=Png&isCircular=false`, {signal, credentials:'omit'});
        if (!response.ok) return; for (const image of (await response.json()).data || []) thumbnails.set(`${type}:${image.targetId}`, image.imageUrl);
      } catch (error) { if (error.name === 'AbortError') throw error; }
    }));
  }
  function mount() {
    if (host) return;
    host = document.createElement('section'); host.className = 'larpblox-modern-catalog-results'; host.id = 'larpblox-modern-catalog-results';
    list = document.createElement('ul'); list.className = 'hlist item-cards-stackable organic-items-wrapper larpblox-sort-recovery-list';
    const status = document.createElement('div'); status.className = 'larpblox-sort-recovery-status';
    const more = document.createElement('button'); more.className = 'larpblox-sort-recovery-more'; more.textContent = 'Load more'; more.hidden = true;
    const retry = document.createElement('button'); retry.textContent = 'Retry'; retry.hidden = true;
    host.append(status, retry, list, more); native.before(host);
    more.onclick = () => fetchPage(); retry.onclick = () => { retry.hidden = true; fetchPage(); };
    host._status = status; host._more = more; host._retry = retry;
  }
  function show() { mount(); shown = true; nativeHidden = native.hidden; native.hidden = true; native.classList.add('larpblox-sort-recovery-hidden'); render(); }
  function render() { if (!host) return; list.replaceChildren(...items.map(card)); host._more.hidden = !cursor; host._status.textContent = items.length ? '' : 'No high-priced items found.'; }
  async function fetchPage(reset = false) {
    if (!native || inFlight) return; checked = true; inFlight = true; const route = location.href; const ticket = ++generation; controller?.abort(); controller = new AbortController(); const signal = controller.signal;
    if (reset) { items = []; cursor = ''; thumbnails.clear(); }
    try {
      const response = await fetch(`https://catalog.roblox.com/v2/search/items/details?${queryFor(new URLSearchParams(location.search), cursor)}`, {signal, credentials:'omit'});
      if (!response.ok) throw new Error(`Catalog request failed (${response.status}).`);
      const payload = await response.json(); if (ticket !== generation || route !== location.href) return; if (!Array.isArray(payload.data)) throw new Error('Catalog returned an unexpected response.');
      const next = payload.data.filter(x => Number.isSafeInteger(x.id) && x.id > 0 && ['Asset','Bundle'].includes(x.itemType));
      await loadThumbs(next, signal); if (ticket !== generation) return;
      if (route !== location.href) return;
      items.push(...next); cursor = payload.nextPageCursor || '';
      const expected = next[0]?.id; const nativeIds = [...native.querySelectorAll('a[href]')].map(a => itemId(a.href)).filter(Boolean);
      if (!shown && expected && nativeIds.length && !nativeIds.includes(expected)) show();
      else if (!shown && host) { host.remove(); host = list = null; }
      else if (host) render();
    } catch (error) {
      if (ticket !== generation || error.name === 'AbortError') return;
      mount(); host._status.textContent = error.message; host._retry.hidden = false;
    } finally { if (ticket === generation) inFlight = false; }
  }
  function reset() {
    native?.isConnected && (native.hidden = shown ? nativeHidden : native.hidden, native.classList.remove('larpblox-sort-recovery-hidden'));
    host?.remove(); host = list = null; native = null; items = []; cursor = ''; thumbnails.clear(); shown = false; checked = false; controller?.abort(); generation++; inFlight = false;
  }
  function eligible() { return root.LarpbloxAppearance?.get?.() === 'modern' && /^\/catalog\/?$/.test(location.pathname) && new URLSearchParams(location.search).get('SortType') === '5'; }
  function sync() {
    const route = location.href;
    if (route !== observedRoute) { reset(); observedRoute = route; }
    if (!eligible()) return;
    if (native && !native.isConnected) reset();
    if (!native) native = [...document.querySelectorAll('ul.organic-items-wrapper')].find(node => !node.classList.contains('larpblox-sort-recovery-list'));
    if (!checked && native?.querySelector('a[href]')) fetchPage();
  }
  let queued = false;
  const observer = new MutationObserver(() => { if (queued) return; queued = true; requestAnimationFrame(() => { queued = false; sync(); }); });
  function routeChange() { sync(); }
  for (const method of ['pushState','replaceState']) { const original = history[method]; history[method] = function (...args) { const result = original.apply(this, args); routeChange(); return result; }; }
  addEventListener('popstate', routeChange);
  function start() { observer.observe(document.body, {childList:true,subtree:true}); sync(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once:true}); else start();
})();
