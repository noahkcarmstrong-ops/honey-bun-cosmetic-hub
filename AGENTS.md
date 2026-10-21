# Larpblox project instructions

## Event-driven behavior and performance

- Prefer event-driven updates and targeted executor hooks over polling. React to the actual state change instead of repeatedly checking for it.
- Do not introduce polling loops, recurring timer checks, or per-frame scans to detect changes. Do not disguise polling as a Heartbeat, RenderStepped, or PreAnimation listener.
- When Roblox does not expose a suitable event, use a narrowly scoped executor hook for the relevant callback, property assignment, or method invocation. Preserve the original behavior and arguments, avoid recursive hooks, and ignore unrelated objects.
- Coalesce duplicate events with deferred work when needed. A deferred reaction to an event is appropriate; a repeating retry timer is not.
- Disconnect listeners and release hook ownership when a character is replaced, a feature is disabled, or the module is destroyed. Keep hooks safe across interface reloads.
- If neither an event nor a safe hook can observe the change, explain the limitation and ask before adding any polling fallback.
