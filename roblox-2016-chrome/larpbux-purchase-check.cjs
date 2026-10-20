const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

// Reuse the lightweight DOM used by the dropdown test without adding a runtime dependency.
const harnessPath = require.resolve('./larpbux-dropdown-check.cjs');
let harness = fs.readFileSync(harnessPath, 'utf8');
harness = harness.slice(0, harness.indexOf('const first = setup'));
harness = harness.replace('const context = {', `const context = {fetch: async () => ({ok: true, json: async () => ({PriceInRobux: 100, AssetTypeId: 8, Name: 'Blue Hat'})}),`);
harness = harness.replace('return {document, amount, menu, storage, mutateNative()', 'return {document, amount, menu, storage, location: context.location, mutateNative()');
harness = harness.replace('const queries = selector.split', `if (selector.includes(' ') && !selector.includes('aria-label')) selector = selector.trim().split(/\\s+/).pop();\n    const queries = selector.split`);
harness += `
Element.prototype.showModal = function () { this.open = true; };
Element.prototype.close = function () { this.open = false; };
module.exports = {setup, Element};
`;
const harnessModule = {exports: {}};
vm.runInNewContext(`((module) => {${harness}\n})(module);`, {module: harnessModule, require, console, setTimeout, clearTimeout}, {filename: harnessPath});
const {setup, Element} = harnessModule.exports;

const stalledHarness = harness.replace("fetch: async () => ({ok: true, json: async () => ({PriceInRobux: 100, AssetTypeId: 8, Name: 'Blue Hat'})}),", 'fetch: () => new Promise(() => {}),');
const stalledModule = {exports: {}};
vm.runInNewContext(`((module) => {${stalledHarness}\n})(module);`, {module: stalledModule, require, console, setTimeout, clearTimeout}, {filename: harnessPath});
const {setup: setupStalled} = stalledModule.exports;
const timeoutModule = {exports: {}};
const timeoutHarness = stalledHarness.replace('const context = {', 'const context = {AbortController,');
vm.runInNewContext(`((module) => {${timeoutHarness}\n})(module);`, {module: timeoutModule, require, console, AbortController, setTimeout: (callback, delay) => setTimeout(callback, delay === 8000 ? 5 : delay), clearTimeout}, {filename: harnessPath});
const {setup: setupTimeout} = timeoutModule.exports;

