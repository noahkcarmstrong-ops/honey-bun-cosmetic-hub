(() => {
  'use strict';
  if (globalThis.LarpbloxAppearance?.get?.() === 'modern') return;
  function decorate() {
    const editor = document.querySelector('#avatar-web-app');
    if (!editor) return;
    // Decorate the real layout branches without moving Angular/React-owned nodes.
    const left = editor.querySelector('.left-wrapper');
    const right = editor.querySelector('.right-wrapper-six-column, .right-wrapper');
    if (left && right && left !== right) {
      let parent = left.parentElement;
      while (parent && parent !== editor && !parent.contains(right)) parent = parent.parentElement;
      if (parent && parent.contains(right)) {
        let leftBranch = left;
        let rightBranch = right;
        while (leftBranch.parentElement !== parent) leftBranch = leftBranch.parentElement;
        while (rightBranch.parentElement !== parent) rightBranch = rightBranch.parentElement;
        if (leftBranch !== rightBranch) {
          parent.classList.add('rbx2016-avatar-columns');
          leftBranch.classList.add('rbx2016-avatar-preview');
          rightBranch.classList.add('rbx2016-avatar-inventory');
        }
      }
    }
    // Some editor builds wrap cards in an extra list; grid the immediate card parent.
    for (const card of editor.querySelectorAll('.items-list.avatar-item-list .item-card')) {
      card.parentElement.classList.add('rbx2016-avatar-grid');
    }
    const title = editor.querySelector('.avatar-editor-header h1');
    if (title && title.textContent.trim() === 'Avatar Editor') title.textContent = 'Character Customize';
    for (const label of editor.querySelectorAll('.rbx-tab .text-lead')) {
      if (!label.children.length && label.textContent.trim() === 'Avatars') label.textContent = 'Characters';
    }
    for (const link of editor.querySelectorAll('.catalog-header a')) {
      if (link.matches('[class*="btn-"]') && !link.textContent.trim()) link.textContent = 'Get More';
    }
  }
  function start() {
    decorate();
    let scheduled = false;
    new MutationObserver(() => {
      if (scheduled) return;
      scheduled = true;
      requestAnimationFrame(() => { scheduled = false; decorate(); });
    }).observe(document.body, {childList: true, subtree: true});
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true});
  else start();
})();
