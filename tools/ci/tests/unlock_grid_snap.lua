-- client: both
-- Unlock UI: Snap to Grid is its own switch. With Show Grid on and Snap to Grid off the grid only
-- shows and a dropped box stays where it lands (a reviewer: turning Snapping off still snapped to
-- the grid). The switch shows only while the grid does.
local SP = ShamanPower
local o = SP.opt
local keep = { o.unlockGrid, o.unlockGridSnap, o.unlockSnap }

o.unlockGrid, o.unlockGridSnap = true, nil
SP:SetMasterUnlock(true)
__sim.advance(0.6)
check("grid step with Show Grid on (Snap to Grid on by default)", SP:UnlockGridStep() ~= nil)

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
local sw = findSwitch("Snap to Grid")
check("Snap to Grid switch exists", sw ~= nil)
check("Snap to Grid shows while the grid does", sw and sw:IsShown())

o.unlockSnap = false
o.unlockGridSnap = false
check("no grid step with Snap to Grid off", SP:UnlockGridStep() == nil)
o.unlockGridSnap = nil

if sw then
	sw:Click()
	checkEq("clicking it off saves false", o.unlockGridSnap, false)
	sw:Click()
	checkEq("clicking it on saves nil (the default)", o.unlockGridSnap, nil)
end

o.unlockGrid = nil
if ShamanPowerUnlockBar and ShamanPowerUnlockBar.Refresh then ShamanPowerUnlockBar:Refresh() end
check("Snap to Grid hides with the grid off", sw and not sw:IsShown())
check("no grid step with the grid off", SP:UnlockGridStep() == nil)

SP:SetMasterUnlock(false)
o.unlockGrid, o.unlockGridSnap, o.unlockSnap = keep[1], keep[2], keep[3]
finish()
