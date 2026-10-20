(() => {
  'use strict';

  const records = new Map();
  const profileNames = '#profile-header-title-container-name, .stylistic-alts-username, .profile-header-title, .profile-header-username, .profile-header-display-name, [data-testid="profile-header-title"], [data-testid="profile-header-username"], [data-testid="profile-header-display-name"]';
  const skip = 'input, textarea, select, button, [contenteditable="true"], [data-larpbux], .larpbux-dropdown, .larpbux-panel, #larpbux-root, #larpblox-root';

  function textNodes(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    const result = [];
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (node.parentElement && !node.parentElement.closest(skip)) result.push(node);
    }
    return result;
  }

  function ownProfile(userId) {
    const path = String(location.pathname || '');
    const numeric = path.match(/^\/users\/(\d+)\/profile\/?$/i);
    return numeric ? numeric[1] === String(userId) : /^\/users\/profile\/?$/i.test(path);
  }

  function ownAccountLink(anchor, userId) {
    try {
      const url = new URL(anchor.getAttribute('href') || '', 'https://www.roblox.com');
      if (url.origin !== 'https://www.roblox.com') return false;
      const numeric = url.pathname.match(/^\/users\/(\d+)\/profile\/?$/i);
      return /^\/users\/profile\/?$/i.test(url.pathname) || Boolean(numeric && numeric[1] === String(userId));
    } catch (_) { return false; }
  }

  function roots(userId) {
    const found = [];
    for (const anchor of document.querySelectorAll('a[href]')) {
      // Current Foundation sidebar has no legacy navigation ID. Its own-avatar
      // link and the header's absolute profile URL still identify the account.
      if (ownAccountLink(anchor, userId) && (anchor.querySelector('img') || anchor.closest('#navigation, #header, header, .rbx-header, [data-testid="user-menu"], [data-testid="account-menu"]'))) found.push(anchor);
    }
    found.push(...document.querySelectorAll('.rbx2016-welcome h1'));
    if (ownProfile(userId)) found.push(...document.querySelectorAll(profileNames));
    return found;
  }

  function syncRecords() {
    for (const [node, record] of records) {
      if (!node.isConnected) { records.delete(node); continue; }
      if (record.shown !== null && node.nodeValue !== record.shown) {
        record.real = node.nodeValue;
        record.shown = null;
      }
    }
  }

  function restore() {
    syncRecords();
    for (const [node, record] of records) {
      if (node.nodeValue !== record.real) node.nodeValue = record.real;
      record.shown = null;
    }
    records.clear();
  }

  function update({userId, mode, username} = {}) {
    const activeName = mode && userId != null ? String(username || '') : '';
    if (document.documentElement.dataset.larpbloxName !== activeName) document.documentElement.dataset.larpbloxName = activeName;
    syncRecords();
    if (!mode || userId == null) { restore(); return; }
    const meta = document.querySelector('meta[name="user-data"]');
    const realUsername = meta?.getAttribute('data-name') || '';
    const realDisplayName = meta?.getAttribute('data-displayname') || '';
    const wanted = new Map();
    for (const root of roots(userId)) {
      if (root.matches?.(skip)) continue;
      const usernameField = root.matches('.stylistic-alts-username, .profile-header-username, [data-testid="profile-header-username"]');
      const displayField = root.matches('#profile-header-title-container-name, .profile-header-title, .profile-header-display-name, [data-testid="profile-header-title"], [data-testid="profile-header-display-name"]');
      for (const node of textNodes(root)) {
        const original = records.get(node)?.real ?? node.nodeValue;
        const text = original.trim();
        const greeting = root.matches('.rbx2016-welcome h1');
        const ownLink = root.matches('a[href]');
        let alias;
        if (greeting && username) {
          wanted.set(node, `Hello, ${username}!`); continue;
        }
        if (ownLink && /^(profile|view profile|my profile)$/i.test(text)) continue;
        if (usernameField) alias = username;
        else if (displayField) alias = username;
        else if (text === realUsername || text === '@' + realUsername) alias = username;
        else if (realDisplayName && text === realDisplayName) alias = username;
        else if (ownLink && /[\p{L}\p{N}]/u.test(text)) alias = username;
        if (!alias || !text) continue;
        if (text.startsWith('@') && usernameField) alias = '@' + alias;
        else if (text === '@' + realUsername) alias = '@' + alias;
        wanted.set(node, original.replace(text, () => alias));
      }
    }
    // Restore labels that left our scope, or whose alias was cleared.
    for (const [node, record] of records) {
      if (!wanted.has(node)) {
        if (node.nodeValue !== record.real) node.nodeValue = record.real;
        records.delete(node);
      }
    }
    for (const [node, text] of wanted) {
      if (!records.has(node)) records.set(node, {real: node.nodeValue, shown: null});
      if (node.nodeValue !== text) node.nodeValue = text;
      records.get(node).shown = text;
    }
  }

  const api = {update};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else globalThis.LarpbloxNames = api;
})();
