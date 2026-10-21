# Prism

`Prism.rbxm` contains the unmodified Luau bindings and bundled runtime from [3xjn/prism](https://github.com/3xjn/prism) at revision `2383bbd` ([PR #35](https://github.com/3xjn/prism/pull/35)).

Build it in the Prism checkout with `npm ci`, `rokit install`, and `npm run build:bindings`, then copy `dist/Prism.rbxm` here. The model carries Prism's MIT license and dependency licenses in `ThirdPartyNotices`.

`prism.lua` loads this model in the client executor. `ui.lua` applies Larpblox's classic styles to its public React components.
