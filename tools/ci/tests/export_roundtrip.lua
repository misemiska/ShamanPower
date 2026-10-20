-- client: both
-- Export This Profile carries everything (beta ends 2026-10-21; players save their setup as a code):
-- the whole profile and every module table, this release's new settings included, survive an
-- export, a wipe and an import exactly.
local SP = ShamanPower
local o = SP.opt
-- 3.0.9.2's own settings, in every kind of place they live
o.totemOwn = { [5730] = { totemCueExpired = true, totemCueExpiredStyle = "proc", totemRangeLook = "both" } }
o.rangeTracker = o.rangeTracker or {}
o.rangeTracker.icons = { soe = { iconSize = 50, oorGlowShape = "proc" } }
o.unlockGridSnap, o.unlockSnap = true, false
o.totemBarPadding = 7
if SP.ReadyReminderSetIconOpt then
	SP:ReadyReminderSetIconOpt("earthshock", "oomTint", true)
	SP:ReadyReminderSetIconOpt("earthshock", "oomColor", { r = 1, g = 0, b = 0 })
	SP:ReadyReminderSetIconOpt("earthshock", "buffTimeSize", 18)
end
if type(ShamanPower_ReadyReminders) == "table" then ShamanPower_ReadyReminders.ownOff = { maelstrom = true } end

local function snap(t, seen)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do if type(v) ~= "function" then out[k] = snap(v) end end
	return out
end
local NAMES = { "ShamanPower_RangeTracker", "ShamanPower_ReactiveTotems", "ShamanPowerTremorReminderDB", "ShamanPower_TotemLoadouts",
	"ShamanPower_ESTracker", "ShamanPowerExpiringAlertsDB", "ShamanPower_ReadyReminders", "ShamanPower_TargetTracker",
	"ShamanPower_RaidCooldowns", "ShamanPower_Assignments", "ShamanPower_EarthShieldAssignments", "ShamanPower_TwistAssignments" }
local before = { profile = snap(SP.db.profile), extras = {} }
for _, n in ipairs(NAMES) do before.extras[n] = snap(_G[n]) end

local code = SP:EncodeShare(SP:BuildSharePayload({ includeExtras = true }))
check("an export code is made", type(code) == "string" and #code > 100, code and #code)

-- everything changes after the export
o.totemOwn, o.rangeTracker.icons, o.unlockGridSnap, o.totemBarPadding = nil, nil, nil, 2
if type(ShamanPower_ReadyReminders) == "table" then ShamanPower_ReadyReminders.icons = {}; ShamanPower_ReadyReminders.ownOff = nil end

local ok, err = SP:ImportShare(code, "overwrite")
check("the import takes it: " .. tostring(err), ok ~= nil)

-- every setting that was saved before the export is back, exactly
local missing, firstMiss = 0, nil
local function same(a, b, path)
	if type(a) == "table" then
		if type(b) ~= "table" then missing = missing + 1; firstMiss = firstMiss or path; return end
		for k, v in pairs(a) do same(v, b[k], path .. "." .. tostring(k)) end
	elseif a ~= b then
		missing = missing + 1; firstMiss = firstMiss or (path .. " = " .. tostring(a) .. " (now " .. tostring(b) .. ")")
	end
end
same(before.profile, SP.db.profile, "profile")
for _, n in ipairs(NAMES) do if before.extras[n] ~= nil then same(before.extras[n], _G[n], n) end end
checkEq("every saved setting came back", missing, 0, firstMiss)
checkEq("a totem's own effects", SP.opt.totemOwn and SP.opt.totemOwn[5730] and SP.opt.totemOwn[5730].totemCueExpiredStyle, "proc")
checkEq("a Range Tracker icon's own look", SP.opt.rangeTracker.icons and SP.opt.rangeTracker.icons.soe and SP.opt.rangeTracker.icons.soe.iconSize, 50)
checkEq("Snap to Grid", SP.opt.unlockGridSnap, true)
if SP.ReadyReminderOwnOpt then
	check("a reminder's When Out of Mana", SP:ReadyReminderOwnOpt("earthshock", "oomTint") == true)
	checkEq("a reminder's Time Left Size", SP:ReadyReminderOwnOpt("earthshock", "buffTimeSize"), 18)
	check("Maelstrom off its own spot", ShamanPower_ReadyReminders.ownOff and ShamanPower_ReadyReminders.ownOff.maelstrom == true)
end
finish()
