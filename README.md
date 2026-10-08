# yancer — WoW 3.3.5a AddOns

A collection of World of Warcraft **3.3.5a (build 12340)** addons for **Warmane**.

| Addon | Status | What it does |
|---|---|---|
| `yancer-bars` | v0.9.0 | Replaces Blizzard's action bars with movable, customizable bars (square icons, outlines, fading, range colouring, cooldown timers), and makes the rest of the default UI movable. |
| `yancer-chat` | v0.1.0 | Square, movable chat: class colours, short channels, timestamps, clickable URLs, copy chat, better scrolling. Needs yancer-bars. |
| `yancer-frames` | v0.2.0 | Custom Player, Target, Focus, Party and Arena frames: movable, resizable, square with outlines, class-coloured health, auras, cast bars. Needs yancer-bars. |
| `yancer-bags` | v0.1.0 | All bags in one square, searchable window with quality borders, free slots and gold. Needs yancer-bars. |
| `yancer-quests` | v0.1.0 | Movable square quest tracker (auto-collapse, coloured objectives), which mobs to kill and which mobs drop quest items (bundled quest database), square quest windows. Needs yancer-bars. |
| `yancer-plates` | v0.2.0 | Flat square nameplates: class icons, debuffs with stacks and timers, health text, cast bars, target and threat borders. Needs yancer-bars. |
| `yancer-minimap` | v0.1.0 | Movable round or square minimap with zone text and clock, plus an FPS / latency / durability text. Needs yancer-bars. |

## Conventions

- **Naming:** every addon folder and `.toc` starts with `yancer-` (`yancer-bars`, `yancer-plates`, ...).
  The folder name, `.toc` file name and AceAddon name are identical.
- **Title** in the `.toc`: `|cff33ccffyancer|r-<name>` so they group together in the addon list.
- **SavedVariables:** `yancer<Name>DB` (e.g. `yancerBarsDB`, `yancerPlatesDB`).
- **Globals:** only the addon object (e.g. `YancerBars`) and its SavedVariables. Everything else is `local`
  or lives in the private namespace: `local addonName, ns = ...`.
- **Frame names:** `yancer<Name><Thing><n>` (e.g. `yancerBarsBar1`, `yancerBarsBar1Button3`), or unnamed.
- **Interface version:** `## Interface: 30300`.
- **Style:** tabs for indentation, one feature per file, listed in load order in the `.toc`.

## Libraries

Each addon embeds the libraries it needs in its own `Libs/` folder and loads them through
`embeds.xml`. LibStub makes sure only the newest copy runs when several addons ship the same library.

- **Ace3 r969** is the official Ace3 release for 3.3.5, from wowace.com (Oct 2010).
  Do **not** swap in newer Ace3 releases. They use API that doesn't exist on this client.
- Don't copy libraries out of other installed addons without checking them. Some 3.3.5 addons
  (e.g. Gladdy) depend on the `!!!ClassicAPI` shim, and ElvUI renames its config libs to `-ElvUI` variants.

## 3.3.5a API gotchas

Code or docs written for retail or Classic often breaks here:

- No `C_*` namespaces, no `C_Timer` (use an `OnUpdate` script or AceTimer-3.0).
- No `BackdropTemplate`. `frame:SetBackdrop()` works on any frame directly.
- No `SetShown`, no `SetColorTexture` (use `SetTexture(r, g, b, a)`).
  Prefer `SetWidth`/`SetHeight` over `SetSize`.
- String helpers are globals: `strtrim`, `strsplit`, `wipe`, `tinsert`.
- `COMBAT_LOG_EVENT_UNFILTERED` args start `timestamp, event, sourceGUID, sourceName, sourceFlags,
  destGUID, destName, destFlags, ...` (no `hideCaster`, no raid flags).
- `SendAddonMessage(prefix, text, channel)` needs no prefix registration. Messages are limited to about 255 characters.
- Protected actions (casting, targeting, moving secure frames) are blocked in combat and can't be automated.
  Action buttons and their headers are secure: create, move, resize, reparent or re-attribute them
  **only out of combat**. Queue changes and apply them on `PLAYER_REGEN_ENABLED`.
