-- client: both
-- Ready Reminders: When Out of Mana (3.0.9.2). While you can't afford the spell the icon takes the
-- Out of Mana Color and plays its own effect; with the mana back both go. Off to start; the menu group
-- sits under Effects & Sound; the colors are theme colors.
local SP = ShamanPower
local W = __sim.W
local f = SP.readyReminderFrames and nil
local realUsable = C_Spell.IsSpellUsable
local noMana = false
C_Spell.IsSpellUsable = function() return not noMana, noMana end

check("off to start", SP:ReadyReminderIconOpt("earthshock", "oomTint") ~= true and (SP:ReadyReminderIconOpt("earthshock", "oomEffect") or "none") == "none")
SP:ReadyReminderSetSpell("earthshock", true)
SP:ReadyReminderSetShow("earthshock", "always_bright")
SP:ReadyReminderSetIconOpt("earthshock", "oomTint", true)
SP:ReadyReminderSetIconOpt("earthshock", "oomEffect", "glow")
SP:UpdateReadyReminders(); __sim.advance(0.2)
f = SP.readyReminderFrames and SP.readyReminderFrames.earthshock
if not (f and f:IsShown()) then skip("Earth Shock's icon not on screen here") end
local function blue()
	local r, g, b = f.icon:GetVertexColor()
	return r and math.abs(r - 0.45) < 0.02 and math.abs(g - 0.45) < 0.02 and math.abs(b - 1) < 0.02
end
check("with the mana: no tint", not blue())
check("with the mana: no effect", not (f.oomFx and f.oomFx:IsShown()))
noMana = true
W.fireEvent("SPELL_UPDATE_USABLE"); __sim.advance(0.1)
check("out of mana: the icon is the out-of-mana blue", blue())
check("out of mana: the effect shows", f.oomFx ~= nil and f.oomFx:IsShown())
SP:ReadyReminderSetIconOpt("earthshock", "oomColor", { r = 1, g = 0, b = 0 })
SP:UpdateReadyReminders(); __sim.advance(0.1)
local r, g, b = f.icon:GetVertexColor()
check("its own color", r and r > 0.95 and g < 0.05 and b < 0.05)
noMana = false
W.fireEvent("SPELL_UPDATE_USABLE"); __sim.advance(0.1)
r, g, b = f.icon:GetVertexColor()
check("the mana back: white again", r and r > 0.95 and g > 0.95 and b > 0.95)
check("the mana back: the effect goes", not f.oomFx:IsShown())

-- Combined Shocks' split picture: its slices take the tint too
SP:ReadyReminderSetSpell("shocks", true)
if SP.ReadyReminderSetShockOpt then SP:ReadyReminderSetShockOpt("shockIcon", "split") end
SP:ReadyReminderSetShow("shocks", "always_bright")
SP:ReadyReminderSetIconOpt("shocks", "oomTint", true)
SP:UpdateAllReadyReminderAppearance(); SP:UpdateReadyReminders(); __sim.advance(0.2)
local sf = SP.readyReminderFrames and SP.readyReminderFrames.shocks
local slice = sf and sf.slices and sf.slices[2]
if slice and slice:IsShown() then
	noMana = true
	W.fireEvent("SPELL_UPDATE_USABLE"); __sim.advance(0.1)
	local sr, sg, sb = slice:GetVertexColor()
	check("Combined Shocks: its slices turn blue too", sr and math.abs(sr - 0.45) < 0.02 and math.abs(sb - 1) < 0.02)
	noMana = false
	W.fireEvent("SPELL_UPDATE_USABLE"); __sim.advance(0.1)
	sr = slice:GetVertexColor()
	check("Combined Shocks: and back", sr and sr > 0.95)
else
	skip("no split Combined Shocks here")
end
SP:ReadyReminderResetIcon("shocks")
SP:ReadyReminderSetSpell("shocks", false)

-- the menu
local Row = SP.ReadyIconsRow
if Row then
	local grp
	for _, it in ipairs(Row.def.menu({ key = "earthshock" })) do if it.text == "When Out of Mana" and it.sub then grp = it end end
	check("menu: When Out of Mana", grp ~= nil)
	local rows = grp and grp.sub() or {}
	local names = {}
	for _, it in ipairs(rows) do if it.text then names[it.text] = true end end
	check("its rows: tint, color, effect, glow shape, glow color, copy",
		names["Tint The Icon"] and names["Out of Mana Color"] and names.Effect and names["Glow Shape"] and names["Glow Color"]
		and names["Copy Out of Mana Effects To All Icons"])
	local none
	for _, it in ipairs(Row.def.menu({ key = "weaponset" })) do if it.text == "When Out of Mana" then none = it end end
	check("no When Out of Mana on Weapon Set", none == nil)
end
-- themes: the colors are theme spots
local ok = false
if SP.ThemeFlatSnapshot then
	local snap = SP:ThemeFlatSnapshot()
	if type(snap) == "table" then
		for k in pairs(snap) do if tostring(k):find("oomColor", 1, true) then ok = true break end end
	end
end
check("the out-of-mana colors are in the themes", ok)

SP:ReadyReminderResetIcon("earthshock")
SP:ReadyReminderSetSpell("earthshock", false)
SP:UpdateReadyReminders()
C_Spell.IsSpellUsable = realUsable
finish()
