-- client: forever
-- Totem Assignments (A50): the Raid Buffs strip only in the demo or a raid
local SP = ShamanPower
if not SPCompat.FOREVER then skip("Forever only") end
SP:ToggleAssignmentWindow()
__sim.advance(0.4)
local f = ShamanPowerAssignFrame
check("window", f ~= nil and f:IsShown())
SP:AssignDemo(true)
__sim.advance(0.6)
check("strip in the demo", f.raid ~= nil and f.raid:IsShown())
local hDemo = f:GetHeight()
SP:AssignDemo(false)
__sim.advance(0.6)
if not f:IsShown() then f:Show(); __sim.advance(0.3) end
check("no strip in a party", f.raid ~= nil and not f.raid:IsShown())
check("window shorter without it", f:GetHeight() < hDemo)
finish()