- Action buttons: use Blizzard's `ActionBarButtonTemplate` with `SetID(0)` and drive the `action` attribute
  (the template's `OnAttributeChanged` refreshes the button). Paging is done with a
  `SecureHandlerStateTemplate` header, `RegisterStateDriver(header, "page", "<macro conditions>")`, and
  `control:ChildUpdate(...)`. Reference source: github.com/wowgaming/3.3.5-interface-files.
- Keybinds for custom buttons: `CLICK <ButtonName>:LeftButton` entries in `Bindings.xml`, with labels in
  `BINDING_HEADER_*` / `BINDING_NAME_*` globals. A new or changed `Bindings.xml` needs a client restart.
- Textures must be power-of-two sized `.tga` (32-bit, uncompressed) or `.blp`, referenced without the extension.
- References: the WoWWiki archive and the wowprogramming.com archive, filtered to patch 3.3.
  warcraft.wiki.gg is the current wiki, so check each page's patch history.

## Project layout

```
yancer/
├─ yancer-bars/          addon (junctioned into the game's AddOns folder)
│  ├─ yancer-bars.toc
│  ├─ embeds.xml         loads Libs/
│  ├─ Bindings.xml       keybind entries (auto-loaded by the client)
│  ├─ Libs/              Ace3 r969 subset
│  ├─ Media/             textures
│  └─ *.lua
├─ yancer-chat/          module addon: Core, Style, Messages, Copy, Options (no Libs/)
├─ yancer-frames/        module addon: Core, Frames, Auras, CastBar, Options (no Libs/)
├─ yancer-bags/          module addon: Core, Bags, Hooks, Options (no Libs/)
├─ yancer-minimap/       module addon: Core, Minimap, InfoText, Options
├─ yancer-plates/        module addon: Core, Plates, Options
├─ yancer-quests/        module addon: Data/QuestDB (generated), Core, Tracker, QuestInfo, Skin, Options
├─ tools/
│  ├─ link.ps1           junction every yancer-* folder into WoW's AddOns
│  ├─ lint.ps1           luacheck every yancer-* addon
│  ├─ luacheck.exe       luacheck 1.2.0 (auto-downloaded, not committed)
│  ├─ gen_shadow.py      regenerates yancer-bars/Media/Shadow.tga
│  └─ gen_questdb.py     regenerates yancer-quests/Data/QuestDB.lua from pfQuest-wotlk
├─ .luacheckrc           lint config (Lua 5.1 + allowed WoW globals)
└─ .luarc.json           Lua language server config (VS Code "Lua" extension)
```

## Workflow

1. **Link (once per new addon):** `.\tools\link.ps1`. This creates a junction at
   `D:\World of Warcraft 3.3.5a\Interface\AddOns\yancer-*` pointing at this folder.
   Deleting the junction in the game folder does not delete the source.
2. **Edit** the code here.
3. **Lint:** `.\tools\lint.ps1`. Fix every warning. When you start using a new WoW API function,
   add it to `read_globals` in `.luacheckrc` **and** `diagnostics.globals` in `.luarc.json`.
4. **Test in-game:** `/reload`. Show Lua errors with `/console scriptErrors 1`.
   A new file listed in a `.toc`, or a new `.toc`, needs a full client restart, not just `/reload`.
5. **Debug:** `/run print(YancerBars.db.profile.locked)`, `/dump <expr>` (Blizzard_DebugTools),
   `/framestack` to inspect frames under the mouse.

## yancer-bars

- `/yb` (or `/yancerbars`) opens the settings (also in Interface → AddOns → yancer-bars).
- `/yb move` toggles moving mode: drag the blue overlays, or right-click one to open that bar's settings.
  `/yb lock` and `/yb unlock` set it directly. Bars lock automatically when you enter combat.
- **Action bars:** up to 10 bars with 1–12 real action buttons each. Each bar shows one action page
  (12 slots). The defaults recreate Blizzard's five bars in the same slots:

  | Bar | Page | Blizzard bar |
  |---|---|---|
  | Main Bar | 1 (with paging) | main bar |
  | Bottom Left Bar | 6 | bottom left |
  | Bottom Right Bar | 5 | bottom right |
  | Right Bar | 3 | right |
  | Right Bar 2 | 4 | right 2 |

  Shortly after the first login, each of these stays shown if it was enabled in Blizzard's Interface
  options or already holds spells, and is switched off otherwise. **Restore Blizzard Bars** (General)
  recreates any that were deleted. A **New Bar** gets an unused page and appears mid-screen.
- **Main Bar Paging:** switches pages like Blizzard's main bar (stances, forms, stealth, possess,
  Shift+1–6, Shift+wheel). For rogues, **Shadow Dance as Stealth** (on by default) also shows the
  Stealth page during Shadow Dance. For druids, **Prowl Page** (on by default) gives Prowl in Cat Form
  its own page (8, Tree of Life's page, which a feral spec doesn't use), so Cat Form has three states:
  normal, Cat and Prowl.
