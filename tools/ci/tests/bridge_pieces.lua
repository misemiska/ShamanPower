-- client: both
-- Hide When No Totems in a fight (the helper): Totem Rows wanted, Grid not, Dropped's pieces off, the totem frame re-homed
local SP = ShamanPower
local o = SP.opt
local keep = { hide = o.hideWhenNoTotems, fade = o.fadeInsteadOfHide, rows = o.totemRows, grid = o.gridStyle }
o.hideWhenNoTotems, o.fadeInsteadOfHide, o.gridStyle, o.totemRows = true, nil, nil, true
check("Totem Rows no longer turn the helper off", SP:TotemBarBridgeWanted() == true or not SP:TotemBarInUse())
o.gridStyle = true
check("Grid still does", SP:TotemBarBridgeWanted() == false)
o.gridStyle, o.totemRows = keep.grid, keep.rows
check("RowBridgeHost exists", type(SP.RowBridgeHost) == "function")
local tf, pf = _G.TotemFrame, _G.PlayerFrame
if tf and pf and SP.autoButton and tf:GetParent() == pf and SP:TotemBarBridgeWanted() then
	SP:UpdateTotemBarBridge()
	local h = SP.totemBarBridge
	check("helper made", h ~= nil)
	pf:Hide(); SP:UpdateTotemBarBridge()
	check("player frame hidden: the totem frame hangs under UIParent, faded out", tf:GetParent() == UIParent and tf:GetAlpha() == 0)
	pf:Show(); SP:UpdateTotemBarBridge()
	check("player frame back: the totem frame goes home", tf:GetParent() == pf and tf.spRehomed == nil)
	if h and SP.TotemBarStyle and SP:TotemBarStyle("dropped") then
		local style = SP:GetTotemBarStyle()
		SP:SetTotemBarStyle("dropped"); SP:ApplyDroppedTotems(); SP:UpdateTotemBarBridge()
		check("Dropped: the bar is the helper's, the buttons and Drop All are not", h:GetAttribute("show-bar") == 1 and h:GetAttribute("show-b1") == 0 and h:GetAttribute("show-dropall") == 0)
		SP:SetTotemBarStyle(style); SP:ApplyDroppedTotems(); SP:UpdateTotemBarBridge()
	end
else
	check("(no player-frame totem frame in the sim: the re-home is Run Checks' in game)", true)
end
o.hideWhenNoTotems, o.fadeInsteadOfHide = keep.hide, keep.fade
pcall(SP.UpdateTotemBarBridge, SP)
finish()
