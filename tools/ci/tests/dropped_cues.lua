-- client: both
-- Dropped Totems: the Effects tab's Totem Destroyed / Totem Expired / Red X play on the picture of a totem
-- that went (PR #27): the picture stays up for the cue, whichever of the cue and the style's own pass sees
-- the totem go first; Keep the Red X Until Recast holds it until the fight ends, then 4.5 s more.
local SP = ShamanPower
local o = SP.opt
local keep = { o.droppedTotems, o.totemCueDestroyed, o.totemCueExpired, o.totemCueDestroyedMark, o.totemCueDestroyedMarkStays }
local realInfo = SP.GetElementTotemInfo
local down = {}
SP.GetElementTotemInfo = function(self, e)
	if down[e] then return true, "Totem", down[e], 120, "Interface\\Icons\\Spell_Nature_EarthBindTotem", e end
	return false
end
o.droppedTotems = true
SP:ApplyDroppedTotems()
__sim.advance(0.2)
if not SP:DroppedActive() then skip("Dropped Totems not active") end
local function drop(e) down[e] = GetTime(); SP:WakeUpdateSubsystem("dropped"); __sim.advance(0.2) end
local function gone(e) down[e] = nil; SP:WakeUpdateSubsystem("dropped") end
local function shown(e) return SP:DroppedHost(e) ~= nil end

-- all cues off: the picture goes at once, as before
o.totemCueDestroyed, o.totemCueExpired, o.totemCueDestroyedMark, o.totemCueDestroyedMarkStays = false, false, false, false
drop(1)
check("a totem down: its picture shows", shown(1))
gone(1); __sim.advance(0.2)
check("cues off: the picture goes at once", not shown(1))

-- Totem Expired, the style's pass first (the totem seen gone, then the cue)
o.totemCueExpired = true
drop(1)
gone(1); __sim.advance(0.1)
check("expired, pass first: the picture waits for the verdict", shown(1))
SP:TotemEndCue(1, "expired")
__sim.advance(1.2)
check("expired, pass first: still up for the cue at 1.3 s", shown(1))
__sim.advance(1.2)
check("expired, pass first: gone after the cue", not shown(1))

-- Totem Expired, the cue first (the same PLAYER_TOTEM_UPDATE, before the style's pass)
drop(1)
gone(1)
SP:TotemEndCue(1, "expired")
__sim.advance(1.2)
check("expired, cue first: still up for the cue at 1.2 s", shown(1))
__sim.advance(1.2)
check("expired, cue first: gone after the cue", not shown(1))

-- Red X with Keep: in a fight it stays until the fight ends, then 4.5 s more
o.totemCueExpired, o.totemCueDestroyedMark, o.totemCueDestroyedMarkStays = false, true, true
__sim.setCombat(true)
drop(2)
gone(2); __sim.advance(0.6)
SP:TotemEndCue(2, "destroyed")
__sim.advance(20)
check("Red X kept, in a fight: the picture stays", shown(2))
__sim.setCombat(false)
__sim.advance(3)
check("Red X kept: still up 3 s after the fight", shown(2))
__sim.advance(2)
check("Red X kept: gone 5 s after the fight", not shown(2))

-- out of a fight the kept X fades after the usual few seconds
drop(2)
gone(2); __sim.advance(0.6)
SP:TotemEndCue(2, "destroyed")
__sim.advance(3)
check("Red X kept, out of a fight: up at 3.6 s", shown(2))
__sim.advance(2.5)
check("Red X kept, out of a fight: gone after the usual time", not shown(2))

-- a recast in the fight takes the held picture's place
__sim.setCombat(true)
drop(3)
gone(3); __sim.advance(0.6)
SP:TotemEndCue(3, "destroyed")
__sim.advance(5)
drop(3)
check("recast: the element's totem shows again", shown(3))
gone(3)
__sim.setCombat(false)
__sim.advance(0.2)

SP.GetElementTotemInfo = realInfo
o.droppedTotems, o.totemCueDestroyed, o.totemCueExpired, o.totemCueDestroyedMark, o.totemCueDestroyedMarkStays = keep[1], keep[2], keep[3], keep[4], keep[5]
SP:ApplyDroppedTotems()
finish()