- **Hide Blizzard Action Bars** (on by default) hides the default buttons, the side and bottom bars, and the
  bar art. The XP bar, bags, micro menu, and stance and pet bars stay. The default keybinds (1–=, bottom
  and side bar binds) are redirected with override bindings to our buttons on the same page, so they
  click our buttons directly, and their keys are shown on those buttons. Turning it off needs a `/reload`.
- **Keybinds:** Esc → Key Bindings → "yancer-bars Bar N". These take priority over the Blizzard binds in the
  button labels.
- **All Bars** (top of `/yb` → Bars) changes every bar at once. It shows the Main Bar's values.
- **Per-bar settings** (tabs in `/yb` → Bars):
  - **General:** name, enabled, action page, main-bar paging, show empty buttons.
  - **Layout:** buttons, buttons per row, button order (left to right or right to left), rows grow up
    or down, button size, spacing, padding,
    position, strata, level.
  - **Visibility:** always / in combat only / custom macro conditions (e.g. `[combat][harm] show; hide`),
    hide in vehicle, opacity, fade unless mouseover (faded bars return while moving bars or holding
    a spell on the cursor).
  - **Appearance:** outline style (solid outline or soft shadow); bar background, border and outline;
    button background, border and outline.
  - **Text:** keybinds, macro names, stack count sizes, range dot, cooldown timers.
- **Range & mana coloring:** icons tint red out of range, blue without mana, grey when unusable.
- **Cooldown timers:** cooldowns shorter than the minimum (default 2s, which hides the GCD) get no timer.
  OmniCC is told to skip our buttons while timers are on.
- **Moving:** a grid shows while unlocked (red centre lines), and dropped bars snap their centre to it.
  Both are optional, and the grid size is adjustable.
- **Button style:** Square (no Blizzard frame, icons cropped by **Icon Zoom** to remove the rounded corners, flat
  hover/pressed/active/auto-attack overlays, equipped items get a green border) or Blizzard default.
  Blizzard re-applies its rounded slot art on every button update, so the Square style strips it again
  in a hook on `ActionButton_Update`.
- **UI Elements** (`/yb` → UI Elements): moves Blizzard's other pieces: XP bar, reputation bar, buffs,
  debuffs, stance bar (rogues: Stealth / Shadow Dance), pet bar, possess bar, totem bar, micro menu
  (Character, Spellbook, …), bags and cast bar. Each is dragged in `/yb move` like the bars
  (right-click opens its settings) and has its own scale and **Reset Position**. Blizzard keeps
  re-anchoring several of these (the frame position manager, vehicles, reputation updates, the
  pet bar slide-in), so after any Blizzard `SetPoint` on them yancer-bars puts them back. The stance,
  pet, possess and totem bars hold secure buttons and are only re-placed out of combat.
  Turning an element off leaves it where it is until `/reload`.
- **Square style for UI elements** (`/yb` → UI Elements → Style, on by default): stance, pet, possess and
  totem buttons, bags, the micro menu, buffs/debuffs (debuff type colour on the border) get square cropped icons and flat
  highlights; the XP, reputation and cast bars become flat bars with a border. All share one outline
  (style, size, colour). The totem slot buttons and keyring keep Blizzard's art. Undoing it needs
  a `/reload`.
- **Player cast bar** (Square style): the spell icon on its left. Smooth fill computed from the cast's real
  start/end time every frame, with a soft spark on its edge. Blizzard's flash art no longer shows when a
  cast ends. Channelled spells (Mind Flay, Mind Sear, Penance, Drain Soul/Life/Mana, Health Funnel, Hellfire,
  Rain of Fire, Arcane Missiles, Blizzard, Evocation, Hurricane, Tranquility, Volley, Divine Hymn, Hymn of
  Hope) get dark tick marks and a ticks-left counter on the right. Pushback shows in red on the left:
  `+0.5s` when a cast is delayed, `-0.8s` when a channel is cut short.
