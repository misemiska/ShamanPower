-- client: both
-- TotemTimers Style, Single Totem and Dynamic (PvP) show the totem that is down on its button; the
-- button's cooldown is then that totem's, not the assigned one's (a reviewer: Stoneskin assigned,
-- Earthbind dropped from the flyout, Earthbind on the button and no cooldown; 3.0.9.2).
local SP = ShamanPower
local o = SP.opt
local EARTHBIND = 2484
local ebIdx, otherIdx
for idx = 1, 20 do
	local id = SP:GetTotemSpell(1, idx)
	if id == EARTHBIND then ebIdx = idx elseif id and not otherIdx then otherIdx = idx end
end
if not (ebIdx and otherIdx and SP.totemButtons and SP.totemButtons[1]) then skip("no Earthbind or a second Earth totem here") end

local keep = { o.activeTotemAsMain, o.activeAssignedCorner, o.dynamicTotemMode }
SP.pendingAssignments = { [1] = otherIdx }   -- assigned: not Earthbind
local realInfo, realSpell = SP.GetElementTotemInfo, SP.GetTotemSpell
local ebName = GetSpellInfo(EARTHBIND)   -- (the game names the totem that is down by its spell name)
SP.GetElementTotemInfo = function(self, element)
	if element == 1 then return true, ebName, GetTime(), 45, nil, 2 end
	return realInfo(self, element)
end
SP:GetActiveTotemIndex(1)   -- (its first lookup walks every Earth totem: kept, so a pass reads only the one it shows)
local asked
SP.GetTotemSpell = function(self, element, idx)
	if element == 1 and asked then asked[#asked + 1] = idx end
	return realSpell(self, element, idx)
end
local function askedFor()
	asked = {}
	SP:UpdateTotemCooldowns()
	local got = asked
	asked = nil
	local eb, other = false, false
	for _, idx in ipairs(got) do if idx == ebIdx then eb = true elseif idx == otherIdx then other = true end end
	return eb, other
end

for _, st in ipairs({
	{ "Single Totem", function() o.activeTotemAsMain, o.activeAssignedCorner, o.dynamicTotemMode = true, false, false end },
	{ "TotemTimers Style", function() o.activeTotemAsMain, o.activeAssignedCorner, o.dynamicTotemMode = true, nil, false end },
	{ "Dynamic (PvP)", function() o.activeTotemAsMain, o.activeAssignedCorner, o.dynamicTotemMode = false, nil, true end },
}) do
	st[2]()
	local eb, other = askedFor()
	check(st[1] .. ": the button reads Earthbind's cooldown", eb)
	check(st[1] .. ": not the assigned totem's", not other)
end
o.activeTotemAsMain, o.activeAssignedCorner, o.dynamicTotemMode = false, nil, false
local eb, other = askedFor()
check("Normal: the button keeps the assigned totem's cooldown", other and not eb)

SP.GetElementTotemInfo, SP.GetTotemSpell = realInfo, realSpell
SP.pendingAssignments = nil
o.activeTotemAsMain, o.activeAssignedCorner, o.dynamicTotemMode = keep[1], keep[2], keep[3]
finish()
