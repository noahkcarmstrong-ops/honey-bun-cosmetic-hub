# Honey Bun Cosmetic Hub

A universal, local avatar editor with the Honey Bun menu style. It has its own repository and does not detect the current game or load features from the original hub.

## Load

Run this in your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/main/loader.lua", false))()
```

## Accessories

1. Open **ACCESSORIES**.
2. Paste a Roblox catalog link or numeric asset ID.
3. Click **Equip accessory**.

Supports compatible rigid accessories, including hats, masks, and hair. Added accessories appear in a remove list. **Remove added accessories** leaves your existing accessories alone. Asset scripts are stripped before anything is equipped. At most 20 added accessories are allowed at once.

## Skin

1. Open **SKIN** and choose the whole body or a region with **Apply to**.
2. Choose a palette color, enter RGB numbers from 0 to 255, or paste a six-digit hex color.
3. Click the matching Apply button for custom colors.

Clothing and textured bodies can cover skin colors. R6 and R15 limb groups are supported.

## Body

1. Open **BODY**.
2. Choose **Blocky**, **Girl**, or **Robloxian 2.0**, or paste a Roblox body bundle link/ID and click **Apply body package**.

The editor keeps your current character model and rig type. R6 uses compatible CharacterMesh bodies; R15 uses Roblox's body-part replacement API. Body bundles must expose a usable avatar outfit. The Girl and Robloxian 2.0 presets use Roblox's official outfits. Body-only package changes do not add the package's clothes or hair.

## Controls and limits

- **Restore original appearance** removes added accessories and restores the captured body and colors.
- **Right Shift** shows/hides the menu. Hiding keeps your changes.
- **Refresh** restores the original appearance, closes the old editor, and loads the latest version from this repository.
- Respawning clears the current selection; apply cosmetics again on the new character.

Changes are local and visible to you. They do not update your Roblox account avatar. Asset permissions, custom game characters, and client API restrictions can prevent an item or package from loading; the menu shows an error. Layered clothing is not supported by the rigid accessory equipper. Live behavior still needs verification in the user's client.

## Verification

```sh
npx --offline --package=fengari-node-cli fengari tests/avatar.lua
npx --offline --package=fengari-node-cli fengari tests/menu.lua
```

These use Roblox stand-ins to check the editor logic; they do not prove that a game permits a particular asset.

API references: [Accessories](https://create.roblox.com/docs/reference/engine/classes/Accessory), [Humanoid body-part replacement](https://create.roblox.com/docs/reference/engine/classes/Humanoid#ReplaceBodyPartR15), and [Players avatar generation](https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescriptionAsync).
