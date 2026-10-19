# Larpblox

A universal, local avatar editor with the Larpblox menu style. It has its own repository. An MM2 menu appears in Murder Mystery 2; the cosmetic tabs remain universal. It does not load features from the original hub.

## Load

Run this in your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/larpblox/main/loader.lua", false))()
```

## Accessories

1. Open **ACCESSORIES**.
2. Paste Roblox catalog links or numeric asset IDs, separated by spaces, commas, or new lines.
3. Click **Add accessories**. Existing hats stay on; you can keep adding more.

The added accessory list shows your count and a separate Remove button for each item. Successful entries clear from the input; any failed entries stay there to retry, with an explanation above the list.

Supports compatible rigid accessories, including hats, masks, and hair. Added accessories appear in a remove list. **Remove added accessories** leaves your existing accessories alone. Asset scripts are stripped before anything is equipped. At most 20 added accessories are allowed at once.

**Remove current Roblox accessories** hides the accessories your avatar is already wearing, including your account's hats. Accessories added by the hub stay equipped. **Restore original appearance** brings the original accessories back. Refresh re-applies your saved choice. This does not remove anything from your Roblox inventory.

### Hat sounds

Equipped accessories can play their embedded original sounds locally. Brighteyes' Witches Brew Hat uses its original three laughs and randomly plays one every 5–15 seconds while worn, matching its original SoundPlayer behavior. Hidden or removed hats stop hub-started playback. Roblox audio permissions still apply; arbitrary accessory scripts are not executed.

Original asset inspected: https://assetdelivery.roblox.com/v1/asset/?id=305888394 (WitchesBrewHat; Laugh 62777535, Laugh2 88108663, Laugh3 88108686).

## Clothes

1. Open **CLOTHES** and paste a classic 2D shirt catalog link or ID, then click **Equip shirt**.
2. Paste a classic 2D pants catalog link or ID, then click **Equip pants**.
3. Use **Restore original shirt** or **Restore original pants** to reset just that garment.

Shirts and pants work together and save like your other cosmetic selections, including after rejoining when file auto-save is on. These controls support classic `Shirt` and `Pants` assets; layered 3D clothing is rejected. Changing clothes keeps accessories, skin, body packages, emotes, and movement animations.

## Skin

1. Open **SKIN** and choose the whole body or a region with **Apply to**.
2. Expand **Roblox colors** for all 30 exact RGB swatches from the supplied screenshot, in its original 5-column order. You can also enter RGB numbers from 0 to 255 or paste a six-digit hex color.
3. Click the matching Apply button for custom colors.

Clothing and textured bodies can cover skin colors. R6 and R15 limb groups are supported.

**Restore original skin** resets only your skin colors and clears saved color overrides. It keeps added hats, body packages, hidden original accessories, emotes, and movement animations.

## Body

1. Open **BODY**.
2. Choose **Blocky**, **Girl**, or **Robloxian 2.0**, or paste a Roblox body bundle link/ID and click **Apply body package**.
3. Expand **Custom body parts** to mix a head, torso, left/right arm, and left/right leg from different packages. Each region has its own link box and Equip button. Use a body bundle URL to select that package's region, or the individual part's catalog URL/asset ID. Individual region replacement requires R15; arms and legs include matching hands and feet.
4. Use **Restore original body** to restore your avatar's original body shapes while keeping accessories, clothing, and skin colors.

The editor keeps your current character model, live limbs, rig, and gear connections. R6 uses compatible CharacterMesh bodies; R15 updates existing mesh appearance with ApplyMesh instead of replacing hands or other live body parts. Package limb dimensions and matching rig attachment offsets are applied to the existing limbs and body joints. Full packages also apply their floor height. Game gear attachments and tool joints are preserved; restore returns the original sizes, joint offsets, and floor height. Compatible Part-based heads use visual meshes. Unsupported conversions show an error instead of replacing a live part. Body bundles must expose a usable avatar outfit. The Girl and Robloxian 2.0 presets use Roblox's official outfits. Body-only package changes do not add the package's clothes or hair. Custom part selections save and reapply over your selected base package. Equipping a new full body package replaces the mixed part selections. Unsupported or restricted parts show an error; live compatibility depends on the asset and game.

Package changes preserve the source body's hidden parts, including Korblox Deathspeaker's invisible lower-leg and foot pieces. Restore original body returns your original parts' visibility.

## Emotes

1. Open **EMOTES** and select one of the eight wheel slots.
2. Paste a Roblox emote catalog link or ID and click **Assign to slot**.
3. Use **Open Roblox emote wheel**, or **Preview slot** to try your selection. **Reset slot** restores that slot's original assignment.

Wheel assignments save for the session and reapply after respawning or Refresh. Roblox's standard wheel requires an R15 avatar and the game's emote menu to be enabled. Private or restricted emotes may not play.

## Animations

1. Open **ANIMATIONS** and paste a Roblox movement animation bundle link, such as `https://www.roblox.com/bundles/82/Robot`.
2. Click **Equip animation bundle**, then walk or run to try it.
3. Click **Restore original animations** to return to your original movement set.