const storage = new Map();
;(async () => {
const page = setup('101', '1,000', storage);
page.location.pathname = '/catalog/123';

const details = page.document.createElement('section'); details.setAttribute('id', 'item-details');
const title = page.document.createElement('h1'); title.textContent = 'Blue Hat';
const type = page.document.createElement('div'); type.setAttribute('id', 'type-content'); type.textContent = 'Hat';
const thumbContainer = page.document.createElement('div'); thumbContainer.setAttribute('id', 'item-thumbnail-container-frontend');
const thumb = page.document.createElement('img'); thumb.src = '/blue-hat.png'; thumbContainer.append(thumb);
const priceRow = page.document.createElement('div'); priceRow.className = 'price-row-container';
const nativePrice = page.document.createElement('span'); nativePrice.className = 'item-price-value text-robux-lg'; nativePrice.textContent = '250';
const nativeBuy = page.document.createElement('button'); nativeBuy.textContent = 'Buy';
priceRow.append(nativePrice, nativeBuy);
details.append(title, type, thumbContainer, priceRow);
page.document.body.append(details);

// The production code reads the clean metadata price (100), then uses the visible
// resale price (250) as the current quote. This proves the live page price wins.
page.mutateNative();
const action = priceRow.querySelector('.larpbux-item-actions');
assert.ok(action, 'item page receives Larpbux purchase controls');
const buy = action.querySelector('.larpbux-classic-buy');
assert.ok(buy, 'purchase button is present');
assert.equal(nativeBuy.textContent, 'Buy', 'native purchase button remains untouched');

async function click(element) {
  element.dispatchEvent({type: 'click', stopPropagation() {}});
  await new Promise(resolve => setImmediate(resolve));
  await new Promise(resolve => setImmediate(resolve));
}
function dialog() { return page.document.querySelector('.larpbux-buy-dialog'); }
function confirmButton() { return dialog().querySelector('.larpbux-buy-confirm'); }
function cancelButton() { return dialog().querySelector('.larpbux-buy-cancel'); }
function textOf(element) { return element.textContent + element.children.map(textOf).join(' '); }

// Set a 300 balance, open the dialog, and cancel: nothing is charged.
const controls = page.menu.querySelector('.larpbux-dropdown');
const balance = controls.querySelector('input[aria-label="Pretend Larpbux balance"]');
const mode = controls.querySelector('input[aria-label="Larp mode"]');
balance.value = '300';
controls.querySelector('form').dispatchEvent({type: 'submit', preventDefault() {}});
mode.checked = true;
mode.dispatchEvent({type: 'change'});
page.mutateNative();
await click(buy);
assert.ok(dialog(), 'Buy opens a confirmation dialog');
assert.match(textOf(dialog()), /100|250/);
await click(cancelButton());
assert.equal(dialog(), null, 'Cancel closes the dialog');
assert.equal(storage.get('larpblox-cosmetics-v1:101').includes('"balance":300'), true, 'Cancel does not charge');

// Confirm once: balance drops by the visible price exactly once and item is owned.
await click(buy);
await click(confirmButton());
assert.equal(dialog().getAttribute('aria-label'), 'Purchase Complete');
assert.equal(storage.get('larpblox-cosmetics-v1:101').includes('"balance":50'), true, 'confirmation subtracts the quoted price once');
assert.ok(storage.get('larpblox-cosmetics-v1:101').includes('Blue Hat'), 'confirmed item is persisted');
assert.equal(nativeBuy.textContent, 'Buy', 'native purchase handler remains untouched');

// If Roblox changes the visible quote while the dialog is open, reopen with the
// current quote and leave the wallet untouched.
const changed = setup('303', '1,000', storage);
changed.location.pathname = '/catalog/123';
const changedDetails = changed.document.createElement('section'); changedDetails.setAttribute('id', 'item-details');
const changedTitle = changed.document.createElement('h1'); changedTitle.textContent = 'Blue Hat';
const changedThumb = changed.document.createElement('div'); changedThumb.setAttribute('id', 'item-thumbnail-container-frontend');
const changedRow = changed.document.createElement('div'); changedRow.className = 'price-row-container';
const changedPrice = changed.document.createElement('span'); changedPrice.className = 'item-price-value text-robux-lg'; changedPrice.textContent = '250';
changedRow.append(changedPrice); changedDetails.append(changedTitle, changedThumb, changedRow); changed.document.body.append(changedDetails); changed.mutateNative();
const changedControls = changed.menu.querySelector('.larpbux-dropdown');
const changedBalance = changedControls.querySelector('input[aria-label="Pretend Larpbux balance"]'); changedBalance.value = '300'; changedControls.querySelector('form').dispatchEvent({type: 'submit', preventDefault() {}});
const changedMode = changedControls.querySelector('input[aria-label="Larp mode"]'); changedMode.checked = true; changedMode.dispatchEvent({type: 'change'}); changed.mutateNative();
const changedBuy = changedRow.querySelector('.larpbux-classic-buy'); changedBuy.dispatchEvent({type: 'click', stopPropagation() {}}); await new Promise(resolve => setImmediate(resolve)); await new Promise(resolve => setImmediate(resolve));
changedPrice.textContent = '275';
const changedConfirm = changed.document.querySelector('.larpbux-buy-confirm'); changedConfirm.dispatchEvent({type: 'click'}); await new Promise(resolve => setImmediate(resolve)); await new Promise(resolve => setImmediate(resolve));
assert.equal(changed.document.querySelector('.larpbux-buy-dialog').getAttribute('aria-label'), 'Purchase Item', 'changed quote reopens the purchase dialog');
assert.match(textOf(changed.document.querySelector('.larpbux-buy-dialog')), /275/);
const changedSaved = JSON.parse(storage.get('larpblox-cosmetics-v1:303'));
assert.equal(changedSaved.items.length, 0, 'changed quote does not charge the old amount');
assert.equal(changedSaved.balance, 300);

// A persistence failure must leave the in-memory purchase state and dialog intact.
const failingStorage = new Map([['larpblox-cosmetics-v1:404', JSON.stringify({version: 1, mode: true, balance: 300, items: [], equipped: []})]]);
const failing = setup('404', '1,000', failingStorage); failing.location.pathname = '/catalog/123';
const failingDetails = failing.document.createElement('section'); failingDetails.setAttribute('id', 'item-details');
const failingTitle = failing.document.createElement('h1'); failingTitle.textContent = 'Blue Hat';
const failingRow = failing.document.createElement('div'); failingRow.className = 'price-row-container';
const failingPrice = failing.document.createElement('span'); failingPrice.className = 'item-price-value text-robux-lg'; failingPrice.textContent = '250';
failingRow.append(failingPrice); failingDetails.append(failingTitle, failingRow); failing.document.body.append(failingDetails); failing.mutateNative();
const failingBuy = failingRow.querySelector('.larpbux-classic-buy'); failingBuy.dispatchEvent({type: 'click', stopPropagation() {}}); await new Promise(resolve => setImmediate(resolve)); await new Promise(resolve => setImmediate(resolve));
failing.storage.set = () => { throw new Error('simulated storage failure'); };
failing.document.querySelector('.larpbux-buy-confirm').dispatchEvent({type: 'click'}); await new Promise(resolve => setImmediate(resolve)); await new Promise(resolve => setImmediate(resolve));
assert.equal(failing.document.querySelector('.larpbux-buy-dialog').getAttribute('aria-label'), 'Purchase Item', 'storage failure does not show success');
assert.match(textOf(failing.document.querySelector('.larpbux-purchase-status')), /could not save/i);
assert.equal(JSON.parse(failingStorage.get('larpblox-cosmetics-v1:404')).balance, 300, 'storage failure leaves balance uncharged');

// A slow metadata endpoint must not block the local purchase prompt when the
// native page already exposes the name, type, thumbnail, and visible price.
const stalled = setupStalled('505', '1,000', new Map()); stalled.location.pathname = '/catalog/123';
const stalledDetails = stalled.document.createElement('section'); stalledDetails.setAttribute('id', 'item-details-container');
const stalledTitle = stalled.document.createElement('h1'); stalledTitle.textContent = 'Blue Hat';
const stalledType = stalled.document.createElement('div'); stalledType.setAttribute('id', 'type-content'); stalledType.textContent = 'Hat';
const stalledThumbContainer = stalled.document.createElement('div'); stalledThumbContainer.setAttribute('id', 'item-thumbnail-container-frontend');
const stalledThumb = stalled.document.createElement('img'); stalledThumb.src = '/blue-hat.png'; stalledThumbContainer.append(stalledThumb);
const stalledItemDetails = stalled.document.createElement('div'); stalledItemDetails.setAttribute('id', 'item-details');
const stalledRow = stalled.document.createElement('div'); stalledRow.className = 'price-row-container';
const stalledPrice = stalled.document.createElement('span'); stalledPrice.className = 'item-price-value text-robux-lg'; stalledPrice.textContent = 'R$ 250';
stalledRow.append(stalledPrice); stalledItemDetails.append(stalledRow);
stalledDetails.append(stalledTitle, stalledType, stalledThumbContainer, stalledItemDetails); stalled.document.body.append(stalledDetails); stalled.mutateNative();
const stalledControls = stalled.menu.querySelector('.larpbux-dropdown');
const stalledBalance = stalledControls.querySelector('input[aria-label="Pretend Larpbux balance"]'); stalledBalance.value = '300'; stalledControls.querySelector('form').dispatchEvent({type: 'submit', preventDefault() {}});
const stalledMode = stalledControls.querySelector('input[aria-label="Larp mode"]'); stalledMode.checked = true; stalledMode.dispatchEvent({type: 'change'}); stalled.mutateNative();
const stalledBuy = stalledItemDetails.querySelector('.larpbux-classic-buy');
stalledBuy.dispatchEvent({type: 'click', stopPropagation() {}});
await new Promise(resolve => setImmediate(resolve));
await new Promise(resolve => setImmediate(resolve));
assert.ok(stalled.document.querySelector('.larpbux-buy-dialog'), 'Buy opens immediately while metadata is still pending');
for (let attempt = 0; attempt < 3; attempt++) {
  stalled.document.querySelector('.larpbux-buy-cancel').dispatchEvent({type: 'click'});
  assert.equal(stalled.document.querySelector('.larpbux-buy-dialog'), null, 'Cancel closes the pending purchase prompt');
  stalledBuy.dispatchEvent({type: 'click', stopPropagation() {}});
  await new Promise(resolve => setImmediate(resolve));
  assert.ok(stalled.document.querySelector('.larpbux-buy-dialog'), 'Buy can reopen while metadata is still pending');
}
stalled.document.querySelector('.larpbux-buy-confirm').dispatchEvent({type: 'click'});
await new Promise(resolve => setImmediate(resolve));
await new Promise(resolve => setImmediate(resolve));
const stalledSaved = JSON.parse(stalled.storage.get('larpblox-cosmetics-v1:505'));
assert.equal(stalledSaved.balance, 50, 'pending metadata confirmation charges the native price once');
assert.equal(stalledSaved.items.length, 1, 'pending metadata confirmation saves one item');
assert.equal(stalled.document.querySelector('.larpbux-buy-dialog').getAttribute('aria-label'), 'Purchase Complete');

// Current item pages can expose the price row directly under the details
// container, without the legacy #item-details wrapper. The visible quote must
// still open and confirm while metadata is unavailable.
const containerPage = setupStalled('511', '1,000', new Map()); containerPage.location.pathname = '/catalog/511';
const container = containerPage.document.createElement('section'); container.setAttribute('id', 'item-details-container');
const containerTitle = containerPage.document.createElement('h1'); containerTitle.textContent = 'Container Hat';
const containerType = containerPage.document.createElement('div'); containerType.setAttribute('id', 'type-content'); containerType.textContent = 'Hat';
const containerRow = containerPage.document.createElement('div'); containerRow.className = 'price-row-container';
const containerPrice = containerPage.document.createElement('span'); containerPrice.className = 'item-price-value'; containerPrice.textContent = '95 R$';
containerRow.append(containerPrice); container.append(containerTitle, containerType, containerRow); containerPage.document.body.append(container); containerPage.mutateNative();
const containerControls = containerPage.menu.querySelector('.larpbux-dropdown');
const containerBalance = containerControls.querySelector('input[aria-label="Pretend Larpbux balance"]'); containerBalance.value = '100'; containerControls.querySelector('form').dispatchEvent({type:'submit', preventDefault() {}});
const containerMode = containerPage.menu.querySelector('input[aria-label="Larp mode"]'); containerMode.checked = true; containerMode.dispatchEvent({type:'change'}); containerPage.mutateNative();
const containerBuy = containerRow.querySelector('.larpbux-classic-buy');
assert.ok(containerBuy, 'container-only item pages receive Larp purchase controls');
await click(containerBuy); await click(containerPage.document.querySelector('.larpbux-buy-confirm'));
const containerSaved = JSON.parse(containerPage.storage.get('larpblox-cosmetics-v1:511'));
assert.equal(containerSaved.balance, 5, 'container-only visible quote is charged once');
assert.equal(containerSaved.items[0].name, 'Container Hat');

// Missing native details plus a hung service must release Buy and allow retries.
const timed = setupTimeout('606', '1,000', new Map()); timed.location.pathname = '/catalog/456';
const timedDetails = timed.document.createElement('div'); timedDetails.setAttribute('id', 'item-details');
const timedRow = timed.document.createElement('div'); timedRow.className = 'price-row-container';
timedDetails.append(timedRow); timed.document.body.append(timedDetails);
const timedMode = timed.menu.querySelector('input[aria-label="Larp mode"]'); timedMode.checked = true; timedMode.dispatchEvent({type: 'change'}); timed.mutateNative();
const timedBuy = timedRow.querySelector('.larpbux-classic-buy');
for (let attempt = 0; attempt < 2; attempt++) {
  timedBuy.dispatchEvent({type: 'click', stopPropagation() {}});
  await new Promise(resolve => setTimeout(resolve, 20));
  assert.equal(timedBuy.disabled, false, 'timeout releases Buy for another attempt');
  assert.match(textOf(timedRow), /took too long/i, 'timeout replaces Loading with a useful error');
}

// Reloading the account reconstructs the owned item and never permits a negative balance.
const reloaded = setup('101', '1,000', storage);
reloaded.location.pathname = '/users/101/inventory';
reloaded.mutateNative();
assert.equal(reloaded.document.querySelector('.larpbux-inventory-page'), null, 'reload does not add a separate Purchased Items section');

const poor = setup('202', '1,000', storage);
poor.location.pathname = '/catalog/123';
const poorDetails = poor.document.createElement('section'); poorDetails.setAttribute('id', 'item-details');
const poorTitle = poor.document.createElement('h1'); poorTitle.textContent = 'Blue Hat';
const poorPrice = poor.document.createElement('span'); poorPrice.className = 'item-price-value text-robux-lg'; poorPrice.textContent = '250';
const poorRow = poor.document.createElement('div'); poorRow.className = 'price-row-container'; poorRow.append(poorPrice); poorDetails.append(poorTitle, poorRow); poor.document.body.append(poorDetails);
poor.mutateNative();
const poorControls = poor.menu.querySelector('.larpbux-dropdown');
const poorMode = poorControls.querySelector('input[aria-label="Larp mode"]'); poorMode.checked = true; poorMode.dispatchEvent({type: 'change'});
poor.mutateNative();
const poorBuy = poorRow.querySelector('.larpbux-classic-buy');
poorBuy.dispatchEvent({type: 'click', stopPropagation() {}});
await new Promise(resolve => setImmediate(resolve));
await new Promise(resolve => setImmediate(resolve));
assert.ok(poor.document.querySelector('.larpbux-buy-dialog'), 'insufficient balance still gives an informative dialog');
assert.equal(poor.document.querySelector('.larpbux-buy-confirm').disabled, true, 'insufficient balance cannot confirm');
const poorSaved = JSON.parse(storage.get('larpblox-cosmetics-v1:202'));
assert.equal(poorSaved.items.length, 0, 'insufficient balance does not create a purchase');

// Current Marketplace labels and Free prices must work without metadata.
for (const scenario of [
  {account:'707',id:81550816889926,name:'Diwali Sparkler Headband',type:'Head Accessories',price:'95',cost:95,assetType:8},
  {account:'706',id:19399858,name:'Dark Bat Wings',type:'Back Accessories',price:'350',cost:350,assetType:46,balance:350},
  {account:'708',id:7654321,name:'Free Hair',type:'Hair Accessories',price:'Free',cost:0,assetType:41},
  {account:'709',id:7654322,name:'Classic Shirt',type:'Classic Shirts',price:'0',cost:0,assetType:11},
]) {
  const sampleStore=new Map([[`larpblox-cosmetics-v1:${scenario.account}`,JSON.stringify({version:1,mode:true,balance:scenario.balance || 100,items:[],equipped:[]})]]);
  const sample=setupStalled(scenario.account,'1,000',sampleStore);sample.location.pathname=`/catalog/${scenario.id}`;
  const root=sample.document.createElement('section');root.setAttribute('id','item-details');
  const heading=sample.document.createElement('h1');heading.textContent=scenario.name;
  const type=sample.document.createElement('div');type.setAttribute('id','type-content');type.textContent=scenario.type;
  const row=sample.document.createElement('div');row.className='price-row-container';
  const price=sample.document.createElement('span');price.className='item-price-value text-robux-lg';price.textContent=scenario.price;
  row.append(price);root.append(heading,type,row);sample.document.body.append(root);sample.mutateNative();
  await click(row.querySelector('.larpbux-classic-buy'));
  assert.ok(sample.document.querySelector('.larpbux-buy-dialog'),`${scenario.name} opens immediately with stalled metadata`);
  await click(sample.document.querySelector('.larpbux-buy-confirm'));
  const result=JSON.parse(sampleStore.get(`larpblox-cosmetics-v1:${scenario.account}`));
  assert.equal(result.items[0]?.assetType,scenario.assetType,`${scenario.type} keeps the correct wearable category`);
  assert.equal(result.balance,(scenario.balance || 100)-scenario.cost,'only the quoted local price is charged');
}

// Animation packs retain typed components through the actual purchase path.
const bundleHarness=harness.replace("fetch: async () => ({ok: true, json: async () => ({PriceInRobux: 100, AssetTypeId: 8, Name: 'Blue Hat'})}),", "AbortController, fetch: async () => ({ok:true,json:async()=>({name:'Robot Animation Pack',bundleType:'AvatarAnimations',product:{priceInRobux:80},items:[{id:619521748,name:'Robot Idle',type:'Asset',assetType:51},{id:619522849,name:'Robot Walk',type:'Asset',assetType:55}]})}),");
const bundleModule={exports:{}};
vm.runInNewContext(`((module)=>{${bundleHarness}\n})(module);`,{module:bundleModule,require,console,AbortController,setTimeout,clearTimeout},{filename:harnessPath});
const bundleStore=new Map([['larpblox-cosmetics-v1:710',JSON.stringify({version:1,mode:true,balance:100,items:[],equipped:[]})]]);
const bundlePage=bundleModule.exports.setup('710','1,000',bundleStore);bundlePage.location.pathname='/bundles/82/Robot-Animation-Pack';
const bundleRoot=bundlePage.document.createElement('div');bundleRoot.setAttribute('id','item-details');
const bundleTitle=bundlePage.document.createElement('h1');bundleTitle.textContent='Robot Animation Pack';
const bundleRow=bundlePage.document.createElement('div');bundleRow.className='price-row-container';
const bundlePrice=bundlePage.document.createElement('span');bundlePrice.className='item-price-value text-robux-lg';bundlePrice.textContent='80';
bundleRow.append(bundlePrice);bundleRoot.append(bundleTitle,bundleRow);bundlePage.document.body.append(bundleRoot);bundlePage.mutateNative();
await click(bundleRow.querySelector('.larpbux-classic-buy'));
await click(bundlePage.document.querySelector('.larpbux-buy-confirm'));
const purchasedPack=JSON.parse(bundleStore.get('larpblox-cosmetics-v1:710'));
assert.equal(purchasedPack.balance,20,'pack is charged once');
assert.equal(purchasedPack.items[0].assets[0].assetType,51,'pack purchase keeps Idle component type');
assert.equal(purchasedPack.items[0].assets[1].assetType,55,'pack purchase keeps Walk component type');

// Offsale quotes work from the visible label and the product API fallback.
for (const label of ['Off Sale','']) {
 const offHarness=harness.replace("fetch: async () => ({ok: true, json: async () => ({PriceInRobux: 100, AssetTypeId: 8, Name: 'Blue Hat'})}),", "AbortController, fetch: async () => ({ok:true,json:async()=>({PriceInRobux:null,IsForSale:false,AssetTypeId:8,Name:'Offsale Hat'})}),");
 const mod={exports:{}};
 vm.runInNewContext(`((module)=>{${offHarness}\n})(module);`,{module:mod,require,console,AbortController,setTimeout,clearTimeout},{filename:harnessPath});
 const store=new Map([['larpblox-cosmetics-v1:811',JSON.stringify({version:1,mode:true,balance:15000,items:[],equipped:[]})]]);
 const off=mod.exports.setup('811','1,000',store);off.location.pathname='/catalog/99/Offsale-Hat';
 const root=off.document.createElement('section');root.setAttribute('id','item-details');
 const title=off.document.createElement('h1');title.textContent='Offsale Hat';
 const row=off.document.createElement('div');row.className='price-row-container';
 if(label){const price=off.document.createElement('span');price.className='item-price-value';price.textContent=label;row.append(price);}
 root.append(title,row);off.document.body.append(root);off.mutateNative();
 await click(row.querySelector('.larpbux-classic-buy'));
 assert.match(textOf(off.document.querySelector('.larpbux-buy-dialog')),/10,000/);
 await click(off.document.querySelector('.larpbux-buy-confirm'));
 const saved=JSON.parse(store.get('larpblox-cosmetics-v1:811'));
 assert.equal(saved.balance,5000,'offsale purchase charges exactly 10k');
 assert.equal(saved.items[0].id,99,'offsale item is added to collection');
}

console.log('Larpbux purchase dialog, cancel, quoted-price charge, persistence, insufficient-balance protection, and native purchase preservation checks passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
