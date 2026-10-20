const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

class ClassList {
  constructor() { this.values = new Set(); }
  add(...values) { values.forEach(value => this.values.add(value)); }
  remove(...values) { values.forEach(value => this.values.delete(value)); }
  toggle(value, force) {
    const next = force === undefined ? !this.values.has(value) : Boolean(force);
    if (next) this.values.add(value); else this.values.delete(value);
    return next;
  }
  contains(value) { return this.values.has(value); }
}

class Element {
  constructor(tagName, ownerDocument) {
    this.tagName = tagName.toUpperCase();
    this.ownerDocument = ownerDocument;
    this.children = [];
    this.parentNode = null;
    this.attributes = new Map();
    this.listeners = new Map();
    this.classList = new ClassList();
    this.dataset = Object.create(null);
    this.hidden = false;
    this.value = '';
    this.checked = false;
    this.textContent = '';
  }
  get className() { return [...this.classList.values].join(' '); }
  set className(value) { this.classList = new ClassList(); String(value).split(/\s+/).filter(Boolean).forEach(v => this.classList.add(v)); }
  get isConnected() { let current = this; while (current) { if (current.tagName === '#DOCUMENT') return true; current = current.parentNode; } return false; }
  append(...children) {
    for (const child of children) {
      if (child == null) continue;
      child.remove();
      child.parentNode = this;
      this.children.push(child);
    }
  }
  prepend(...children) { const previous = this.children.filter(child => !children.includes(child)); this.children = []; this.append(...children, ...previous); }
  replaceChildren(...children) { this.children = []; this.append(...children); }
  remove() { if (!this.parentNode) return; this.parentNode.children = this.parentNode.children.filter(child => child !== this); this.parentNode = null; }
  after(...siblings) {
    if (!this.parentNode) return;
    const index = this.parentNode.children.indexOf(this);
    siblings.forEach((sibling, offset) => { sibling.parentNode = this.parentNode; this.parentNode.children.splice(index + 1 + offset, 0, sibling); });
  }
  contains(candidate) { let current = candidate; while (current) { if (current === this) return true; current = current.parentNode; } return false; }
  setAttribute(name, value) { this.attributes.set(name, String(value)); if (name === 'class') String(value).split(/\s+/).filter(Boolean).forEach(v => this.classList.add(v)); }
  getAttribute(name) { return this.attributes.get(name) ?? null; }
  addEventListener(type, listener) { const list = this.listeners.get(type) || []; list.push(listener); this.listeners.set(type, list); }
  dispatchEvent(event) { event.target = this; for (const listener of this.listeners.get(event.type) || []) listener.call(this, event); return true; }
  focus() {}
  hasAttribute(name) { return this.attributes.has(name); }
  select() {}
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
  querySelectorAll(selector) {
    const result = [];
    const matchOne = (element, query) => {
      if (query.startsWith('.')) return element.classList.contains(query.slice(1));
      if (query.startsWith('#')) return element.getAttribute('id') === query.slice(1);
      const aria = query.match(/^input\[aria-label=["']([^"']+)["']\]$/);
      if (aria) return element.tagName === 'INPUT' && element.getAttribute('aria-label') === aria[1];
      const role = query.match(/^([a-zA-Z]*)\[role=["']([^"']+)["']\]$/);
      if (role) return (!role[1] || element.tagName === role[1].toUpperCase()) && element.getAttribute('role') === role[2];
      const attr = query.match(/^([a-zA-Z]*)\[([^=]+)=["']([^"']+)["']\]$/);
      if (attr) return (!attr[1] || element.tagName === attr[1].toUpperCase()) && element.getAttribute(attr[2]) === attr[3];
      return element.tagName === query.toUpperCase();
    };
    const queries = selector.split(',').map(query => query.trim());
    const match = element => queries.some(query => matchOne(element, query));
    const visit = element => { if (match(element)) result.push(element); element.children.forEach(visit); };
    this.children.forEach(visit);
    return result;
  }
  closest(selector) { let current = this; while (current) { if (selector.split(',').some(query => this.querySelectorAll(query.trim()).includes(current))) return current; current = current.parentNode; } return null; }
}

class Document extends Element {
  constructor() {
    super('#document', null);
    this.ownerDocument = this;
    this.documentElement = new Element('html', this);
    this.body = new Element('body', this);
    this.documentElement.append(this.body);
    this.append(this.documentElement);
    this.readyState = 'complete';
  }
  createElement(tagName) { return new Element(tagName, this); }
  createElementNS(namespace, tagName) { return this.createElement(tagName); }
  createTextNode(text) { return new Element('#text', this, text); }
}