The bundle changes its included walk, run, idle, jump, fall, climb, and swimming animations while keeping your current appearance. Idle variants and swimming idle are preserved when included. The equipped bundle saves for the session and returns after resets or Refresh. This requires an R15 avatar with Roblox's standard Animate controls; games with custom movement systems may not support it. A bundle that fails to load leaves your equipped movement set in place. Tabs scroll sideways on narrow screens.

## Saved characters

1. Put together your look using the cosmetic tabs.
2. Open **CHARACTERS**, click **Create New Character**, enter a name, and click **Create**.
3. Click a square character preview to equip it. Names appear underneath; **Search by name...** filters the grid as you type. The grid widens on desktop and adapts to smaller screens.
4. Click the cog in the top-right of a preview for **Update**, **Rename**, **Delete**, and **Cancel**. Update replaces that saved character with your current look and preview; Rename changes its name. Delete asks for confirmation and leaves your equipped look alone.

Save up to 12 looks. Each snapshot keeps your hub accessories, skin colors, body package and individual parts, classic clothes, emote slots, and movement bundle. Equipping replaces all those selections and makes that look the one that returns after resets and rejoining. Saved looks use your current account avatar as their original base; they do not change your Roblox account. File access is required to keep the wardrobe after leaving, just like the other saved settings. Previews show the saved outfit’s classic shirts and pants alongside its body and accessories. Native body meshes are reused or loaded in the background so classic clothing can render without blocking the menu. Previews are local visual snapshots; asset permissions and unusual game characters can limit rendering.

## Controls and limits

- **Restore original appearance** removes added accessories, brings back hidden original accessories, restores original clothes, the captured body, colors, emote wheel and movement animations, and clears saved cosmetic selections.
- **Right Shift** shows/hides the menu. Hiding keeps your changes.
- In the weapon position editor's avatar preview, **left-drag** rotates, **right-drag** moves the view up/down/sideways, and **scroll** zooms. Moving the view does not change weapon placement.
- **Refresh** closes the old editor and loads the latest version from this repository, then reapplies your saved cosmetics.
- Respawning or resetting automatically reapplies your body package, hidden original accessories, added accessories, and per-region colors after your new character finishes loading.
- **Reapply saved cosmetics** retries saved items if an asset failed to load. Failed saved items are kept for retry.
- Hiding original accessories changes only their local visibility. Identified avatar hats stay parented with their scripts and joints intact; unidentified game equipment is left alone. The hub does not clear Backpack tools or rebuild game-owned accessory joints.

Selections and editor fields survive respawns, resets, Refresh, and re-running the launcher. When your executor supports `readfile` and `writefile`, automatic saving also stores accessories, classic shirts and pants, colors, body packages, emote slots, movement bundles, and editor fields in `HoneyBunCosmeticHub_<RobloxUserId>.json`, with a `.bak` backup. Run the hub again after rejoining to load them. The file belongs to your account on that executor/device and is shared across games; it does not follow you to a different device automatically.

The menu displays **Auto-save: on**, **session only**, or a file-write failure. Without executor file access, saving lasts only for the current Roblox session. Refreshing into this version saves your existing selections automatically.

Accessory, body, skin, and wheel assignment changes are local. They do not update your Roblox account avatar. Animation and emote playback uses the character's existing Animator: when that Animator was created by the server, Roblox normally shares the playback with other players. This depends on the game's character system and asset permissions; multiplayer visibility has not been verified in a live session. Asset permissions, custom game characters, and client API restrictions can prevent an item or package from loading; the menu shows an error. Layered clothing is not supported by the rigid accessory equipper.

## Verification

