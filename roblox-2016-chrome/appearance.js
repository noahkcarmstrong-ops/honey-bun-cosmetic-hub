(() => {
  'use strict';

  const key = 'larpblox-browser-appearance';
  const read = () => {
    try { return localStorage.getItem(key) === 'modern' ? 'modern' : 'classic'; }
    catch { return 'classic'; }
  };
  const apply = root => {
    if (!root) return;
    const modern = read() === 'modern';
    root.classList.toggle('rbx2016', !modern);
    root.classList.toggle('larpblox-modern', modern);
  };
  const get = () => read();
  const set = value => {
    const next = value === 'modern' ? 'modern' : 'classic';
    try { localStorage.setItem(key, next); }
    catch (error) { throw new Error('Larpblox could not save the browser appearance preference.', {cause: error}); }
    location.reload();
  };

  globalThis.LarpbloxAppearance = {get, set};
  if (typeof document === 'undefined') return;
  const root = document.documentElement;
  if (root) apply(root);
  else document.addEventListener('DOMContentLoaded', () => apply(document.documentElement), {once: true});
  if (typeof window !== 'undefined') window.addEventListener('storage', event => {
    if (event.key !== key) return;
    const next = event.newValue === 'modern' ? 'modern' : 'classic';
    const current = document.documentElement?.classList.contains('larpblox-modern') ? 'modern' : 'classic';
    if (next !== current) location.reload();
  });
})();
