-- client: both
-- Space Between Icons (3.0.9.2): on Totem Bar > Bar and the Cooldown Bar page, under Move, the same
-- setting as Button Spacing on Appearance (the owner: room for the glows)
local SP = ShamanPower
local o = SP.opt
local tb = SP.options.args.buttons.args.auto_button.args.tb_bar_spacing
local cd
for _, g in pairs(SP.options.args.fluffy.args) do
	if type(g) == "table" and g.args and g.args.cdbar_spacing then cd = g.args.cdbar_spacing end
end
check("Totem Bar > Bar: Space Between Icons", tb ~= nil and tb.order ~= nil)
check("Cooldown Bar page: Space Between Icons", cd ~= nil and cd.order ~= nil)
local keep = { o.totemBarPadding, o.cooldownBarPadding }
if tb then tb.set(nil, 7); checkEq("the totem bar's Button Spacing takes it", o.totemBarPadding, 7) end
if cd then cd.set(nil, 9); checkEq("the cooldown bar's Button Spacing takes it", o.cooldownBarPadding, 9) end
o.totemBarPadding, o.cooldownBarPadding = keep[1], keep[2]
SP:UpdateRoster()
finish()