function setup(account, realAmount = '1,000', storage = new Map()) {
  const document = new Document();
  const menu = document.createElement('div'); menu.setAttribute('id', 'robux-menu');
  const amount = document.createElement('span'); amount.setAttribute('id', 'nav-robux-amount'); amount.textContent = realAmount;
  const meta = document.createElement('meta'); meta.setAttribute('name', 'user-data'); meta.setAttribute('data-userid', account);
  document.body.append(meta, amount, menu);
  const observers = [];
  const window = {addEventListener() {}};
  const context = {
    document, window, location: {pathname: '/home'}, localStorage: {
      getItem: key => storage.has(key) ? storage.get(key) : null,
      setItem: (key, value) => storage.set(key, String(value))
    },
    MutationObserver: class { constructor(callback) { this.callback = callback; observers.push(this); } observe() {} },
    requestAnimationFrame: callback => callback(),
    setTimeout,
    clearTimeout,
    console
  };
  vm.runInNewContext(fs.readFileSync(require.resolve('./larpbux.js'), 'utf8'), context, {filename: 'larpbux.js'});
  return {document, amount, menu, storage, mutateNative() { for (const observer of observers) observer.callback([]); }};
}

function controls(menu) {
  const dropdown = menu.querySelector('.larpbux-dropdown');
  assert.ok(dropdown, 'Larpbux controls live in the native Robux dropdown');
  const mode = dropdown.querySelector('input[aria-label="Larp mode"]');
  const balance = dropdown.querySelector('input[aria-label="Pretend Larpbux balance"]');
  const form = dropdown.querySelector('form');
  assert.ok(mode && balance && form, 'dropdown has the mode toggle and balance form');
  return {dropdown, mode, balance, form};
}

const first = setup('101', '1,000');
const firstControls = controls(first.menu);
assert.equal(first.document.body.querySelectorAll('.larpbux-dropdown').length, 1);
firstControls.balance.value = '2500';
firstControls.form.dispatchEvent({type: 'submit', preventDefault() {}});
firstControls.mode.checked = true;
firstControls.mode.dispatchEvent({type: 'change'});
assert.equal(first.amount.textContent, '2,500', 'Larp mode replaces the native displayed amount');
assert.equal(first.document.querySelectorAll('.larpbux-header-label').length, 0, 'the balance has no extra Larp label');

// A Roblox/native update must be remembered while pretend mode is active.
first.amount.textContent = '1,125';
first.mutateNative();
assert.equal(first.amount.textContent, '2,500', 'native count updates do not overwrite Larp mode');

firstControls.mode.checked = false;
firstControls.mode.dispatchEvent({type: 'change'});
assert.equal(first.amount.textContent, '1,125', 'real mode restores the latest native count');

const second = setup('202', '9,999', first.storage);
const secondControls = controls(second.menu);
assert.equal(secondControls.balance.value, '0', 'a second account starts with its own balance');
secondControls.balance.value = '75';
secondControls.form.dispatchEvent({type: 'submit', preventDefault() {}});
assert.equal(secondControls.balance.value, '75');
assert.equal(first.storage.get('larpblox-cosmetics-v1:101').includes('2500'), true, 'first account state is saved under its own key');
assert.equal(first.storage.has('larpblox-cosmetics-v1:202'), true, 'second account state uses a separate key');

const reloaded = setup('101', '7,777', first.storage);
const reloadedControls = controls(reloaded.menu);
assert.equal(reloadedControls.balance.value, '2500', 'saved balance returns for the original account');

console.log('Larpbux native dropdown, pretend amount override, real count restoration, async count protection, and account isolation checks passed.');

firstControls.mode.checked = true;
firstControls.mode.dispatchEvent({type: 'change'});
firstControls.balance.value = '999999999';
firstControls.form.dispatchEvent({type: 'submit', preventDefault() {}});
assert.equal(first.amount.textContent, '999M+', 'large balances use compact formatting in the actual header');
assert.equal(firstControls.balance.value, '999999999', 'the edit box keeps the full exact balance');
firstControls.mode.checked = false;
firstControls.mode.dispatchEvent({type: 'change'});
assert.equal(first.amount.textContent, '1,125', 'formatted Larp balances never replace the saved real count');
console.log('Compact header, full edit amount, and real balance restoration checks passed.');
