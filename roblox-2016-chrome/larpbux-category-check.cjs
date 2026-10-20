const assert = require('node:assert/strict');
const {matchesAvatarCategory, supportsOutfit, outfit, mergeGameSnapshot, equip, previewDefinition, gameCommand} = require('./larpbux.js');

const item = assetType => ({itemType: 'Asset', assetType});
const hat = item(8);
const shirt = item(11);
const pants = item(12);
const tShirt = item(2);
const animation = item(50);
const layered = item(68);
const eyebrow = item(76);
const eyelash = item(77);
const unsupported = item(99);
const accessory = assetType => item(assetType);

assert.equal(matchesAvatarCategory(hat, 'Hats'), true);
assert.equal(matchesAvatarCategory(shirt, 'Hats'), false);
assert.equal(matchesAvatarCategory(shirt, 'Shirts'), true);
assert.equal(matchesAvatarCategory(tShirt, 'Shirts'), false, 'T-Shirts are not classic Shirts');
assert.equal(matchesAvatarCategory(tShirt, 'T-Shirts'), true, 'T-Shirts use asset type 2');
assert.equal(matchesAvatarCategory(layered, 'Layered Clothing'), true, 'Layered clothing is shown in its own category');
assert.equal(matchesAvatarCategory(eyebrow, 'Accessories Eyebrow'), true, 'Eyebrows are accessory makeup');
assert.equal(matchesAvatarCategory(eyelash, 'Accessories Eyelash'), true, 'Eyelashes are accessory makeup');
assert.equal(matchesAvatarCategory(animation, 'Animations'), true, 'Animation assets appear in Animations');
assert.equal(matchesAvatarCategory(pants, 'Pants'), true);
for (const category of ['Creations', 'Avatars', 'Body', 'Animations', 'Unknown']) {
  assert.equal(matchesAvatarCategory(hat, category), false, `${category} does not show local cosmetics`);
}
for (const candidate of [hat, shirt, pants, accessory(41), accessory(42), accessory(43), accessory(44), accessory(45), accessory(46), accessory(47)]) {
  assert.equal(matchesAvatarCategory(candidate, 'RecentRecentlyAdded'), true);
}
assert.equal(matchesAvatarCategory(unsupported, 'RecentRecentlyAdded'), false);
assert.equal(matchesAvatarCategory(hat, 'RecentCurrentlyWearing', true), true);
assert.equal(matchesAvatarCategory(hat, 'RecentCurrentlyWearing', false), false);

for (const [assetType, category] of [[41, 'AccessoriesHair'], [42, 'AccessoriesFace'], [43, 'AccessoriesNeck'], [44, 'AccessoriesShoulder'], [45, 'AccessoriesFront'], [46, 'AccessoriesBack'], [47, 'AccessoriesWaist']]) {
  assert.equal(matchesAvatarCategory(accessory(assetType), category), true, `${category} accepts asset type ${assetType}`);
  assert.equal(matchesAvatarCategory(hat, category), false, `${category} rejects hats`);
}
assert.equal(matchesAvatarCategory(accessory(46), 'Back'), true, 'Back labels map to back accessories');
assert.equal(matchesAvatarCategory(item(18), 'Body Faces'), true, 'Body Faces use classic face assets');
assert.equal(matchesAvatarCategory(item(18), 'Classic Faces'), true, 'Classic Faces use asset type 18');
assert.equal(matchesAvatarCategory(item(42), 'Accessories Face'), true, 'Face accessories remain asset type 42');

const animationPack = {itemType: 'Bundle', id: 900, name: 'Movement Pack', bundleType: 'AvatarAnimations', assets: [item(50), item(56)].map((asset, index) => ({...asset, id: index + 1, name: `Animation ${index + 1}`}))};
assert.equal(supportsOutfit(animationPack), true, 'AvatarAnimations bundles are wearable');
assert.equal(JSON.parse(outfit({items: [animationPack], equipped: ['Bundle:900']}, 7)).items.length, 2, 'Animation bundles expand in outfit export');
const merged = mergeGameSnapshot({items: [animationPack], equipped: ['Bundle:900']}, {userId: '7', items: animationPack.assets, definition: {assets: animationPack.assets.map(asset => ({id: asset.id}))}});
assert.deepEqual(merged.equipped, ['Bundle:900'], 'Expanded game animation components preserve bundle equipped state');

console.log('Larpbux avatar category matching Hats, classic clothing, Recent filters, accessory subtypes, and excluded categories checks passed.');

assert.equal(matchesAvatarCategory(animationPack,'RecentRecentlyAdded',false),true,'new unselected packs appear in Recently Added');
assert.equal(matchesAvatarCategory(animationPack,'RecentCurrentlyWearing',false),false,'unselected packs stay out of Currently Wearing');
assert.equal(matchesAvatarCategory({itemType:'Asset',assetType:76},'MakeupEyebrows'),true,'makeup eyebrows category works');
assert.equal(matchesAvatarCategory({itemType:'Asset',assetType:64},'ClothingClassicTShirts'),false,'layered T-shirts stay out of classic graphic T-shirts');

for (const type of [8,41,42,43,44,45,46,47,50]) assert.equal(matchesAvatarCategory(item(type), "AccessoriesGear"), false, "Gear rejects other categories");
assert.equal(matchesAvatarCategory(item(19), "AccessoriesGear"), true, "Gear accepts actual gear");
assert.equal(supportsOutfit(item(19)), true, "Gear can be equipped");

const gears=[{id:100,name:'Sword',itemType:'Asset',assetType:19},{id:101,name:'Coil',itemType:'Asset',assetType:19}];
const gearState=equip({items:gears,equipped:['Asset:100']},'Asset:101');
assert.deepEqual(gearState.equipped,['Asset:101'],'equipping a gear replaces held gear');
assert.equal(JSON.parse(outfit(gearState,7)).items[0].assetType,19,'export includes gear');
const gearLook={userId:'7',items:[gears[0]],definition:{assets:[{id:100}]}};
assert.deepEqual(gameCommand({...gearState,gameLook:gearLook},7).items,[gears[1]],'game command replaces old gear');
const gearPreview=previewDefinition({assets:[{id:100,assetType:{id:19}}],bodyColors:{},playerAvatarType:'R15'},{},[gears[1]]);
assert.deepEqual(gearPreview.assets,[{id:101}],'preview replaces old gear');

const headless={id:134082579,name:'Headless Horseman Head',itemType:'Asset',assetType:17};
const ordinaryHead={id:300,name:'Classic Head',itemType:'Asset',assetType:17};
const epicFace={id:200,name:'Epic Face',itemType:'Asset',assetType:18};
const faceState=equip({items:[headless,ordinaryHead,epicFace],equipped:['Asset:134082579','Asset:300']},'Asset:200');
assert.deepEqual(faceState.equipped,['Asset:300','Asset:200'],'equipping a classic face removes Headless but keeps an ordinary head');
const facePreview=previewDefinition({assets:[{id:134082579,assetType:{id:17}},{id:300,assetType:{id:17}}],bodyColors:{},playerAvatarType:'R15'},{},[epicFace]);
assert.deepEqual(facePreview.assets,[{id:300},{id:200}],'classic face preview removes only the known Headless asset');
