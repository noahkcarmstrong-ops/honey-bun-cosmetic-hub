const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {mergeGameSnapshot, gamePreviewDefinition, gameCommand, equip, gameOutfitMatches} = require('./larpbux.js');
const {validateSnapshot, validateNames, validateImage} = require('./larpbux-game-bridge.js');
const snapshot = {version:1, userId:'123', revision:1, updatedAt:100, definition:{
  assets:[{id:10,meta:{version:2}},{id:20},{id:30},{id:40}],
  bodyColors:Object.fromEntries(['head','torso','leftArm','rightArm','leftLeg','rightLeg'].map(part=>[part+'Color','eab892'])),
  scales:{height:1,bodyType:0},playerAvatarType:{playerAvatarType:'R6'}},
  items:[{id:10,name:'Original hat',assetType:8,itemType:'Asset'},{id:20,name:'Larp hat',assetType:8,itemType:'Asset'},{id:30,name:'Shirt',assetType:11,itemType:'Asset'},{id:40,name:'Face',assetType:18,itemType:'Asset'}]};
assert.equal(validateSnapshot(snapshot,'123'),snapshot);
assert.throws(()=>validateSnapshot(snapshot,'456'),/different account/);
assert.throws(()=>validateSnapshot({...snapshot,definition:{...snapshot.definition,bodyColors:{}}},'123'),/colors/);
assert.deepEqual(validateNames({version:1,userId:'123',enabled:true,name:'Pilot_7'},'123'),{version:1,userId:'123',enabled:true,name:'Pilot_7'});
assert.throws(()=>validateNames({version:1,userId:'456',enabled:true,name:'Pilot_7'},'123'),/name/);
assert.equal(validateImage({version:1,userId:'123',definition:snapshot.definition,imageUrl:'https://tr.rbxcdn.com/1DAY-Avatar-Png/420/420/Avatar/Png/noFilter'},'123').imageUrl.includes('/Png/'),true);
const prior={version:1, mode:true, balance:500, items:[{id:20,name:'Old name',assetType:0,itemType:'Asset',price:100},{id:99,name:'Owned local hat',assetType:8,itemType:'Asset',price:50}],equipped:[]};
let state=mergeGameSnapshot(prior,snapshot);
assert.equal(state.balance,500,'sync never changes the wallet');
assert.ok(state.items.some(item=>item.id===99),'existing collection is preserved');
assert.equal(state.items.find(item=>item.id===20).price,100,'existing purchase data is preserved');
assert.equal(state.items.find(item=>item.id===20).assetType,8,'live metadata repairs an unknown purchase category');
assert.deepEqual(state.equipped,['Asset:10','Asset:20','Asset:30','Asset:40']);
assert.deepEqual(gamePreviewDefinition(state),snapshot.definition,'game preview uses actual game outfit, including equipped face/body assets');
assert.equal(gamePreviewDefinition({...state,bodyColors:{headColor:'112233',torsoColor:'112233',leftArmColor:'112233',rightArmColor:'112233',leftLegColor:'112233',rightLegColor:'112233'}}).bodyColors.headColor,'112233','local browser skin color overrides the last game snapshot');
state=equip(state,'Asset:20');
assert.deepEqual(gamePreviewDefinition(state).assets.map(x=>x.id),[10,30,40],'Remove excludes the game hat from the preview');
state=equip(state,'Asset:99');
const command=gameCommand(state,'123');
assert.equal(gameOutfitMatches(snapshot,command),false,'old game outfit must not acknowledge a new browser selection');
assert.equal(gameOutfitMatches({...command,items:[...command.items].reverse()},command),true,'acknowledgement ignores item ordering');
assert.equal(gameOutfitMatches({...command,items:[]},command),false,'a temporary empty game outfit must not acknowledge equipped hats');
assert.equal(gameOutfitMatches({...command,definition:{...command.definition,bodyColors:{...command.definition.bodyColors,headColor:'ABCDEF'}}},command),false,'a color-only change must not acknowledge the old outfit');
assert.equal(gameOutfitMatches({...command,definition:{...command.definition,bodyColors:{...command.definition.bodyColors,headColor:'#EAB892'}}},command),true,'color matching ignores an optional hash and case');
assert.deepEqual(command.definition.assets.map(x=>x.id),[10,30,40,99],'command adds browser hat and removes deselected game hat');
assert.deepEqual(command.definition.bodyColors,snapshot.definition.bodyColors,'skin colors do not change');
assert.deepEqual(command.definition.assets[0].meta,{version:2},'asset metadata survives both directions');
validateSnapshot(command,'123');
assert.deepEqual(snapshot.definition.assets.map(x=>x.id),[10,20,30,40],'local changes do not mutate the saved game snapshot');

// Selecting a saved character must replace the previous full outfit, including
// slots that the new character uses differently.
const savedCharacter = {
  version:1, userId:'123', definition:{...snapshot.definition, assets:[{id:501},{id:502}]},
  items:[{id:501,name:'Saved character hat',assetType:8,itemType:'Asset'},{id:502,name:'Saved character pants',assetType:12,itemType:'Asset'}]
};
const switched = mergeGameSnapshot(state, savedCharacter);
const switchedCommand = gameCommand(switched,'123');
assert.deepEqual(switchedCommand.definition.assets.map(x=>x.id),[501,502],'saved character sends its complete asset definition');
assert.deepEqual(switchedCommand.items.map(x=>x.id),[501,502],'saved character command drops every old outfit item');

