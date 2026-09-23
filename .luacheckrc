-- luacheck config for all yancer-* addons (WoW 3.3.5a, Lua 5.1).
-- Run with: .\tools\lint.ps1
std = "lua51"
max_line_length = false
unused_args = false

exclude_files = {
	"**/Libs/**",
	"tools/**",
}

-- Globals our addons are allowed to create.
globals = {
	"YancerUI",
	"yancerUIDB",
}

-- WoW 3.3.5a API used by our code. Add to this list as new API is used;
-- anything missing is reported as an undefined global, which catches typos.
-- Keep diagnostics.globals in .luarc.json in sync.
read_globals = {
	"LibStub",
	"CreateFrame",
	"UIParent",
	"GameTooltip",
	"wipe",
	"strtrim",
	"strsplit",
	"format",
	"tinsert",
	"tremove",
	"InCombatLockdown",
	"GetTime",
	"UnitName",
	"UnitClass",
}
