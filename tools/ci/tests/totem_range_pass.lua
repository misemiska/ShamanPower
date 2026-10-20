-- client: both
-- The totem bar's own Out of Range look updates on its own pass, with party dots, range counters
-- and coverage all off (their pass stops then; the bar's gray rode on it and never came: 3.0.9.2).
local SP = ShamanPower
local W = __sim.W
local o = SP.opt
local keep = { o.showPartyRangeDots, o.rangeCounter and o.rangeCounter.enabled, o.coverage and o.coverage.enabled, o.totemOwn }
o.showPartyRangeDots = false
if o.rangeCounter then o.rangeCounter.enabled = false end
if o.coverage then o.coverage.enabled = false end
if SP.UpdatePartyRangeDots then SP:UpdatePartyRangeDots() end
local pr = SP.updateSystem.subsystems.partyRange
check("party features off: their pass stops", not (pr and pr.enabled))

local name = GetSpellInfo(8075)
local realInfo, realBuffName, realUB = SP.GetElementTotemInfo, SP.GetActiveTotemBuffName, SPCompat.UnitBuff
local t0 = GetTime()
SP.GetElementTotemInfo = function(self, e) if e == 1 then return true, name, t0, 300, nil, 2 end return false end
SP.GetActiveTotemBuffName = function(self, e) if e == 1 then return "Strength of Earth" end return nil end
local inRange = true
SPCompat.UnitBuff = function(unit, i) if inRange and i == 1 then return "Strength of Earth" end return nil end
o.totemOwn = { [8075] = { totemRangeLook = "both" } }
SP:InvalidateTotemInfo()
local btn = SP.totemButtons[1]
W.fireEvent("UNIT_AURA", "player", { isFullUpdate = true })
__sim.advance(1.5)
check("in range: no gray, no glow", not btn.icon:IsDesaturated() and not (btn.spRangeGlow and btn.spRangeGlow:IsShown()))
inRange = false
W.fireEvent("UNIT_AURA", "player", { isFullUpdate = true })
__sim.advance(1.5)
check("walked out of range: gray and the glow, by the bar's own pass", btn.icon:IsDesaturated() and btn.spRangeGlow ~= nil and btn.spRangeGlow:IsShown())
inRange = true
W.fireEvent("UNIT_AURA", "player", { isFullUpdate = true })
__sim.advance(1.5)
check("back in range: both go", not btn.icon:IsDesaturated() and not btn.spRangeGlow:IsShown())
o.totemOwn = nil
inRange = false
W.fireEvent("UNIT_AURA", "player", { isFullUpdate = true })
__sim.advance(1.5)
check("no own look: the gray as always", btn.icon:IsDesaturated() and not btn.spRangeGlow:IsShown())

SP.GetElementTotemInfo, SP.GetActiveTotemBuffName, SPCompat.UnitBuff = realInfo, realBuffName, realUB
o.showPartyRangeDots, o.totemOwn = keep[1], keep[4]
if o.rangeCounter then o.rangeCounter.enabled = keep[2] end
if o.coverage then o.coverage.enabled = keep[3] end
finish()
