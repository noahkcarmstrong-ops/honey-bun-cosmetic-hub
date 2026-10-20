(() => {
  'use strict';
  const key = id => `larpblox-characters-v1:${id}`;
  const thumbnails = new Map();
  const thumbnailQueue = [];
  let thumbnailBusy = false;
  let current;
  const diagnosticKey = 'larpblox-outfit-debug-v1';
  function log(event, details = {}) {
    try {
      const entries = JSON.parse(localStorage.getItem(diagnosticKey) || '[]');
      entries.push({time:Date.now(), build:'1.18.45', event, ...details});
      localStorage.setItem(diagnosticKey, JSON.stringify(entries.slice(-40)));
    } catch (_) {}
  }
  log('loaded');
  window.addEventListener('pointerdown', event => {
    const card = event.target.closest?.('.item-card');
    if (card?.closest('#avatar-web-app')) log('pointer', {profile:card.dataset.larpbloxProfile || null, active:Boolean(current?.options?.active), target:event.target.tagName});
  }, true);

  // Window capture runs before document/editor handlers that can swallow outfit clicks.
  window.addEventListener('click', event => {
    if (event.target.closest?.('.larpbux-character-card')) log('click', {active:Boolean(current?.options?.active)});
    if (!current?.options?.active || !current.editor.contains(event.target)) return;
    const control = event.target.closest?.('.larpbux-character-card button');
    if (control) {
      event.preventDefault(); event.stopImmediatePropagation();
      if (control.disabled) return;
      if (control.dataset.larpbloxAction === 'wear') {
        const card = control.closest('.larpbux-character-card');
        const profile = read(current.id).profiles.find(profile => profile.id === card.dataset.larpbloxProfile);
        if (profile) selectProfile(current, profile, card);
      } else if (typeof control.onclick === 'function') control.onclick(event);
      return;
    }
    const card = event.target.closest?.('.item-card');
    if (card?.classList.contains('larpbux-character-card')) {
      if (event.target.closest?.('.larpbux-character-menu, .larpbux-character-gear')) return;
      event.preventDefault(); event.stopImmediatePropagation();
      const profile = read(current.id).profiles.find(profile => profile.id === card.dataset.larpbloxProfile);
      if (profile) selectProfile(current, profile, card);
      return;
    }
    if (card?._larpbuxWearCreation && event.target.closest?.('.item-card-thumb')
        && !event.target.closest?.('.item-card-menu, .item-card-options, .icon-more, .icon-settings')) {
      card._larpbuxWearCreation(event);
    }
  }, true);

  const text = value => String(value || '').trim();
  function read(id) {
    try { const data = JSON.parse(localStorage.getItem(key(id)) || '{"profiles":[]}'); return Array.isArray(data.profiles) ? data : {profiles: []}; }
    catch { return {profiles: []}; }
  }
  const write = (id, data) => localStorage.setItem(key(id), JSON.stringify(data));
  const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
  async function drainThumbnails() {
    if (thumbnailBusy) return;
    thumbnailBusy = true;
    await wait(1000);
    while (thumbnailQueue.length) {
      const entry = thumbnailQueue.shift();
      if (!current || current.id !== entry.id || !current.options.active) { thumbnails.delete(entry.cacheKey); entry.resolve(''); continue; }
      let url = '';
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          url = await entry.thumbnail(entry.snapshot);
          if (url) break;
        } catch (error) {
          if (attempt === 2) break;
          const retryAfter = Number(error?.retryAfter);
          await wait(Math.min(Math.max(Number.isFinite(retryAfter) && retryAfter >= 0 ? retryAfter * 1000 : 2000, 200), 30000));
        }
      }
      if (url) {
        const latest = read(entry.id), profile = latest.profiles.find(p => p.id === entry.profileId);
        if (profile && JSON.stringify(profile.snapshot) === JSON.stringify(entry.snapshot)) { profile.thumbnail = url; try { write(entry.id, latest); } catch (_) {} }
      } else thumbnails.delete(entry.cacheKey);
      entry.resolve(url || '');
      if (thumbnailQueue.length) await wait(500);
    }
    thumbnailBusy = false;
  }
  function thumbnailFor(id, profile, options) {
    if (profile.thumbnail) return Promise.resolve(profile.thumbnail);
    const cacheKey = `${id}:${profile.id}`;
    let entry = thumbnails.get(cacheKey);
    if (!entry) {
      entry = {cacheKey, id, profileId: profile.id, snapshot: profile.snapshot, thumbnail: options.thumbnail};
      entry.promise = new Promise(resolve => { entry.resolve = resolve; });
      thumbnails.set(cacheKey, entry);
      thumbnailQueue.push(entry); drainThumbnails();
    }
    return entry.promise;
  }
  function creations(editor) {
    const label = [...editor.querySelectorAll('.breadcrumb-container,.breadcrumb,.avatar-category-title,[aria-label="Breadcrumb"],[aria-label="breadcrumb"]')].find(e => e.getClientRects().length && text(e.textContent));
    return /creation/i.test(label?.textContent || editor.querySelector('[aria-selected="true"]')?.textContent || '');
  }
  const node = (tag, className, label) => { const e = document.createElement(tag); e.className = className || ''; if (label) e.textContent = label; return e; };
  function clear() {
    current?.dialog?.remove();
    if (current) for (const control of current.editor.querySelectorAll('.item-card,button,a')) {
      for (const property of ['_larpbuxWearCreation', '_larpbuxCharacterHandler']) {
        if (control[property]) { control.removeEventListener('click', control[property], true); delete control[property]; }
      }
    }
    if (current) for (const e of current.editor.querySelectorAll('.larpbux-character-card,.larpbux-character-dialog')) e.remove();
    current = undefined;
  }
  function createDialog(profile) {
    if (!current || current.dialog?.isConnected) return;
    const record = current;
    const dialog = node('dialog', 'larpbux-character-dialog'); dialog.setAttribute('aria-label', 'Save character');
    const form = node('form'), input = node('input'); form.noValidate = true; input.maxLength = 40; input.setAttribute('aria-required', 'true'); input.setAttribute('aria-label', 'Character name'); input.placeholder = 'Character name';
    if (profile) input.value = profile.name;
    const save = node('button', '', 'Save character'); save.type = 'submit';
    const cancel = node('button', '', 'Cancel'); cancel.type = 'button';
    const status = node('p'); status.setAttribute('role', 'alert'); status.id = 'larpbux-character-save-message'; input.setAttribute('aria-describedby', status.id);
    form.append(input, save, cancel, status); dialog.append(node('h2', '', 'Save character'), form); document.body.append(dialog); record.dialog = dialog;
    cancel.onclick = () => dialog.remove(); dialog.addEventListener('cancel', () => dialog.remove());
    form.addEventListener('submit', async event => {
      event.preventDefault(); if (save.disabled) return;
      const name = text(input.value); if (!name || name.length > 40) { status.textContent = 'Enter a character name first (up to 40 characters).'; input.setAttribute('aria-invalid', 'true'); input.focus(); return; }
      input.removeAttribute('aria-invalid');
      save.disabled = true; status.textContent = 'SavingÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦';
      try {
        const snapshot = profile ? profile.snapshot : await record.options.capture();
        if (current !== record || !dialog.isConnected) throw new Error('The page changed while saving. Try again.');
        if (!snapshot || typeof snapshot !== 'object' || JSON.stringify(snapshot).length > 90000) throw new Error('Could not save this character snapshot.');
        const latest = read(record.id);
        if (profile) {
          const saved = latest.profiles.find(p => p.id === profile.id);
          if (!saved) throw new Error('This character was deleted.');
          saved.name = name;
        } else {
          if (latest.profiles.length >= 12) throw new Error('Your character library is full.');
          latest.profiles.push({id: `${Date.now()}-${Math.random()}`, name, snapshot});
        }
        write(record.id, latest); dialog.remove();
        record.signature = undefined; update(record.options);
      } catch (error) { status.textContent = error.message; save.disabled = false; }
    });
    dialog.showModal(); input.focus();
  }
  async function selectProfile(record, profile, card) {
    if (current !== record || card.dataset.larpbloxSelecting === 'true') return;
    const wear = card.querySelector('.item-card-thumb'), name = card.querySelector('.item-card-name-link');
    const status = card.querySelector('.larpbux-character-status');
    card.dataset.larpbloxSelecting = 'true'; wear.disabled = true; name.disabled = true;
    status.textContent = 'Applying outfit…';
    log('apply-start', {profile:profile.id, assets:profile.snapshot?.items?.length});
    try {
      await record.options.apply(profile.snapshot);
      for (const other of record.editor.querySelectorAll('.larpbux-character-card .item-card-thumb')) other.setAttribute('aria-pressed', 'false');
      status.textContent = ''; wear.setAttribute('aria-pressed', 'true');
      log('apply-complete', {profile:profile.id});
    } catch (error) { status.textContent = error.message; log('apply-error', {profile:profile.id, message:error.message}); }
    finally { card.dataset.larpbloxSelecting = 'false'; wear.disabled = false; name.disabled = false; }
  }
  function update(options = {}) {
    const editor = options.editor, id = String(options.userId || '');
    if (!editor || !options.active || !id || !creations(editor)) { clear(); return; }
    if (current && (current.editor !== editor || current.id !== id)) clear();
    const list = [...editor.querySelectorAll('.items-list.avatar-item-list')].find(e => e.getClientRects().length);
    if (!list) return;
    const native = [...list.querySelectorAll('.item-card')].find(e => !e.classList.contains('larpbux-character-card'));
    const grid = native?.parentElement || list.querySelector('ul') || list;
    const profiles = read(id).profiles;
    const signature = JSON.stringify([profiles.map(p => [p.id, p.name]), native?.className]);
    if (!current) current = {editor, id};
    const record = current; record.options = options;
    for (const card of list.querySelectorAll('.item-card:not(.larpbux-character-card)')) {
      if (card._larpbuxWearCreation) continue;
      card._larpbuxWearCreation = async event => {
        if (!current || current.editor !== editor || !current.options.active || !creations(editor)) return;
        if (!event.target.closest('.item-card-thumb') || event.target.closest('.item-card-menu, .item-card-options, .icon-more, .icon-settings')) return;
        event.preventDefault(); event.stopImmediatePropagation();
        if (card.dataset.larpbloxLoading === 'true') return;
        card.dataset.larpbloxLoading = 'true';
        let status = card.querySelector('.larpbux-creation-status');
        if (!status) { status = node('span', 'larpbux-creation-status'); status.setAttribute('role','status'); card.append(status); }
        status.textContent = 'LoadingÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦';
        try { await current.options.applyNative(card); status.textContent = ''; }
        catch (error) { status.textContent = error.message; }
        finally { card.dataset.larpbloxLoading = 'false'; }
      };
      card.addEventListener('click', card._larpbuxWearCreation, true);
    }
    const create = [...editor.querySelectorAll('button,a')].find(e => /^create(?: new)?(?: character| outfit)?$/i.test(text(e.textContent)));
    if (create && !create._larpbuxCharacterHandler) {
      create._larpbuxCharacterHandler = event => {
        if (!current || current.editor !== editor || !creations(editor)) return;
        event.preventDefault(); event.stopImmediatePropagation(); createDialog();
      };
      create.addEventListener('click', create._larpbuxCharacterHandler, true);
    }
    if (record.signature === signature && record.grid === grid && grid.querySelectorAll('.larpbux-character-card').length === profiles.length) return;
    record.signature = signature; record.grid = grid;
    editor.querySelectorAll('.larpbux-character-card').forEach(e => e.remove());
    for (const profile of profiles) {
      const card = node(native?.tagName?.toLowerCase() || 'li', `${native?.className || 'item-card'} larpbux-character-card`);
      card.dataset.larpbloxProfile = profile.id;
      const container = node('div', 'item-card-container'), holder = node('div', 'item-card-thumb-container');
      const wear = node('button', 'item-card-thumb'); wear.type = 'button'; wear.setAttribute('aria-label', `Wear ${profile.name}`);
      const thumb = node('span', 'thumbnail-2d-container'), image = node('img'); image.alt = profile.name; image.style.visibility = 'hidden'; thumb.append(image); wear.append(thumb); holder.append(wear);
      const caption = node('div', 'item-card-caption'), nameButton = node('button', 'item-card-name-link', profile.name); nameButton.type = 'button'; caption.append(nameButton);
      wear.dataset.larpbloxAction = 'wear'; nameButton.dataset.larpbloxAction = 'wear';
      const gear = node('button', 'larpbux-character-gear'); gear.type = 'button';
      gear.setAttribute('aria-label', `Manage ${profile.name}`); gear.setAttribute('aria-expanded', 'false');
      const cog = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      cog.setAttribute('viewBox', '0 0 24 24'); cog.setAttribute('aria-hidden', 'true');
      const shape = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      shape.setAttribute('fill', 'currentColor'); shape.setAttribute('fill-rule', 'evenodd');
      shape.setAttribute('d', 'M10 2h4l.6 2.4 1.5.9 2.4-.7 2 3.5-1.8 1.7v1.8l1.8 1.7-2 3.5-2.4-.7-1.5.9L14 20h-4l-.6-2.4-1.5-.9-2.4.7-2-3.5 1.8-1.7v-1.8L3.5 8.7l2-3.5 2.4.7 1.5-.9L10 2Zm5.5 9a3.5 3.5 0 1 0-7 0 3.5 3.5 0 0 0 7 0Z');
      cog.append(shape); gear.append(cog);
      const menu = node('div', 'larpbux-character-menu'); menu.hidden = true;
      const nativeMenu = [...(native?.querySelectorAll('div,ul') || [])].find(e => e.textContent.trim().replace(/\s+/g,' ') === 'Update Rename Delete Cancel');
      if (nativeMenu) {
        menu.className = `${nativeMenu.className} larpbux-character-menu`;
        const background = getComputedStyle(nativeMenu).backgroundColor;
        if (background !== 'rgba(0, 0, 0, 0)') menu.style.backgroundColor = background;
      }
      const action = label => {
        const source = [...(nativeMenu?.querySelectorAll('button,a') || [])].find(e => e.textContent.trim() === label);
        const button = node('button', source?.className || '', label); button.type = 'button'; menu.append(button); return button;
      };
      const replace = action('Update'), rename = action('Rename'), remove = action('Delete'), cancel = action('Cancel');
      holder.append(menu, gear);
      const status = node('span', 'larpbux-character-status'); status.setAttribute('role', 'status');
      container.append(holder, caption, status); card.append(container); grid.prepend(card);
      wear.onclick = () => selectProfile(record, profile, card);
      nameButton.onclick = () => selectProfile(record, profile, card);
      gear.onclick = event => {
        event?.preventDefault(); event?.stopPropagation();
        const opening = menu.hidden;
        for (const other of editor.querySelectorAll('.larpbux-character-menu')) other.hidden = true;
        for (const other of editor.querySelectorAll('.larpbux-character-gear')) other.setAttribute('aria-expanded', 'false');
        menu.hidden = !opening; gear.setAttribute('aria-expanded', String(opening));
      };
      cancel.onclick = () => { menu.hidden = true; gear.setAttribute('aria-expanded','false'); };
      rename.onclick = () => { cancel.onclick(); createDialog(profile); };
      replace.onclick = async () => {
        if (current !== record || replace.disabled) return;
        replace.disabled = true; status.textContent = 'UpdatingÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦';
        try {
          const snapshot = await record.options.capture();
          if (current !== record) return;
          const latest = read(id), saved = latest.profiles.find(p => p.id === profile.id);
          if (!saved) throw new Error('This character was deleted.');
          if (JSON.stringify(snapshot).length > 90000) throw new Error('This character snapshot is too large.');
          saved.snapshot = snapshot; delete saved.thumbnail; write(id,latest); thumbnails.delete(`${id}:${profile.id}`); record.signature = undefined; update(record.options);
        } catch (error) { status.textContent = error.message; replace.disabled = false; }
      };
      remove.onclick = () => {
        if (current !== record) return;
        try { const latest = read(id); latest.profiles = latest.profiles.filter(p => p.id !== profile.id); write(id, latest); record.signature = undefined; update(record.options); }
        catch (error) { status.textContent = error.message; }
      };
      if (options.thumbnail) {
        if (profile.thumbnail) { image.src = profile.thumbnail; image.style.visibility = 'visible'; }
        else thumbnailFor(id, profile, options).then(url => {
          if (url && card.isConnected && current === record) { image.src = url; image.style.visibility = 'visible'; }
        });
      }
    }
  }
  globalThis.LarpbloxCharacters = {update};
})();
