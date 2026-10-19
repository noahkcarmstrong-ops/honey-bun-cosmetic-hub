# Honey Bun Cosmetic Hub

A universal, local avatar editor with the Honey Bun menu style. It has its own repository and does not detect the current game or load features from the original hub.

## Load

Run this in your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/main/loader.lua", false))()
```

## Accessories

1. Open **ACCESSORIES**.
2. Paste Roblox catalog links or numeric asset IDs, separated by spaces, commas, or new lines.
3. Click **Add accessories**. Existing hats stay on; you can keep adding more.

The added accessory list shows your count and a separate Remove button for each item. Successful entries clear from the input; any failed entries stay there to retry, with an explanation above the list.

Supports compatible rigid accessories, including hats, masks, and hair. Added accessories appear in a remove list. **Remove added accessories** leaves your existing accessories alone. Asset scripts are stripped before anything is equipped. At most 20 added accessories are allowed at once.

**Remove current Roblox accessories** hides the accessories your avatar is already wearing, including your account's hats. Accessories added by the hub stay equipped. **Restore original appearance** brings the original accessories back. Refresh re-applies your saved choice. This does not remove anything from your Roblox inventory.

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

The editor keeps your current character model and rig type. R6 uses compatible CharacterMesh bodies; R15 uses Roblox's body-part replacement API. Body bundles must expose a usable avatar outfit. The Girl and Robloxian 2.0 presets use Roblox's official outfits. Body-only package changes do not add the package's clothes or hair. Custom part selections save and reapply over your selected base package. Equipping a new full body package replaces the mixed part selections. Unsupported or restricted parts show an error; live compatibility depends on the asset and game.

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

## Controls and limits

- **Restore original appearance** removes added accessories, brings back hidden original accessories, restores original clothes, the captured body, colors, emote wheel and movement animations, and clears saved cosmetic selections.
- **Right Shift** shows/hides the menu. Hiding keeps your changes.
- **Refresh** closes the old editor and loads the latest version from this repository, then reapplies your saved cosmetics.
- Respawning or resetting automatically reapplies your body package, hidden original accessories, added accessories, and per-region colors after your new character finishes loading.
- **Reapply saved cosmetics** retries saved items if an asset failed to load. Failed saved items are kept for retry.

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
```

These use Roblox stand-ins to check the editor logic; they do not prove that a game permits a particular asset.

API references: [Accessories](https://create.roblox.com/docs/reference/engine/classes/Accessory), [Humanoid body-part replacement](https://create.roblox.com/docs/reference/engine/classes/Humanoid#ReplaceBodyPartR15), [Players avatar generation](https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescriptionAsync), [emote assignments](https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription#SetEquippedEmotes), and [animation replication](https://create.roblox.com/docs/reference/engine/classes/Animator#LoadAnimation).
