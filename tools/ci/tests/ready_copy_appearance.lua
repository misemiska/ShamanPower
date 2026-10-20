-- client: both
-- Ready Reminders > Appearance (3.0.9.2): Copy Appearance To... one icon you pick, and Copy
-- Appearance To This Row (Rows placement), beside Copy Appearance To All Icons.
local SP = ShamanPower
local Row = SP.ReadyIconsRow
if not (Row and Row.def and Row.def.menu) then skip("no Spells row") end
local function sub(items, text)
	for _, it in ipairs(items or {}) do if it.text == text and not it.label then return it end end
end
SP:ReadyReminderSetIconOpt("earthshock", "iconSize", 61)
SP:ReadyReminderSetIconOpt("earthshock", "opacity", 0.7)
SP:ReadyReminderSetIconOpt("earthshock", "soundOnReady", true)   -- (not appearance: never copied)
local app = sub(Row.def.menu({ key = "earthshock" }), "Appearance")
local rows = app and app.sub()
check("Appearance: Copy Appearance To All Icons", sub(rows, "Copy Appearance To All Icons") ~= nil)
local pick = sub(rows, "Copy Appearance To...")
check("Appearance: Copy Appearance To...", pick ~= nil and not pick.disabled)
local target = pick and sub(pick.sub(), "Flame Shock")
check("Copy Appearance To... lists Flame Shock", target ~= nil)
if target then target.onClick() end
checkEq("Flame Shock took the size", SP:ReadyReminderOwnOpt("flameshock", "iconSize"), 61)
checkEq("Flame Shock took the opacity", SP:ReadyReminderOwnOpt("flameshock", "opacity"), 0.7)
check("not the sound (not appearance)", SP:ReadyReminderOwnOpt("flameshock", "soundOnReady") == nil)
check("Frost Shock untouched", SP:ReadyReminderOwnOpt("frostshock", "iconSize") == nil)
check("no To This Row outside Rows placement", sub(rows, "Copy Appearance To This Row") == nil)
for _, k in ipairs({ "earthshock", "flameshock" }) do SP:ReadyReminderResetIcon(k) end
finish()
