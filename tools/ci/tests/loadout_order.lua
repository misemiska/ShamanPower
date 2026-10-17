-- client: both
-- Loadouts Remember the Totem Bar Order: save, switch, a damaged list, the switch off
local SP = ShamanPower
if not (ShamanPower_Assignments and SP.player and ShamanPower_Assignments[SP.player]) then skip("no assignments in the sim") end
local keepOrder = SP.opt.totemBarOrder and { SP.opt.totemBarOrder[1], SP.opt.totemBarOrder[2], SP.opt.totemBarOrder[3], SP.opt.totemBarOrder[4] } or nil
local keepSwitch, keepActive = SP.opt.loadoutsRememberOrder, SP.opt.activeLoadout
local n0 = #ShamanPower_TotemLoadouts
if n0 >= 8 then skip("8 loadouts already") end
SP.opt.loadoutsRememberOrder = true
SP.opt.totemBarOrder = { 2, 1, 3, 4 }
SP:SaveLoadout("ci order")
local idx = #ShamanPower_TotemLoadouts
check("saved", idx == n0 + 1)
local lo = ShamanPower_TotemLoadouts[idx]
check("the order is kept", lo and lo.order and lo.order[1] == 2 and lo.order[2] == 1 and lo.order[3] == 3 and lo.order[4] == 4)
checkEq("the tooltip names it", SP:LoadoutOrderText(lo), "Fire, Earth, Water, Air")
SP.opt.totemBarOrder = { 1, 2, 3, 4 }
SP:ApplyLoadout(idx, true)
check("switching puts the order on the bar", SP.opt.totemBarOrder[1] == 2 and SP.opt.totemBarOrder[2] == 1)
SP.opt.loadoutsRememberOrder = nil
SP.opt.totemBarOrder = { 1, 2, 3, 4 }
SP:ApplyLoadout(idx, true)
check("switch off: the bar's order stays", SP.opt.totemBarOrder[1] == 1 and SP.opt.totemBarOrder[2] == 2)
lo.order = { 9, 1, 1 }
SP.opt.loadoutsRememberOrder = true
SP:ApplyLoadout(idx, true)
check("a damaged list: every element once, the rest in the usual order", #SP.opt.totemBarOrder == 4 and SP.opt.totemBarOrder[1] == 1 and SP.opt.totemBarOrder[4] == 4)
SP:DeleteLoadout(idx)
check("deleted again", #ShamanPower_TotemLoadouts == n0)
SP.opt.loadoutsRememberOrder = keepSwitch
SP.opt.totemBarOrder = keepOrder
SP.opt.activeLoadout = keepActive
SP:UpdateMiniTotemBar()
finish()
