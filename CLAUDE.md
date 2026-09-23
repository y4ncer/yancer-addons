@README.md

- The target is the WoW 3.3.5a client (Lua 5.1, Interface 30300). Check every API call against the 3.3.5 API, not retail or Classic.
- The game can't be run from here. After changes, run `.\tools\lint.ps1` (it must be clean) and then ask the user to `/reload` and report any errors.
- The WoW install is `D:\World of Warcraft 3.3.5a`. Addons are junctioned in with `.\tools\link.ps1`.
