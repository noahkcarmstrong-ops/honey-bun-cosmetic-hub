(() => {
  'use strict';
  // Labels follow the classic catalog; values address today's Marketplace.
  const categories = [
    ['All Items', '1'], ['Featured', '0'], ['Collectibles', '2'],
    ['Clothing', '3'], ['Shirts', '3:56'], ['T-Shirts', '3:55'], ['Pants', '3:57'],
    ['Accessories', '11'], ['Hats', '11:54'], ['Hair', '11:20'],
    ['Face Accessories', '11:21'], ['Neck', '11:22'], ['Shoulder', '11:23'],
    ['Front', '11:24'], ['Back', '11:25'], ['Waist', '11:26'],
    ['Faces', '18:10'], ['Heads', '18:15'], ['Packages', '18:37'], ['Gear', '11:5'],
    ['Animations', '12'], ['Emotes', '12:39']
  ];
  const sorts = [['Relevance', '0'], ['Most Favorited', '1'], ['Bestselling', '2'], ['Recently Updated', '3'], ['Price (Low to High)', '4'], ['Price (High to Low)', '5']];
  function queryFor(params, cursor = '') {
    const query = new URLSearchParams({Category: '1', Limit: '30', SortType: '0'});
    for (const key of ['Category', 'Subcategory', 'Keyword', 'CreatorName', 'CreatorType', 'CreatorTargetId', 'MinPrice', 'MaxPrice', 'SortType', 'SortAggregation', 'salesTypeFilter', 'IncludeNotForSale']) {
      if (params.get(key)) query.set(key, params.get(key));
    }
    if (params.get('UGC') !== '1') {
      query.delete('CreatorName');
      query.set('CreatorType', 'User');
      query.set('CreatorTargetId', '1');
    }
    if (cursor) query.set('Cursor', cursor);
    return query;
  }
  function priceFor(item) {
    if (item.priceStatus === 'OffSale') return 'Off Sale';
    if (item.priceStatus === 'NoResellers') return 'No Resellers';
    const price = item.lowestResalePrice > 0 ? item.lowestResalePrice : item.price;
    if (price === 0 || item.priceStatus === 'Free') return 'Free';
    return typeof price === 'number' ? `R$${price.toLocaleString('en-US')}` : 'See Item';
  }
  function limitedType(item) {
    const restrictions = item.itemRestrictions || [];
    if (restrictions.includes('LimitedUnique')) return 'unique';
    return restrictions.some(value => ['Limited', 'Collectible'].includes(value)) ? 'limited' : '';
  }
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = {categories, sorts, queryFor, priceFor, limitedType};
    return;
  }
  if (globalThis.LarpbloxAppearance?.get?.() === 'modern') return;
  const create = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };
  let mounted, revision = 0, request;
  function mount(host) {
    const root = create('section', 'rbx2016-catalog');
    const header = create('header', 'rbx2016-catalog-header');
    const search = create('form', 'rbx2016-catalog-search');
    const keyword = create('input'); keyword.type = 'search'; keyword.setAttribute('aria-label', 'Search catalog');
    const category = create('select'); category.setAttribute('aria-label', 'Item category');
    for (const [label, value] of categories) { const option = create('option', '', label); option.value = value; category.append(option); }
    search.append(keyword, category, create('button', '', 'Search'));
    header.append(create('h1', '', 'Catalog'), search);
    const layout = create('div', 'rbx2016-catalog-layout');
    const sidebar = create('aside', 'rbx2016-catalog-sidebar');
    const browse = create('h2', '', 'Browse by'); browse.append(create('span', '', 'Category')); sidebar.append(browse);
    const results = create('main', 'rbx2016-catalog-results');
    const resultsHeader = create('div', 'rbx2016-catalog-results-header');
    const title = create('h2');
    const buy = create('a', 'rbx2016-catalog-buy', 'Buy ROBUX'); buy.href = '/upgrades/robux';
    resultsHeader.append(title, buy);
    const status = create('p', 'rbx2016-catalog-status'); status.setAttribute('role', 'status');
    const grid = create('div', 'rbx2016-catalog-grid');
    const pages = create('nav', 'rbx2016-catalog-pages'); pages.setAttribute('aria-label', 'Catalog pages');
    const previous = create('button', '', '‹ Previous');
    const page = create('span');
    const next = create('button', '', 'Next ›');
    pages.append(previous, page, next); results.append(resultsHeader, status, grid, pages);
    layout.append(sidebar, results); root.append(header, layout); host.append(root);
    host.classList.add('rbx2016-catalog-host');
    const state = {host, root, keyword, category, sidebar, title, status, grid, previous, next, page, params: null, url: '', cursor: '', pageNumber: 1};
    const filters = {};
    function filter(key, label) {
      const details = create('details', 'rbx2016-catalog-filter');
      const summary = create('summary', '', label); const menu = create('div', 'rbx2016-catalog-menu');
      details.append(summary, menu); sidebar.append(details); filters[key] = {details, summary, menu};
      details.addEventListener('toggle', () => {
        if (details.open) for (const other of Object.values(filters)) if (other.details !== details) other.details.open = false;
      });
      return menu;
    }
    function choice(menu, label, changes) {
      const button = create('button', '', label); button.type = 'button';
      button.addEventListener('click', () => {
        navigate(changes);
        for (const filter of Object.values(filters)) filter.details.open = false;
      }); menu.append(button);
    }
    const categoryMenu = filter('category', 'All Items');
    for (const [label, value] of categories) {
      const [Category, Subcategory = ''] = value.split(':');
      choice(categoryMenu, label, {Category, Subcategory});
    }
    const creatorMenu = filter('creator', 'All Creators');
    choice(creatorMenu, 'All Creators', {UGC: '1', CreatorName: '', CreatorType: '', CreatorTargetId: ''});
    choice(creatorMenu, 'ROBLOX', {UGC: '', CreatorName: '', CreatorType: 'User', CreatorTargetId: '1'});
    const creatorForm = create('form');
    const creatorName = create('input'); creatorName.placeholder = 'Creator name'; creatorName.setAttribute('aria-label', 'Creator name'); creatorName.required = true;
    creatorForm.append(creatorName, create('button', '', 'Apply'));
    creatorForm.addEventListener('submit', event => { event.preventDefault(); navigate({UGC: '1', CreatorName: creatorName.value.trim(), CreatorType: '', CreatorTargetId: ''}); filters.creator.details.open = false; });
    creatorMenu.append(creatorForm);
    const priceMenu = filter('price', 'Any Price');
    choice(priceMenu, 'Any Price', {MinPrice: '', MaxPrice: ''});
    choice(priceMenu, 'Free', {MinPrice: '', MaxPrice: '0'});
    const priceForm = create('form');
    const min = create('input'), max = create('input');
    max.addEventListener('input', () => max.setCustomValidity(''));
    min.addEventListener('input', () => max.setCustomValidity(''));
    for (const [input, label] of [[min, 'Min price'], [max, 'Max price']]) { input.type = 'number'; input.min = '0'; input.step = '1'; input.placeholder = label; input.setAttribute('aria-label', label); }
    priceForm.append(min, max, create('button', '', 'Apply'));
    priceForm.addEventListener('submit', event => {
      event.preventDefault(); max.setCustomValidity('');
      if (min.value && max.value && Number(min.value) > Number(max.value)) { max.setCustomValidity('Maximum price must be at least the minimum.'); max.reportValidity(); return; }
      navigate({MinPrice: min.value, MaxPrice: max.value}); filters.price.details.open = false;
    });
    priceMenu.append(priceForm);
    const sortMenu = filter('sort', 'Sort by Relevance');
    for (const [label, value] of sorts) choice(sortMenu, label, {SortType: value});
    const period = create('select'); period.setAttribute('aria-label', 'Popularity time period');
    for (const [label, value] of [['All Time', '5'], ['Past Day', '1'], ['Past Week', '3'], ['Past Month', '4']]) { const option = create('option', '', label); option.value = value; period.append(option); }
    period.addEventListener('change', () => navigate({SortAggregation: period.value})); sortMenu.append(period);
    const salesMenu = filter('sales', 'Sales Type');
    choice(salesMenu, 'All Items', {salesTypeFilter: '1'});
    choice(salesMenu, 'Limited Items', {salesTypeFilter: '2'});
    const unavailableMenu = filter('unavailable', 'Unavailable Items');
    choice(unavailableMenu, 'Hide Unavailable Items', {IncludeNotForSale: ''});
    choice(unavailableMenu, 'Show Unavailable Items', {IncludeNotForSale: 'true'});
    const ugcLabel = create('label', 'rbx2016-catalog-ugc');
    const ugc = create('input'); ugc.type = 'checkbox';
    ugcLabel.append(ugc, create('span', '', 'Show UGC'));
    sidebar.append(ugcLabel);
    ugc.addEventListener('change', () => navigate({UGC: ugc.checked ? '1' : '', CreatorName: '', CreatorType: '', CreatorTargetId: ''}));
    const legend = create('details', 'rbx2016-catalog-legend'); legend.open = true;
    legend.append(create('summary', '', 'Legend'));
    const bc = create('span', 'legend-bc'); bc.setAttribute('role', 'img'); bc.setAttribute('aria-label', 'Builders Club'); legend.append(bc);
    for (const [badge, heading, description] of [
      ['', 'Builders Club Only', 'Historically purchasable only by Builders Club members. Roblox no longer offers this membership.'],
      ['LIMITED', 'Limited Items', 'Discontinued items that owners can resell to other users.'],
      ['LIMITED U', 'Limited Unique Items', 'Originally sold in limited quantities. Owners can resell available copies.']
    ]) {
      if (badge) legend.append(create('span', badge === 'LIMITED' ? 'legend-limited' : 'legend-unique', badge));
      legend.append(create('strong', '', heading), create('p', '', description));
    }
    sidebar.append(legend);
    function navigate(changes) {
      const params = new URLSearchParams(state.params);
      for (const [key, value] of Object.entries(changes)) value === '' ? params.delete(key) : params.set(key, value);
      params.delete('Cursor');
      history.pushState(null, '', `/catalog?${params}`);
      sync(state);
    }
    search.addEventListener('submit', event => { event.preventDefault(); const [Category, Subcategory = ''] = category.value.split(':'); navigate({Keyword: keyword.value.trim(), Category, Subcategory}); });
    previous.addEventListener('click', () => { state.pageNumber = Math.max(1, state.pageNumber - 1); load(state, state.previousCursor); });
    next.addEventListener('click', () => { state.pageNumber++; load(state, state.nextCursor); });
    state.filters = filters; state.min = min; state.max = max; state.period = period; state.creatorName = creatorName; state.ugc = ugc;
    return state;
  }
  function sync(state) {
    state.url = location.search;
    state.params = new URLSearchParams(location.search);
    state.pageNumber = 1;
    const params = state.params;
    state.ugc.checked = params.get('UGC') === '1';
    const categoryValue = params.get('Category') || '1';
    const sub = params.get('Subcategory');
    const current = categories.find(([, value]) => value === categoryValue + (sub ? `:${sub}` : ''));
    state.category.value = current?.[1] || '1'; state.keyword.value = params.get('Keyword') || '';
    state.min.value = params.get('MinPrice') || ''; state.max.value = params.get('MaxPrice') || '';
    state.period.value = params.get('SortAggregation') || '5'; state.creatorName.value = params.get('CreatorName') || '';
    state.filters.category.summary.textContent = current?.[0] || 'All Items';
    state.filters.creator.summary.textContent = !state.ugc.checked ? 'ROBLOX' : params.get('CreatorName') || (params.get('CreatorTargetId') === '1' ? 'ROBLOX' : 'All Creators');
    state.filters.price.summary.textContent = params.get('MaxPrice') === '0' ? 'Free' : state.min.value || state.max.value ? `R$${state.min.value || '0'} – ${state.max.value || 'Any'}` : 'Any Price';
    state.filters.sort.summary.textContent = `Sort by ${sorts.find(([, value]) => value === (params.get('SortType') || '0'))?.[0] || 'Relevance'}`;
    state.filters.sales.summary.textContent = params.get('salesTypeFilter') === '2' ? 'Limited Items' : 'Sales Type';
    state.filters.unavailable.summary.textContent = params.get('IncludeNotForSale') === 'true' ? 'Show Unavailable Items' : 'Unavailable Items';
    state.title.textContent = state.keyword.value ? `Search Results for “${state.keyword.value}”` : categoryValue === '1' || categoryValue === '0' ? 'Featured Items on ROBLOX' : (current?.[0] || 'Catalog Items');
    load(state, params.get('Cursor') || '');
  }
  async function load(state, cursor) {
    const ticket = ++revision;
    request?.abort(); request = new AbortController(); const signal = request.signal;
    state.previous.disabled = true; state.next.disabled = true;
    state.status.classList.remove('rbx2016-catalog-error'); state.status.textContent = 'Loading items…';
    state.grid.replaceChildren(); state.grid.setAttribute('aria-busy', 'true');
    try {
      const response = await fetch(`https://catalog.roblox.com/v1/search/items/details?${queryFor(state.params, cursor)}`, {signal});
      if (!response.ok) throw new Error(response.status === 429 ? 'Too many searches. Please wait a moment and try again.' : 'Catalog could not be loaded. Please try Search again.');
      const payload = await response.json();
      if (!Array.isArray(payload.data)) throw new Error('Catalog returned an unexpected response. Please try again.');
      const items = payload.data.filter(item => Number.isSafeInteger(item.id) && item.id > 0 && ['Asset', 'Bundle'].includes(item.itemType));
      const images = new Map();
      await Promise.all(['Asset', 'Bundle'].map(async type => {
        const ids = items.filter(item => item.itemType === type).map(item => item.id);
        if (!ids.length) return;
        try {
          const endpoint = type === 'Asset' ? `assets?assetIds=${ids.join(',')}` : `bundles/thumbnails?bundleIds=${ids.join(',')}`;
          const response = await fetch(`https://thumbnails.roblox.com/v1/${endpoint}&size=150x150&format=Png&isCircular=false`, {signal});
          if (response.ok) for (const image of (await response.json()).data || []) images.set(`${type}:${image.targetId}`, image.imageUrl);
        } catch (error) { if (error.name === 'AbortError') throw error; }
      }));
      if (ticket !== revision) return;
      for (const item of items) {
        const card = create('article', 'rbx2016-catalog-item');
        const link = create('a'); link.href = `/${item.itemType === 'Bundle' ? 'bundles' : 'catalog'}/${item.id}`; link.title = item.name;
        const image = create('img'); image.alt = item.name; image.width = 150; image.height = 150; image.loading = 'lazy';
        const url = images.get(`${item.itemType}:${item.id}`); if (url) image.src = url;
        const thumb = create('span', 'rbx2016-catalog-thumb'); thumb.append(image);
        const type = limitedType(item);
        if (type) {
          const badge = create('span', `rbx2016-catalog-item-badge ${type === 'unique' ? 'legend-unique' : 'legend-limited'}`);
          badge.setAttribute('role', 'img'); badge.setAttribute('aria-label', type === 'unique' ? 'Limited Unique' : 'Limited');
          thumb.append(badge);
        }
        link.append(thumb, create('span', 'rbx2016-catalog-item-name', item.name));
        card.append(link, create('div', 'rbx2016-catalog-price', priceFor(item)));
        state.grid.append(card);
      }
      state.status.textContent = items.length ? '' : 'No items found. Try a different search or filter.';
      state.previousCursor = payload.previousPageCursor; state.nextCursor = payload.nextPageCursor;
      state.previous.disabled = !state.previousCursor; state.next.disabled = !state.nextCursor;
      state.page.textContent = `Page ${state.pageNumber}`;
    } catch (error) {
      if (ticket !== revision || error.name === 'AbortError') return;
      state.status.classList.add('rbx2016-catalog-error');
      state.status.textContent = error.message === 'Failed to fetch' ? 'Catalog connection failed. Please try Search again.' : error.message;
    } finally { if (ticket === revision) state.grid.setAttribute('aria-busy', 'false'); }
  }
  function update() {
    const active = /^\/catalog\/?$/.test(location.pathname);
    document.documentElement.classList.toggle('rbx2016-catalog-page', active);
    if (!active) {
      if (mounted) { request?.abort(); revision++; mounted.host.classList.remove('rbx2016-catalog-host'); mounted.root.remove(); mounted = null; }
      return;
    }
    const host = document.querySelector('.container-main > .content');
    if (!host) return;
    if (!mounted || !mounted.root.isConnected || mounted.host !== host) { mounted = mount(host); sync(mounted); }
    else if (mounted.url !== location.search) sync(mounted);
  }
  function start() {
    update(); let queued = false;
    function closeMenus() { if (mounted) for (const filter of Object.values(mounted.filters)) filter.details.open = false; }
    document.addEventListener('click', event => { if (!event.target.closest('.rbx2016-catalog-filter')) closeMenus(); });
    document.addEventListener('keydown', event => { if (event.key === 'Escape') closeMenus(); });
    new MutationObserver(() => { if (queued) return; queued = true; requestAnimationFrame(() => { queued = false; update(); }); }).observe(document.body, {childList: true, subtree: true});
    window.addEventListener('popstate', update);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true}); else start();
})();
