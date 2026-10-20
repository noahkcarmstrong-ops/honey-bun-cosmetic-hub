(() => {
  'use strict';
  const MAX = Number.MAX_SAFE_INTEGER;
  const keyFor = item => `${item.itemType}:${item.id}`;
  function localNames(value = {}) {
    const username = typeof value?.username === 'string' ? value.username.trim() : '';
    if (username && !/^[A-Za-z0-9_]{3,20}$/.test(username)) throw new Error('Use 3–20 letters, numbers, or underscores for the Larp username.');
    return {username};
  }
  function amount(value) {
    const number = Number(value);
    if (!Number.isSafeInteger(number) || number < 0) throw new Error('Enter a whole number from 0 to 9,007,199,254,740,991.');
    return number;
  }
  function formatBalance(value) {
    const number = amount(value);
    // Classic Roblox NumberFormatting: whole units, always a plus suffix.
    if (number < 10000) return number.toLocaleString('en-US');
    if (number < 1000000) return `${Math.floor(number / 1000)}K+`;
    if (number < 1000000000) return `${Math.floor(number / 1000000)}M+`;
    return `${Math.floor(number / 1000000000)}B+`;
  }
  function collect(state, item) {
    const key = keyFor(item);
    if (state.items.some(existing => keyFor(existing) === key)) return state;
    const price = amount(item.price || 0);
    if (price > state.balance) throw new Error('Add more Larpbux first.');
    if (state.items.length >= 2000) throw new Error('Your cosmetic inventory is full.');
    const items = [...state.items, {...item, price}];
    if (isBodyBundle(item)) for (const part of item.assets.filter(isWearableAsset)) if (!items.some(owned => keyFor(owned) === keyFor(part))) items.push({...part, price:0, source:'bundle', assetTypeVerified:true});
    return {...state, balance: state.balance - price, items};
  }
  const bodyAssetTypes = [17, 18, 27, 28, 29, 30, 31, 79];
  const wearableAssetTypes = [17, 18, 27, 28, 29, 30, 31, 79, 2, 8, 11, 12, 19, 41, 42, 43, 44, 45, 46, 47, 48, 50, 51, 52, 53, 54, 55, 56, 64, 65, 66, 67, 68, 69, 70, 71, 72, 76, 77];
  const animationAssetTypes = [48, 50, 51, 52, 53, 54, 55, 56];
  const isWearableAsset = item => item?.itemType === 'Asset' && wearableAssetTypes.includes(Number(item.assetType));
  const isAnimationBundle = item => item?.itemType === 'Bundle' && item.bundleType === 'AvatarAnimations' && Array.isArray(item.assets) && item.assets.some(asset => animationAssetTypes.includes(Number(asset.assetType)));
  const isBodyBundle = item => item?.itemType === 'Bundle' && ['BodyParts', 'DynamicHead'].includes(item.bundleType) && Array.isArray(item.assets) && item.assets.some(asset => bodyAssetTypes.includes(Number(asset.assetType)));
  const expandOutfitItem = item => (isAnimationBundle(item) || isBodyBundle(item)) ? item.assets.filter(isWearableAsset) : (isWearableAsset(item) ? [item] : []);
  const supportsOutfit = item => isWearableAsset(item) || isAnimationBundle(item) || isBodyBundle(item);
  const outfitAssets = items => items.flatMap(expandOutfitItem);
  function matchesAvatarCategory(item, category, equipped = false) {
    if (!supportsOutfit(item)) return false;
    let name = String(category).toLowerCase().replace(/[^a-z]/g, '');
    if (isBodyBundle(item)) return /purchased/.test(name) || (/recent/.test(name) && (!/wearing|equipped/.test(name) || equipped));
    if (isAnimationBundle(item)) return /animation/.test(name) || (/recent/.test(name) && (!/wearing|equipped/.test(name) || equipped));
    if (/gear/.test(name)) return Number(item.assetType) === 19;
    if (/eyebrow/.test(name)) return item.assetType === 76;
    if (/eyelash/.test(name)) return item.assetType === 77;
    if (/avatar|creation|character|makeup|background/.test(name)) return false;
    if (/animation/.test(name)) return animationAssetTypes.includes(Number(item.assetType));
    if (/recent/.test(name)) {
      if (/wearing|equipped/.test(name)) return equipped;
      if (/^(recent|recentall|recentallitems|recentrecentlyadded|recentlyadded)$/.test(name)) return true;
      name = name.replace(/^recent/, '');
    }
    if (/hair/.test(name)) return item.assetType === 41;
    if (/body/.test(name) || /^(head|heads|face|faces|torso|leftarm|rightarm|leftleg|rightleg)$/.test(name)) {
      for (const [label, types] of [['leftarm',[29]],['rightarm',[28]],['leftleg',[30]],['rightleg',[31]],['torso',[27]],['head',[17,79]],['face',[18]]]) if (name.includes(label)) return types.includes(Number(item.assetType));
      return false;
    }
    if (/tshirts?/.test(name)) return item.assetType === 2 || !/classic/.test(name) && item.assetType === 64;
    if (/shirts?$/.test(name)) return item.assetType === 11 || !/classic/.test(name) && [65, 67, 68].includes(item.assetType);
    if (/pants$/.test(name)) return item.assetType === 12 || !/classic/.test(name) && [66, 69, 72].includes(item.assetType);
    if (/hats?$/.test(name)) return item.assetType === 8;
    if (name === 'clothing') return [2, 11, 12, 64, 65, 66, 67, 68, 69, 70, 71, 72].includes(item.assetType);
    if (/layered/.test(name)) return [64, 65, 66, 67, 68, 69, 70, 71, 72].includes(item.assetType);
    if (/^(head|face|neck|shoulder|front|back|waist)$/.test(name)) return {head: 8, face: 42, neck: 43, shoulder: 44, front: 45, back: 46, waist: 47}[name] === item.assetType;
    if (/accessor/.test(name)) {
      for (const [label, type] of [['head', 8], ['face', 42], ['neck', 43], ['shoulder', 44], ['front', 45], ['back', 46], ['waist', 47]]) {
        if (name.includes(label)) return item.assetType === type;
      }
      return ![2, 11, 12, 64, 65, 66, 67, 68, 69, 70, 71, 72].includes(item.assetType);
    }
    return false;
  }
  function equip(state, key) {
    const item = state.items.find(item => keyFor(item) === key);
    if (!item) throw new Error('Collect this cosmetic item first.');
    if (!supportsOutfit(item)) throw new Error('This item can be collected, but the game outfit importer does not support it yet.');
    if (isBodyBundle(item)) {
      const parts = item.assets.filter(isWearableAsset);
      const removing = parts.every(part => state.equipped.includes(keyFor(part)));
      let next = state;
      for (const part of parts) if (removing || !next.equipped.includes(keyFor(part))) next = equip(next, keyFor(part));
      return next;
    }
    if (state.equipped.includes(key)) return {...state, equipped: state.equipped.filter(value => value !== key)};
    let equipped = state.equipped;
    if (item.itemType === 'Bundle' && item.bundleType === 'AvatarAnimations' || animationAssetTypes.includes(Number(item.assetType))) equipped = equipped.filter(value => {
      const other = state.items.find(candidate => keyFor(candidate) === value);
      return !expandOutfitItem(other).some(asset => animationAssetTypes.includes(Number(asset.assetType)));
    });
    if ([17, 18, 27, 28, 29, 30, 31, 79, 2, 11, 12, 19, 64, 65, 66, 67, 68, 69, 70, 71, 72].includes(item.assetType)) equipped = equipped.filter(value => {
      const other = state.items.find(candidate => keyFor(candidate) === value);
      return !expandOutfitItem(other).some(asset => asset.assetType === item.assetType || [17,79].includes(asset.assetType) && [17,79].includes(item.assetType));
    });
    if (equipped.length >= 20) throw new Error('Equip at most 20 cosmetic items.');
    return {...state, equipped: [...equipped, key]};
  }
  function outfit(state, userId) {
    return JSON.stringify({version: 1, kind: 'larpblox-cosmetic-outfit', userId, items: outfitAssets(state.items.filter(item => supportsOutfit(item) && state.equipped.includes(keyFor(item)))).map(({id, name, itemType, assetType}) => ({id, name, itemType, assetType}))});
  }
  function previewDefinition(avatar, rules, items) {
    items = outfitAssets(items);
    const slots = new Set(items.filter(item => [17, 18, 27, 28, 29, 30, 31, 79, 2, 11, 12, 19, 48, 50, 51, 52, 53, 54, 55, 56, 64, 65, 66, 67, 68, 69, 70, 71, 72].includes(item.assetType)).map(item => item.assetType));
    if (slots.has(17) || slots.has(79)) { slots.add(17); slots.add(79); }
    const renderAsset = asset => asset.meta === undefined ? {id: asset.id} : {id: asset.id, meta: asset.meta};
    const assets = (avatar.assets || []).filter(asset => !slots.has(asset.assetType?.id)).map(renderAsset);
    for (const item of items) if (!assets.some(asset => asset.id === item.id)) assets.push(renderAsset(item));
    const bodyColors = {};
    for (const [part, color] of Object.entries(avatar.bodyColor3s || avatar.bodyColors || {})) {
      if (avatar.bodyColor3s) {
        if (typeof color !== 'string' || !/^#?[0-9a-f]{6}$/i.test(color)) throw new Error('Roblox could not load the avatar colors for the preview.');
        bodyColors[part.replace(/Color3$/, 'Color')] = color;
        continue;
      }
      const hex = typeof color === 'string' && /^#[0-9a-f]{6}$/i.test(color) ? color : rules.bodyColorsPalette?.find(entry => entry.brickColorId === color)?.hexColor;
      if (!hex) throw new Error('Roblox could not load the avatar colors for the preview.');
        bodyColors[part.replace(/ColorId$/, 'Color')] = hex.startsWith('#') ? hex : `#${hex}`;
    }
    return {assets, bodyColors, scales: avatar.scales, playerAvatarType: {playerAvatarType: avatar.playerAvatarType}};
  }
  function mergeGameSnapshot(state, snapshot, preserveBodyRemovals = false) {
    const bodySlot = type => Number(type) === 79 ? 17 : Number(type);
    const selectedBodySlots = new Set(outfitAssets(state.items.filter(item => state.equipped.includes(keyFor(item)))).map(item => bodySlot(item.assetType)));
    const removedBodySlots = new Set(preserveBodyRemovals ? (state.gameLook?.items || []).filter(item => bodyAssetTypes.includes(Number(item.assetType)) && !selectedBodySlots.has(bodySlot(item.assetType))).map(item => bodySlot(item.assetType)) : []);
    const items = [...state.items];
    const snapshotItems = snapshot.items.filter(supportsOutfit);
    const bundled = new Set();
    for (const bundle of state.items.filter(isAnimationBundle)) {
      if (bundle.assets.length && bundle.assets.every(asset => snapshotItems.some(item => item.id === asset.id))) {
        bundled.add(keyFor(bundle));
        bundle.assets.forEach(asset => bundled.add(keyFor(asset)));
      }
    }
    for (const item of snapshotItems) {
      if (bundled.has(keyFor(item))) continue;
      const index = items.findIndex(existing => keyFor(existing) === keyFor(item));
      if (index < 0) items.push({...item, price: 0, source: 'game'});
      else items[index] = {...items[index], name: item.name, assetType: items[index].assetTypeVerified ? items[index].assetType : item.assetType};
    }
    const equipped = snapshotItems.filter(item => !bundled.has(keyFor(item)) && !removedBodySlots.has(bodySlot(item.assetType))).map(keyFor);
    for (const key of bundled) if (state.items.some(item => keyFor(item) === key)) equipped.push(key);
    return {...state, items, equipped, gameLook: snapshot};
  }
  function gamePreviewDefinition(state) {
    const look = state.gameLook;
    const selected = outfitAssets(state.items.filter(item => state.equipped.includes(keyFor(item)) && supportsOutfit(item)));
    const selectedIds = new Set(selected.map(item => item.id));
    const managed = new Set(look.items.filter(supportsOutfit).map(item => item.id));
    const replaceSlots = new Set(selected.filter(item => [17, 18, 27, 28, 29, 30, 31, 79, 2, 11, 12, 19, 48, 50, 51, 52, 53, 54, 55, 56, 64, 65, 66, 67, 68, 69, 70, 71, 72].includes(item.assetType)).map(item => item.assetType));
    if (replaceSlots.has(17) || replaceSlots.has(79)) { replaceSlots.add(17); replaceSlots.add(79); }
    const types = new Map(look.items.map(item => [item.id, item.assetType]));
    const assets = look.definition.assets.filter(asset =>
      (!managed.has(asset.id) || selectedIds.has(asset.id)) && (!replaceSlots.has(types.get(asset.id)) || selectedIds.has(asset.id)));
    for (const item of selected) if (!assets.some(asset => asset.id === item.id)) assets.push({id: item.id});
    return {...look.definition, assets};
  }
  function gameOutfitMatches(snapshot, command) {
    const defaultSlots = [...animationAssetTypes, ...bodyAssetTypes];
    const requested = new Set(outfitAssets(command.items).map(item => item.assetType === 79 ? 17 : item.assetType));
    const keys = value => value.items.flatMap(expandOutfitItem).filter(item => !defaultSlots.includes(item.assetType) || requested.has(item.assetType === 79 ? 17 : item.assetType)).map(keyFor).sort().join(',');
    const normalizeColor = value => typeof value === 'string' ? value.replace(/^#/, '').toLowerCase() : value;
    const colors = ['headColor', 'torsoColor', 'leftArmColor', 'rightArmColor', 'leftLegColor', 'rightLegColor'];
    const bodyColorsMatch = colors.every(color => normalizeColor(snapshot.definition?.bodyColors?.[color]) === normalizeColor(command.definition?.bodyColors?.[color]));
    return String(snapshot.userId) === String(command.userId) && keys(snapshot) === keys(command) && bodyColorsMatch;
  }
  function gameCommand(state, userId) {
    const definition = gamePreviewDefinition(state);
    const items = new Map(state.gameLook.items.map(item => [item.id, item]));
    for (const item of outfitAssets(state.items.filter(item => state.equipped.includes(keyFor(item))))) items.set(item.id, item);
    return {version: 1, userId: String(userId), definition, items: definition.assets.map(asset => items.get(asset.id)).filter(Boolean).map(({id, name, assetType}) => ({id, name, assetType, itemType: 'Asset'}))};
  }
  if (typeof module !== 'undefined' && module.exports) { module.exports = {localNames, amount, formatBalance, collect, equip, outfit, supportsOutfit, previewDefinition, matchesAvatarCategory, mergeGameSnapshot, gamePreviewDefinition, gameCommand, gameOutfitMatches}; return; }
  let state, userId, panel, controls, list, balance, mode, message, exportBox, purchaseDialog, previewElement, previewViewer, previewSignature, previewController;
  let nameUsername;
  const thumbnails = new Map();
  const counts = new Map();
  const details = new Map();
  let namesPending=false;
  let bridgeStatus, bridgePending = false, bridgeSending = false, queuedGameCommand, awaitingGameOutfit;
  const node = (tag, text, className) => { const element = document.createElement(tag); if (text) element.textContent = text; if (className) element.className = className; return element; };
  const key = () => `larpblox-cosmetics-v1:${userId}`;
  function save(next, syncOutfit = false) {
    next = {...next, pendingOutfit: Boolean(next.mode && (syncOutfit || next.pendingOutfit))};
    if (!next?.mode) { queuedGameCommand = undefined; awaitingGameOutfit = undefined; }
    try { localStorage.setItem(key(), JSON.stringify(next)); } catch (_) { throw new Error('Your browser could not save this change.'); }
    state = read(userId);
    if (syncOutfit) sendGameOutfit();
    render(); syncNames();
  }
  function action(fn) { try { fn(); } catch (error) { message.textContent = error.message; } }
  function read(id) {
    let saved;
    try { saved = JSON.parse(localStorage.getItem(`larpblox-cosmetics-v1:${id}`) || 'null'); } catch (_) {}
    let items = Array.isArray(saved?.items) ? saved.items.filter(item => Number.isSafeInteger(item.id) && item.id > 0 && ['Asset', 'Bundle'].includes(item.itemType) && typeof item.name === 'string').slice(0, 2000) : [];
    for (const bundle of items.filter(isBodyBundle)) for (const part of bundle.assets.filter(isWearableAsset)) if (!items.some(item => keyFor(item) === keyFor(part))) items.push({...part, price:0, source:'bundle', assetTypeVerified:true});
    let names;
    try { names = localNames(saved?.names); } catch (_) { names = localNames(); }
    let gameLook;
    if (saved?.gameLook && typeof LarpbloxGameBridge !== 'undefined') {
      try { gameLook = LarpbloxGameBridge.validateSnapshot(saved.gameLook, id); } catch (_) {}
    }
    return {version: 1, names, mode: saved?.mode === true, pendingOutfit: saved?.mode === true && saved?.pendingOutfit === true, balance: Number.isSafeInteger(saved?.balance) && saved.balance >= 0 ? saved.balance : 0, items, equipped: Array.isArray(saved?.equipped) ? saved.equipped.filter(value => items.some(item => keyFor(item) === value)).slice(0, 100) : [], ...(gameLook ? {gameLook} : {})};
  }
  const avatarUrl = () => '/my/avatar';
  async function syncNames() {
    if (typeof LarpbloxGameBridge === 'undefined' || !userId || !state || namesPending) return;
    const account=userId;
    const name=state.names?.username || '';
    namesPending=true;
    try {
      await LarpbloxGameBridge.request('publishNames',account,{names:{version:1,userId:account,enabled:Boolean(state.mode),name}});
    } catch (error) {
      if (account===userId && bridgeStatus) bridgeStatus.textContent=error.message;
    } finally { namesPending=false; }
  }
  async function syncGame() {
    if (typeof LarpbloxGameBridge === 'undefined' || !userId || !state?.mode || bridgePending || bridgeSending) return;
    const account = userId;
    bridgePending = true;
    try {
      const result = await LarpbloxGameBridge.request('read', account);
      if (account !== userId || !state?.mode || bridgeSending || queuedGameCommand) return;
      if (!result.connected) { if (bridgeStatus) bridgeStatus.textContent = 'Not connected.'; return; }
      if (!result.snapshot) { if (bridgeStatus) bridgeStatus.textContent = 'Helper connected. Connect Larpblox in-game with the same code.'; return; }
      const snapshot = LarpbloxGameBridge.validateSnapshot(result.snapshot, account);
      if (state.pendingOutfit && !state.gameLook) {
        // Keep edits made before the first game snapshot; merge previously unseen originals.
        const known = new Set(state.items.map(keyFor));
        const desired = state.equipped;
        const merged = mergeGameSnapshot(state, snapshot);
        save({...merged, equipped: [...new Set([...merged.equipped.filter(item => !known.has(item)), ...desired])]});
        queuedGameCommand = gameCommand(state, account);
        return;
      }
      if (state.pendingOutfit && !awaitingGameOutfit && state.gameLook) awaitingGameOutfit = {command: gameCommand(state, account)};
      if (awaitingGameOutfit) {
        if (!gameOutfitMatches(snapshot, awaitingGameOutfit.command)) {
          if (!queuedGameCommand && account === userId && state?.mode) queuedGameCommand = awaitingGameOutfit.command;
          if (bridgeStatus) bridgeStatus.textContent = 'Waiting for the game to apply your outfit...';
          return;
        }
        awaitingGameOutfit = undefined;
      }
      if (state.pendingOutfit || JSON.stringify(snapshot) !== JSON.stringify(state.gameLook)) save({...mergeGameSnapshot(state, snapshot, true), pendingOutfit: false});
      if (bridgeStatus) bridgeStatus.textContent = 'Connected. Game outfit synced to this account.';
    } catch (error) { if (account === userId && bridgeStatus) bridgeStatus.textContent = error.message; }
    finally { bridgePending = false; if (account === userId && queuedGameCommand && !bridgeSending) sendGameOutfit(); }
  }
  if (typeof chrome !== 'undefined' && chrome.runtime?.onMessage?.addListener) chrome.runtime.onMessage.addListener(message => {
    if (message?.type !== 'larpblox-game-state' || String(message.userId) !== String(userId)) return;
    // A socket push is authoritative and wakes the existing sync path immediately.
    syncGame();
  });
  async function sendGameOutfit() {
    if (!state?.mode || !state.gameLook || typeof LarpbloxGameBridge === 'undefined') return;
    queuedGameCommand = gameCommand(state, userId);
    if (bridgeSending) return;
    bridgeSending = true;
    try {
      while (queuedGameCommand) {
        const command = queuedGameCommand; queuedGameCommand = undefined;
        if (command.userId !== userId || !state?.mode) continue;
        awaitingGameOutfit = {command};
        let result;
        try {
          result = await LarpbloxGameBridge.request('publish', userId, {snapshot: command});
        } catch (error) {
          if (!queuedGameCommand && command.userId === userId && state?.mode) queuedGameCommand = command;
          if (bridgeStatus) bridgeStatus.textContent = error.message;
          break;
        }
        if (!result.connected) {
          if (!queuedGameCommand && command.userId === userId && state?.mode) queuedGameCommand = command;
          if (bridgeStatus) bridgeStatus.textContent = 'Not connected. Retrying when the game connection returns.';
          break;
        }
        if (command.userId !== userId) continue;
        if (bridgeStatus) bridgeStatus.textContent = 'Waiting for the game to confirm your outfit. If this stays here, check Accessories → Browser Connection in the game.';
      }
    } catch (error) { if (bridgeStatus) bridgeStatus.textContent = error.message; }
    finally { bridgeSending = false; }
  }
  let imageCache;
  function validAvatarImage(url) {
    try { const parsed = new URL(url); return parsed.protocol === 'https:' && /^(tr|t[0-7])\.rbxcdn\.com$/i.test(parsed.hostname) && !parsed.username && !parsed.password && !parsed.port && !parsed.search && !parsed.hash && (/\.png$/i.test(parsed.pathname) || /\/Png\/[^/]*$/i.test(parsed.pathname)); } catch (_) { return false; }
  }
  async function publishPreviewImage(definition, renderedUrl, account, signal, signature, forceThumbnail = false) {
    let imageUrl = !forceThumbnail && validAvatarImage(renderedUrl) ? renderedUrl : null;
    if (!imageUrl && typeof LarpbloxAvatarSurfaces !== 'undefined' && typeof LarpbloxAvatarSurfaces.characterThumbnail === 'function') {
      try { imageUrl = await LarpbloxAvatarSurfaces.characterThumbnail(definition, account, signal); } catch (_) { return; }
    }
    if (!validAvatarImage(imageUrl) || account !== userId || signal?.aborted || signature !== previewSignature) return;
    const cacheKey = `${account}:${JSON.stringify(definition)}`;
    if (imageCache?.key === cacheKey && imageCache.imageUrl === imageUrl) return;
    try {
      const result = await LarpbloxGameBridge.request('publishImage', account, {image: {version: 1, userId: String(account), definition, imageUrl}});
      if (!result?.connected) return;
      imageCache = {key: cacheKey, imageUrl};
    } catch (_) {}
  }
  function thumbnail(image, item) {
    image.alt = item.name;
    if (item.thumbnail) { image.src = item.thumbnail; return; }
    const key = keyFor(item);
    if (!thumbnails.has(key)) {
      const endpoint = item.itemType === 'Bundle' ? `bundles/thumbnails?bundleIds=${item.id}` : `assets?assetIds=${item.id}`;
      const request = (async () => {
        for (let attempt = 0; attempt < 4; attempt++) {
          if (attempt) await new Promise(resolve => setTimeout(resolve, attempt * 500));
          try {
            const response = await fetch(`https://thumbnails.roblox.com/v1/${endpoint}&size=150x150&format=Png&isCircular=false`);
            const entry = response.ok ? (await response.json())?.data?.[0] : null;
            if (entry?.imageUrl) return entry.imageUrl;
            if (entry?.state === 'Blocked' || entry?.state === 'InReview') break;
          } catch (_) {}
        }
        thumbnails.delete(key);
        return null;
      })();
      thumbnails.set(key, request);
    }
    thumbnails.get(key).then(url => { if (url) image.src = url; });
  }
  function inventoryCards(target) {
    target.replaceChildren();
    if (!state.items.length) { target.append(node('p', 'You have no purchased items yet.')); return; }
    for (const item of [...state.items].reverse()) {
      const row = node('article', '', 'larpbux-inventory-item');
      const link = node('a'); link.href = `/${item.itemType === 'Bundle' ? 'bundles' : 'catalog'}/${item.id}`;
      const image = node('img'); thumbnail(image, item);
      link.append(image, node('span', item.name));
      const button = node('button', state.equipped.includes(keyFor(item)) ? 'Remove' : 'Wear'); button.type = 'button';
      button.disabled = !supportsOutfit(item);
      if (button.disabled) button.textContent = 'Collection only';
      button.addEventListener('click', () => action(() => { save(equip(state, keyFor(item)), true); message.textContent = 'Outfit saved.'; }));
      row.append(link, button); target.append(row);
    }
  }
  let browserAvatarBase;
  async function loadBrowserPreview(selected, signal) {
    const account = userId;
    if (!browserAvatarBase || browserAvatarBase.account !== account || Date.now() > browserAvatarBase.expires) {
      const entry = {account, expires: Date.now() + 15000};
      browserAvatarBase = entry;
      entry.promise = (async () => {
        const controller = new AbortController(), timeout = setTimeout(() => controller.abort(), 10000);
        try {
          const response = await fetch('https://avatar.roblox.com/v2/avatar/avatar', {credentials: 'include', signal: controller.signal});
          if (!response.ok) throw new Error('Could not load your avatar.');
          const avatar = await response.json();
          let rules = {};
          if (!avatar.bodyColor3s && Object.values(avatar.bodyColors || {}).some(color => typeof color === 'number')) {
            const palette = await fetch('https://avatar.roblox.com/v1/avatar-rules', {credentials: 'include', signal: controller.signal});
            if (!palette.ok) throw new Error('Could not load your avatar colors.');
            rules = await palette.json();
          }
          return {avatar, rules};
        } catch (error) { if (browserAvatarBase === entry) browserAvatarBase = undefined; throw error; }
        finally { clearTimeout(timeout); }
      })();
    }
    const {avatar, rules} = await browserAvatarBase.promise;
    if (signal.aborted || account !== userId) throw new Error('Avatar update cancelled.');
    return previewDefinition(avatar, rules, selected);
  }
  async function captureCharacter() {
    const account = userId, current = state;
    if (!current?.mode) throw new Error('Turn Larp mode on first.');
    const selected = outfitAssets(current.items.filter(item => current.equipped.includes(keyFor(item)) && supportsOutfit(item)));
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15000);
    try {
      const definition = current.gameLook ? gamePreviewDefinition(current) : await loadBrowserPreview(selected, controller.signal);
      const known = new Map([...(current.gameLook?.items || []), ...selected].map(item => [item.id, item]));
      const items = [];
      for (let start = 0; start < definition.assets.length; start += 4) {
        const batch = await Promise.all(definition.assets.slice(start, start + 4).map(async asset => {
          let item = known.get(asset.id);
          if (!item?.assetType) {
            const response = await fetch(`https://economy.roblox.com/v2/assets/${asset.id}/details`, {signal: controller.signal});
            if (!response.ok) throw new Error('Could not read all worn items. Try saving again.');
            const data = await response.json();
            item = {assetType: data.AssetTypeId, name: data.Name};
          }
          return {id: asset.id, itemType: 'Asset', assetType: Number(item.assetType), name: String(item.name || `Item ${asset.id}`).slice(0, 128)};
        }));
        items.push(...batch);
      }
      if (account !== userId || !state.mode || JSON.stringify(current.equipped) !== JSON.stringify(state.equipped) || JSON.stringify(current.gameLook) !== JSON.stringify(state.gameLook)) throw new Error('Your outfit changed while saving. Try again.');
      const snapshot = {version: 1, userId: String(account), definition, items};
      return JSON.parse(JSON.stringify(LarpbloxGameBridge.validateSnapshot(snapshot, account)));
    } finally { clearTimeout(timer); }
  }
  function applyCharacter(snapshot) {
    if (!state?.mode) throw new Error('Turn Larp mode on first.');
    LarpbloxGameBridge.validateSnapshot(snapshot, userId);
    save(mergeGameSnapshot(state, JSON.parse(JSON.stringify(snapshot))), true);
  }
  async function applyNativeCharacter(card) {
    const account = userId;
    const controller = new AbortController(), timer = setTimeout(() => controller.abort(), 20000);
    const readJson = async url => {
      const response = await fetch(url, {credentials:'include', signal:controller.signal});
      if (!response.ok) throw new Error('Could not load this Roblox character. Try again.');
      return response.json();
    };
    try {
      let id = Number(card.dataset.outfitId || card.dataset.userOutfitId);
      const source = card.querySelector('img')?.getAttribute('src') || '';
      if (!id && /type=Outfit/i.test(source)) id = Number(source.match(/[?&]id=(\d+)/i)?.[1]);
      if (!id) {
        const name = (card.querySelector('.item-card-name-link, .item-card-name')?.textContent || '').trim();
        const matches = [];
        for (let page = 1; page <= 20; page++) {
          const result = await readJson(`https://avatar.roblox.com/v1/users/${account}/outfits?outfitType=Avatar&page=${page}&itemsPerPage=100`);
          matches.push(...(result.data || []).filter(outfit => outfit.name === name));
          if (!(result.data || []).length || result.data.length < 100) break;
        }
        if (matches.length !== 1) throw new Error('Could not identify this saved outfit. Give it a unique name and try again.');
        id = matches[0].id;
      }
      const avatar = await readJson(`https://avatar.roblox.com/v1/outfits/${id}/details`);
      const rules = avatar.bodyColor3s ? {} : await readJson('https://avatar.roblox.com/v1/avatar-rules');
      const definition = previewDefinition(avatar, rules, []);
      const items = (avatar.assets || []).map(asset => ({id:asset.id,name:String(asset.name || `Item ${asset.id}`).slice(0,128),itemType:'Asset',assetType:Number(asset.assetType?.id)}));
      if (account !== userId || !editingLarp()) throw new Error('The selected avatar changed while loading. Switch to Larp avatar and try again.');
      applyCharacter({version:1,userId:String(account),definition,items});
    } finally { clearTimeout(timer); }
  }
  async function characterThumbnail(snapshot) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 20000);
    try { return await LarpbloxAvatarSurfaces.characterThumbnail(snapshot.definition, snapshot.userId, controller.signal); }
    finally { clearTimeout(timer); }
  }
  let avatarEditorView = 'larp';
  let previewRetryTimer, previewRetryKey, previewFailure, previewRetries = 0;
  const editingLarp = () => Boolean(state?.mode && avatarEditorView === 'larp');
  function updateAvatarViewControls(editor) {
    if (!editor) return;
    let controls = editor.querySelector('.larpbux-avatar-view-controls');
    if (!state?.mode) { controls?.remove(); editor.removeAttribute('data-larpbux-avatar-view'); return; }
    editor.setAttribute('data-larpbux-avatar-view', avatarEditorView);
    if (!controls) {
      controls = node('div', '', 'larpbux-avatar-view-controls');
      controls.setAttribute('role', 'group'); controls.setAttribute('aria-label', 'Avatar to edit');
      for (const [value, label] of [['real', 'Real avatar'], ['larp', 'Larp avatar']]) {
        const button = node('button', label); button.type = 'button'; button.dataset.avatarView = value;
        button.addEventListener('click', () => { if (value === 'real') browserAvatarBase = undefined; avatarEditorView = value; updateAvatar(); });
        controls.append(button);
      }
      const status = node('span', '', 'larpbux-preview-status'); status.setAttribute('role', 'status');
      const retry = node('button', 'Retry', 'larpbux-preview-retry'); retry.type = 'button'; retry.hidden = true;
      retry.addEventListener('click', () => { previewRetryKey = undefined; previewSignature = undefined; updateAvatar(); });
      controls.append(status, retry);
      const left = editor.querySelector('.left-wrapper') || editor;
      left.prepend(controls);
    }
    if (!editingLarp()) { controls.querySelector('.larpbux-preview-status').textContent = ''; controls.querySelector('.larpbux-preview-retry').hidden = true; }
    for (const button of controls.querySelectorAll('button[data-avatar-view]')) button.setAttribute('aria-pressed', String(button.dataset.avatarView === avatarEditorView));
  }
  const nativeHatTiles = new Map();
  const nativeHatFrames = new WeakSet();
  function syncNativeHatTiles(editor, holder) {
    for (const [tile, saved] of nativeHatTiles) {
      if (editingLarp() && tile.isConnected && editor?.contains(tile)) continue;
      for (const [property, [value, priority]] of Object.entries(saved)) {
        if (value) tile.style.setProperty(property, value, priority); else tile.style.removeProperty(property);
      }
      nativeHatTiles.delete(tile);
    }
    if (!editingLarp() || !holder || typeof getComputedStyle !== 'function') return;
    const left = editor.querySelector('.left-wrapper') || holder.parentElement;
    if (!left) return;
    const frameBounds = holder.getBoundingClientRect();
    const candidates = new Set(left.querySelectorAll('img,.icon-hat,[class*="icon-hat"],[class*="hat-slot"],[class*="accessory-slot"],[class*="icon-head"],[aria-label*="hat" i]'));
    // Roblox also renders empty slots as unlabelled square sprite containers.
    for (const element of left.querySelectorAll('button,a,div,span')) {
      if (element.closest('.larpbux-avatar-hats,.larpbux-avatar-look,.larpbux-avatar-view-controls')) continue;
      const bounds = element.getBoundingClientRect();
      if (bounds.width < 40 || bounds.width > 56 || Math.abs(bounds.width - bounds.height) > 2 || element.textContent.trim()) continue;
      if (bounds.top < frameBounds.top || bounds.bottom > frameBounds.bottom || bounds.left > frameBounds.left + 70 || bounds.right < frameBounds.left - 60) continue;
      const background = getComputedStyle(element).backgroundColor;
      if (background && !['transparent','rgba(0, 0, 0, 0)'].includes(background)) candidates.add(element);
    }
    for (const image of candidates) {
      if (image.closest('.larpbux-avatar-hats,.larpbux-avatar-look,.larpbux-avatar-view-controls')) continue;
      const tile = image.closest('button,a,[role="button"]') || (candidates.has(image) && ['DIV','BUTTON','A'].includes(image.tagName) ? image : image.parentElement);
      if (!tile || tile === holder || tile.contains(holder) || tile.closest('.toggle-three-dee') || tile.textContent.trim()) continue;
      const rect = tile.getBoundingClientRect();
      if (rect.width < 24 || rect.width > 90 || rect.height < 24 || rect.height > 90) continue;
      if (!nativeHatTiles.has(tile)) {
        const style = getComputedStyle(tile);
        const frame = holder.getBoundingClientRect();
        // Keep the initial anchor: Real view can temporarily shift the native viewer.
        if (!nativeHatFrames.has(holder)) {
          holder.style.setProperty('--larpbux-hat-left', `${rect.left - frame.left}px`);
          holder.style.setProperty('--larpbux-hat-top', '15px');
          holder.style.setProperty('--larpbux-hat-size', `${rect.width}px`);
          nativeHatFrames.add(holder);
        }
        if (style.backgroundColor && !['transparent','rgba(0, 0, 0, 0)'].includes(style.backgroundColor)) {
          holder.style.setProperty('--larpbux-hat-background', style.backgroundColor);
          holder.style.setProperty('--larpbux-hat-radius', style.borderRadius);
        }
        const saved = {};
        for (const property of ['visibility','pointer-events','display']) saved[property] = [tile.style.getPropertyValue(property), tile.style.getPropertyPriority(property)];
        nativeHatTiles.set(tile, saved);
      }
      tile.style.setProperty('visibility', 'hidden', 'important'); tile.style.setProperty('pointer-events', 'none', 'important'); tile.style.setProperty('display', 'none', 'important');
    }
  }
  function updateLarpHatRail(editor) {
    const holder = editor?.querySelector('.avatar-thumbnail');
    syncNativeHatTiles(editor, holder);
    if (!holder) return;
    let rail = holder.querySelector('.larpbux-avatar-hats');
    const breadcrumb = [...editor.querySelectorAll('.breadcrumb-container,.breadcrumb,.avatar-category-title,[aria-label="Breadcrumb"],[aria-label="breadcrumb"]')]
      .find(element => element.getClientRects().length && element.textContent?.trim());
    const labels = [];
    const readLabels = element => {
      if (element.childNodes?.length) for (const child of element.childNodes) readLabels(child);
      else labels.push(element.textContent?.trim() || '');
    };
    if (breadcrumb) readLabels(breadcrumb);
    const category = labels.filter(Boolean).join(' ');
    const hatTab = /(?:^|[>\s])hats?(?:$|[>\s])/i.test(category) || (/accessor/i.test(category) && /(?:^|[>\s])head(?:$|[>\s])/i.test(category));
    holder.classList.toggle('larpbux-hat-tab', Boolean(editingLarp() && hatTab));
    if (!editingLarp() || !hatTab) { rail?.remove(); return; }
    if (!rail) { rail = node('div', '', 'larpbux-avatar-hats'); rail.setAttribute('aria-label', 'Equipped Larp hats'); holder.append(rail); }
    const hats = state.items.filter(item => state.equipped.includes(keyFor(item)) && Number(item.assetType) === 8);
    const signature = JSON.stringify(hats);
    if (rail.dataset.signature === signature) return;
    rail.dataset.signature = signature; rail.replaceChildren();
    for (const item of hats) {
      const button = node('button'); button.type = 'button'; button.title = `Remove ${item.name}`; button.setAttribute('aria-label', `Remove ${item.name}`);
      const image = node('img'); image.alt = item.name; thumbnail(image, item); button.append(image);
      button.addEventListener('click', () => { if (editingLarp()) action(() => save(equip(state, keyFor(item)), true)); });
      rail.append(button);
    }
    for (let index = hats.length; index < 3; index++) {
      const empty = node('button'); empty.type = 'button'; empty.disabled = true;
      empty.className = 'larpbux-empty-hat'; empty.setAttribute('aria-label', 'Empty hat slot');
      const icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      icon.setAttribute('viewBox', '0 0 28 24'); icon.setAttribute('width', '28'); icon.setAttribute('height', '24');
      icon.setAttribute('aria-hidden', 'true'); icon.classList.add('larpbux-empty-hat-icon');
      const outline = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      outline.setAttribute('d', 'M6 19 7 8Q8 5 11 7Q14 4 18 7L20 19M7 16Q13 18 20 16M3 20Q14 22 25 20');
      outline.setAttribute('fill', 'none'); outline.setAttribute('stroke', '#bfc0c4');
      outline.setAttribute('stroke-width', '1.6'); outline.setAttribute('stroke-linecap', 'round'); outline.setAttribute('stroke-linejoin', 'round');
      icon.append(outline); empty.append(icon);
      rail.append(empty);
    }
  }
  function previewFeedback(editor, message, retry = false) {
    const status = editor?.querySelector('.larpbux-preview-status'), button = editor?.querySelector('.larpbux-preview-retry');
    if (status && status.textContent !== message) status.textContent = message;
    if (button) button.hidden = !retry;
  }
  async function updateAvatarPreview(editor) {
    const selected = editingLarp() ? state.items.filter(item => state.equipped.includes(keyFor(item)) && supportsOutfit(item)) : [];
    const holder = editor?.querySelector('.avatar-thumbnail');
    const gameLook = editingLarp() && state.gameLook;
    holder?.classList.toggle('larpbux-local-preview', Boolean(editingLarp() && (selected.length || gameLook)));
    if (!holder || (!selected.length && !gameLook)) {
      clearTimeout(previewRetryTimer); previewRetryKey = undefined;
      previewFeedback(editor, '');
      previewController?.abort(); previewViewer?.dispose(); previewElement?.remove();
      previewViewer = undefined; previewElement = undefined; previewSignature = undefined; return;
    }
    if (!editingLarp()) {
      previewController?.abort(); previewViewer?.dispose(); previewElement?.remove();
      previewViewer = undefined; previewElement = undefined; previewSignature = undefined; return;
    }
    // Roblox's existing toggle names the mode it will switch to, not the current mode.
    const toggle = editor.querySelector('.toggle-three-dee');
    const threeDimensional = !/^3d$/i.test(toggle?.textContent?.trim() || '');
    const signature = JSON.stringify([userId, selected.map(item => item.id), threeDimensional, gameLook?.definition, Boolean(state?.mode)]);
    if (previewSignature === signature && (previewElement?.isConnected || (!selected.length && !gameLook))) return;
    clearTimeout(previewRetryTimer);
    if (previewRetryKey !== signature) { previewRetryKey = signature; previewRetries = 0; }
    previewController?.abort(); previewController = new AbortController();
    const controller = previewController, signal = controller.signal, account = userId;
    let timedOut = false;
    const timeout = setTimeout(() => { timedOut = true; controller.abort(); }, 20000);
    previewFeedback(editor, 'Updating avatar…');
    previewSignature = signature;
    if (previewElement?.parentElement !== holder) {
      previewViewer?.dispose(); previewViewer = undefined; previewElement?.remove();
      previewElement = node('div', '', 'larpbux-avatar-look'); previewElement.hidden = true; holder.append(previewElement);
    }
    const surface = previewElement;
    // Use the native viewer's backdrop rather than a separate white panel.
    if (typeof getComputedStyle === 'function') {
      const candidates = [...holder.querySelectorAll('canvas'), holder, editor.querySelector('.avatar-back')].filter(element => element && !surface.contains(element));
      const styles = candidates.map(element => getComputedStyle(element));
      const backdrop = styles.find(style => style.backgroundImage && style.backgroundImage !== 'none')
        || styles.find(style => style.backgroundColor && !['transparent', 'rgba(0, 0, 0, 0)'].includes(style.backgroundColor));
      holder.style.setProperty('--larpbux-preview-background', backdrop?.backgroundColor || 'transparent');
      holder.style.setProperty('--larpbux-preview-image', backdrop?.backgroundImage || 'none');
    }
    const view = previewViewer?.getView();
    const pending = node('div', '', 'larpbux-avatar-scene');
    pending.classList.add('larpbux-avatar-loading');
    surface.append(pending);
    let nextViewer, committed = false;
    try {
      let definition;
      if (gameLook) definition = gamePreviewDefinition(state);
      else {
        definition = await loadBrowserPreview(selected, signal);
      }
      if (account !== userId || signature !== previewSignature || signal.aborted) return;
      if (!selected.length && !gameLook) {
        previewViewer?.dispose(); previewElement?.remove();
        previewViewer = undefined; previewElement = undefined; previewController = undefined;
        return;
      }
      let renderKind = threeDimensional && previewRetries < 2 ? '3d' : '2d';
      const renderBody = () => JSON.stringify({avatarDefinition: definition, thumbnailConfig: {thumbnailId: Number(account), thumbnailType: renderKind, size: '420x420'}});
      let token = globalThis.LarpbloxRenderToken || document.querySelector('meta[name="csrf-token"]')?.getAttribute('data-token');
      for (let attempt = 0; attempt < 20; attempt++) {
        const headers = {'Content-Type': 'application/json'}; if (token) headers['X-CSRF-TOKEN'] = token;
        if (typeof LarpbloxAvatarSurfaces !== 'undefined' && typeof LarpbloxAvatarSurfaces.waitForRender === 'function') await LarpbloxAvatarSurfaces.waitForRender(signal);
        if (signal.aborted) throw new Error('Avatar update cancelled.');
        const response = await fetch('https://avatar.roblox.com/v1/avatar/render', {method: 'POST', credentials: 'include', headers, body: renderBody(), signal});
        const refreshedToken = response.headers.get('x-csrf-token');
        if (response.status === 403 && refreshedToken && refreshedToken !== token) { token = refreshedToken; globalThis.LarpbloxRenderToken = token; continue; }
        if (!response.ok) {
          let details;
          try { details = await response.json(); } catch {}
          const serverMessage = details?.errors?.map(error => error.message).filter(Boolean).join('; ') || details?.message || '';
          previewFailure = {status: response.status, details, avatarDefinition: definition, renderKind};
          const error = new Error(`Avatar render failed (${response.status})${serverMessage ? ': ' + serverMessage : '.'}`);
          error.retryAfter = Number(response.headers.get('retry-after')) || (response.status === 429 ? 10 : 0);
          if (response.status === 429) globalThis.LarpbloxRenderBlockedUntil = Date.now() + error.retryAfter * 1000;
          throw error;
        }
        const result = await response.json();
        if (result.state === 'Completed' && result.imageUrl) {
          if (renderKind === '3d') {
            try {
              if (typeof LarpbloxAvatar3D === 'undefined') throw new Error('3D preview is unavailable.');
              const modelController = new AbortController();
              const cancelModel = () => modelController.abort();
              signal.addEventListener('abort', cancelModel, {once: true});
              const modelTimeout = setTimeout(cancelModel, 8000);
              try { nextViewer = await LarpbloxAvatar3D.create(pending, result.imageUrl, {signal: modelController.signal, view, definition}); }
              finally { clearTimeout(modelTimeout); signal.removeEventListener('abort', cancelModel); }
            } catch (error) {
              if (signal.aborted) throw error;
              pending.replaceChildren(); renderKind = '2d';
              previewFeedback(editor, 'Loading avatar image…');
              continue;
            }
          } else {
            const image = node('img'); image.alt = 'Your avatar with selected items'; image.src = result.imageUrl; pending.append(image);
          }
          if (account !== userId || signature !== previewSignature || signal.aborted) return;
          previewViewer?.dispose(); previewViewer = nextViewer;
          pending.classList.remove('larpbux-avatar-loading');
          surface.replaceChildren(pending); surface.hidden = false;
          committed = true; previewRetries = 0;
          previewFeedback(editor, '');
          for (const button of editor.querySelectorAll('.larpbux-avatar-item button')) button.title = '';
          // Image publication is deliberately detached from preview rendering.
          publishPreviewImage(definition, result.imageUrl, account, signal, signature, renderKind !== '2d');
          return;
        }
        if (result.state !== 'Pending') {
          if (renderKind === '3d') { renderKind = '2d'; continue; }
          throw new Error('Roblox could not preview this outfit.');
        }
        if (renderKind === '3d' && attempt >= 5) renderKind = '2d';
        await new Promise(resolve => setTimeout(resolve, 700)); if (signal.aborted) throw new Error('Avatar update cancelled.');
      }
      throw new Error('The avatar preview is still processing. Try Wear again.');
    } catch (error) {
      if (account !== userId || signature !== previewSignature || (signal.aborted && !timedOut)) return;
      const reason = timedOut ? 'Avatar update timed out.' : error.message;
      surface.title = reason;
      if (previewRetries < 2) {
        previewRetries++;
        previewFeedback(editor, error.retryAfter ? 'Roblox is limiting requests. Waiting before retry…' : 'Retrying avatar update…');
        previewRetryTimer = setTimeout(() => {
          if (signature !== previewSignature || account !== userId || !editingLarp()) return;
          previewSignature = undefined; updateAvatarPreview(editor);
        }, Math.max(800 * previewRetries, Math.min(error.retryAfter || 0, 30) * 1000));
      } else previewFeedback(editor, reason, true);
      for (const button of editor.querySelectorAll('.larpbux-avatar-item button')) button.title = error.message;
    } finally {
      clearTimeout(timeout);
      if (!committed) { nextViewer?.dispose(); pending.remove(); }
    }
  }
  function updateOwnAvatarSurfaces() {
    const current = state, account = userId;
    const selected = current?.items.filter(item => current.equipped.includes(keyFor(item)) && supportsOutfit(item)) || [];
    const signature = JSON.stringify([account, selected.map(item => item.id), current?.gameLook?.definition]);
    const loadDefinition = signal => current?.gameLook ? Promise.resolve(gamePreviewDefinition(current)) : loadBrowserPreview(selected, signal);
    if (typeof LarpbloxProfileWearing !== 'undefined') LarpbloxProfileWearing.update({
      userId: account, active: Boolean(current?.mode), signature,
      items: [...(current?.gameLook?.items || []), ...(current?.items || [])], loadDefinition, thumbnail,
    });
    if (typeof LarpbloxAvatarSurfaces !== 'undefined') LarpbloxAvatarSurfaces.update({
      userId: account,
      active: Boolean(current?.mode && (current.gameLook || selected.length)),
      signature, loadDefinition,
    });
  }
  async function bundleAssets(data, signal) {
    let entries = (data.items || []).filter(entry => entry.type === 'Asset');
    if (entries.some(entry => !Number.isSafeInteger(Number(entry.assetType)) || Number(entry.assetType) <= 0)) {
      const outfit = (data.items || []).find(entry => entry.type === 'UserOutfit');
      if (outfit) {
        const response = await fetch(`https://avatar.roblox.com/v1/outfits/${outfit.id}/details`, {signal});
        if (!response.ok) throw new Error('Character parts could not load.');
        const owned = new Set(entries.map(entry => Number(entry.id)));
        entries = ((await response.json()).assets || []).filter(entry => owned.has(Number(entry.id)));
      } else entries = await Promise.all(entries.map(async entry => {
        const response = await fetch(`https://economy.roblox.com/v2/assets/${entry.id}/details`, {signal});
        if (!response.ok) throw new Error('Character part could not load.');
        const details = await response.json(); return {...entry, assetType:details.AssetTypeId};
      }));
    }
    return entries.map(entry => ({id:Number(entry.id), assetType:Number(entry.assetType?.id || entry.assetType), name:String(entry.name || '').slice(0,128), itemType:'Asset'})).filter(isWearableAsset);
  }
  // Recover older purchases whose category had not loaded when they were bought.
  const typeRepairs = new Map();
  function repairPurchasedTypes() {
    if (!state?.mode || !userId) return;
    const account = userId;
    for (const item of state.items.filter(item => (item.itemType === 'Asset' && (!item.assetTypeVerified || !item.limitedVerified)) || (item.itemType === 'Bundle' && (!item.bundleType || !Array.isArray(item.assets))))) {
      const repairKey = `${account}:${item.id}`;
      if ((typeRepairs.get(repairKey) || 0) > Date.now()) continue;
      if ([...typeRepairs.values()].filter(value => value === Infinity).length >= 4) break;
      typeRepairs.set(repairKey, Infinity);
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 8000);
      const endpoint = item.itemType === 'Bundle' ? `https://catalog.roblox.com/v1/bundles/${item.id}/details` : `https://economy.roblox.com/v2/assets/${item.id}/details`;
      fetch(endpoint, {signal: controller.signal})
        .then(response => { if (!response.ok) throw new Error('Item type unavailable'); return response.json(); })
        .then(async data => {
          const assets = item.itemType === 'Bundle' ? await bundleAssets(data, controller.signal) : undefined;
          if (item.itemType === 'Asset' && (!Number.isSafeInteger(data.AssetTypeId) || data.AssetTypeId <= 0)) throw new Error('Item type unavailable');
          if (item.itemType === 'Bundle' && !['AvatarAnimations','BodyParts','DynamicHead'].includes(data.bundleType)) throw new Error('Item type unavailable');
          if (userId !== account) return;
          const latest = read(account);
          if (!latest.items.some(owned => keyFor(owned) === keyFor(item) && (item.itemType === 'Bundle' || (!owned.assetTypeVerified || !owned.limitedVerified)))) return;
          save({...latest, items: latest.items.map(owned => keyFor(owned) === keyFor(item) ? {...owned, ...(item.itemType === 'Bundle' ? {bundleType: data.bundleType, assets} : {assetType: owned.assetTypeVerified ? owned.assetType : data.AssetTypeId, assetTypeVerified:true, limitedVerified:true, isLimited:data.IsLimited === true, isLimitedUnique:data.IsLimitedUnique === true})} : owned)});
        })
        .catch(() => {})
        .finally(() => { clearTimeout(timer); typeRepairs.set(repairKey, Date.now() + 60000); });
    }
  }
  function updateLimitedBadge(holder, item) {
    holder.querySelector('.larpbux-limited-badge')?.remove();
    if (!item.isLimited && !item.isLimitedUnique) return;
    const badge = node('span', '', `larpbux-limited-badge${item.isLimitedUnique ? ' larpbux-limited-unique' : ''}`);
    badge.setAttribute('role', 'img'); badge.setAttribute('aria-label', item.isLimitedUnique ? 'Limited Unique' : 'Limited');
    badge.append(node('span', '', item.isLimitedUnique ? 'icon-limited-unique-label' : 'icon-limited-label')); 
    holder.append(badge);
  }
  const nativeEquipControls = new Map();
  function restoreNativeEquipControls() {
    for (const [control, saved] of nativeEquipControls) {
      if (saved.disabled) control.setAttribute('disabled', '');
      if (saved.aria === null) control.removeAttribute('aria-disabled'); else control.setAttribute('aria-disabled', saved.aria);
    }
    nativeEquipControls.clear();
  }
  function updateAvatar() {
    updateOwnAvatarSurfaces();
    // Purchased cosmetics use the same grid and card markup as the real editor.
    const editor = document.querySelector('#avatar-web-app');
    updateAvatarViewControls(editor);
    updateLarpHatRail(editor);
    if (typeof LarpbloxCharacters !== 'undefined') LarpbloxCharacters.update({editor, userId, active: editingLarp(), capture: captureCharacter, apply: applyCharacter, applyNative: applyNativeCharacter, thumbnail: characterThumbnail});
    if (!editor) {
      restoreNativeEquipControls();
      for (const card of document.querySelectorAll('.larpbux-avatar-item')) card.remove();
      updateAvatarPreview(null); return;
    }
    if (!editingLarp()) {
      restoreNativeEquipControls();
      for (const card of document.querySelectorAll('.larpbux-avatar-item')) card.remove();
      for (const card of document.querySelectorAll('.larpbux-native-item')) {
        card.classList.remove('larpbux-native-item');
        card.removeAttribute('data-larpbux-equipped');
        card.querySelector('.larpbux-native-equipped')?.remove();
        const holder = card.querySelector('.item-card-thumb-container, .thumbnail-2d-container');
        if (holder) delete holder.dataset.larpbuxNativeIndicator;
      }
      updateAvatarPreview(editor); return;
    }
    repairPurchasedTypes();
    updateAvatarPreview(editor);
    const list = [...editor.querySelectorAll('.items-list.avatar-item-list')].find(element => element.getClientRects().length);
    if (!list) return;
    const first = [...list.querySelectorAll('.item-card:not(.larpbux-avatar-item)')].find(card => !card.classList.contains('larpbux-character-card'));
    const grid = first?.parentElement || list.querySelector('ul, .rbx2016-avatar-grid') || list;
    const nativeCards = [...list.querySelectorAll('.item-card')].filter(card => !card.classList.contains('larpbux-avatar-item') && !card.classList.contains('larpbux-character-card'));
    const account = userId;
    const cardClasses = (first?.className || 'item-card').split(/\s+/).filter(name => name !== 'larpbux-native-item').join(' ');
    const nativeEquipped = nativeCards
      .map(card => [...card.querySelectorAll('.item-card-equipped')].find(indicator => !indicator.classList.contains('larpbux-native-equipped'))).find(Boolean);
    const updateEquipped = (holder, equipped) => {
      if (holder.dataset.larpbuxNativeIndicator === String(equipped)) return;
      holder.querySelector('.larpbux-native-equipped')?.remove();
      holder.dataset.larpbuxNativeIndicator = String(equipped);
      if (!equipped) return;
      const indicator = nativeEquipped ? nativeEquipped.cloneNode(true) : node('span', '', 'item-card-equipped');
      if (!nativeEquipped) indicator.append(node('span', '', 'icon-check-selection'));
      indicator.classList.add('larpbux-native-equipped');
      indicator.removeAttribute('id');
      indicator.setAttribute('aria-hidden', 'true');
      holder.append(indicator);
    };
    const label = [...editor.querySelectorAll('.breadcrumb-container, .breadcrumb, .avatar-category-title, [aria-label="Breadcrumb"], [aria-label="breadcrumb"]')]
      .find(element => element.getClientRects().length && element.textContent?.trim())?.textContent?.toLowerCase() || '';
    const category = label || editor.querySelector('[aria-selected="true"]')?.textContent?.toLowerCase() || '';
    const items = state.items.filter(item => item.source !== 'native' && matchesAvatarCategory(item, category, state.equipped.includes(keyFor(item))));
    const signature = JSON.stringify([userId, items, state.equipped, category, cardClasses, nativeEquipped?.outerHTML]);
    const cards = [...grid.querySelectorAll('.larpbux-avatar-item')];
    if (grid._larpbuxSignature !== signature || cards.length !== items.length) {
      const existing = new Map(cards.map(card => [card.dataset.larpbuxKey, card]));
      const wanted = new Set(items.map(keyFor));
      for (const card of cards) if (!wanted.has(card.dataset.larpbuxKey)) card.remove();
      for (const item of items) {
        const itemKey = keyFor(item), equipped = isBodyBundle(item) ? item.assets.filter(isWearableAsset).every(part => state.equipped.includes(keyFor(part))) : state.equipped.includes(itemKey);
        const label = equipped ? 'Remove' : 'Wear';
        const previous = existing.get(itemKey);
        if (previous) {
          previous.className = `${cardClasses} larpbux-avatar-item`;
          previous.dataset.larpbuxEquipped = String(equipped);
          const button = previous.querySelector('button');
          button.setAttribute('aria-label', `${label} ${item.name}`);
          button.setAttribute('aria-pressed', String(equipped));
          button.querySelector('.larpbux-avatar-action').textContent = label;
          previous.querySelector('.item-card-name-link').textContent = item.name;
          updateEquipped(previous.querySelector('.item-card-thumb-container'), equipped);
          updateLimitedBadge(previous.querySelector('.item-card-thumb'), item);
          grid.prepend(previous);
          continue;
        }
        const card = node('li', '', `${cardClasses} larpbux-avatar-item`);
        card.dataset.larpbuxKey = itemKey;
        card.dataset.larpbuxEquipped = String(equipped);
        card.addEventListener('auxclick', event => {
          if (event.button !== 1) return;
          event.preventDefault(); event.stopPropagation();
          window.open(`https://www.roblox.com/${item.itemType === 'Bundle' ? 'bundles' : 'catalog'}/${item.id}`, '_blank', 'noopener');
        });
        const container = node('div', '', 'item-card-container');
        const holder = node('div', '', 'item-card-thumb-container');
        const button = node('button', '', 'item-card-thumb'); button.type = 'button';
        button.append(node('span', label, 'larpbux-avatar-action'));
        button.setAttribute('aria-label', `${equipped ? 'Remove' : 'Wear'} ${item.name}`);
        button.setAttribute('aria-pressed', String(equipped));
        const thumb = node('span', '', 'thumbnail-2d-container'); const image = node('img'); thumbnail(image, item); thumb.append(image); button.append(thumb);
        button.addEventListener('click', event => { event.preventDefault(); event.stopPropagation(); action(() => save(equip(state, keyFor(item)), true)); });
        holder.append(button);
        updateLimitedBadge(button, item);
        updateEquipped(holder, equipped);
        const caption = node('div', '', 'item-card-caption');
        const link = node('a', item.name, 'item-card-name-link'); link.href = `/${item.itemType === 'Bundle' ? 'bundles' : 'catalog'}/${item.id}`; caption.append(link);
        container.append(holder, caption); card.append(container); grid.prepend(card);
      }
      grid._larpbuxSignature = signature;
    }
    // Roblox's cards normally submit an account avatar change. In Larp mode
    // they are local controls instead: import the card at zero cost, then use
    // the same equip() state and bridge/preview path as purchased cosmetics.
    const categoryAssetType = name => {
      name = String(name).toLowerCase().replace(/[^a-z]/g, '');
      if (/hair/.test(name)) return 41;
      if (/tshirts?/.test(name)) return 2;
      if (/shirts?$/.test(name)) return 11;
      if (/pants$/.test(name)) return 12;
      if (/hats?/.test(name)) return 8;
      if (/gear/.test(name)) return 19;
      if (/eyebrow/.test(name)) return 76;
      if (/eyelash/.test(name)) return 77;
      if (/face/.test(name)) return 42;
      if (/neck/.test(name)) return 43;
      if (/shoulder/.test(name)) return 44;
      if (/front/.test(name)) return 45;
      if (/back/.test(name)) return 46;
      if (/waist/.test(name)) return 47;
      return undefined;
    };
    const nativeCardItem = card => {
      const link = [...card.querySelectorAll('a')].find(anchor => /\/(?:catalog|bundles)\//.test(anchor.getAttribute('href') || anchor.href || ''));
      const href = link?.getAttribute('href') || link?.href || card.getAttribute('data-item-id') || '';
      const match = String(href).match(/\/(?:catalog|bundles)\/(\d+)/) || String(href).match(/(?:^|[^\d])(\d{2,})/);
      const id = Number(match?.[1] || card.dataset?.itemId || 0);
      if (!Number.isSafeInteger(id) || id <= 0) return null;
      const itemType = /\/bundles\//.test(String(href)) || card.dataset?.itemType === 'Bundle' ? 'Bundle' : 'Asset';
      const rawType = card.dataset?.assetType || card.getAttribute('data-asset-type') || card.getAttribute('data-assettype');
      const assetType = Number(rawType) || categoryAssetType(category);
      const name = (card.querySelector('.item-card-name-link, [data-testid="item-name"]')?.textContent || link?.textContent || card.getAttribute('aria-label') || 'Roblox item').trim();
      return {id, name, itemType, assetType, price: 0, source: 'native', assetTypeVerified: Boolean(rawType)};
    };
    for (const card of nativeCards) {
      const native = nativeCardItem(card);
      if (!native) continue;
      const nativeKey = keyFor(native);
      const equipped = state.equipped.includes(nativeKey);
      card.classList.add('larpbux-native-item');
      card.dataset.larpbuxEquipped = String(equipped);
      for (const control of card.querySelectorAll('.item-card-thumb, .item-card-thumb-container button')) {
        if (!nativeEquipControls.has(control)) nativeEquipControls.set(control, {disabled: control.hasAttribute('disabled'), aria: control.getAttribute('aria-disabled')});
        control.removeAttribute('disabled'); control.removeAttribute('aria-disabled');
      }
      const holder = card.querySelector('.item-card-thumb-container, .thumbnail-2d-container');
      if (holder) updateEquipped(holder, equipped);
      if (card._larpbuxNativeClick) continue;
      const click = event => {
        if (!editingLarp() || account !== userId) return;
        const target = event.target;
        const anchor = target?.closest?.('a');
        if (anchor && !anchor.closest?.('.item-card-thumb, .item-card-thumb-container, button')) return;
        event.preventDefault?.(); event.stopPropagation?.(); event.stopImmediatePropagation?.();
        const finish = item => action(() => {
          if (!supportsOutfit(item) || !editingLarp() || account !== userId) return;
          const current = read(userId), existing = current.items.find(value => keyFor(value) === nativeKey);
          const next = existing ? current : {...current, items: [...current.items, item]};
          save(equip(next, nativeKey), true);
        });
        const known = state.items.find(item => keyFor(item) === nativeKey);
        if (supportsOutfit(known)) { finish(known); return; }
        if (native.assetTypeVerified && supportsOutfit(native)) { finish(native); return; }
        const endpoint = native.itemType === 'Bundle' ? `https://catalog.roblox.com/v1/bundles/${native.id}/details` : `https://economy.roblox.com/v2/assets/${native.id}/details`;
        fetch(endpoint).then(response => response.ok ? response.json() : null).then(data => {
          if (!data) return;
          if (native.itemType === 'Asset') finish({...native, assetType: Number(data.AssetTypeId) || 0, assetTypeVerified: true});
          else if (data.bundleType === 'AvatarAnimations') finish({...native, bundleType: data.bundleType, assets: (data.items || []).filter(entry => entry.type === 'Asset').map(entry => ({id: Number(entry.id), assetType: Number(entry.assetType), name: String(entry.name || ''), itemType: 'Asset'}))});
        }).catch(() => {});
      };
      card.addEventListener('click', click, true);
      card._larpbuxNativeClick = click;
    }
  }
  function updateNames() {
    if (typeof LarpbloxNames !== 'undefined') LarpbloxNames.update({userId, mode: state?.mode === true, ...state?.names});
  }
  function render() {
    if (typeof LarpbloxIdentityGate !== 'undefined') LarpbloxIdentityGate.update();
    document.documentElement.classList.toggle('larpblox-pretend-mode', state.mode);
    updateHeaderBalance();
    mode.checked = state.mode; balance.value = String(state.balance);
    nameUsername.value = state.names?.username || '';
    updateNames();
    inventoryCards(list);
    exportBox.value = outfit(state, userId);
    updateItem(); updateAvatar();
  }
  function mount() {
    panel = node('section', '', 'larpbux-panel'); panel.hidden = true;
    const close = node('button', 'Close'); close.type = 'button'; close.addEventListener('click', () => { panel.hidden = true; });
    panel.append(node('h2', 'Larpbux · cosmetic inventory'), close);
    panel.append(node('p', 'Pretend currency and local cosmetics. Your real inventory stays available in Roblox. Added accessories keep your current accessories; clothing replaces its slot and gear replaces your held Larp gear. Real Robux and account ownership do not change.'));
    controls = node('div', '', 'larpbux-dropdown');
    controls.addEventListener('click', event => event.stopPropagation());
    const label = node('label'); mode = node('input'); mode.type = 'checkbox'; mode.setAttribute('aria-label', 'Larp mode'); label.append(mode, document.createTextNode(' Larp mode'));
    mode.addEventListener('change', () => action(() => { closePurchase(); save({...state, mode: mode.checked}); message.textContent = state.mode ? 'Larp mode on. Existing Roblox items are kept.' : 'Real mode on. Roblox purchases use real Robux.'; }));
    const funds = node('form'); balance = node('input'); balance.type = 'number'; balance.min = '0'; balance.max = String(MAX); balance.step = '1'; balance.setAttribute('aria-label', 'Pretend Larpbux balance');
    funds.append(balance, node('button', 'Save')); funds.addEventListener('submit', event => { event.preventDefault(); action(() => { save({...state, balance: amount(balance.value)}); message.textContent = 'Pretend balance saved.'; }); });
    message = node('p'); message.setAttribute('role', 'status');
    list = node('div', '', 'larpbux-inventory larpbux-inventory-grid');
    exportBox = node('textarea'); exportBox.readOnly = true; exportBox.setAttribute('aria-label', 'Larpblox outfit export');
    const select = node('button', 'Select outfit export'); select.type = 'button'; select.addEventListener('click', () => { exportBox.focus(); exportBox.select(); });
    const inventory = node('button', 'Larp inventory'); inventory.type = 'button';
    inventory.addEventListener('click', () => { panel.hidden = !panel.hidden; });
    const diagnostics = node('button', 'Save preview details'); diagnostics.type = 'button';
    diagnostics.addEventListener('click', () => action(() => {
      const data = {...(previewViewer?.getDiagnostics?.() || {}),
        extensionVersion: typeof chrome !== 'undefined' ? chrome.runtime?.getManifest?.().version : undefined,
        route: location.pathname, userId, mode: state?.mode, equipped: state?.equipped,
        hasGameLook: Boolean(state?.gameLook), previewFailure,
        outfitSelectionLog: JSON.parse(localStorage.getItem('larpblox-outfit-debug-v1') || '[]'),
        savedOutfits: JSON.parse(localStorage.getItem(`larpblox-characters-v1:${userId}`) || '{"profiles":[]}'),
        avatarEditorView,
        avatarPictures: typeof LarpbloxAvatarSurfaces === 'undefined' ? {stage: 'module-not-loaded'} : LarpbloxAvatarSurfaces.getDiagnostics()};
      const url = URL.createObjectURL(new Blob([JSON.stringify(data)], {type: 'application/json'}));
      const download = node('a'); download.href = url; download.download = 'larpblox-preview-details.json';
      document.body.append(download); download.click(); download.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      message.textContent = 'Preview details saved. Attach larpblox-preview-details.json in our chat.';
    }));
    controls.append(label, node('p', 'Pretend Robux amount'), funds, message, inventory);
    const outfitLogs = node('button', 'Save outfit logs'); outfitLogs.type = 'button';
    outfitLogs.addEventListener('click', () => diagnostics.click()); controls.append(outfitLogs);
    const appearanceLabel=node('label','Website appearance');
    appearanceLabel.className='larpbux-appearance';
    const appearance=node('select');appearance.setAttribute('aria-label','Website appearance');
    for (const [value,text] of [['classic','Classic Roblox (2016)'],['modern','Current Roblox']]) {
      const option=node('option',text);option.value=value;appearance.append(option);
    }
    appearance.value=typeof LarpbloxAppearance!=='undefined' ? LarpbloxAppearance.get() : 'classic';
    appearance.addEventListener('change',()=>action(()=>LarpbloxAppearance.set(appearance.value)));
    appearanceLabel.append(appearance);
    controls.append(appearanceLabel,node('p','Changes the website look only. Switching reloads this page.'));

    const names = node('form', '', 'larpbux-names');
    names.append(node('h3', 'Larp name'));
    const usernameLabel = node('label', 'Name');
    nameUsername = node('input'); nameUsername.type = 'text'; nameUsername.maxLength = 20;
    nameUsername.autocomplete = 'off'; nameUsername.placeholder = 'Keep real username'; nameUsername.setAttribute('aria-label', 'Larp name');
    usernameLabel.append(nameUsername);
    const applyNames = node('button', 'Save names'); applyNames.type = 'submit';
    const restoreNames = node('button', 'Restore real names'); restoreNames.type = 'button';
    names.addEventListener('submit', event => { event.preventDefault(); action(() => {
      save({...state, names: localNames({username: nameUsername.value})});
      message.textContent = state.mode ? 'Larp names saved for this browser.' : 'Names saved. Turn Larp mode on to show them.';
    }); });
    restoreNames.addEventListener('click', () => action(() => { save({...state, names: localNames()}); message.textContent = 'Real browser names restored.'; }));
    names.append(usernameLabel, applyNames, restoreNames, node('p', 'Visible only to you while Larp mode is on. Connected games update automatically through the local helper.'));
    controls.append(names);
    const connection = node('details', '', 'larpbux-game-connection');
    connection.append(node('summary', 'Connect Potassium / Larpblox'));
    connection.append(node('p', 'Run start-larpblox-connect.cmd, then paste its code here and in Larpblox → Accessories → Browser connection. Turn Larp mode on to sync.'));
    const pairing = node('input'); pairing.type = 'password'; pairing.maxLength = 32; pairing.autocomplete = 'off'; pairing.setAttribute('aria-label', 'Game connection code');
    const connect = node('button', 'Connect'); connect.type = 'button';
    const disconnect = node('button', 'Disconnect'); disconnect.type = 'button';
    bridgeStatus = node('p', 'Not connected.'); bridgeStatus.setAttribute('role', 'status');
    connect.addEventListener('click', async () => {
      if (typeof LarpbloxGameBridge === 'undefined') { bridgeStatus.textContent = 'Reload the extension first.'; return; }
      const account = userId, code = pairing.value; pairing.value = ''; connect.disabled = true;
      try {
        await LarpbloxGameBridge.request('connect', account, {code});
        if (account !== userId) return;
        bridgeStatus.textContent = 'Helper connected. Use the same code in the game script.';
        await syncNames();
        await syncGame();
      } catch (error) { if (account === userId) bridgeStatus.textContent = error.message; }
      finally { connect.disabled = false; }
    });
    disconnect.addEventListener('click', async () => {
      if (typeof LarpbloxGameBridge === 'undefined') return;
      const account = userId;
      try { await LarpbloxGameBridge.request('disconnect', account); if (account === userId) bridgeStatus.textContent = 'Disconnected. Last synced outfit kept locally.'; }
      catch (error) { bridgeStatus.textContent = error.message; }
    });
    connection.append(pairing, connect, disconnect, bridgeStatus); controls.append(connection);
    panel.append(node('h3', 'Your Larpbux collection'), list,
      node('p', 'Game import supports accessories, classic clothes, movement animations, and held gear visuals. Gear actions are not included. Other items are collection only. The updated game script must be installed first. For games: copy this export, then paste it into Accessories → Browser cosmetic outfit in Larpblox. Supported cosmetics are added to your current look.'), exportBox, select, diagnostics);
    document.body.append(panel);
  }
  function nativePrice() {
    const element = document.querySelector('#item-details .item-price-value .text-robux-lg, #item-details .item-price-value, #item-details .price-row-container .text-robux-lg, #item-details-container .item-price-value .text-robux-lg, #item-details-container .item-price-value, #item-details-container .price-row-container .text-robux-lg, .price-row-container .item-price-value');
    const raw = element?.textContent?.trim().replace(/^(?:R\$|Robux|\uE002)\s*/i, '').replace(/\s*(?:R\$|Robux)$/i, '');
    if (/^(?:off\s*sale|not\s+for\s+sale)$/i.test(raw || '')) return 0;
    if (/^free$/i.test(raw || '')) return 0;
    if (raw && /^[\d,\s]+$/.test(raw)) return amount(raw.replace(/[,\s]/g, ''));
    return null;
  }
  function visibleItem() {
    const match = location.pathname.match(/^\/(catalog|bundles)\/(\d+)/);
    const name = document.querySelector('#item-details-container h1, .item-details-name-row h1, #item-details h1')?.textContent?.trim();
    const price = nativePrice();
    if (!match || !name || price === null) return null;
    const typeName = document.querySelector('#type-content')?.textContent?.trim();
    const normalizedType = (typeName || '').toLowerCase().replace(/[^a-z]/g, '');
    const assetType = {
      hat: 8, hats: 8, headaccessories: 8, headaccessory: 8,
      hair: 41, hairaccessory: 41, hairaccessories: 41,
      faceaccessory: 42, faceaccessories: 42, neckaccessory: 43, neckaccessories: 43,
      shoulderaccessory: 44, shoulderaccessories: 44, frontaccessory: 45, frontaccessories: 45,
      backaccessory: 46, backaccessories: 46, waistaccessory: 47, waistaccessories: 47,
      face: 42, neck: 43, shoulder: 44, front: 45, back: 46, waist: 47,
      shirt: 11, shirts: 11, classicshirt: 11, classicshirts: 11,
      pants: 12, classicpants: 12, tshirt: 2, tshirts: 2, classictshirt: 2, classictshirts: 2,
      tshirtaccessory:64, tshirtaccessories:64, shirtaccessory:65, shirtaccessories:65,
      pantsaccessory:66, pantsaccessories:66, jacketaccessory:67, jacketaccessories:67,
      sweateraccessory:68, sweateraccessories:68, shortsaccessory:69, shortsaccessories:69,
      leftshoeaccessory:70, leftshoeaccessories:70, rightshoeaccessory:71, rightshoeaccessories:71,
      dressskirtaccessory:72, dressskirtaccessories:72, eyebrowaccessory:76, eyebrowaccessories:76,
      eyelashaccessory:77, eyelashaccessories:77,
      climbanimation:48, fallanimation:50, idleanimation:51, jumpanimation:52,
      runanimation:53, swimanimation:54, walkanimation:55, poseanimation:56,
      gear:19, gears:19,
      gear:19, gears:19,
    }[normalizedType] || {head:8,hair:41,face:42,neck:43,shoulder:44,front:45,back:46,waist:47,eyebrow:76,eyelash:77}[normalizedType.replace(/accessor(?:y|ies)/g, '')] || 0;
    const image = document.querySelector('#item-thumbnail-container-frontend img');
    return {id: Number(match[2]), itemType: match[1] === 'bundles' ? 'Bundle' : 'Asset', assetType, name: name.slice(0, 128), price, thumbnail: image?.currentSrc || image?.src || undefined};
  }
  async function itemData() {
    // A local quote must not wait on a remote service when the page has the details.
    const visible = visibleItem();
    if (visible && visible.itemType === 'Asset') return visible;
    const match = location.pathname.match(/^\/(catalog|bundles)\/(\d+)/);
    if (!match) return null;
    const path = location.pathname, id = Number(match[2]), type = match[1] === 'bundles' ? 'Bundle' : 'Asset';
    const key = `${type}:${id}`;
    if (!details.has(key)) {
      let timer;
      const controller = new AbortController();
      const timeout = new Promise((_, reject) => {
        timer = setTimeout(() => { controller.abort(); reject(new Error('Item details took too long. Click Buy to try again.')); }, 8000);
      });
      const request = (async () => {
      const response = await fetch(type === 'Asset' ? `https://economy.roblox.com/v2/assets/${id}/details` : `https://catalog.roblox.com/v1/bundles/${id}/details`, {signal: controller.signal});
      if (!response.ok) throw new Error('Item details could not be loaded. Click Buy to try again.');
      const data = await response.json();
      const offsale = type === 'Asset' ? data.IsForSale === false : data.product?.isForSale === false;
      const price = offsale ? 0 : type === 'Asset' ? data.PriceInRobux : data.product?.priceInRobux;
      const assets = type === 'Bundle' ? await bundleAssets(data, controller.signal) : undefined;
      return {id, itemType: type, assetType: type === 'Asset' ? data.AssetTypeId : 0, ...(type === 'Asset' ? {assetTypeVerified:true, limitedVerified:true, isLimited:data.IsLimited === true, isLimitedUnique:data.IsLimitedUnique === true} : {}), bundleType: type === 'Bundle' ? data.bundleType : undefined, assets, name: String(type === 'Asset' ? data.Name : data.name).slice(0, 128), price: price == null ? null : amount(price)};
      })();
      details.set(key, Promise.race([request, timeout]).finally(() => clearTimeout(timer)).catch(error => { details.delete(key); throw error; }));
    }
    let item;
    try { item = await details.get(key); }
    catch (error) {
      if (path !== location.pathname) return null;
      const loaded = visibleItem();
      if (!loaded) throw error;
      return loaded;
    }
    if (path !== location.pathname) return null;
    const price = nativePrice() ?? item.price;
    if (price === null) throw new Error('A price is not available for this item. Try again once its price loads.');
    const image = document.querySelector('#item-thumbnail-container-frontend img');
    return {...item, price, thumbnail: image?.currentSrc || image?.src || undefined};
  }
  function closePurchase() {
    if (!purchaseDialog) return;
    purchaseDialog.close(); purchaseDialog.remove(); purchaseDialog = undefined;
  }
  function purchase(item) {
    closePurchase();
    const account = userId, path = location.pathname;
    const dialog = node('dialog', '', 'larpbux-buy-dialog'); purchaseDialog = dialog;
    dialog.setAttribute('aria-label', 'Purchase Item');
    const title = node('h2', 'Purchase Item');
    const close = node('button', '×', 'larpbux-modal-close'); close.type = 'button'; close.setAttribute('aria-label', 'Close purchase'); close.addEventListener('click', closePurchase);
    const body = node('div', '', 'larpbux-purchase-body');
    const image = node('img'); thumbnail(image, item);
    const copy = node('div');
    copy.append(node('p', `Would you like to purchase “${item.name}” for R$ ${item.price.toLocaleString('en-US')}?`));
    const summary = node('div', '', 'larpbux-balance-summary');
    const before = node('p', `Your balance: R$ ${state.balance.toLocaleString('en-US')}`);
    const after = node('p', item.price <= state.balance ? `Your balance after this purchase will be R$ ${(state.balance - item.price).toLocaleString('en-US')}.` : `You need R$ ${(item.price - state.balance).toLocaleString('en-US')} more to buy this item.`);
    summary.append(before, after); copy.append(summary); body.append(image, copy);
    const status = node('p', '', 'larpbux-purchase-status'); status.setAttribute('role', 'status');
    const footer = node('div', '', 'larpbux-purchase-footer');
    const confirm = node('button', 'Buy Now', 'larpbux-buy-confirm'); confirm.type = 'button'; confirm.disabled = item.price > state.balance;
    const cancel = node('button', 'Cancel', 'larpbux-buy-cancel'); cancel.type = 'button'; cancel.addEventListener('click', closePurchase);
    footer.append(confirm, cancel);
    dialog.append(title, close, body, status, footer, node('small', 'Larp mode', 'larpbux-mode-caption'));
    dialog.addEventListener('cancel', event => { event.preventDefault(); closePurchase(); });
    document.body.append(dialog); dialog.showModal();
    confirm.addEventListener('click', async () => {
      confirm.disabled = true;
      try {
        if (account !== userId || path !== location.pathname || !state?.mode) throw new Error('Larp mode or your account changed. Please reopen the purchase.');
        const latest = await itemData();
        if (!dialog.open || !latest) return;
        if (account !== userId || path !== location.pathname || !state?.mode) throw new Error('Larp mode or your account changed. Please reopen the purchase.');
        if (latest.price !== item.price) { purchase(latest); return; }
        const existing = state.items.some(owned => keyFor(owned) === keyFor(item));
        save(collect(state, latest));
        title.textContent = 'Purchase Complete'; dialog.setAttribute('aria-label', 'Purchase Complete');
        copy.replaceChildren(node('p', existing ? 'You already own this item. Your account has not been charged.' : `You have successfully purchased “${item.name}”.`), node('p', `Your balance is now R$ ${state.balance.toLocaleString('en-US')}.`));
        footer.replaceChildren(); status.textContent = '';
        const view = node('a', 'Customize Character', 'larpbux-buy-confirm'); view.href = avatarUrl();
        const done = node('button', 'Continue Shopping', 'larpbux-buy-cancel'); done.type = 'button'; done.addEventListener('click', closePurchase);
        footer.append(view, done);
      } catch (error) { status.textContent = error.message; confirm.disabled = false; }
    });
  }
  function updateItem() {
    const box = document.querySelector('#item-details .price-row-container, #item-details-container .price-row-container');
    if (!box) return;
    let own = box.querySelector('.larpbux-item-actions');
    if (!own) {
      own = node('div', '', 'larpbux-item-actions');
      const buy = node('button', 'Buy with R$', 'larpbux-classic-buy'); buy.type = 'button';
      const view = node('a', 'Customize Character', 'larpbux-owned-link'); view.hidden = true;
      const status = node('p'); status.setAttribute('role', 'status');
      own.append(buy, view, status); own._buy = buy; own._view = view; own._status = status; own._pending = false; box.append(own);
      buy.addEventListener('click', async () => {
        if (own._pending) return;
        own._pending = true; buy.disabled = true; status.textContent = 'Loading item…';
        try {
          const account = userId, path = location.pathname, item = await itemData();
          if (!item || account !== userId || path !== location.pathname || !state?.mode) return;
          purchase(item); status.textContent = '';
        } catch (error) { status.textContent = error.message; }
        finally { if (status.textContent === 'Loading item…') status.textContent = ''; own._pending = false; updateItem(); }
      });
    }
    const route = location.pathname.match(/^\/(catalog|bundles)\/(\d+)/);
    const itemKey = route && `${route[1] === 'bundles' ? 'Bundle' : 'Asset'}:${Number(route[2])}`;
    const owned = state?.items.find(item => keyFor(item) === itemKey);
    if (owned && !owned.assetType) {
      const visible = visibleItem();
      if (visible?.assetType) {
        action(() => save({...state, items: state.items.map(item => item === owned ? {...item, assetType: visible.assetType} : item)}));
      }
    }
    const modern = globalThis.LarpbloxAppearance?.get?.() === 'modern';
    const text = owned ? 'Item Owned' : own._pending ? 'Loading…' : modern ? 'Buy' : 'Buy with R$';
    if (own._buy.textContent !== text) own._buy.textContent = text;
    own._buy.disabled = Boolean(owned || own._pending); own._view.hidden = !owned; own._view.href = avatarUrl();
  }
  function updateHeaderBalance() {
    for (const element of document.querySelectorAll('#nav-robux-amount, #nav-robux-balance')) {
      if (!counts.has(element)) counts.set(element, {real: element.textContent, shown: null});
    }
    for (const [element, record] of counts) {
      if (!element.isConnected) { counts.delete(element); continue; }
      // Remember genuine updates from Roblox even while the local amount is displayed.
      if (element.textContent !== record.shown) record.real = element.textContent;
      const pretend = state?.mode === true;
      const text = pretend ? formatBalance(state.balance) : record.real;
      if (element.textContent !== text) element.textContent = text;
      record.shown = pretend ? text : null;
    }
  }
  function attachDropdown() {
    let menu = document.querySelector('#robux-menu .dropdown-menu, #robux-menu .popover-content, #robux-menu[role="menu"], #robux-menu');
    if (!menu) {
      // Some Roblox headers render the menu in a separate popover.
      for (const link of document.querySelectorAll('a[href*="/transactions"], a[href*="/redeem"]')) {
        const candidate = link.closest('[role="menu"], .dropdown-menu, .popover-content');
        if (candidate && candidate.querySelector('a[href*="/robux"], a[href*="/upgrades"]')) { menu = candidate; break; }
      }
    }
    if (!menu || menu.contains(controls)) return;
    menu.classList.add('larpbux-robux-menu');
    if (menu.tagName === 'UL' || menu.tagName === 'OL') {
      const row = node('li'); row.append(controls); menu.append(row);
    } else menu.append(controls);
  }
  function update() {
    const id = document.querySelector('meta[name="user-data"]')?.getAttribute('data-userid');
    if (!/^[1-9]\d*$/.test(id || '')) {
      userId = undefined; state = undefined;
      document.documentElement.classList.remove('larpblox-pretend-mode');
      if (panel) { panel.hidden = true; controls.remove(); }
      closePurchase(); updateAvatar();
      updateHeaderBalance(); updateNames();
      return;
    }
    if (!panel) mount();
    if (userId !== id) { closePurchase(); queuedGameCommand = undefined; awaitingGameOutfit = undefined; userId = id; state = read(id); if (bridgeStatus) bridgeStatus.textContent = 'Checking connection…'; render(); }
    attachDropdown();
    updateNames();
    updateHeaderBalance();
    updateItem(); updateAvatar();
  }
  function start() {
    update(); let queued = false;
    new MutationObserver(() => { if (queued) return; queued = true; requestAnimationFrame(() => { queued = false; update(); }); }).observe(document.body, {childList: true, characterData: true, subtree: true, attributes: true, attributeFilter: ['src', 'srcset', 'sizes', 'data-user-id', 'data-userid']});
    window.addEventListener('storage', event => { if (userId && (event.key === key() || event.key === null)) { closePurchase(); state = read(userId); render(); } });
    if (typeof LarpbloxGameBridge !== 'undefined') {
      const poll = async () => {
        if (!document.hidden) syncNames();
        if (!document.hidden || state?.pendingOutfit || queuedGameCommand) await syncGame();
        setTimeout(poll, state?.pendingOutfit || queuedGameCommand ? 250 : 1000);
      };
      document.addEventListener('visibilitychange', () => { if (!document.hidden) { update(); syncNames(); syncGame(); } });
      poll();
    }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true}); else start();
})();
