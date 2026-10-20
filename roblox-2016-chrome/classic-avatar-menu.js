(() => {
  'use strict';
  if (globalThis.LarpbloxAppearance?.get?.() === 'modern') return;
  let deferredLeave;
  let activeBar;
  let queued = false;
  function parts() {
    const editor = document.querySelector('#avatar-web-app');
    if (!editor) return {};
    const menu = [...editor.querySelectorAll('.tab-horizontal-submenu')].find(node =>
      node.getClientRects().length && getComputedStyle(node).visibility !== 'hidden');
    const visible = node => node.getClientRects().length && getComputedStyle(node).visibility !== 'hidden';
    const items = [...editor.querySelectorAll('#avatar-items-container')].find(visible) ||
      [...editor.querySelectorAll('.items-list.avatar-item-list')].find(visible);
    return {editor, menu, bar: activeBar?.isConnected ? activeBar : [...editor.querySelectorAll('.rbx-tabs-horizontal, .nav-tabs, [role="tablist"]')].find(visible), items};
  }
  function insideEditor(event, editor) {
    if (!editor) return false;
    if (event.relatedTarget && editor.contains(event.relatedTarget)) return true;
    const rect = editor.getBoundingClientRect();
    return event.clientX >= rect.left && event.clientX <= rect.right &&
      event.clientY >= rect.top && event.clientY <= rect.bottom;
  }
  function space() {
    queued = false;
    const {menu, items} = parts();
    if (!items) return;
    const previous = Number(items.getAttribute('data-rbx2016-menu-gap')) || 0;
    const baseTop = items.getBoundingClientRect().top - previous;
    let bottom = 0;
    if (menu) {
      const rect = menu.getBoundingClientRect();
      bottom = rect.bottom;
      for (const label of menu.querySelectorAll('li, .text-label, a, button')) {
        if (label.getClientRects().length) bottom = Math.max(bottom, label.getBoundingClientRect().bottom);
      }
      // Native category groups can extend outside a zero-height submenu wrapper.
      menu.style.setProperty('--rbx2016-submenu-height', `${Math.ceil(bottom - rect.top)}px`);
    }
    const gap = menu ? Math.max(0, Math.ceil(bottom + 12 - baseTop)) : 0;
    items.setAttribute('data-rbx2016-menu-gap', String(gap));
    items.style.setProperty('--rbx2016-menu-gap', `${gap}px`);
  }
  function schedule() {
    if (queued) return;
    queued = true; requestAnimationFrame(space);
  }
  function start() {
    document.addEventListener('pointerover', event => {
      const bar = event.target.closest?.('#avatar-web-app .rbx-tabs-horizontal, #avatar-web-app .nav-tabs, #avatar-web-app [role="tablist"]');
      if (bar) activeBar = bar;
    }, true);
    // Native close handlers also live on wrappers outside the tab bar. Keep the
    // menu open throughout the editor instead of relying on a narrow hover bridge.
    for (const type of ['pointerout', 'pointerleave', 'mouseout', 'mouseleave']) document.addEventListener(type, event => {
      const {editor, menu, bar} = parts();
      if (!menu || !bar || !insideEditor(event, editor)) return;
      const source = event.target;
      if (!source.contains?.(bar) && !bar.contains(source) && !source.contains?.(menu) && !menu.contains(source)) return;
      deferredLeave = {target: event.target, type, bubbles: event.bubbles, pointerId: event.pointerId, pointerType: event.pointerType};
      event.stopImmediatePropagation();
    }, true);
    document.addEventListener('pointermove', event => {
      const {editor} = parts();
      if (deferredLeave && !insideEditor(event, editor)) {
        const leave = deferredLeave; deferredLeave = null;
        const LeaveEvent = leave.type.startsWith('pointer') ? PointerEvent : MouseEvent;
        leave.target.dispatchEvent(new LeaveEvent(leave.type, {
          bubbles: leave.bubbles, clientX: event.clientX, clientY: event.clientY,
          relatedTarget: event.target, pointerId: leave.pointerId, pointerType: leave.pointerType
        }));
      }
      schedule();
    }, {passive: true});
    document.addEventListener('click', event => {
      const {menu} = parts();
      if (menu?.contains(event.target)) deferredLeave = null;
      schedule();
    }, true);
    new MutationObserver(schedule).observe(document.body, {childList: true, subtree: true,
      attributes: true, attributeFilter: ['class', 'hidden']});
    window.addEventListener('resize', schedule);
    schedule();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true});
  else start();
})();
