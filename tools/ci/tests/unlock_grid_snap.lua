-- client: both
-- Unlock UI (3.0.9.2): Snap to Boxes and Snap to Grid are one or the other (the owner): Snap to Boxes
-- on to start; turning either on turns the other off; both can be off (a box stays where it lands).
-- Snap to Grid shows only while the grid does.
local SP = ShamanPower
local o = SP.opt
local keep = { o.unlockGrid, o.unlockGridSnap, o.unlockSnap }

o.unlockGrid, o.unlockGridSnap, o.unlockSnap = true, nil, nil
SP:SetMasterUnlock(true)
__sim.advance(0.6)
check("to start: Snap to Boxes, no grid snapping", SP:UnlockGridStep() == nil)

local function findSwitch(label)
	local function walk(f)
		for _, r in ipairs({ f:GetRegions() }) do
			if r.GetText and r:GetText() == label then return f end
		end
		for _, c in ipairs({ f:GetChildren() }) do
			local hit = walk(c)
			if hit then return hit end
		end
	end
	return ShamanPowerUnlockBar and walk(ShamanPowerUnlockBar)
end
local grid, boxes = findSwitch("Snap to Grid"), findSwitch("Snap to Boxes")
check("both switches exist", grid ~= nil and boxes ~= nil)
check("Snap to Grid shows while the grid does", grid and grid:IsShown())
check("Snap to Boxes on, Snap to Grid off to start", boxes and boxes:GetChecked() and not grid:GetChecked())
if grid and boxes then
	grid:Click()
	check("Snap to Grid on: grid snapping", SP:UnlockGridStep() ~= nil)
	check("and Snap to Boxes went off", o.unlockSnap == false and not boxes:GetChecked())
	boxes:Click()
	check("Snap to Boxes on: Snap to Grid went off", SP:UnlockGridStep() == nil and not grid:GetChecked())
	boxes:Click()
	check("both off", o.unlockSnap == false and SP:UnlockGridStep() == nil)
end
o.unlockGrid = nil
if ShamanPowerUnlockBar and ShamanPowerUnlockBar.Refresh then ShamanPowerUnlockBar:Refresh() end
check("Snap to Grid hides with the grid off", grid and not grid:IsShown())

SP:SetMasterUnlock(false)
o.unlockGrid, o.unlockGridSnap, o.unlockSnap = keep[1], keep[2], keep[3]
finish()
