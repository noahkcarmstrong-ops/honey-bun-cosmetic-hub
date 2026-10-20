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
> Appearance changes affect your local client. Both players must enable **Connection → Share Larp appearance** to see each other's shared looks. A custom Larp name is optional.

<details>
<summary>Murder Mystery 2</summary>

Local inventory, weapon, and effect previews. They do not grant ownership. See the [user guide](docs/guide.md#mm2-local-cosmetics).

</details>

## Load

Run in a compatible Roblox client executor:

```lua
local branch = "main"
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/larpblox/" .. branch .. "/launcher.lua", false))(branch)
```

## Companion apps

- [Larpblox Desktop](https://github.com/3xjn/larpblox-desktop/releases) — Windows installer for the local browser/game connection.
- [Browser extension](https://github.com/3xjn/larpblox-extension/releases) — maintained and downloaded separately.

## Documentation

- [User guide](docs/guide.md)
