# Cyberpunk 2077 RedScript Mod - RagdollGravityHelper

## Project Overview

This mod does exactly one thing: applies a light, continuous downward force to NPC ragdolls while they're falling, to counteract vanilla Cyberpunk 2077's unrealistically low ragdoll gravity. That's the entire scope.

## Scope lock

This mod exists specifically as the minimal alternative to bloated ragdoll-physics overhauls (see: SPLAT Physics, a ~25,000-line mod with per-death-type routing, trip/twitch/tumble systems, vehicle impulses, four preset "personalities", and a ~45,000-line settings UI - none of which this mod replicates or wants).

**Do not add**: per-pose or per-situation behavior (stairs/cower/running/workspot detection), per-death-type or per-weapon reactions, trip/twitch/tumble animation systems, vehicle or explosion-specific impulse handling, forward/directional pushes, multiple preset "modes", or a CET native-settings menu. If a future request sounds like any of these, push back and ask whether it really belongs in this mod versus a separate one.

## File Structure

- `r6/scripts/ragdoll_gravity_helper/Settings.reds` - the only configurable values (enabled, force strength, safety-cap duration), exposed via the native in-game Mod Settings menu (`@runtimeProperty` annotations) - no CET dependency.
- `r6/scripts/ragdoll_gravity_helper/GravityAssistSystem.reds` - the actual mechanism: hooks `NPCPuppet.OnRagdollEnabledEvent`, then drives a per-frame `DelayCallback` loop (via `DelaySystem.DelayCallbackNextFrame`) that applies a small downward `CreateRagdollApplyImpulseEvent` scaled by measured delta-time, until the puppet stops ragdolling, can't ragdoll, or the safety-cap duration elapses.
- `r6/scripts/ragdoll_gravity_helper/Logging.reds` - trivial no-op-by-default logger.

## Code Style & Conventions

### RedScript (.reds files)

- Use PascalCase for class names and public methods
- Use camelCase for variables and private methods
- Use m_varName for private fields on custom classes (fields added to native classes via `@addField` use a short `rgh_` prefix instead, matching how other CP77 ragdoll mods extend native puppet classes)
- Comment complex logic, especially game API interactions
- raw source dumps for api reference: E:\Tools\mods\cp77\redscript\source

### Settings

- All configurable options go through `RGHSettings` (native Mod Settings, not CET) - keep it to the handful of values that actually need in-game tuning. Do not add a preset/mode system.

### Delay system

- Continuous per-puppet ticking uses `DelaySystem.DelayCallbackNextFrame(ref<DelayCallback>)` (reschedule the *same* callback instance each frame) rather than a fixed-interval `DelayCallback(callback, delaySeconds, ...)`, to avoid visible steppiness. Scale any per-tick effect by measured delta-time (`EngineTime.ToFloat(GameInstance.GetSimTime(gi))` between calls) so it stays framerate-independent.

## Notes

- This mod modifies game behavior at runtime
- Be careful with game API calls to avoid crashes
- PERFORMANCE IS KING - this runs per-frame per ragdolling NPC, keep each tick trivially cheap

## Deployment target

Z:\\GOG\\Cyberpunk 2077

- game root contains the r6 folder, where these files can be deposited without special steps.

## Deploy/launch/pack scripts

- `node deploy.js` deletes `r6/scripts/ragdoll_gravity_helper` under the deployment target, then copies the entire local `./r6` folder over the target's `r6` folder (this also overwrites any non-mod files under the target's `r6/`, not just this mod's subfolder).
- `node launch.js` starts Cyberpunk 2077 via its shortcut, fire-and-forget (no wait for the game to actually launch).
- `node pack.js` deletes the local `./r6.zip` if it exists, then zips the entire local `./r6` folder into `./r6.zip` via `7z`. Only touches the local build artifact.
- These are ordinary scripts, not pre-authorized commands - confirm with the user before running them, same as any other command with real side effects (overwriting files in the game install, launching the game, etc).
