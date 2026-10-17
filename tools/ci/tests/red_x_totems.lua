-- client: both
-- The Totem Bar's Red X Until Recast (tb-6): shows with Totem Destroyed's animation off, stays with
-- Keep the Red X Until Recast, and goes when that totem is recast, on a Totem Rows button too
local SP = ShamanPower
local o = SP.opt
local keep = { o.totemCueDestroyed, o.totemCueExpired, o.totemCueDestroyedMark, o.totemCueDestroyedMarkStays }
o.totemCueDestroyed, o.totemCueExpired, o.totemCueDestroyedMark, o.totemCueDestroyedMarkStays = false, false, true, true
check("Red X alone is enough to watch for destroyed totems", SP:TotemCuesWanted())
local b = SP.totemButtons and SP.totemButtons[1]
if not (b and b:IsVisible()) then skip("no visible Earth button") end
SP:TotemEndCue(1, "destroyed")
local c = b.spCue
check("destroyed, animation off: the X shows", c ~= nil and c.markHold:IsPlaying())
check("Keep the Red X Until Recast: held for good", c and c.markHoldStay:GetDuration() > 100)
__sim.advance(6)
check("still there after 6 s", c and c.markHold:IsPlaying())
-- recast: the slot has a totem again
local realInfo = SP.GetElementTotemInfo
local down = {}
SP.GetElementTotemInfo = function(self, e) if down[e] then return true, "Totem", GetTime(), 120, nil, e end return false end
down[1] = true
SP:CueTotemUpdate()
check("recast: the X goes", c and not c.markHold:IsPlaying())
down[1] = nil
SP:CueTotemUpdate()
-- Keep off: the old 4.5 s
o.totemCueDestroyedMarkStays = false
SP:TotemEndCue(1, "destroyed")
check("Keep off: the X fades after 4.5 s", c.markHold:IsPlaying() and c.markHoldStay:GetDuration() < 10)
__sim.advance(6)
check("Keep off: gone after 6 s", not c.markHold:IsPlaying())
-- a Totem Rows button drawn instead of the bar's: its X goes with the recast too
o.totemCueDestroyedMarkStays = true
local row = CreateFrame("Button", nil, UIParent)
row:SetSize(30, 30); row:SetPoint("CENTER"); row.icon = row:CreateTexture(); row:Show()
local realCarry = SP.RowsCarryButton
SP.RowsCarryButton = function(self, e) if e == 2 then return row end end
SP:TotemEndCue(2, "destroyed")
check("on a row's button: the X shows", row.spCue ~= nil and row.spCue.markHold:IsPlaying())
down[2] = true
SP:CueTotemUpdate()
check("on a row's button: the recast takes it away", row.spCue and not row.spCue.markHold:IsPlaying())
SP.RowsCarryButton, SP.GetElementTotemInfo = realCarry, realInfo
o.totemCueDestroyed, o.totemCueExpired, o.totemCueDestroyedMark, o.totemCueDestroyedMarkStays = keep[1], keep[2], keep[3], keep[4]
SP:CueTotemUpdate()
finish()
