-- client: both
-- Grounding Totem puts an aura on everyone in its range (8178, measured on WoW: Forever 10-21), so
-- there it is tracked like Strength of Earth: the bar's Out of Range look, the Totem Range Tracker,
-- the dots, counters, Party Coverage and the Party Strip. Never Raid Coverage: it only reaches your
-- party. TBC Anniversary shows its hits already: not tracked there.
local SP = ShamanPower
local o = SP.opt
local W = __sim.W
if not SPCompat.FOREVER then
	check("Anniversary: not in the party buff list", SP.TotemBuffSpellIDs[4][5] == nil)
	check("Anniversary: not on the Totem Range Tracker", not (SP.TrackableTotemsByID and SP.TrackableTotemsByID.grounding))
	finish()
	return
end
checkEq("in the party buff list", SP.TotemBuffSpellIDs[4][5], 8178)
check("its aura's ranks", SP.TotemBuffRanks[8178] and SP.TotemBuffRanks[8178][1] == 8178)
local buffName = SPCompat.SpellName(8178)
check("its aura's name", type(buffName) == "string" and buffName ~= "")
checkEq("its name for the buff reads", SP.TotemBuffNames[4][5], buffName)
local tr = SP.TrackableTotemsByID and SP.TrackableTotemsByID.grounding
check("on the Totem Range Tracker", tr ~= nil and tr.element == 4 and tr.index == 5 and tr.buffSpellID == 8178)
check("watched by Party Coverage like the others", SP.CoverageWatches and SP:CoverageWatches(4, 5))
if SP.RAID_COVERAGE_TOTEMS then
	local raid = false
	for _, t in ipairs(SP.RAID_COVERAGE_TOTEMS) do if t[1] == 4 and t[2] == 5 then raid = true end end
	check("not on Raid Coverage (a party aura)", not raid)
end

-- the bar: in range while its aura is on you, Out of Range (gray and glow, its own look) when it is not
local keep = { o.totemOwn }
local realInfo, realUB, realUnread, realPos = SP.GetElementTotemInfo, SPCompat.UnitBuff, SPCompat.AurasUnreadable, UnitPosition
local name = GetSpellInfo(8177)
local t0 = GetTime()
SP.GetElementTotemInfo = function(self, e) if e == 4 then return true, name, t0, 45, nil, 4 end return false end
local onMe, fight, px = true, false, 0
SPCompat.UnitBuff = function(unit, i) if not fight and onMe and i == 1 then return buffName end return nil end
SPCompat.AurasUnreadable = function() return fight end
UnitPosition = function() return 0, px, 0, 0 end
SP.totemBuffCache[4] = nil
SP:InvalidateTotemInfo()
checkEq("the bar knows its buff", SP:GetActiveTotemBuffName(4), buffName)
o.totemOwn = { [8177] = { totemRangeLook = "both" } }
-- the active totem shows on the button or on its overlay (the assigned Air totem is another one)
local function icon()
	local ov = SP.activeTotemOverlays and SP.activeTotemOverlays[4]
	if ov and ov.isActive and ov.icon and not o.activeTotemAsMain then return ov.icon end
	return SP.totemButtons[4] and SP.totemButtons[4].icon
end
-- the bar reuses its buff scan until an aura event says the list changed (as in the game)
local function pass() W.fireEvent("UNIT_AURA", "player", { isFullUpdate = true }); SP:UpdatePlayerTotemRange() end
local function glowing() local g = SP.totemRangeGlows and SP.totemRangeGlows[4] return g ~= nil and g.on == true end
pass()
check("its aura on you: in range", SP.totemRangeResults[4] == true)
check("in range: no gray, no glow", icon() and not icon():IsDesaturated() and not glowing())
onMe = false
pass()
check("no aura on you: out of range", SP.totemRangeResults[4] == false)
check("out of range: its own look, gray and the glow", icon() and icon():IsDesaturated() and glowing())
onMe = true
pass()
check("back in range: both go", icon() and not icon():IsDesaturated() and not glowing())

-- in a fight (auras hidden): distance from where it went down, like every other totem
SP:RecordTotemDrop(4)
fight = true
px = 5; SP:UpdatePlayerTotemRange()
local near = SP.totemRangeResults[4]
px = 60; SP:UpdatePlayerTotemRange()
local far = SP.totemRangeResults[4]
check("in a fight: in range by its drop spot", near == true)
check("in a fight: out of range 60 yards away", far == false)
check("the tracker agrees in a fight", tr and SP:SPRangeOwnTotemInRange(tr) == false)
fight, px = false, 0

SP.GetElementTotemInfo, SPCompat.UnitBuff, SPCompat.AurasUnreadable, UnitPosition = realInfo, realUB, realUnread, realPos
o.totemOwn = keep[1]
SP.totemBuffCache[4] = nil
SP:InvalidateTotemInfo()
SP:UpdatePlayerTotemRange()
finish()