- **Profiles:** per-character by default. Copy, reset or share them through the Profiles tab.
- **Reusable API for other yancer addons:** `YancerBars:CreateShadow(frame)`,
  `YancerBars:UpdateShadow(frame, size, {r,g,b,a})`, `YancerBars:CreateMover(frame, label, onMoved)`.
- **Other bar addons:** bar addons like Dominos use the same action slots, so they show the same
  spells. Disable Dominos if you only want yancer-bars.

## yancer-chat

Needs yancer-bars (its settings live in `/yb` → Chat, and it uses the same movers and outline).

- **Look & Position:** square style (flat background with the shared outline, no Blizzard frame art or
  tab art, square input box), background opacity, hide the scroll/menu/friends buttons, input box above
  or below the chat. The main chat window (and the windows docked to it) is placed with `/yb move`
  and sized with Width/Height; Blizzard's tab dragging is locked while yancer-chat manages it.
- **Messages:** class-coloured names in every chat type, short channel names (`[G]`, `[P]`, `[RW]`,
  `[2]` …), timestamps, clickable URLs (click to get the link ready to copy), and a **C** button on each
  window that opens its last 300 lines as copyable text.
- **Scrolling & fading:** wheel scrolls N lines, Shift+wheel jumps to top/bottom, Ctrl+wheel scrolls a
  page; history length; fading on/off and how long lines stay.
- Turning off the square style or showing the buttons again needs a `/reload`.

## yancer-frames

Needs yancer-bars (its settings live in `/yb` → Unit Frames, and it uses the same movers and outline).

- Replaces Blizzard's Player, Target and Focus frames (plus combo points and the target-of-target frames)
  with square frames: health and power bars, name and level, a 3D or 2D portrait on either side.
  Left-click targets, right-click opens Blizzard's unit menu. Works with Clique.
- **Per unit** (a tab each): enabled, width, health/power height, scale; class-coloured health for
  players and reaction colours for NPCs (or a fixed colour); health text (current, percent, both,
  missing) and power text; portrait style and side; name, level, **Horde / Alliance (PvP) icon**,
  raid mark and party leader icons (player: combat/resting icon); auras above the frame (size, count,
  only my debuffs); a cast bar below it; combo points on the target. **Reset Position** puts it back.
- Placed with `/yb move`. While unlocked every frame shows, with sample values when the unit doesn't exist.
- The pet frame, death knight runes and shaman totem timers stay, below the Player frame.
- **Party** (party1-4) and **Arena** (arena1-5) frames: one tab and one mover per group, the members
  stacked with adjustable spacing. Party frames: right-click menu, hide in raids, fade out of range
  (about 40 yards). Arena frames: class icon, cast bar, the enemy's PvP trinket with its 2 minute
  cooldown. Left-click targets, right-click focuses. Turn Arena off if you use Gladdy.
- Portraits can also be a **class icon**.
- Turning a frame off needs a `/reload` to get Blizzard's back.

## yancer-bags

Needs yancer-bars (its settings live in `/yb` → Bags, and it uses the same movers and outline).

- The backpack and the four bags in **one window**: square slots, quality-coloured borders (quest items
  yellow), stack counts, cooldowns, free slots (general bags only) and gold. A search box dims items
  whose name doesn't match.
- Blizzard's bag functions are replaced for bags 0–4, so B, Shift+B, the bag keybinds, the bag bar
  buttons, merchants, mail and Escape all use it. The **bank bags and keyring keep Blizzard's windows**.
- Items work like Blizzard's (the slots are `ContainerFrameItemButtonTemplate` buttons in holder frames
  whose ID is the bag): click, drag, sell, split stacks, link, socket.
- Settings: columns, slot size, spacing, scale, background opacity, quality borders, Reset Position.
  Placed with `/yb move` (the bag opens while unlocked). Turning **One Bag** off needs a `/reload`.

## yancer-quests

Needs yancer-bars (its settings live in `/yb` → Quests, and it uses the same movers and outline).

