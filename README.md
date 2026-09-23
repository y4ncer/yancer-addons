# yancer — WoW 3.3.5a AddOns

A collection of World of Warcraft **3.3.5a (build 12340)** addons for **Warmane**.

| Addon | Status | What it does |
|---|---|---|
| `yancer-ui` | v0.2.0 | Movable, customizable action bars with soft shadows. Base for the rest of the suite. |

## Conventions

- **Naming:** every addon folder and `.toc` starts with `yancer-` (`yancer-ui`, `yancer-plates`, ...).
  The folder name, `.toc` file name and AceAddon name are identical.
- **Title** in the `.toc`: `|cff33ccffyancer|r-<name>` so they group together in the addon list.
- **SavedVariables:** `yancer<Name>DB` (e.g. `yancerUIDB`, `yancerPlatesDB`).
- **Globals:** only the addon object (e.g. `YancerUI`) and its SavedVariables. Everything else is `local`
  or lives in the private namespace: `local addonName, ns = ...`.
- **Frame names:** `yancer<Name><Thing><n>` (e.g. `yancerUIBar1`, `yancerUIBar1Button3`), or unnamed.
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
├─ yancer-ui/            addon (junctioned into the game's AddOns folder)
│  ├─ yancer-ui.toc
│  ├─ embeds.xml         loads Libs/
│  ├─ Bindings.xml       keybind entries (auto-loaded by the client)
│  ├─ Libs/              Ace3 r969 subset
│  ├─ Media/             textures
│  └─ *.lua
├─ tools/
│  ├─ link.ps1           junction every yancer-* folder into WoW's AddOns
│  ├─ lint.ps1           luacheck every yancer-* addon
│  ├─ luacheck.exe       luacheck 1.2.0 (auto-downloaded, not committed)
│  └─ gen_shadow.py      regenerates yancer-ui/Media/Shadow.tga
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
5. **Debug:** `/run print(YancerUI.db.profile.locked)`, `/dump <expr>` (Blizzard_DebugTools),
   `/framestack` to inspect frames under the mouse.

## yancer-ui

- `/yui` or `/yancer` opens the options (also in Interface → AddOns → yancer-ui).
- `/yui move` toggles moving mode (drag the blue overlays). `/yui lock` and `/yui unlock` set it directly.
  Bars lock automatically when you enter combat.
- **Action bars:** up to 10 bars with 1–12 real action buttons each. Each bar shows one action page
  (12 slots). The defaults are Main Bar = page 1, Bar 2 = page 6 (Blizzard's bottom-left bar),
  Bar 3 = page 5 (bottom-right).
- **Main Bar Paging:** switches pages like Blizzard's main bar (stances, forms, stealth, possess,
  Shift+1–6, Shift+wheel).
- **Keybinds:** Esc → Key Bindings → "yancer-ui Bar N".
- **Per-bar settings:** buttons, buttons per row, button size, spacing, padding, position, strata,
  background, border, bar shadow and button shadows, show empty buttons, hide in vehicle.
- **Button style:** Clean (square icons, thin border) or Blizzard default.
- **Profiles:** per-character by default. Copy, reset or share them through the Profiles tab.
- **Reusable API for other yancer addons:** `YancerUI:CreateShadow(frame)`,
  `YancerUI:UpdateShadow(frame, size, {r,g,b,a})`, `YancerUI:CreateMover(frame, label, onMoved)`.
- **Other bar addons:** Blizzard's bars and bar addons like Dominos use the same action slots, so
  they show the same spells. Disable Dominos if you only want yancer-ui bars.
