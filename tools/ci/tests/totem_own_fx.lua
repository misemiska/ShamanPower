-- client: both
-- Totem Bar (3.0.9.2): each totem's own effects from its right-click menu. Unset, a totem follows the
-- bar's own settings as they were; set, its own wins: the end cues, Expiring Soon, Out of Range.
local SP = ShamanPower
local o = SP.opt
if not (SP.TotemCueOpt and SP.TotemRangeGlow) then skip("no per-totem effects") end
local keep = { o.totemOwn, o.totemCueExpired, o.totemCueExpiring }
local EARTHBIND = 2484
o.totemOwn, o.totemCueExpired, o.totemCueExpiring = nil, false, false
check("unset: the bar's own", SP:TotemCueOpt(EARTHBIND, "totemCueExpired") == false)
check("nothing wanted with everything off", not SP:TotemCuesWanted())
o.totemOwn = { [EARTHBIND] = { totemCueExpired = true, totemCueExpiredStyle = "flash" } }
checkEq("its own wins", SP:TotemCueOpt(EARTHBIND, "totemCueExpired"), true)
checkEq("its own style", SP:TotemCueOpt(EARTHBIND, "totemCueExpiredStyle"), "flash")
check("another totem keeps the bar's", SP:TotemCueOpt(8071, "totemCueExpired") == false)
check("one totem's own switch wakes the cues", SP:TotemCuesWanted())
-- the totem by its name
local name = GetSpellInfo(EARTHBIND)
checkEq("the cues find the totem by its name", SP.CueTotemOf(1, name), EARTHBIND)
-- Out of Range: its own look and glow
o.totemOwn[EARTHBIND].totemRangeLook = "glow"
local btn = SP.totemButtons and SP.totemButtons[1]
if btn then
	SP:TotemRangeGlow(1, btn, true, EARTHBIND)
	check("its own Out of Range glow shows", btn.spRangeGlow ~= nil and btn.spRangeGlow:IsShown())
	SP:TotemRangeGlow(1, btn, false, EARTHBIND)
	check("and goes back in range", not btn.spRangeGlow:IsShown())
end
local realInfo = SP.GetElementTotemInfo
SP.GetElementTotemInfo = function(self, e) if e == 1 then return true, name, GetTime(), 45 end return realInfo(self, e) end
check("Glow alone: no gray", not SP:TotemRangeGrays(1))
o.totemOwn[EARTHBIND].totemRangeLook = "both"
check("Gray + Glow: gray", SP:TotemRangeGrays(1))
o.totemOwn[EARTHBIND].totemRangeLook = nil
check("unset: gray as always", SP:TotemRangeGrays(1))
SP.GetElementTotemInfo = realInfo
-- the Effects tab is gone: everything is in each totem's menu; its old address opens Totem Bar > Bar
local sec = SP.options.args.fluffy.args.totembar_effects_section
local a = sec.args
check("the Effects tab's options are hidden", sec.hidden == true)
local alias = SP.SettingsPathAliases and SP.SettingsPathAliases["fluffy/totembar_effects_section"]
check("its old address opens Totem Bar > Bar", alias and alias[1] == "buttons" and alias[2] == "auto_button")
-- a totem's own Effects Look and Signature Moves: its own style for the signature
o.totemOwn[EARTHBIND].totemCueLook = "elemental"
o.totemOwn[EARTHBIND].totemCueSignature = true
checkEq("its own look", SP:TotemCueOpt(EARTHBIND, "totemCueLook"), "elemental")
-- the usual-totem reminder: a temporary totem's own Test plays with its own settings, no error
o.totemOwn[8143] = { usualTotemReminder = true, usualTotemStyle = "pulse", usualTotemLabel = false }
local ok, err = pcall(SP.TestUsualTotemReminder, SP, 8143)
check("Tremor's own Test Usual Totem Reminder runs: " .. tostring(err), ok)
o.totemOwn[8143] = nil
-- Proc Glow: one more style for each totem effect, and it plays and stops
check("Proc Glow in Expired's styles", a.totemCueExpiredStyle.values.proc == "Proc Glow")
check("Proc Glow in Expiring Soon's styles", a.totemCueExpiringStyle.values.proc == "Proc Glow")
if btn and SP.CueFx then
	local ok = pcall(SP.CueFx.play, btn, "proc", "expired")
	check("Proc Glow plays once", ok)
	ok = pcall(SP.CueFx.loop, btn, "proc", "expiring")
	check("Proc Glow loops", ok and btn.spCueProcLoop == true)
	SP.CueFx.stop(btn)
	check("and stops", not btn.spCueProcLoop)
end
o.totemOwn, o.totemCueExpired, o.totemCueExpiring = keep[1], keep[2], keep[3]
finish()