// Exercise the actual service-worker message path with a mock loopback service.
let listener; const storage={}; const calls=[];
const context={AbortController,setTimeout,clearTimeout,console, LarpbloxGameBridge:{validateSnapshot,validateNames},importScripts(){},
 chrome:{runtime:{id:'test-extension',onMessage:{addListener(fn){listener=fn;}}},storage:{local:{async get(key){return {[key]:storage[key]};},async set(values){Object.assign(storage,values);},async remove(key){delete storage[key];}}}},
 fetch:async(url,options)=>{calls.push({url,options});return{ok:true,status:200,json:async()=>url.endsWith('/status')?{version:1,connected:true}:snapshot};}};
vm.runInNewContext(fs.readFileSync(require.resolve('./larpbux-game-background.js'),'utf8'),context);
const sender={id:'test-extension',url:'https://www.roblox.com/my/avatar'};
function message(action,extra={},from=sender){return new Promise(resolve=>listener({type:'larpblox-game-bridge',action,userId:'123',...extra},from,resolve));}
(async()=>{
 assert.equal((await message('connect',{code:'a'.repeat(32)})).ok,true);
 assert.equal((await message('read')).data.snapshot.userId,'123');
 assert.equal((await message('publish',{snapshot:command})).ok,true);
 assert.equal((await message('publishNames',{names:{version:1,userId:'123',enabled:true,name:'Pilot_7'}})).ok,true);
 assert.match(calls.at(-1).url,/\/v1\/names\/123$/);
 assert.ok(calls.every(call=>call.url.startsWith('http://127.0.0.1:38261/v1/')),'requests only reach the fixed local data relay');
 assert.equal(calls.at(-1).options.method,'POST');
 assert.equal(calls.at(-1).options.credentials,'omit','Roblox cookies never reach the helper');
 assert.equal((await message('read',{}, {...sender,url:'https://evil.example/'})).ok,false,'other origins cannot use the bridge');
 assert.equal((await message('publish',{snapshot:{...command,userId:'456'}})).ok,false,'cross-account commands are rejected');
 // Chrome can stop and recreate the background worker; storage survives it.
 vm.runInNewContext(fs.readFileSync(require.resolve('./larpbux-game-background.js'),'utf8'),{...context});
 assert.equal((await message('read')).data.connected,true,'restarted background worker reconnects using the saved code');
 const workingFetch=context.fetch;
 vm.runInNewContext(fs.readFileSync(require.resolve('./larpbux-game-background.js'),'utf8'),{...context,fetch:async()=>{throw new TypeError('helper offline');}});
 assert.equal((await message('read')).ok,false,'temporarily offline helper reports a connection error');
 vm.runInNewContext(fs.readFileSync(require.resolve('./larpbux-game-background.js'),'utf8'),{...context,fetch:workingFetch});
 assert.equal((await message('read')).data.connected,true,'helper returning reconnects without pairing again');
 await message('disconnect');
 assert.equal((await message('read')).data.connected,false,'disconnect forgets the token');
 console.log('Game outfit merge, preview, Wear/Remove commands, metadata, account isolation and service-worker relay checks passed.');
})().catch(error=>{console.error(error);process.exitCode=1;});

// Removing a movement pack restores native animation defaults in the game.
const restoredAnimation={id:700,name:'Native walk',assetType:55,itemType:'Asset'};
assert.equal(gameOutfitMatches({...command,items:[...command.items,restoredAnimation]},command),true,'native movement defaults do not block pack-removal acknowledgement');
assert.equal(gameOutfitMatches({...command,items:[...command.items,restoredAnimation]},{...command,items:[...command.items,{...restoredAnimation,id:701}]}),false,'a requested custom animation must match the equipped animation');

const knownWings={id:19399858,name:'Dark Bat Wings',itemType:'Asset',assetType:46,assetTypeVerified:true};
const wingsMerged=mergeGameSnapshot({items:[knownWings],equipped:[]},{items:[{...knownWings,assetType:8}],definition:{assets:[{id:19399858}]}});
assert.equal(wingsMerged.items[0].assetType,46,'game fallback Hat type cannot overwrite the verified Back category');

const leg={id:139607673,name:'Korblox Left Leg',assetType:30,itemType:'Asset'};
const nativeLeg={...leg,id:901,name:'Native Left Leg'};
const lookWithLeg={...snapshot,items:[leg],definition:{...snapshot.definition,assets:[{id:leg.id}]}};
let removedLeg=mergeGameSnapshot({...prior,items:[],equipped:[]},lookWithLeg);
removedLeg=equip(removedLeg,'Asset:139607673');
removedLeg=mergeGameSnapshot(removedLeg,lookWithLeg,true);
assert.deepEqual(removedLeg.equipped,[],'stale game snapshot must not reselect a removed leg');
const restoredLook={...lookWithLeg,items:[nativeLeg],definition:{...lookWithLeg.definition,assets:[{id:nativeLeg.id}]}};
removedLeg=mergeGameSnapshot(removedLeg,restoredLook,true);
removedLeg=mergeGameSnapshot(JSON.parse(JSON.stringify(removedLeg)),restoredLook,true);
assert.deepEqual(removedLeg.equipped,[],'restored native body stays unselected after later polls and refresh');
assert.deepEqual(gameCommand(removedLeg,'123').items,[],'future commands keep the body override removed');
removedLeg=equip(removedLeg,'Asset:139607673');
assert.deepEqual(mergeGameSnapshot(removedLeg,lookWithLeg,true).equipped,['Asset:139607673'],'explicitly wearing the leg again works');
assert.deepEqual(mergeGameSnapshot({...removedLeg,equipped:[]},lookWithLeg).equipped,['Asset:139607673'],'saved outfit still selects its body parts');
