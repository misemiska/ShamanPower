-- client: both
-- Totemic Recall's icon and settings sit on the page of the bar it is on (3.0.9.2, the owner): Bar = Totem Bar
-- puts it on Totem Bar > Bar's Buttons row (after Drop All, with its Cooldown Bar menu) and takes it off the
-- Cooldown Bar's Items row; the settings search follows it; Bar back = back on the Cooldown Bar page.
local SP = ShamanPower
local cfg = ShamanPowerConfig
local BTN, CD = SP.TotemBarRows and SP.TotemBarRows.buttons, SP.CooldownBarRow
if not (BTN and CD and SP.RecallOnTotemBarPage and SP.CdItemOpt and SP.CooldownTypeExists and SP:CooldownTypeExists(2)) then
	skip("no Totemic Recall rows here")
end
local keepOwn = SP.CdItemOwnOpt and SP:CdItemOwnOpt(2, "onTotemBar")
local keepOrder = SP.opt.cooldownBarOrder and { unpack(SP.opt.cooldownBarOrder) }
local keepShown = SP.opt.cdbarShowRecall

local function keys(row)
	local out = {}
	row.def.list(out)
	local k = {}
	for i, it in ipairs(out) do k[i] = it.key end
	return k
end
local function has(list, key) for i, k in ipairs(list) do if k == key then return i end end end
local function onTotemBar(v) SP:SetCdItemOpt(2, "onTotemBar", v); SP:RecreateCooldownBar(); __sim.advance(0.2) end

-- on the Cooldown Bar (as it comes)
onTotemBar(false)
check("on the Cooldown Bar: not on the Totem Bar page", not SP:RecallOnTotemBarPage())
check("on the Cooldown Bar: in its Items row", has(keys(CD), 2) ~= nil)
check("on the Cooldown Bar: not in the Totem Bar's Buttons row", has(keys(BTN), "recall") == nil)

-- Bar: Totem Bar
onTotemBar(true)
local b = keys(BTN)
check("on the totem bar: in the Totem Bar's Buttons row", has(b, "recall") ~= nil)
check("on the totem bar: right after Drop All", has(b, "recall") == (has(b, "dropall") or -1) + 1)
check("on the totem bar: not in the Cooldown Bar's Items row", has(keys(CD), 2) == nil)
local item = { key = "recall", name = "Totemic Recall" }
local menu = BTN.def.menu(item)
local bar
for _, m in ipairs(menu) do if m.text == "Bar" then bar = m end end
check("its menu from the Totem Bar page: the Cooldown Bar menu (Show, Bar, Keys ...)", #menu > 8 and bar ~= nil)
check("its icon: Recall's", BTN.def.textures(item, {}) == 1)
-- a click: shown or hidden, the Cooldown Bar's own switch
local before = BTN.def.shown(item)
BTN.def.toggle(item)
check("a click on the Totem Bar page hides / shows it (the bar's own switch)", (SP.opt.cdbarShowRecall ~= false) ~= before)
BTN.def.toggle(item)

-- the search: the Totem Bar page has it, the Cooldown Bar page's Items row doesn't
local function descOf(path)
	local n = SP.options
	for k in path:gmatch("[^.]+") do n = n and n.args and n.args[k] end
	local d = n and n.desc
	if type(d) == "function" then d = d() end
	return string.lower(d or "")
end
local tbDesc, cdDesc = descOf("buttons.auto_button.tb_buttons"), descOf("fluffy.cdbar_page.cdbarIcons")
if tbDesc == "" then
	-- (the Bar tab's rows may sit one group down)
	for k, g in pairs(SP.options.args.buttons.args.auto_button.args) do
		if type(g) == "table" and g.args and g.args.tb_buttons then tbDesc = descOf("buttons.auto_button." .. k .. ".tb_buttons") end
	end
end
check("search: the Totem Bar page finds Totemic Recall", tbDesc:find("totemic recall", 1, true) ~= nil, tbDesc:sub(1, 40))
check("search: the Cooldown Bar's Items row doesn't", cdDesc ~= "" and cdDesc:find("totemic recall", 1, true) == nil)

-- dragging on the Cooldown Bar while Recall is away: Recall keeps its saved place
local order = SP:GetCooldownBarOrder()
local recallAt = has(order, 2)
local cdKeys = keys(CD)
if #cdKeys >= 3 then
	CD.def.move({ key = cdKeys[1] }, 3)
	__sim.advance(0.2)
	local after = SP:GetCooldownBarOrder()
	check("a drag on the Cooldown Bar page keeps Recall's place", has(after, 2) == recallAt)
	local newKeys = keys(CD)
	check("the dragged item lands where it was dropped", newKeys[3] == cdKeys[1])
end

-- Bar: Cooldown Bar from the Totem Bar page: the choice's own setter
local setter
for _, m in ipairs(menu) do if m.text == "Bar" then setter = m end end
local sub = setter and type(setter.sub) == "function" and setter.sub() or (setter and setter.sub) or {}
local toCd
for _, o in ipairs(sub) do if o.text == "Cooldown Bar" then toCd = o end end
check("Bar has Cooldown Bar", toCd ~= nil)
if toCd and toCd.onClick then
	toCd.onClick()
	__sim.advance(0.5)
	check("Bar: Cooldown Bar: back on the Cooldown Bar page", not SP:RecallOnTotemBarPage() and has(keys(CD), 2) ~= nil)
	check("Bar: Cooldown Bar: off the Totem Bar page", has(keys(BTN), "recall") == nil)
end

-- put back
SP:SetCdItemOpt(2, "onTotemBar", keepOwn)
SP.opt.cooldownBarOrder = keepOrder
SP.opt.cdbarShowRecall = keepShown
SP:RecreateCooldownBar()
finish()