```sh
npx --offline --package=fengari-node-cli fengari tests/avatar.lua
npx --offline --package=fengari-node-cli fengari tests/menu.lua
npx --offline --package=fengari-node-cli fengari tests/motion.lua
npx --offline --package=fengari-node-cli fengari tests/animations.lua
npx --offline --package=fengari-node-cli fengari tests/storage.lua
npx --offline --package=fengari-node-cli fengari tests/clothes.lua
npx --offline --package=fengari-node-cli fengari tests/characters.lua
npx --offline --package=fengari-node-cli fengari tests/previews.lua
npx --offline --package=fengari-node-cli fengari tests/mm2.lua
npx --offline --package=fengari-node-cli fengari tests/native_inventory.lua
npx --offline --package=fengari-node-cli fengari tests/mm2_effects.lua
```

These use Roblox stand-ins to check the editor logic; they do not prove that a game permits a particular asset.

API references: [Accessories](https://create.roblox.com/docs/reference/engine/classes/Accessory), [Humanoid body-part replacement](https://create.roblox.com/docs/reference/engine/classes/Humanoid#ReplaceBodyPartR15), [Players avatar generation](https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescriptionAsync), [emote assignments](https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription#SetEquippedEmotes), and [animation replication](https://create.roblox.com/docs/reference/engine/classes/Animator#LoadAnimation).

## MM2 local cosmetics

The sheriff crosshair accepts Roblox image IDs and decal IDs or links, including Creator Store links. Decals are resolved to their image texture before previewing and saving.

**Show all MM2 emotes** remembers ON or OFF across Refresh and rerunning the menu. With **Auto-save: on**, it also restores your choice when you run the menu after rejoining MM2, including the Game Emotes bar.

Open MM2's Weapons inventory, then open **MM2 → Open MM2 menu** in the hub and enable **Show all weapons**. Supported native item cards are copied into the game's inventory window using the loaded knife/gun catalog. Click a local card to select it. The selection applies to a matching native weapon now or when it becomes available, and reapplies after respawning. Season 1, Classic, and Holiday use the loaded item metadata; cards sort by available order metadata, rarity, chroma status, and name. The local collection reconnects when MM2 reopens or rebuilds its inventory. Disable the toggle to restore the original inventory display and weapon appearance.

This changes the local inventory display; it does not add ownership or trading rights. It requires a recognizable native card layout and loaded catalog. Unsupported layouts or model formats report an explanation. Use **Copy MM2 report** if the inventory cannot be detected. Live compatibility with every rare item and emote is not yet verified.

Weapon appearances are visible only to the person running the hub. The hub tries the selected model asset and exact, identifiable copies MM2 has already loaded. If neither source is available, the inventory selection remains saved but its avatar appearance cannot be shown. Loaded scripts are stripped; supported meshes are applied to the existing native weapon/display without replacing its connections. The tab matcher supports image buttons with separate caption labels. Copy MM2 report includes category totals, matched tab controls, pending selections, item asset IDs, and equip failures.

### Saved local guns

In the MM2 hub menu, enter a player's Roblox username and click **Copy and equip player's gun** while their gun is loaded nearby. The hub saves the original mesh, texture, and proportions; it shows a separate local visual attached to your existing gun without replacing the game's tool or joints. Custom animations, particles, and additional model parts are not included.

Use **Open saved guns** to list saved captures and their Equip buttons. Captures and the last selected saved gun survive rejoining when the hub reports **Auto-save: on**. The source player does not need to stay in your server. Earlier session-only captures must be collected once more with this version. Rendering still depends on Roblox making the saved mesh and texture available.

### Local knife effects

Open MM2's **Effects** inventory and enable **MM2 → Show all effects**. This separately lists the entries in the loaded `Database.Sync.Effects` catalog using native item cards. Clicking a card selects a local knife effect; supported, available visual templates are copied onto your knife display and knife tool. The selected preview reapplies when those targets arrive after a reset. The effects toggle does not change the weapons toggle.

An inventory entry alone does not guarantee its effect assets are available. Missing templates and effects that depend on game-controlled kill behavior report an unavailable explanation instead of inventing a substitute effect. These previews do not grant ownership or change what other players see. Turning effects off or closing the hub removes the added visuals and restores the native inventory display.

## Personal saves and distribution

Distribute the published source files, not your executor workspace or personal save files. Outfits, saved MM2 weapons/effects, cosmetic selections, custom names, and menu preferences are saved locally per Roblox account in `HoneyBunCosmeticHub_<UserId>.json` (plus its `.bak` backup). They are not uploaded by the save system or bundled in the repository. New users start with their own empty saved collections. Existing local save files remain compatible; newly written files also include the owning account ID.

Personal save files are excluded by `.gitignore`. These are local files, not encrypted storage; someone with access to the same computer can read them.
