<p align="center">
  <img src="assets/larpblox-logo.png" alt="Larpblox" width="520">
</p>

<p align="center">best way to larp.</p>

## Features

- Edit accessories, clothes, skin, body parts, emotes, and movement animations.
- Save and switch between character looks.
- Pair with the browser wardrobe for outfit sync and optional Larp names.
- Share supported appearances with Larpblox users in the same live server.

> [!NOTE]
> Appearance changes affect your local client. Enable **Share appearance** on the browser's Avatar page to share supported looks with other Larpblox users in the same server. Both players must enable sharing. A custom Larp name is optional.

<details>
<summary>Murder Mystery 2</summary>

Local inventory, weapon, and effect previews. They do not grant ownership. See the [user guide](docs/guide.md#mm2-local-cosmetics).

</details>

## Load

Run in a compatible Roblox client executor:

The interface uses [Prism](https://github.com/3xjn/prism) with Larpblox's classic styling. The executor needs local file and asset support (`writefile` and `getcustomasset` or `getsynasset`).

```lua
local branch = "main"
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/larpblox/" .. branch .. "/launcher.lua", false))(branch)
```

## Companion apps

- [Larpblox Desktop](https://github.com/3xjn/larpblox-desktop/releases) — Windows installer for the local browser/game connection.
- [Browser extension](https://github.com/3xjn/larpblox-extension/releases) — maintained and downloaded separately.

## Documentation

- [User guide](docs/guide.md)