- **Tracker:** Blizzard's objective tracker, restyled rather than replaced (quest item buttons, clicks
  and the right-click menu keep working). Placed with `/yb move`. Width, height, scale, font size and
  background opacity are adjustable. The background only shows behind the collapsed header, and the collapse button is a flat +/-.
  Quest titles are in their difficulty colour with a level tag (`[12]`, `[12+]` elite/group, `[12D]`
  dungeon, `[12R]` raid, `[12H]` heroic, `Y` daily). Objectives go red → yellow → green with progress.
  **Collapse automatically** in combat, dungeons, raids and battlegrounds/arenas (your own click wins).
- **Quest info:** which mobs to kill and which mobs or objects drop each quest item, for the quests in
  your log. Hovering a mob shows the quests it counts for, your progress and its drop chance. Hovering a
  chest or plant shows what it's needed for. Hovering a quest in the tracker lists `Kill:` (with zone),
  `Drops from:` (with drop chance), `Found in:` and `Use:` for each objective.
- The data is `Data/QuestDB.lua` (about 5,500 quests, 600 KB), generated by `python -I tools/gen_questdb.py`
  from [pfQuest-wotlk](https://github.com/Sattva-108/pfQuest-wotlk) (MIT, see `LICENSE-pfQuest.txt`).
  Mobs and objects are matched by name, so it also works where a server's NPC ids differ.
- **Windows:** square quest log, NPC quest dialog and gossip window with light text.
- Turning off the tracker style or the window style needs a `/reload`.

## yancer-plates

Needs yancer-bars (its settings live in `/yb` → Nameplates).

- Restyles Blizzard's nameplates (V / Shift+V): flat health and cast bars with a square border and the
  shared outline. The name is above the bar, the level right of it, and the spell icon left of the cast bar.
  Casts that can't be interrupted are grey.
- **Class icons** above player nameplates: group members by name, enemies from their class colour
  (needs **Class-Colored Enemies**, Blizzard's setting, which this turns on).
- **Debuffs** above the name: wide cropped icons with the stack count, soonest to expire first. Only yours by
  default, with the time left on every plate (red under 3 seconds), also after you switch targets. 3.3.5 plates don't say
  which unit they are, so a plate learns it when it is your target or under the mouse (players also by
  name from the combat log). Your own debuffs are then followed through the combat log.
  `/yplates` prints what it knows about your target's plate (for bug reports).
- Health text (percent or current), a white border on your target, the border in the threat colour
  instead of Blizzard's glow.
- 3.3.5 has no nameplate API: plates are found as WorldFrame children with the nameplate border texture.
  Turning it off needs a `/reload`.

## yancer-minimap

Needs yancer-bars (its settings live in `/yb` → Minimap).

- **Minimap:** placed with `/yb move`. Round or square (square gets the shared outline), with adjustable size and scale.
  The zone name sits above it in its PvP colour (red hostile/arena, green friendly, orange contested,
  blue sanctuary). A clock sits at the bottom (local or server time, click for the calendar). The mouse wheel zooms.
  The zoom, world map and calendar buttons are hidden. Tracking, mail, battleground/LFG and dungeon
  difficulty sit on the map's corners. Minimap button addons are told the shape (`GetMinimapShape`).
- **Info text:** `FPS: 60   MS: 26   Dur: 94%`, coloured green / yellow / red, placed with `/yb move`.
  Hover for the top addons by memory, bandwidth and latency. Click to free unused memory.
- Turning off the minimap style, the info text or Hide Buttons needs a `/reload`.

## Module API (yancer-bars)

Other yancer addons declare `## Dependencies: yancer-bars` and get the addon with
`LibStub("AceAddon-3.0"):GetAddon("yancer-bars")`. They use the libraries yancer-bars loads, so they
need no `Libs/` folder.

- `YB:CreateMover(frame, label, onMoved, onRightClick)`: drag in `/yb move`, grid snapping, combat lock.
- `YB:Outline(frame)`: the shared outline (UI Elements → Style), kept in sync when it changes.
- `YB:SquareBackdrop(frame, bgAlpha)`, `YB:UpdateShadow(frame, size, color, style)`.
- `YB:RegisterModuleOptions(key, group)`: adds a top-level AceConfig group (order 10–99) to `/yb`.
  `YB:OpenOptions(key, ...)` opens it, `YB:NotifyOptionsChanged()` redraws it.
