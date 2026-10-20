(() => {
  'use strict';
  if (globalThis.LarpbloxAppearance?.get?.() === 'modern') return;

  const FALLBACK = 'rbx2016-home-favorites';
  const RECENT = 'rbx2016-recent-row';
  const FAVORITES = 'rbx2016-favorites-row';

  const text = node => (node?.textContent || '').replace(/\s+/g, ' ').trim().toLowerCase();

  function rowForHeading(heading) {
    let row = heading.closest?.('.game-sort, .game-sort-container');
    if (!row) row = heading.closest?.('section, .section, .home-section');
    if (!row) row = heading.parentElement;
    if (!row || !row.querySelector?.('.game-card-container, .game-card, [data-testid="game-card"]')) return null;
    return row;
  }

  function markNative(home) {
    const headings = [...home.querySelectorAll('h2, h3, .game-sort-header')];
    const rows = [];
    for (const heading of headings) {
      if (heading.closest?.('.' + FALLBACK)) continue;
      const label = text(heading);
      const row = rowForHeading(heading);
      if (!row) continue;
      const kind = label === 'favorites' || label === 'my favorites' ? 'favorites' : /^(continue|continue playing|recently played)$/.test(label) ? 'recent' : '';
      if (!kind) continue;
      const title = kind === 'favorites' ? 'My Favorites' : 'Recently Played';
      if (heading.textContent !== title) heading.textContent = title;
      row.classList.add('rbx2016-home-feed-row', kind === 'favorites' ? FAVORITES : RECENT);
      rows.push(row);
    }
    if (!rows.length) return false;
    const feed = rows[0].parentElement;
    if (feed) {
      feed.classList.add('rbx2016-home-game-feed');
      [...feed.children].forEach(child => {
        if (child.querySelector?.('.game-card-container, .game-card, [data-testid="game-card"]')) child.classList.add('rbx2016-home-feed-row');
      });
    }
    return rows.some(row => row.classList.contains(FAVORITES));
  }

  function card(game, image) {
    const id = Number(game?.rootPlace?.id || game?.placeId);
    const name = typeof game?.name === 'string' ? game.name.trim() : '';
    if (!Number.isFinite(id) || !name) return null;
    const item = document.createElement('div'); item.className = 'game-card';
    const box = document.createElement('div'); box.className = 'game-card-container';
    const link = document.createElement('a'); link.className = 'game-card-link'; link.href = `/games/${id}`; link.setAttribute('aria-label', name);
    const thumb = document.createElement('div'); thumb.className = 'game-card-thumb-container';
    const img = document.createElement('img'); img.className = 'game-card-thumb'; img.src = image || ''; img.alt = '';
    thumb.append(img);
    const title = document.createElement('div'); title.className = 'game-card-name'; title.textContent = name;
    link.append(thumb, title); box.append(link); item.append(box);
    return item;
  }

  function fallback(home, userId) {
    let row = home.querySelector(`.${FALLBACK}`);
    if (!row) {
      row = document.createElement('section'); row.className = `rbx2016-home-game-row ${FALLBACK} ${FAVORITES} rbx2016-home-feed-row`;
      const header = document.createElement('div'); header.className = 'container-header';
      const heading = document.createElement('h2'); heading.textContent = 'My Favorites';
      const all = document.createElement('a'); all.className = 'rbx2016-see-all'; all.href = `/users/${encodeURIComponent(userId)}/favorites#!/places`; all.textContent = 'See All';
      header.append(heading, all);
      const list = document.createElement('div'); list.className = 'rbx2016-home-game-list';
      row.append(header, list);
      const feed = home.querySelector('.rbx2016-home-game-feed') || home;
      feed.append(row);
    }
    return row;
  }

  async function loadFavorites(home, userId) {
    const row = fallback(home, userId);
    const list = row.querySelector('.rbx2016-home-game-list');
    row.setAttribute('data-rbx2016-state', 'loading');
    list.textContent = 'Loading favorites…';
    try {
      const response = await fetch(`https://games.roblox.com/v2/users/${encodeURIComponent(userId)}/favorite/games?limit=10&sortOrder=Desc`, {credentials: 'include'});
      if (!response.ok) throw new Error(`favorites ${response.status}`);
      const payload = await response.json();
      if (!Array.isArray(payload?.data)) throw new Error('invalid favorites response');
      const games = payload.data.filter(game => Number.isFinite(Number(game?.id)) && Number.isFinite(Number(game?.rootPlace?.id)) && typeof game?.name === 'string').slice(0, 6);
      if (!games.length) { list.textContent = 'No favorite games yet.'; row.setAttribute('data-rbx2016-state', 'loaded'); return; }
      const ids = games.map(game => Number(game?.id)).filter(Number.isFinite);
      let images = [];
      if (ids.length) {
        const thumbs = await fetch(`https://thumbnails.roblox.com/v1/games/icons?universeIds=${ids.join(',')}&size=150x150&format=Png&isCircular=false`, {credentials: 'include'});
        if (thumbs.ok) images = (await thumbs.json()).data || [];
      }
      list.textContent = '';
      let rendered = 0;
      for (const game of games) {
        const id = Number(game?.id);
        const image = images.find(item => Number(item.targetId) === id)?.imageUrl;
        const item = card(game, image);
        if (item) { list.append(item); rendered++; }
      }
      if (!rendered) list.textContent = 'No favorite games found.';
      row.setAttribute('data-rbx2016-state', 'loaded');
    } catch (_) {
      list.textContent = 'Favorites could not be loaded right now.';
      row.setAttribute('data-rbx2016-state', 'error');
    }
  }

  function update() {
    const home = document.querySelector('#HomeContainer');
    const meta = document.querySelector('meta[name="user-data"]');
    const userId = meta?.getAttribute('data-userid');
    if (!home || !userId) return;
    const nativeFavorites = markNative(home);
    const own = home.querySelector(`.${FALLBACK}`);
    if (nativeFavorites) { if (own) own.hidden = true; return; }
    if (own) {
      own.hidden = false;
      if (own.getAttribute('data-rbx2016-state')) return;
    }
    loadFavorites(home, userId);
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
