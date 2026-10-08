@README.md

- The target is the WoW 3.3.5a client (Lua 5.1, Interface 30300). Check every API call against the 3.3.5 API, not retail or Classic.
- The game can't be run from here. After changes, run `.\tools\lint.ps1` (it must be clean) and then ask the user to `/reload` and report any errors.
- The WoW install is `D:\World of Warcraft 3.3.5a`. Addons are junctioned in with `.\tools\link.ps1`.
- After each finished change: lint, then commit and push to `origin/main` (github.com/y4ncer/yancer-addons)
  without asking. No Claude co-author trailer in commits.

## Blizzard 3.3.5 source (check it before touching a Blizzard frame)

- Raw files are at the **repo root**, not under `FrameXML/`:
  `curl -sL https://raw.githubusercontent.com/wowgaming/3.3.5-interface-files/main/<File>.lua` (or `.xml`),
  e.g. `MainMenuBarMicroButtons.lua`, `FloatingChatFrame.lua`, `ActionButton.lua`, `UIParent.lua`.
  `gh` isn't set up here, so use curl and grep the result in `$TEMP`.
- When something we skinned or moved "doesn't stay put", grep that source for the frame's name and look for
  `SetPoint`, `SetClampRectInsets`, `SetWidth`, `SetTexture` calls. Blizzard usually re-applies them from an
  update function. The fix pattern is `hooksecurefunc("<BlizzardFunction>", reapply)` or a
  `hooksecurefunc(frame, "SetPoint", ...)` guarded by a flag (see `yancer-chat/Style.lua`).

## Lessons learned (bugs already hit)

- `MainMenuMicroButton_SetNormal/SetPushed` re-anchor `MainMenuBarPerformanceBar` (TOPLEFT) on every
  `UpdateMicroButtons`, so it has to be re-placed from hooks (`yancer-bars/Skin.lua`).
- Chat frames have `SetClampRectInsets(-35, 35, 26|38, -50)` from `FloatingChatFrame_OnLoad`. Near a screen
  edge they got pushed away from the mover. yancer-chat zeroes the insets.
- `PetFrame`, `RuneFrame` and `TotemFrame` are children of `PlayerFrame`. Hiding `PlayerFrame` (reparent to a
  hidden frame) hides them too, so yancer-frames reparents them to `UIParent` under its player frame.
- `UNIT_SPELLCAST_FAILED` also fires when pressing a spell mid-cast. Only treat a cast as failed if
  `UnitCastingInfo(unit)` returns nothing.
- `PLAYER_REGEN_DISABLED` handlers still run out of lockdown, so yancer-bars locks movers there.
  Anything secure after that must be queued for `PLAYER_REGEN_ENABLED`.

## Status / next up (update this at the end of a session)

- Tested in-game by the user: yancer-bars (incl. the Quartz-style player cast bar, channel ticks, pushback),
  yancer-chat, yancer-quests tracker (background only while collapsed), nameplate debuffs with timers.
- Written 2026-10-09, **not yet confirmed in-game**: yancer-frames v0.2.0 Party/Arena frames (class icons,
  trinket cooldowns, range fade; is `[group:raid]` ok on 3.3.5?), aura timer numbers on unit frames and
  Blizzard buffs, yancer-minimap (round/square, zone text, clock, info text, right-click tracking menu),
  quest windows skin (backdrop insets in `yancer-quests/Skin.lua` are guesses), yancer-bags, druid Prowl page.
- The user has XPerl and Gladdy installed: they overlap our Party/Arena frames. They have !BugGrabber
  without BugSack, so Lua errors are hidden: ask them to `/console scriptErrors 1`.
- `/yplates` prints nameplate debuff debug info.
- Ideas: map/minimap pins from the quest DB coords, quest givers, auto accept/turn-in; yancer-frames cast
  bars in the Quartz style; merged bank window, bag sorting; pet / target-of-target frames; vehicle swap
  on the player frame. Arena frames can't show the spec (no 3.3.5 API).

## Finding a lost session

Past transcripts are `~/.claude/projects/C--Users-Misha-Qadagishvili-Desktop-yancer/*.jsonl`. Grep the
`"type":"user"` messages to find the last request, then read the last assistant tool calls to see where it stopped.
