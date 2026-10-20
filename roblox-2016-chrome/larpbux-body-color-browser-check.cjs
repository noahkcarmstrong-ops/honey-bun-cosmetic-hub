const assert = require('node:assert/strict');
const path = require('node:path');
const {chromium} = require('playwright');

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  try {
    const page = await browser.newPage();
    page.setDefaultTimeout(2500);
    const snapshot = {version: 1, userId: '123', definition: {
      assets: [], bodyColors: Object.fromEntries(['head', 'torso', 'leftArm', 'rightArm', 'leftLeg', 'rightLeg'].map(part => [part + 'Color', 'ffffff'])),
      scales: {}, playerAvatarType: {playerAvatarType: 'R15'}
    }, items: []};
    await page.addInitScript(snapshot => {
      localStorage.setItem('larpblox-cosmetics-v1:123', JSON.stringify({version: 1, mode: true, pendingOutfit: false, gameLook: snapshot, items: [], equipped: []}));
      window.published = [];
      window.nativeColorClicks = 0;
      window.LarpbloxAvatar3D = {create: async () => ({dispose() {}, getView() {return undefined;}})};
      window.chrome = {runtime: {sendMessage: async message => {
        if (message.action === 'publish') window.published.push(message.snapshot);
        return {ok: true, data: message.action === 'read' ? {connected: true, snapshot} : {connected: true}};
      }}};
    }, snapshot);
    await page.route('https://www.roblox.com/my/avatar', route => route.fulfill({contentType: 'text/html', body: '<meta name="user-data" data-userid="123"><main id="avatar-web-app"><div class="left-wrapper"><div class="avatar-thumbnail"></div></div><div class="breadcrumb-container">Body Colors</div><button class="color-swatch" aria-label="Body color" data-color="#112233"></button></main>'}));
    const renders = [];
    await page.route('https://avatar.roblox.com/v1/avatar/render', route => {
      renders.push(route.request().postDataJSON().avatarDefinition);
      return route.fulfill({json: {state: 'Completed', imageUrl: 'https://example.com/fixture.json'}});
    });
    await page.route('https://avatar.roblox.com/v1/avatar-rules', route => route.fulfill({json: {bodyColorsPalette: [{brickColorId: 1004, hexColor: '#ff0000'}]}}));
    await page.goto('https://www.roblox.com/my/avatar');
    await page.evaluate(() => document.querySelector('.color-swatch').addEventListener('click', () => window.nativeColorClicks++));
    await page.addScriptTag({path: path.join(__dirname, 'larpbux-game-bridge.js')});
    await page.addScriptTag({path: process.argv[2] || path.join(__dirname, 'larpbux.js')});
    await page.locator('.color-swatch').click();
    await page.waitForFunction(() => JSON.parse(localStorage.getItem('larpblox-cosmetics-v1:123')).bodyColors.headColor === '#112233');
    assert.equal(await page.evaluate(() => window.published.at(-1).definition.bodyColors.headColor), '#112233');
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('larpblox-cosmetics-v1:123')).pendingOutfit), true);
    await page.waitForFunction(() => window.published.length > 0);
    await page.waitForTimeout(100);
    assert.ok(renders.some(definition => definition.bodyColors.headColor === '#112233'), 'color changes invalidate the browser preview');
    assert.equal(await page.evaluate(() => window.nativeColorClicks), 0, 'Larp selection does not update the real account');
    await page.evaluate(() => {
      const swatch = document.querySelector('.color-swatch');
      swatch.setAttribute('data-region', 'Left Arm');
      swatch.setAttribute('data-color', '#abcdef');
    });
    await page.locator('.color-swatch').click();
    await page.waitForFunction(() => JSON.parse(localStorage.getItem('larpblox-cosmetics-v1:123')).bodyColors.leftArmColor === '#abcdef');
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('larpblox-cosmetics-v1:123')).bodyColors.headColor), '#112233', 'per-limb colors preserve other regions');
    await page.evaluate(() => {
      const swatch = document.querySelector('.color-swatch');
      swatch.removeAttribute('data-region'); swatch.removeAttribute('data-color');
      swatch.setAttribute('data-color-id', '1004'); swatch.className = '';
    });
    await page.locator('[data-color-id]').click();
    await page.waitForFunction(() => JSON.parse(localStorage.getItem('larpblox-cosmetics-v1:123')).bodyColors.headColor === '#ff0000');
    await page.getByRole('button', {name: 'Real avatar', exact: true}).click();
    await page.evaluate(() => document.querySelector('[data-color-id]').addEventListener('click', () => window.nativeColorClicks++));
    await page.locator('[data-color-id]').click();
    assert.equal(await page.evaluate(() => window.nativeColorClicks), 2, 'Real avatar keeps native color handling');
    console.log('Body color swatch is intercepted, saved locally, and published to the game.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
