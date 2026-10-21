# Larpblox project instructions

## Preserve Roblox's native icons

- Do not modify Roblox installation files, bundled sprite sheets, or native menu/voice-chat icons. The user explicitly requested these remain untouched after a cross-version image-sheet replacement broke the UI.
- Never copy Studio assets into a Player installation or mix assets between Roblox versions.
- Keep Larpblox identity and avatar changes scoped to player names, badges, and avatar thumbnails; exclude native controls, keyboard hints, separators, and voice indicators.
- For suspected native asset problems, inspect first. Restore only files previously changed by this project, using the exact installed Player version and a verified backup; do not replace assets from another build.

## Event-driven behavior and performance

- Prefer event-driven updates and targeted executor hooks over polling. React to the actual state change instead of repeatedly checking for it.
- Do not introduce polling loops, recurring timer checks, or per-frame scans to detect changes. Do not disguise polling as a Heartbeat, RenderStepped, or PreAnimation listener.
- When Roblox does not expose a suitable event, use a narrowly scoped executor hook for the relevant callback, property assignment, or method invocation. Preserve the original behavior and arguments, avoid recursive hooks, and ignore unrelated objects.
- Coalesce duplicate events with deferred work when needed. A deferred reaction to an event is appropriate; a repeating retry timer is not.
- Disconnect listeners and release hook ownership when a character is replaced, a feature is disabled, or the module is destroyed. Keep hooks safe across interface reloads.
- If neither an event nor a safe hook can observe the change, explain the limitation and ask before adding any polling fallback.
