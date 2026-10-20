(() => {
  'use strict';
  const selector = 'a[href="/users/profile"], #navigation a[href*="/profile"], #header a[href*="/profile"], header a[href*="/profile"], .rbx-header a[href*="/profile"]';
  function update() {
    const root = document.documentElement;
    if (!root) return;
    const meta = document.querySelector('meta[name="user-data"]');
    const id = meta?.getAttribute('data-userid') || meta?.getAttribute('data-user-id');
    if (!id && document.readyState === 'loading') return;
    let state;
    try { state = JSON.parse(localStorage.getItem(`larpblox-cosmetics-v1:${id}`) || 'null'); } catch {}
    const name = state?.mode ? state.names?.username || '' : '';
    const avatar = Boolean(state?.mode && (state.gameLook || state.equipped?.length));
    for (const [key,value] of [['larpbloxIdentityChecked','true'],['larpbloxIdentityName',name?'true':'false'],['larpbloxIdentityAvatar',String(avatar)]]) {
      if (root.dataset[key] !== value) root.dataset[key] = value;
    }
    for (const link of document.querySelectorAll(selector)) {
      const label = link.textContent.trim();
      const ready = !name || label === name || label === '@'+name || /^(profile|view profile|my profile)$/i.test(label);
      if (link.dataset.larpbloxAliasReady !== String(ready)) link.dataset.larpbloxAliasReady = String(ready);
    }
  }
  globalThis.LarpbloxIdentityGate = {update};
  update();
  new MutationObserver(update).observe(document, {childList:true,characterData:true,subtree:true,attributes:true,attributeFilter:['href','src','srcset','data-userid','data-user-id']});
  document.addEventListener('DOMContentLoaded',update,{once:true});
  window.addEventListener('storage',update);
})();
