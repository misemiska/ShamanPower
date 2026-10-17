-- ShamanPower_Config :: IconScreen
-- (3.0.9 alpha, sheet A30) Click an icon: its own screen. With Click an Icon Opens Its
-- Screen on (General > Main, opt.iconScreens; off to start), a left-click on an icon row's
-- item (IconRow.lua) draws that item's own screen in the page body instead of turning it
-- on or off: a header (a back link to the page, the icon, its name, Show This Icon), then
-- one card per group of its right-click menu, and inside a card every choice is a PICTURE
-- of what you get (the item's own icon drawn in that state, from the `pic` hints the page
-- files put on their menu rows) with its name under it: click the picture you want. An
-- on / off row is one picture with a check corner. Sliders and colors stay sliders and
-- swatches (a live picture beside them when the hint says what they change), buttons stay
-- buttons. The screen is built from the SAME menu the right-click opens (def.menu(item)),
-- read through ListLook's menu reader, so the three looks (icons, old look, screen) always
-- agree. Right-click keeps today's menu; the Old Settings Look is untouched.
--
-- Window.lua: RenderPageInner asks IconScreen:Takes(entry, query, tab) and, when it takes
-- the page, draws IconScreen:Render(body, fullW, element, onChanged) -> first, height in
-- place of the page's rows; ClearPage calls IconScreen:Release(). A page or tab change or a
-- search drops the screen (Takes answers false and forgets it); the window closing drops it
-- too (its OnHide calls IconScreen:Close). Back draws the page scrolled where it was.
-- IconRow.lua: ButtonClick opens it (IconScreen:Wants(row) / :Open(row, key)).
-- Tests: ShamanPower:IconScreenOpen(rowKey, itemKey) / :IconScreenClose().
local _, ns = ...
local Core = ns.Core
local SP = ShamanPower
if not (Core and SP and ns.Widgets) then return end
local Widgets = ns.Widgets

local max, min, floor, ceil = math.max, math.min, math.floor, math.ceil

local IconScreen = {}
ns.IconScreen = IconScreen

-- the screen's measures (sheet A30, in the settings window's units)
local TILE_W      = 96     -- a picture tile
local TILE_PAD    = 8      -- above the plate, under the caption
local PLATE       = 48     -- the plate (the icon 44 in it, 2 px round)
local ICON        = 44
local CAP_GAP     = 6      -- plate to caption
local TILE_GAP    = 10     -- tile to tile
local CARD_GAP    = 12     -- the cards' gap (Window.lua's)
local CARD_PAD    = 12     -- inside a card: the content's inset
local HEAD_H      = 104    -- the header block
local CHECK       = 12     -- the check corner of an on / off tile
local LIVE_W      = 64     -- the live picture beside a slider: the plate alone
local LIVE_ROOM   = 12     -- a live ring's room (a smaller stage: the ring shrinks its icon to fit)
local MANY        = 9      -- more choices than this (every sound): a dropdown row instead of tiles
local CORNER_ICON = 18     -- a buff in the corner
local GLOW_SCALE  = 1.55   -- a square / round glow's size over the plate's
local GLOW_ROOM   = 20     -- room above and below a glowing picture: a ring reaches past the icon (its real reach)
local SWEEP_DUR   = 60     -- the sample sweep's length (slow enough to read as a sweep)
local GROUP_H     = 24     -- a nested group's heading line
local SEP_GAP     = 6

local function Report(err) geterrorhandler()(err) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then Report(a) return nil end
	return a, b, c
end
local function Call4(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then Report(a) return nil end
	return a, b, c, d
end

-- ListLook's menu reader (ListLook.lua loads first): one reading per frame, resolved by path
local function M() return ns.ListLook and ns.ListLook.Menu end
-- a row's definition: the shared row's def, or a page's own row's listDef (Target Tracker)
local function DefOf(row) return row and (row.def or row.listDef) or nil end

-- ---------------------------------------------------------------------------
-- State: the screen that is open (one at a time)
-- ---------------------------------------------------------------------------
local open   -- { row, key, entry, tab }
local frameOf = function() return _G.ShamanPowerConfigUIFrame end

function IconScreen:On() return SP.opt ~= nil and SP.opt.iconScreens == true end
function IconScreen:Wants(row)
	local def = DefOf(row)
	return self:On() and def ~= nil and def.menu ~= nil
end
function IconScreen:IsOpen() return open ~= nil end

local function Refresh()
	local cfg = _G.ShamanPowerConfig
	if cfg and cfg.RefreshCurrent then cfg:RefreshCurrent() end
end

function IconScreen:Open(row, key)
	if not (row and key ~= nil) then return end
	local f = frameOf()
	open = { row = row, key = key, entry = f and f._current or nil, tab = f and f._activeTab or nil,
		scroll = f and f.bodyScroll and f.bodyScroll:GetVerticalScroll() or 0 }
	if ns.ContextMenu and ns.ContextMenu:IsOpen() then ns.ContextMenu:Close() end
	if f and f.bodyScroll then f.bodyScroll:SetVerticalScroll(0) end
	Refresh()
end

-- Back: the page again, scrolled where it was
function IconScreen:Close(noRefresh)
	if not open then return end
	local back = open.scroll
	open = nil
	if noRefresh then return end
	local cfg, f = _G.ShamanPowerConfig, frameOf()
	if cfg and cfg.RenderPage and f and f:IsShown() and f._current then
		cfg:RenderPage(f._current, f._query, back)
	else
		Refresh()
	end
end

-- the page asks: is the screen on this page and tab, with no search running?
function IconScreen:Takes(entry, query, tab)
	if not open then return false end
	if not self:On() or (query and query ~= "") or entry ~= open.entry or tab ~= open.tab then
		open = nil
		return false
	end
	return true
end

-- the item as the row lists it now (the list is read again: a name or a key may have changed)
local listScratch = {}
local function FindItem(row, key)
	wipe(listScratch)
	Call(DefOf(row).list, listScratch)
	for _, it in ipairs(listScratch) do
		if it.key == key then return it end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Pools: tiles, plain frames (the header's plate, back link, headings, words), buttons
-- ---------------------------------------------------------------------------
local pools = { tile = { free = {}, used = {} }, frame = { free = {}, used = {} }, button = { free = {}, used = {} },
	text = { free = {}, used = {} }, mslider = { free = {}, used = {} } }

local function Take(kind, parent, create)
	local p = pools[kind]
	local f = table.remove(p.free)
	if not f then f = create(parent) end
	p.used[#p.used + 1] = f
	f:SetParent(parent)
	f:ClearAllPoints()
	f:Show()
	return f
end

local function GiveBack(kind, reset)
	local p = pools[kind]
	for i = #p.used, 1, -1 do
		local f = p.used[i]
		if reset then reset(f) end
		f:Hide()
		f:ClearAllPoints()
		p.free[#p.free + 1] = f
		p.used[i] = nil
	end
end

-- the menu's slider row (ContextMenu.lua SliderRow), pooled
local function NewMenuSlider(parent)
	return ns.ContextMenu.SliderRow.New(parent)
end

local plateRGB = function()
	local p = SP.Brand and SP.Brand.plate
	if p then return p[1], p[2], p[3] end
	return 5 / 255, 7 / 255, 10 / 255
end

-- a plain frame carrying one font string (headings, the crumb, a card's words)
local function NewText(parent)
	local f = CreateFrame("Frame", nil, parent)
	f.text = f:CreateFontString(nil, "OVERLAY")
	f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.text:SetJustifyH("LEFT")
	f.text:SetJustifyV("TOP")
	f.text:SetWordWrap(true)
	return f
end
local function Text(parent, x, y, w, s, font, colorKey, h)
	local f = Take("text", parent, NewText)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	f.text:SetFontObject(font)
	f.text:SetWordWrap(true)
	f.text:SetWidth(w)
	f.text:SetText(s or "")
	if colorKey then f.text:SetTextColor(Core:Color(colorKey)) end
	local th = h or ceil(f.text:GetStringHeight())
	f:SetSize(w, th)
	return f, th
end

-- the item's icon on a plate (the header's, and a tile's); up to three slices as the row draws them
local function NewPlate(parent)
	local p = CreateFrame("Frame", nil, parent)
	p:SetSize(PLATE, PLATE)
	p.bg = p:CreateTexture(nil, "BACKGROUND")
	p.bg:SetAllPoints(p)
	p.bg:SetColorTexture(plateRGB())
	p.icons = {}
	for i = 1, 3 do
		local t = p:CreateTexture(nil, "ARTWORK")
		t:Hide()
		p.icons[i] = t
	end
	return p
end

local function PaintPlate(p, ctx, size, swapTex)
	local n = swapTex and 1 or ctx.n
	local inset = (size - size * ICON / PLATE) / 2
	local iconW = size - 2 * inset
	for i = 1, 3 do
		local t = p.icons[i]
		if i <= n then
			t:ClearAllPoints()
			t:SetSize(iconW / n, iconW)
			t:SetPoint("TOPLEFT", p, "TOPLEFT", inset + (i - 1) * iconW / n, -inset)
			t:SetTexture(swapTex or ctx.tex[i])
			local l, r, tp, bt
			if not swapTex and ctx.def.texCoords then l, r, tp, bt = Call4(ctx.def.texCoords, ctx.item, i) end
			if l then t:SetTexCoord(l, r, tp, bt)
			else t:SetTexCoord(0.08 + 0.84 * (i - 1) / n, 0.08 + 0.84 * i / n, 0.08, 0.92) end
			t:SetDesaturated(false)
			t:SetVertexColor(1, 1, 1, 1)
			t:SetAlpha(1)
			t:Show()
		else
			t:Hide()
		end
	end
	p:SetSize(size, size)
	p:SetAlpha(1)
end

-- ---------------------------------------------------------------------------
-- A tile: the picture, its caption, the lit edge when it is the pick, the check corner
-- ---------------------------------------------------------------------------
local function NewTile(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(TILE_W, 92)
	b:RegisterForClicks("LeftButtonUp")
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints(b)
	Core:RegisterFade(b.bg, "windowBg", 1)
	b.lit = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.lit:SetAllPoints(b)
	b.lit:SetColorTexture(Core:Color("accent", 0.16))
	b.lit:Hide()
	Core:MakeBorder(b, "border", 1)
	b.plate = NewPlate(b)
	b.plate:SetPoint("TOP", b, "TOP", 0, -TILE_PAD)
	b.caption = b:CreateFontString(nil, "OVERLAY")
	b.caption:SetFontObject(Core.fonts.small)
	b.caption:SetJustifyH("CENTER")
	b.caption:SetJustifyV("TOP")
	b.caption:SetWordWrap(true)
	b.caption:SetWidth(TILE_W - 8)
	b.caption:SetPoint("TOP", b.plate, "BOTTOM", 0, -CAP_GAP)
	-- the check corner (an on / off tile, a pick-any list)
	b.check = CreateFrame("Frame", nil, b)
	b.check:SetSize(CHECK, CHECK)
	b.check:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, -4)
	Core:MakeBorder(b.check, "border", 1)
	b.check.fill = b.check:CreateTexture(nil, "ARTWORK")
	b.check.fill:SetPoint("TOPLEFT", b.check, "TOPLEFT", 3, -3)
	b.check.fill:SetPoint("BOTTOMRIGHT", b.check, "BOTTOMRIGHT", -3, 3)
	b.check.fill:SetColorTexture(Core:Color("accentHi"))
	b.check:Hide()
	b:SetScript("OnEnter", function(s)
		if s.disabled then return end
		Core:SetBorderColor(s, "accent")
		if s.tip then Core:AttachTooltip(s, s.tipTitle, s.tip) end
	end)
	b:SetScript("OnLeave", function(s)
		Core:SetBorderColor(s, s.picked and "accentHi" or "border")
	end)
	b:SetScript("OnClick", function(s) if s.onClick and not s.disabled then s.onClick() end end)
	return b
end

-- the treatment layers, made the first time a tile needs them
local function Veil(b)
	if not b.veil then
		b.veil = b.plate:CreateTexture(nil, "ARTWORK", nil, 2)
		b.veil:SetAllPoints(b.plate)
	end
	return b.veil
end
local function Word(b)
	if not b.word then
		local o = b.plate:CreateFontString(nil, "OVERLAY")
		o:SetFont(Core.fonts.tiny:GetFont(), 11, "OUTLINE")
		o:SetPoint("CENTER", b.plate, "CENTER", 0, 0)
		o:SetJustifyH("CENTER")
		b.word = o
	end
	return b.word
end
local function Big(b)
	if not b.big then
		local o = b.plate:CreateFontString(nil, "OVERLAY")
		o:SetFont(Core.fonts.title:GetFont(), 20, "OUTLINE")
		o:SetPoint("CENTER", b.plate, "CENTER", 0, 0)
		b.big = o
	end
	return b.big
end
local function Sweep(b)
	if not b.cd then
		local cd = CreateFrame("Cooldown", nil, b.plate, "CooldownFrameTemplate")
		cd:SetPoint("TOPLEFT", b.plate, "TOPLEFT", 2, -2)
		cd:SetPoint("BOTTOMRIGHT", b.plate, "BOTTOMRIGHT", -2, 2)
		if cd.SetDrawEdge then cd:SetDrawEdge(false) end
		if cd.SetDrawBling then cd:SetDrawBling(false) end
		if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
		if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.7) end
		cd:SetReverse(false)
		b.cd = cd
	end
	return b.cd
end
local function Glow(b)
	if not b.glow then
		local t = b.plate:CreateTexture(nil, "OVERLAY", nil, 2)
		t:SetPoint("CENTER", b.plate, "CENTER", 0, 0)
		t:SetBlendMode("ADD")
		b.glow = t
	end
	return b.glow
end
local function Corner(b)
	if not b.cornerIcon then
		local f = CreateFrame("Frame", nil, b.plate)
		f:SetSize(CORNER_ICON + 2, CORNER_ICON + 2)
		f:SetPoint("TOPRIGHT", b.plate, "TOPRIGHT", 3, 3)
		f:SetFrameLevel(b.plate:GetFrameLevel() + 2)
		f.edge = f:CreateTexture(nil, "BACKGROUND")
		f.edge:SetAllPoints(f)
		f.edge:SetColorTexture(plateRGB())
		f.icon = f:CreateTexture(nil, "ARTWORK")
		f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
		f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.cornerIcon = f
	end
	return b.cornerIcon
end
local function Edge(b, thick)
	thick = thick or 3
	b.edges = b.edges or {}
	local f = b.edges[thick]
	if not f then
		f = CreateFrame("Frame", nil, b.plate)
		f:SetPoint("TOPLEFT", b.plate, "TOPLEFT", -1, 1)
		f:SetPoint("BOTTOMRIGHT", b.plate, "BOTTOMRIGHT", 1, -1)
		f:SetFrameLevel(b.plate:GetFrameLevel() + 1)
		Core:MakeBorder(f, "accent", thick)
		b.edges[thick] = f
	end
	return f
end
-- a dotted edge: dashes round the plate from plain textures (as the Target Tracker draws its dotted looks)
local function Dots(b, thick, r, g, bl)
	b.dots = b.dots or {}
	local host = b.plate
	local o, d, gap = 1, 4, 3
	local len = PLATE + 2 * o
	local count = max(2, floor((len + gap) / (d + gap) + 0.5))
	local step = (len - d) / (count - 1)
	local used = 0
	local function dot(x, y, w, h)
		used = used + 1
		local tx = b.dots[used]
		if not tx then
			tx = host:CreateTexture(nil, "OVERLAY", nil, 1)
			b.dots[used] = tx
		end
		tx:ClearAllPoints()
		tx:SetPoint("TOPLEFT", host, "TOPLEFT", x, -y)
		tx:SetSize(w, h)
		tx:SetColorTexture(r, g, bl, 1)
		tx:Show()
	end
	for i = 0, count - 1 do
		local q = -o + i * step
		dot(q, -o, d, thick)
		dot(q, PLATE + o - thick, d, thick)
		if i > 0 and i < count - 1 then
			dot(-o, q, thick, d)
			dot(PLATE + o - thick, q, thick, d)
		end
	end
	for i = used + 1, #b.dots do b.dots[i]:Hide() end
end
-- a strip of orbs under the icon (Shield Charges' orb looks: the module's own strip art, as the bar draws it)
local function Orbs(b)
	if not b.orbs then
		local back = b:CreateTexture(nil, "ARTWORK")
		back:SetPoint("TOP", b.plate, "BOTTOM", 0, -3)
		local fill = b:CreateTexture(nil, "ARTWORK", nil, 1)
		fill:SetPoint("LEFT", back, "LEFT", 0, 0)
		b.orbs, b.orbFill = back, fill
	end
	return b.orbs, b.orbFill
end
-- the icon drawn bigger than its plate: a pulse (the icon's own grow-and-shrink, caught mid-grow)
local function Bulge(p, size, k)
	local n = 0
	for i = 1, 3 do if p.icons[i]:IsShown() then n = i end end
	if n == 0 then return end
	local inset = (size - size * ICON / PLATE) / 2
	local iconW = size - 2 * inset
	for i = 1, n do
		local t = p.icons[i]
		local cx = inset + (i - 0.5) * iconW / n - size / 2
		t:ClearAllPoints()
		t:SetPoint("CENTER", p, "CENTER", cx * k, 0)
		t:SetSize(iconW / n * k, iconW * k)
	end
end
local function SquareGlow(b)
	if not b.sqGlow then
		local f = CreateFrame("Frame", nil, b.plate)
		f:SetPoint("TOPLEFT", b.plate, "TOPLEFT", -5, 5)
		f:SetPoint("BOTTOMRIGHT", b.plate, "BOTTOMRIGHT", 5, -5)
		f:SetFrameLevel(b.plate:GetFrameLevel() + 1)
		Core:MakeBorder(f, "accent", 5)
		b.sqGlow = f
	end
	return b.sqGlow
end
local function Bar(b)
	if not b.bar then
		local bg = b:CreateTexture(nil, "ARTWORK")
		bg:SetPoint("TOPLEFT", b.plate, "BOTTOMLEFT", 0, -2)
		bg:SetSize(PLATE, 4)
		bg:SetColorTexture(0, 0, 0, 0.8)
		local fill = b:CreateTexture(nil, "ARTWORK", nil, 1)
		fill:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
		fill:SetHeight(4)
		b.bar = bg
		b.barFill = fill
	end
	return b.bar, b.barFill
end
-- When It's Gone on a bar / orb strip picture (Shield Charges, 3.0.9): `goneGlow` = its edges lit in that color
-- with the halo round them (rings of light stepping out, each fainter), `goneLit` = its track lit (an orb strip:
-- its own orbs), as the module draws them
local GONE_RINGS = { 0.5, 0.32, 0.18, 0.08 }
local GoneRGB   -- (below PicColor)
local function BarGone(b, box, pic, orbFile)
	if not (pic.goneGlow or pic.goneLit) then
		if b.barGone then b.barGone:Hide() end
		return 0
	end
	local f = b.barGone
	if not f then
		f = CreateFrame("Frame", nil, b)
		f:SetFrameLevel(b:GetFrameLevel() + 2)
		f.rings = {}
		for k = 1, #GONE_RINGS do
			local ring, inner, o = {}, k - 1, k
			for i = 1, 4 do
				local t = f:CreateTexture(nil, "OVERLAY", nil, 1)
				t:SetTexture("Interface\\Buttons\\WHITE8X8")
				t:SetBlendMode("ADD")
				ring[i] = t
			end
			ring[1]:SetPoint("TOPLEFT", f, "TOPLEFT", -o, o); ring[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", o, o); ring[1]:SetHeight(1)
			ring[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -o, -o); ring[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", o, -o); ring[2]:SetHeight(1)
			ring[3]:SetPoint("TOPLEFT", f, "TOPLEFT", -o, inner); ring[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -o, -inner); ring[3]:SetWidth(1)
			ring[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", o, inner); ring[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", o, -inner); ring[4]:SetWidth(1)
			f.rings[k] = ring
		end
		f.edges = {}
		for i = 1, 4 do
			local t = f:CreateTexture(nil, "OVERLAY", nil, 2)
			t:SetTexture("Interface\\Buttons\\WHITE8X8")
			t:SetBlendMode("ADD")
			f.edges[i] = t
		end
		local E = f.edges
		E[1]:SetPoint("TOPLEFT"); E[1]:SetPoint("TOPRIGHT"); E[1]:SetHeight(1)
		E[2]:SetPoint("BOTTOMLEFT"); E[2]:SetPoint("BOTTOMRIGHT"); E[2]:SetHeight(1)
		E[3]:SetPoint("TOPLEFT"); E[3]:SetPoint("BOTTOMLEFT"); E[3]:SetWidth(1)
		E[4]:SetPoint("TOPRIGHT"); E[4]:SetPoint("BOTTOMRIGHT"); E[4]:SetWidth(1)
		local lit = f:CreateTexture(nil, "OVERLAY", nil, 0)
		lit:SetAllPoints(f)
		lit:SetBlendMode("ADD")
		f.lit = lit
		b.barGone = f
	end
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", box, "TOPLEFT", -1, 1)
	f:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 1, -1)
	if pic.goneGlow then
		local r, g, bl = GoneRGB(pic.goneGlow)
		for i = 1, 4 do f.edges[i]:SetVertexColor(r, g, bl, 0.9); f.edges[i]:Show() end
		for k, ring in ipairs(f.rings) do
			for i = 1, 4 do ring[i]:SetVertexColor(r, g, bl, GONE_RINGS[k]); ring[i]:Show() end
		end
	else
		for i = 1, 4 do f.edges[i]:Hide() end
		for _, ring in ipairs(f.rings) do for i = 1, 4 do ring[i]:Hide() end end
	end
	if pic.goneLit then
		local r, g, bl = GoneRGB(pic.goneLit)
		if orbFile then
			f.lit:SetTexture(orbFile); f.lit:SetTexCoord(0, 1, 0, 1); f.lit:SetVertexColor(r, g, bl, 0.8)
		else
			f.lit:SetTexture("Interface\\Buttons\\WHITE8X8"); f.lit:SetTexCoord(0, 1, 0, 1); f.lit:SetVertexColor(r, g, bl, 0.55)
		end
		f.lit:Show()
	else
		f.lit:Hide()
	end
	f:Show()
	return pic.goneGlow and 6 or 0   -- (the halo's reach below: the caption clears it)
end
local function RedX(b)
	if not b.redx then
		local t = b.plate:CreateTexture(nil, "OVERLAY", nil, 3)
		t:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
		t:SetSize(26, 26)
		t:SetPoint("CENTER", b.plate, "CENTER", 0, 0)
		b.redx = t
	end
	return b.redx
end
-- a speaker: the box, its cone and three waves, from plain textures
local function Speaker(b)
	if not b.spk then
		local s = CreateFrame("Frame", nil, b.plate)
		s:SetAllPoints(b.plate)
		s:SetFrameLevel(b.plate:GetFrameLevel() + 2)
		s.parts = {}
		local function part(w, h, x, y)
			local t = s:CreateTexture(nil, "OVERLAY")
			t:SetSize(w, h)
			t:SetPoint("CENTER", s, "CENTER", x, y)
			s.parts[#s.parts + 1] = t
			return t
		end
		part(7, 10, -11, 0)      -- the box
		part(6, 18, -4, 0)       -- the cone (as a taller bar)
		part(2, 10, 5, 0)        -- three waves
		part(2, 16, 10, 0)
		part(2, 22, 15, 0)
		b.spk = s
	end
	return b.spk
end
local function Fill(b)
	if not b.fill then
		local t = b.plate:CreateTexture(nil, "ARTWORK", nil, 1)
		t:SetPoint("TOPLEFT", b.plate, "TOPLEFT", 2, -2)
		t:SetPoint("BOTTOMRIGHT", b.plate, "BOTTOMRIGHT", -2, 2)
		b.fill = t
	end
	return b.fill
end
local function Name(b)
	if not b.name then
		local o = b:CreateFontString(nil, "OVERLAY")
		o:SetFontObject(Core.fonts.tiny)
		o:SetTextColor(1, 0.82, 0)
		o:SetJustifyH("CENTER")
		o:SetWidth(TILE_W - 8)
		b.name = o
	end
	return b.name
end

-- everything a treatment may have turned on, off again (a pooled tile comes back clean)
local function ResetTile(b)
	b.picked, b.disabled, b.onClick, b.tip, b.tipTitle, b.extraH, b.noPic = nil, nil, nil, nil, nil, nil, nil
	b.spTipTitle, b.spTipBody = nil, nil
	b.lit:Hide()
	b.check:Hide()
	Core:SetBorderColor(b, "border")
	b:SetAlpha(1)
	b:SetSize(TILE_W, 92)
	b.plate:Show()
	b.plate:SetAlpha(1)
	b.plate:ClearAllPoints()
	b.plate:SetPoint("TOP", b, "TOP", 0, -TILE_PAD)
	b.plate:SetSize(PLATE, PLATE)
	for i = 1, 3 do b.plate.icons[i]:Hide() end
	if b.veil then b.veil:Hide() end
	if b.word then b.word:Hide() end
	if b.big then b.big:Hide() end
	if b.cd then
		if b.cd.Resume then b.cd:Resume() end   -- (a sample sweep sits paused)
		b.cd:Clear(); b.cd:Hide()
	end
	if b.glow then b.glow:Hide() end
	if b.sqGlow then b.sqGlow:Hide() end
	if b.cornerIcon then b.cornerIcon:Hide() end
	if b.edges then for _, f in pairs(b.edges) do f:Hide() end end
	if b.dots then for _, tx in ipairs(b.dots) do tx:Hide() end end
	if b.orbs then b.orbs:Hide(); b.orbFill:Hide() end
	if b.bar then b.bar:Hide(); b.barFill:Hide() end
	if b.barGone then b.barGone:Hide() end
	if b.redx then b.redx:Hide() end
	if b.spk then b.spk:Hide() end
	if b.fill then b.fill:Hide() end
	if b.name then b.name:Hide() end
	if b.procOn and SP.ProcGlow_Stop then SP.ProcGlow_Stop(b.plate, "ics") b.procOn = nil end
	Core:HideTooltipFor(b)
end

-- a hint's color: plain numbers (a table, or a function that answers r, g, b); nil = unset
local function PicColor(pic, dr, dg, db)
	local c = pic and pic.color
	if type(c) == "function" then
		local r, g, b = Call(c)
		if type(r) == "number" and type(g) == "number" and type(b) == "number" then return r, g, b end
	elseif type(c) == "table" then
		local r, g, b = tonumber(c[1] or c.r), tonumber(c[2] or c.g), tonumber(c[3] or c.b)
		if r and g and b then return r, g, b end
	end
	return dr, dg, db
end
local goneScratch = {}
GoneRGB = function(c) goneScratch.color = c; return PicColor(goneScratch, 1, 1, 1) end

local function GlowShape(pic, ctx)
	local s = pic and pic.shape
	if s == nil and SP.opt then s = SP.opt.glowShape end
	if s == nil or s == "" then s = "default" end
	return s
end

-- the room a picture needs above and below its plate: a glow reaches past the icon
local function PicRoom(pic)
	local k = pic and pic.kind
	if k == "glow" or k == "flash" then return GLOW_ROOM end
	return 0
end

-- the Proc Glow ring on a tile's plate: the ring reaches 20% of the icon plus the thickness past each edge
-- (ProcGlow_Start); when that would not fit the stage the icon shrinks and keeps the ring's proportion
local function ProcRing(b, ctx, pic, room, r, g, bl)
	local p = b.plate
	local c
	if not (r > 0.98 and g > 0.98 and bl > 0.98) then c = { r, g, bl, 1 } end
	local out = tonumber(pic.thick) or (SP.ProcGlowOut and SP:ProcGlowOut()) or 0.2
	local stage = PLATE + 2 * room
	local s = min(PLATE, floor(stage / (1.4 + 2 * out)))
	PaintPlate(p, ctx, s)
	p:ClearAllPoints()
	p:SetPoint("TOP", b, "TOP", 0, -(TILE_PAD + room + (PLATE - s) / 2))
	SP.ProcGlow_Start(p, { color = c, key = "ics", startAnim = false, xOffset = s * out, yOffset = s * out })
	b.procOn = true
end

-- the picture: the item's icon on the plate, then the hint's treatment over it; room: the stage's
-- room above and below the plate (PicRoom)
local function PaintPicture(b, ctx, pic, room)
	room = room or 0
	local kind = pic and pic.kind or "plain"
	local p = b.plate
	if kind == "none" then
		p:Hide()
		return 0
	end
	if kind == "color" then
		PaintPlate(p, ctx, PLATE)
		for i = 1, 3 do p.icons[i]:Hide() end
		local r, g, bl = PicColor(pic, 1, 1, 1)
		local f = Fill(b)
		f:SetColorTexture(r, g, bl, 1)
		f:Show()
		return PLATE
	end
	if kind == "sound" then
		PaintPlate(p, ctx, PLATE)
		for i = 1, 3 do p.icons[i]:Hide() end
		local s = Speaker(b)
		local r, g, bl = Core:Color("accentHi")
		for _, t in ipairs(s.parts) do t:SetColorTexture(r, g, bl, 1) end
		s:Show()
		return PLATE
	end
	if kind == "hidden" then
		PaintPlate(p, ctx, PLATE)
		for i = 1, 3 do p.icons[i]:Hide() end
		p:SetAlpha(0.6)
		local w = Word(b)
		w:SetText("nothing")
		w:SetTextColor(Core:Color("textMute"))
		w:Show()
		return PLATE
	end
	PaintPlate(p, ctx, PLATE, kind == "swap" and pic.icon or nil)
	if kind == "faded" then
		p:SetAlpha(tonumber(pic.alpha) or 0.35)
	elseif kind == "gray" then
		for i = 1, 3 do p.icons[i]:SetDesaturated(true); p.icons[i]:SetVertexColor(0.8, 0.8, 0.8) end
	elseif kind == "dark" then
		local v = Veil(b)
		v:SetColorTexture(0, 0, 0, tonumber(pic.alpha) or 0.5)
		v:Show()
	elseif kind == "sweep" then
		local cd = Sweep(b)
		local frac = tonumber(pic.frac) or 0.6
		cd:Show()
		cd:SetCooldown(GetTime() - SWEEP_DUR * (1 - frac), SWEEP_DUR)
		if cd.Pause then cd:Pause() end
		local w = Word(b)
		w:SetText(pic.text or "4")
		w:SetTextColor(Core:Color("text"))
		w:Show()
	elseif kind == "glow" then
		local shape = GlowShape(pic, ctx)
		local r, g, bl = PicColor(pic, 1, 1, 1)
		if shape == "proc" and SP.ProcGlow_Start then
			ProcRing(b, ctx, pic, room, r, g, bl)
		elseif shape == "default" and not (r > 0.98 and g > 0.98 and bl > 0.98) then
			-- the game's square glow art is gold: a colored square glow is drawn as a soft border in the color
			local f = SquareGlow(b)
			for _, tx in pairs(f.spBorder) do tx:SetColorTexture(r, g, bl, 0.85) end
			f:Show()
		else
			local t = Glow(b)
			if SP.PaintGlowShape then SP:PaintGlowShape(t, shape) end
			t:SetSize(PLATE * GLOW_SCALE, PLATE * GLOW_SCALE)
			t:SetVertexColor(r, g, bl, 1)
			t:Show()
		end
		if pic.pulse then Bulge(p, p:GetWidth(), 1.18) end   -- (the plate may have shrunk for a thick ring)
	elseif kind == "pulse" then
		Bulge(p, PLATE, 1.18)
	elseif kind == "word" then
		local w = Word(b)
		w:SetText(pic.text or "")
		w:SetTextColor(Core:Color("text"))
		w:Show()
	elseif kind == "number" then
		local w = Big(b)
		w:SetText(pic.text or "3")
		w:SetTextColor(Core:Color("text"))
		w:Show()
	elseif kind == "corner" then
		local c = Corner(b)
		c.icon:SetTexture(pic.icon)
		c.icon:SetVertexColor(PicColor(pic, 1, 1, 1))
		c:Show()
	elseif kind == "edge" then
		local r, g, bl = PicColor(pic, Core:Color("accent"))
		local thick = max(1, min(4, floor((tonumber(pic.thick) or 3) + 0.5)))
		if pic.dotted then
			Dots(b, thick, r, g, bl)
		else
			local e = Edge(b, thick)
			if e.spBorder then
				for _, t in pairs(e.spBorder) do t:SetColorTexture(r, g, bl, 1) end
			end
			e:Show()
		end
	elseif kind == "orbs" then
		-- the module's strip: the empty orbs behind, the filled ones over them (cropped to `frac`, whole orbs)
		local back, fill = Orbs(b)
		local w = PLATE + 8
		local h = max(6, floor(w * (tonumber(pic.aspect) or 0.25) + 0.5))
		local frac = max(0, min(1, tonumber(pic.frac) or 1))
		local r, g, bl = PicColor(pic, 1, 1, 1)
		back:SetSize(w, h)
		back:SetTexture(pic.back)
		if pic.backColor then
			local c = pic.backColor
			back:SetVertexColor(c[1], c[2], c[3], c[4] or 0.9)
		else
			back:SetVertexColor(r * 0.55, g * 0.55, bl * 0.55, 0.9)
		end
		back:SetShown(pic.empty ~= false)
		fill:SetSize(max(1, floor(w * frac + 0.5)), h)
		fill:SetTexture(pic.file)
		fill:SetTexCoord(0, frac, 0, 1)
		fill:SetBlendMode(pic.add and "ADD" or "BLEND")
		fill:SetVertexColor(r, g, bl, 1)
		fill:SetShown(frac > 0)   -- (an empty strip: no sliver)
		b.extraH = h + 6 + BarGone(b, back, pic, pic.file)   -- (the caption clears the strip)
	elseif kind == "bar" then
		local bg, fill = Bar(b)
		local r, g, bl = PicColor(pic, Core:Color("accentHi"))
		fill:SetColorTexture(r, g, bl, 1)
		local frac = tonumber(pic.frac) or 0.6
		fill:SetWidth(max(1, PLATE * frac))
		bg:Show(); fill:SetShown(frac > 0)   -- (an empty bar: no sliver)
		b.extraH = 8 + BarGone(b, bg, pic, nil)   -- (the caption clears the bar)
	elseif kind == "redx" then
		RedX(b):Show()
	elseif kind == "tint" then
		local r, g, bl = PicColor(pic, 1, 0.2, 0.2)
		for i = 1, 3 do p.icons[i]:SetVertexColor(r, g, bl) end
	elseif kind == "flash" then
		local t = Glow(b)
		if SP.PaintGlowShape then SP:PaintGlowShape(t, "default") end
		t:SetSize(PLATE * GLOW_SCALE, PLATE * GLOW_SCALE)
		t:SetVertexColor(1, 0.82, 0, 1)
		t:Show()
		local n = Name(b)
		n:SetText(ctx.item.name or "")
		n:ClearAllPoints()
		n:SetPoint("TOP", p, "BOTTOM", 0, -3)
		n:Show()
		return PLATE + 14
	end
	return PLATE + (b.extraH or 0)
end

-- one tile laid out: returns its height
local function FillTile(b, ctx, spec, room)
	ResetTile(b)
	room = room or 0
	b.picked = spec.picked and true or false
	b.disabled = spec.disabled and true or false
	b.onClick = spec.onClick
	b.tip, b.tipTitle = spec.tip, spec.caption
	if room > 0 then
		b.plate:ClearAllPoints()
		b.plate:SetPoint("TOP", b, "TOP", 0, -(TILE_PAD + room))
	end
	local picH = PaintPicture(b, ctx, spec.pic, room)
	b.noPic = picH == 0
	b.caption:SetText(spec.caption or "")
	b.caption:ClearAllPoints()
	local capTop = TILE_PAD
	if picH > 0 then capTop = TILE_PAD + 2 * room + picH + CAP_GAP elseif spec.check then capTop = TILE_PAD + CHECK end
	b.caption:SetPoint("TOP", b, "TOP", 0, -capTop)
	b.caption:SetTextColor(Core:ColorIf(b.disabled, "textMute", b.picked and "text" or "textDim"))
	local capH = ceil(b.caption:GetStringHeight())
	local h = capTop + capH + TILE_PAD
	b:SetHeight(h)
	b.lit:SetShown(b.picked)
	Core:SetBorderColor(b, b.picked and "accentHi" or "border")
	if spec.check then
		b.check:Show()
		b.check.fill:SetShown(spec.on and true or false)
		Core:SetBorderColor(b.check, spec.on and "accentHi" or "border")
	end
	if b.disabled then b:SetAlpha(0.55) end
	return h
end

-- a row of tiles wrapping to the width: returns the height used
local setTiles = {}
local function TilesRow(ctx, parent, x, y, w, specs)
	if #specs == 0 then return 0 end
	local per = max(1, floor((w + TILE_GAP) / (TILE_W + TILE_GAP)))
	-- a glowing picture's room goes to the whole set, so every plate sits level
	local room = 0
	for _, spec in ipairs(specs) do room = max(room, PicRoom(spec.pic)) end
	-- every picture tile of the set as tall as its tallest (one grid); a caption-only tile keeps its
	-- height, centered on its line
	wipe(setTiles)
	local setH = 0
	for i, spec in ipairs(specs) do
		local b = Take("tile", parent, NewTile)
		local h = FillTile(b, ctx, spec, room)
		b.lineNo, b.colNo = floor((i - 1) / per), (i - 1) % per
		setTiles[i] = b
		if not b.noPic then setH = max(setH, h) end
	end
	-- a line's height: the set's where it holds a picture; a line of captions alone stays short
	local lineH, lines = {}, 0
	for _, b in ipairs(setTiles) do
		local ln = b.lineNo + 1
		lines = max(lines, ln)
		if not b.noPic then lineH[ln] = setH
		elseif lineH[ln] ~= setH then lineH[ln] = max(lineH[ln] or 0, b:GetHeight()) end
	end
	local lineY, ty = {}, y
	for ln = 1, lines do lineY[ln] = ty; ty = ty + (lineH[ln] or 0) + TILE_GAP end
	for _, b in ipairs(setTiles) do
		local ln = b.lineNo + 1
		local by = lineY[ln]
		if b.noPic then by = by + (lineH[ln] - b:GetHeight()) / 2 else b:SetHeight(setH) end
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + b.colNo * (TILE_W + TILE_GAP), -by)
	end
	wipe(setTiles)
	return ty - y - TILE_GAP
end

-- ---------------------------------------------------------------------------
-- A change: the page as the menus do it (the row's onChanged), then drawn again
-- ---------------------------------------------------------------------------
local redrawQueued = false
local function Redraw()
	if redrawQueued then return end
	redrawQueued = true
	C_Timer.After(0, function()
		redrawQueued = false
		Refresh()
	end)
end
local function Changed(ctx)
	local fn = ctx.onChanged
	if fn then
		local ok, err = pcall(fn)
		if not ok then Report(err) end
	end
	Redraw()
end
local function Refuse(ctx)
	local row = ctx.row
	if row and row.RefuseLocked then return row:RefuseLocked() end
	return false
end
local function Locked(ctx)
	local def = ctx.def
	return (def.locked and Call(def.locked)) and true or false
end

-- ---------------------------------------------------------------------------
-- The entries of a card: pictures for the choices, rows for the rest
-- ---------------------------------------------------------------------------
local scratch, specs = {}, {}

local function PathTo(path, entry, index)
	local p = {}
	for i = 1, #path do p[i] = path[i] end
	p[#p + 1] = { text = entry.text, index = index }
	return p
end

-- an entry's disabled flag or one of its parents', read again when asked
local function Disabled(ctx, p, forced)
	local m = M()
	local def, item = ctx.def, ctx.item
	local prefix = {}
	return function()
		if forced or Locked(ctx) then return true end
		for d = 1, #p do
			prefix[d] = p[d]
			for k = #prefix, d + 1, -1 do prefix[k] = nil end
			local e = m.Resolve(def, item, prefix)
			if e and m.Disabled(e) then return true end
		end
		return false
	end
end

local function RowOpts(ctx, card, label, desc, x, y, w, disabled)
	return {
		label = label, desc = desc, x = x, y = y, width = w, inCard = true, section = card,
		disabled = disabled, onChanged = function() Changed(ctx) end,
	}
end

-- the live picture beside a slider (what the value changes); a color row is a plain swatch row (the
-- choice tiles show where the color goes)
local LIVE = { size = true, opacity = true, thick = true, count = true }

local function LiveSpec(ctx, entry, kind, p)
	local pic = entry.pic
	if kind == "slider" then
		local sl = entry.slider
		local v = tonumber(sl and sl.get and Call(sl.get)) or 0
		local lo, hi = tonumber(sl.min) or 0, tonumber(sl.max) or 100
		local t = (hi > lo) and (v - lo) / (hi - lo) or 1
		local pk = pic.kind
		if pk == "size" then
			return { pic = { kind = "plain" }, caption = "", scale = 0.45 + 0.55 * t }
		elseif pk == "opacity" then
			local a = v
			if hi > 1 then a = v / 100 end   -- (a 0..100 slider)
			return { pic = { kind = "faded", alpha = max(0.05, min(1, a)) }, caption = "" }
		elseif pk == "thick" then
			return { pic = { kind = "glow", shape = pic.shape or "proc", color = pic.color, thick = v }, caption = "" }
		elseif pk == "count" then
			return { pic = { kind = "number", text = tostring(floor(v + 0.5)) }, caption = "" }
		end
	end
	return nil
end

local RenderEntries   -- (recursive)

-- a slider or a color row, with its live picture on the left when the hint says what it changes
local function PaintLive(tile, ctx, spec)
	local room = 0
	if PicRoom(spec.pic) > 0 then room = LIVE_ROOM end
	FillTile(tile, ctx, spec, room)
	if spec.scale then
		local s = PLATE * spec.scale
		tile.plate:SetSize(s, s)
		PaintPlate(tile.plate, ctx, s)
		tile.plate:ClearAllPoints()
		tile.plate:SetPoint("TOP", tile, "TOP", 0, -(TILE_PAD + (PLATE - s) / 2))
	end
	local lw = LIVE_W
	if room > 0 then lw = TILE_W end   -- (a ring needs the whole tile's width)
	tile:SetSize(lw, TILE_PAD + 2 * room + PLATE + TILE_PAD)
end
-- a slider row with its live picture at its right, beside the control
local function LiveRow(ctx, card, x, y, w, entry, kind, p, disabled, make)
	local spec = entry.pic and LIVE[entry.pic.kind] and LiveSpec(ctx, entry, kind, p) or nil
	local body = card:GetParent()
	local tile, repaint, tw = nil, nil, 0
	if spec then
		tile = Take("tile", body, NewTile)
		PaintLive(tile, ctx, spec)
		tw = tile:GetWidth()
		tile:SetPoint("TOPRIGHT", body, "TOPLEFT", x + w, -y)
		-- while the slider is held: the picture follows the value in place, the page is left alone
		repaint = function()
			local s2 = LiveSpec(ctx, entry, kind, p)
			if s2 and tile:IsShown() then PaintLive(tile, ctx, s2) end
		end
	end
	local rw = w
	if tile then rw = w - tw - TILE_GAP end
	local f, h = make(x, rw, nil, repaint)
	if tile then
		local th = tile:GetHeight()
		if th > h then   -- the row centered on its picture
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", body, "TOPLEFT", x, -(y + floor((th - h) / 2)))
			h = th
		end
	end
	return h
end

-- a choice row's name over its pictures, when the card holds more than that one row
local function RowLabel(body, x, y, w, entry, disabled)
	local _, th = Text(body, x, y + 4, w, entry.text or "", Core.fonts.row, disabled and "textMute" or "textDim")
	return th + 10
end

-- rootIndex: a top-level row drawn alone in its card keeps its index in the menu (the path's fallback)
RenderEntries = function(ctx, card, x, y, w, list, path, forced, skipChoices, rootIndex)
	local m = M()
	local def, item, body = ctx.def, ctx.item, card:GetParent()
	local pendingOn = {}   -- on / off rows drawn as part of a run
	local count = 0
	for _, e in ipairs(list) do
		if type(e) == "table" and not e.separator and not e.label and not (skipChoices and e.selected ~= nil) then count = count + 1 end
	end
	local several = count > 1
	for index, entry in ipairs(list) do
		if type(entry) == "table" and not entry.label and not (skipChoices and entry.selected ~= nil) then
			local sub = entry.sub and m.Sub(entry) or nil
			local kind = m.Kind(entry, sub)
			local p = PathTo(path, entry, rootIndex or index)
			local disabled = Disabled(ctx, p, forced)
			local mixed = kind == "mixed" or kind == "mixedonoff"
			if kind == "mixedonoff" then kind = "onoff" elseif kind == "mixed" then kind = "choice" end

			if kind == "sep" then
				y = y + SEP_GAP

			elseif kind == "group" and m.OnlyButtons(sub) then
				-- a list of targets (Copy Settings To...): one dropdown, a pick runs that line
				local o = RowOpts(ctx, card, entry.text, entry.tip, x, y, w, disabled)
				local labels = {}
				o.values = function()
					local v = {}
					local e = m.Resolve(def, item, p)
					for i, c in ipairs(m.Choices(e, scratch)) do v[i] = c.text or ""; labels[i] = c.text end
					return v
				end
				o.order = function()
					local order = {}
					local e = m.Resolve(def, item, p)
					for i in ipairs(m.Choices(e, scratch)) do order[i] = i end
					return order
				end
				o.get = function() return nil end
				o.set = function(i)
					if Refuse(ctx) then return end
					local e = m.Resolve(def, item, p)
					local list2, c = m.Choices(e, scratch), nil
					for _, xx in ipairs(list2) do if labels[i] ~= nil and xx.text == labels[i] then c = xx end end
					c = c or list2[i]
					if not c or m.Disabled(c) then return end
					m.Invalidate()
					if c.onClick then Call(c.onClick) end
					Changed(ctx)
				end
				local _, h = Widgets:Dropdown(body, o)
				y = y + h

			elseif kind == "group" then
				-- a group inside a card: its heading line, then its rows
				local vt
				if entry.value then vt = Call(entry.value) end
				local dimmed = (forced or m.Disabled(entry)) and true or false
				local f, th = Text(body, x, y + 6, w, strupper(entry.text or ""), Core.fonts.group,
					dimmed and "textMute" or "accentHi")
				if vt and vt ~= "" then
					local v = Take("text", body, NewText)
					v:SetPoint("TOPLEFT", body, "TOPLEFT", x + f.text:GetStringWidth() + 8, -(y + 6))
					v.text:SetFontObject(Core.fonts.strip)
					v.text:SetWidth(w - f.text:GetStringWidth() - 8)
					v.text:SetText(tostring(vt))
					v.text:SetTextColor(Core:Color("textDim"))
					v:SetSize(w, th)
				end
				y = y + max(GROUP_H, th + 10)
				y = RenderEntries(ctx, card, x, y, w, sub, p, forced)

			elseif kind == "choice" and #m.Choices(entry, scratch, true) > MANY then
				-- a long list (every sound, every spell): a dropdown row, as the old look draws it
				local o = RowOpts(ctx, card, entry.text, entry.tip, x, y, w, disabled)
				local labels = {}
				o.values = function()
					local v = {}
					for i, c in ipairs(m.Choices(m.Resolve(def, item, p), scratch, true)) do v[i] = c.text or ""; labels[i] = c.text end
					return v
				end
				o.order = function()
					local order = {}
					for i in ipairs(m.Choices(m.Resolve(def, item, p), scratch, true)) do order[i] = i end
					return order
				end
				o.get = function()
					for i, c in ipairs(m.Choices(m.Resolve(def, item, p), scratch, true)) do
						if c.selected then return i end
					end
					return nil
				end
				o.set = function(i)
					if Refuse(ctx) then return end
					local list2, c = m.Choices(m.Resolve(def, item, p), scratch, true), nil
					for _, xx in ipairs(list2) do if labels[i] ~= nil and xx.text == labels[i] then c = xx end end
					c = c or list2[i]
					if not c or m.Disabled(c) then return end
					m.Invalidate()
					if c.onClick then Call(c.onClick) end
					Changed(ctx)
				end
				local _, h = Widgets:Dropdown(body, o)
				y = y + h
				if mixed then y = RenderEntries(ctx, card, x, y, w, sub, p, forced, true) end

			elseif kind == "choice" or kind == "multi" then
				if several then y = y + RowLabel(body, x, y, w, entry, disabled()) end
				wipe(specs)
				local choices = m.Choices(entry, scratch, true)
				for ci, c in ipairs(choices) do
					local text = c.text
					local pic = c.pic or entry.pic
					specs[#specs + 1] = {
						caption = text, picked = c.selected and true or false, on = c.selected and true or false,
						check = kind == "multi", pic = pic, tip = c.tip, disabled = m.Disabled(c) or disabled(),
						-- (a pick-any list keeps every pick's picture; its check says whether it is on)
						onClick = function()
							if Refuse(ctx) then return end
							local e = m.Resolve(def, item, p)
							local cc
							for _, xx in ipairs(m.Choices(e, scratch, true)) do if xx.text == text then cc = xx end end
							cc = cc or m.Choices(e, scratch, true)[ci]
							if not cc or m.Disabled(cc) then return end
							if kind == "choice" and cc.selected and not cc.onClick then return end
							m.Invalidate()
							if cc.onClick then Call(cc.onClick) end
							Changed(ctx)
						end,
					}
				end
				y = y + TilesRow(ctx, body, x, y, w, specs) + (mixed and SEP_GAP or 0)
				if mixed or kind == "multi" then y = RenderEntries(ctx, card, x, y, w, sub, p, forced, true) end

			elseif kind == "onoff" then
				if not pendingOn[entry] then   -- (else: drawn already, with the on / off row before it)
					-- this on / off row and the plain on / off rows right after it: one line of tiles
					wipe(specs)
					local run = {}
					for j = index, #list do
						local e2 = list[j]
						if type(e2) ~= "table" or e2.separator then break end
						if j > index then
							local s2 = e2.sub and m.Sub(e2) or nil
							if m.Kind(e2, s2) ~= "onoff" then break end
							pendingOn[e2] = true
						end
						run[#run + 1] = { entry = e2, index = (j == index) and (rootIndex or j) or j }
						if mixed then break end   -- (its other rows go under it: a line of its own)
					end
					for _, r in ipairs(run) do
						local e2, p2 = r.entry, PathTo(path, r.entry, r.index)
						local on = false
						for _, c in ipairs(m.Choices(e2, scratch, true)) do
							if c.text == "On" then on = c.selected and true or false end
						end
						local d2 = Disabled(ctx, p2, forced)
						local pic2   -- the ON picture when it is on; off: the plain icon with the check off
						if on then pic2 = e2.pic end
						specs[#specs + 1] = {
							caption = e2.text, picked = on, on = on, check = true, pic = pic2, tip = e2.tip, disabled = d2(),
							onClick = function()
								if Refuse(ctx) then return end
								local e = m.Resolve(def, item, p2)
								local want = on and "Off" or "On"
								for _, c in ipairs(m.Choices(e, scratch, true)) do
									if c.text == want then
										if m.Disabled(c) then return end
										m.Invalidate()
										if c.onClick then Call(c.onClick) end
										Changed(ctx)
										return
									end
								end
							end,
						}
					end
					y = y + TilesRow(ctx, body, x, y, w, specs) + (mixed and SEP_GAP or 0)
					if mixed then y = RenderEntries(ctx, card, x, y, w, sub, p, forced, true) end
				end

			elseif kind == "slider" then
				-- the right-click menu's own slider row (ContextMenu.lua SliderRow): the same code the menu
				-- drags with; the live picture follows each value it hands to the item
				local h = LiveRow(ctx, card, x, y, w, entry, "slider", p, disabled, function(rx, rw, label, repaint)
					local sl = entry.slider
					-- a percentage drags in 1% steps whatever its step, as the settings pages' sliders do (a
					-- 5% step leaves the thumb sixteen places on the track)
					local step = sl.step
					if sl.isPercent and step then step = math.min(step, 0.01) end
					local guarded = setmetatable({ step = step, set = function(v)
						if Refuse(ctx) then return end
						if sl.set then return sl.set(v) end
					end }, { __index = sl })
					local b = Take("mslider", body, NewMenuSlider)
					b:SetPoint("TOPLEFT", body, "TOPLEFT", rx, -y)
					ns.ContextMenu.SliderRow.Fill(b, { text = entry.text, slider = guarded, disabled = disabled() }, rw,
						ctx.element, function() if repaint then repaint() end end)
					local tipTitle
					if entry.tip then tipTitle = entry.text end
					Core:AttachTooltip(b, tipTitle, entry.tip)
					return b, b:GetHeight()
				end)
				y = y + h

			elseif kind == "swatch" then
				local h = LiveRow(ctx, card, x, y, w, entry, "swatch", p, disabled, function(rx, rw, label)
					local o = RowOpts(ctx, card, label or entry.text, entry.tip, rx, y, rw, disabled)
					o.hasAlpha = false
					o.get = function()
						local e = m.Resolve(def, item, p)
						local s = e and e.swatch
						if s then return s[1] or 1, s[2] or 1, s[3] or 1, 1 end
						return 1, 1, 1, 1
					end
					o.set = function() end
					o.click = function()
						if Refuse(ctx) then return end
						m.Invalidate()
						local e = m.Resolve(def, item, p)
						local fn = e and e.onClick
						if not fn and e and e.sub then
							local first = m.Choices(e, scratch)[1]
							fn = first and first.onClick
						end
						if fn then Call(fn) end
					end
					return Widgets:Color(body, o)
				end)
				y = y + h

			elseif kind == "button" then
				local o = RowOpts(ctx, card, entry.text, entry.tip, x, y, w, disabled)
				o.buttonText = entry.text
				if entry.value then
					local vt = Call(entry.value)
					if vt ~= nil and vt ~= "" then o.buttonText = entry.text .. ": " .. tostring(vt) end
				end
				o.func = function()
					if Refuse(ctx) then return end
					m.Invalidate()
					local e = m.Resolve(def, item, p)
					if e and e.onClick then Call(e.onClick) end
					Changed(ctx)
				end
				local _, h = Widgets:Button(body, o)
				y = y + h

			else   -- a line that only says something (Button Key: Not Set)
				local vt
				if entry.value then vt = Call(entry.value) end
				vt = vt ~= nil and tostring(vt) or nil
				local _, h = Widgets:Description(body, {
					text = vt and (entry.text .. ": " .. vt) or entry.text,
					x = x, y = y, width = w, inCard = true, section = card,
				})
				y = y + h
			end
		end
	end
	return y
end

-- ---------------------------------------------------------------------------
-- A card: its strip (the group's name, its words after it), its entries, two columns
-- ---------------------------------------------------------------------------
local function Card(ctx, body, x, y, w, title, words, list, path, forced, rootIndex)
	local card = Widgets:Card(body, { x = x, y = y, width = w, element = ctx.element, label = title })
	local cy = y + Widgets.STRIP_H
	if words and words ~= "" then
		local lw = card.label:GetStringWidth()
		local room = w - 26 - lw - 22
		local f = Take("text", body, NewText)
		f.text:SetFontObject(Core.fonts.strip)
		f.text:SetTextColor(Core:Color("textMute"))
		f.text:SetWordWrap(false)
		f.text:SetWidth(0)
		f.text:SetText(words)
		if f.text:GetStringWidth() <= room then
			f:SetPoint("TOPLEFT", body, "TOPLEFT", x + 26 + lw + 10, -(y + 8))
			f.text:SetWidth(room)
			f:SetSize(room, 12)
		else
			-- too long for the strip: its own line under it, wrapped, never cut short
			f.text:SetWordWrap(true)
			f.text:SetWidth(w - 2 * CARD_PAD)
			f:SetPoint("TOPLEFT", body, "TOPLEFT", x + CARD_PAD, -(cy + 6))
			local th = ceil(f.text:GetStringHeight())
			f:SetSize(w - 2 * CARD_PAD, th)
			cy = cy + th + 6
		end
	end
	cy = cy + CARD_PAD
	cy = RenderEntries(ctx, card, x + CARD_PAD, cy, w - 2 * CARD_PAD, list, path, forced, nil, rootIndex)
	local h = cy - y + CARD_PAD
	Widgets:CardFinish(card, h)
	return card, h
end

-- the item's own on / off (its icon's click), worded from the row's hint
-- nil: a click that does something else (a loadout's click switches to it): no switch in the header
local function TitleCase(s) return (s:gsub("(%a)([%w']*)", function(a, rest) return a:upper() .. rest end)) end
local function ToggleWords(def, name)
	local hint = type(def.hint) == "string" and def.hint:match("^Click:%s*([^\n]+)") or nil
	if not hint then return nil end
	local h = hint:lower()
	local desc = (h:gsub("^%l", string.upper)) .. "."
	local rest = h:match("^show or hide (.+)$")
	if rest then
		if rest == "it" then return "Show " .. name, desc end
		return "Show " .. TitleCase((rest:gsub("^it ", name .. " "))), desc
	end
	if h:find("^watch it") then return "Watch " .. name, desc end
	if h:find("^track it") then return "Track " .. name, desc end
	if h:find("^flash it") then return "Flash " .. name .. " When Ready", desc end
	if h:find("turn it on or off", 1, true) then return "Alert On", desc end
	return nil
end

-- a bevel button (the back link and the bottom row), pooled
local function NewButton(parent)
	local b = Core:MakeButton(parent, "", 0, false)
	return b
end
local function Button(parent, x, y, text, onClick, disabled, primary)
	local b = Take("button", parent, NewButton)
	b.text:SetText(text)
	b:SetWidth(max(0, b.text:GetStringWidth() + 28))
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	b:SetScript("OnClick", onClick)
	if disabled then b:Disable(); b:SetAlpha(0.5) else b:Enable(); b:SetAlpha(1) end
	return b, b:GetWidth()
end

-- ---------------------------------------------------------------------------
-- The screen
-- ---------------------------------------------------------------------------
function IconScreen:Render(body, fullW, element, onChanged)
	local m = M()
	if not (open and m) then return nil, 0 end
	local row = open.row
	local def = DefOf(row)
	local item = FindItem(row, open.key)
	if not item then open = nil return nil, 0 end
	-- the menus' Row:Changed (a color picker's every step) reaches the page as it does with icons, then the
	-- pictures follow; a held slider repaints its own picture instead (above)
	row.onChanged = function()
		if onChanged then pcall(onChanged) end
		if not Widgets.sliderDragging then Redraw() end
	end
	local INSET = Widgets.CARD_INSET
	local tex = {}
	local n = Call(def.textures, item, tex) or 0
	local ctx = { row = row, def = def, item = item, body = body, onChanged = onChanged, tex = tex, n = n,
		element = element }
	local name = item.name or tostring(item.key)
	local f = frameOf()
	local pageName = (f and f._current and f._current.label) or "Back"
	if ns.Tree and ns.Tree.StripColor then pageName = ns.Tree:StripColor(pageName) end

	-- the header: a card with the back link, the crumb, the plate, the name, Show This Icon
	local y = 0
	local head = Widgets:Card(body, { x = 0, y = y, width = fullW, element = element })
	local first = head
	local bx = INSET + 12
	Button(body, bx, y + 10, "<  " .. pageName, function() IconScreen:Close() end)
	local crumb = pageName
	if open.tab and open.tab ~= "" then crumb = crumb .. "  /  " .. tostring(open.tab) end
	Text(body, bx, y + 42, fullW - bx - 260, crumb .. "  /  " .. name, Core.fonts.tiny, "textMute")
	local plate = Take("frame", body, NewPlate)
	plate:SetPoint("TOPLEFT", body, "TOPLEFT", bx, -(y + 56))
	PaintPlate(plate, ctx, PLATE)
	if def.overlay then
		local word = Call(def.overlay, item)
		if word and word ~= "" then
			if not plate.word then
				local o = plate:CreateFontString(nil, "OVERLAY")
				o:SetFont(Core.fonts.tiny:GetFont(), 10, "OUTLINE")
				o:SetPoint("CENTER", plate, "CENTER", 0, 0)
				plate.word = o
			end
			plate.word:SetText(word)
			plate.word:Show()
		elseif plate.word then plate.word:Hide() end
	elseif plate.word then plate.word:Hide() end
	Text(body, bx + PLATE + 14, y + 54, fullW - bx - PLATE - 260, name, Core.fonts.title, "text")
	Text(body, bx + PLATE + 14, y + 82, fullW - bx - PLATE - 260, "Click a picture to pick it.",
		Core.fonts.rowDim, "textDim")
	local label, desc
	if def.toggle and def.shown and not def.clickMenu then label, desc = ToggleWords(def, name) end
	if label then
		local o = RowOpts(ctx, head, label, desc, fullW - INSET - 230, y + 58, 218,
			function() return Locked(ctx) end)
		o.get = function() return Call(def.shown, item) and true or false end
		o.set = function(v)
			if Refuse(ctx) then return end
			m.Invalidate()
			if (Call(def.shown, item) and true or false) ~= (v and true or false) then Call(def.toggle, item) end
			if row.Repaint then row:Repaint() end
		end
		Widgets:Toggle(body, o)
	end
	Widgets:CardFinish(head, HEAD_H + 10)
	y = y + HEAD_H + 10 + CARD_GAP

	-- the cards: one per group, full width, in the menu's order (a row of choices needs the width: six
	-- tiles to a line); a choice / on-off / slider / color of its own gets a card of its own; the
	-- buttons at the end (Copy Settings, Hide, Reset) make the bottom row
	local list = m.Of(def, item)
	local footer = {}
	local footerSeen = false
	for index, entry in ipairs(list) do
		if type(entry) == "table" and not entry.separator and not entry.label then
			local sub = entry.sub and m.Sub(entry) or nil
			local kind = m.Kind(entry, sub)
			if kind == "button" then
				footer[#footer + 1] = { entry = entry, index = index }
				footerSeen = true
			elseif kind ~= "sep" then
				local title = entry.text or ""
				local words = entry.words
				local one = { entry }
				local cardList, path, forced = one, {}, false
				if kind == "group" and not m.OnlyButtons(sub) then
					cardList, path = sub, { { text = entry.text, index = index } }
					forced = m.Disabled(entry) and true or false
					if not words and entry.value then
						local vt = Call(entry.value)
						if vt and vt ~= "" then words = tostring(vt) end
					end
				end
				local _, h = Card(ctx, body, 0, y, fullW, title, words, cardList, path, forced,
					(cardList == one) and index or nil)
				y = y + h + CARD_GAP
			end
		end
	end
	if footerSeen then
		local bx2 = INSET + 12
		local fy = y + 4
		local lineH = 0
		for _, fb in ipairs(footer) do
			local e = fb.entry
			local text = e.text or ""
			if e.value then
				local vt = Call(e.value)
				if vt ~= nil and vt ~= "" then text = text .. ": " .. tostring(vt) end
			end
			local disabled = (e.disabled == true) or (type(e.disabled) == "function" and Call(e.disabled)) or Locked(ctx)
			local b, bw = Button(body, bx2, fy, text, function()
				if Refuse(ctx) then return end
				m.Invalidate()
				local ee = m.Resolve(def, item, { { text = e.text, index = fb.index } })
				if ee and ee.onClick then Call(ee.onClick) end
				Changed(ctx)
			end, disabled)
			if bx2 + bw > fullW - INSET then   -- a new line of buttons
				fy = fy + 26 + 8
				bx2 = INSET + 12
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", body, "TOPLEFT", bx2, -fy)
			end
			bx2 = bx2 + bw + 10
			lineH = 26
		end
		y = fy + lineH + 8
	end
	return first, y
end

function IconScreen:Release()
	GiveBack("tile", ResetTile)
	GiveBack("frame")
	GiveBack("button", function(b) b:SetScript("OnClick", nil) end)
	GiveBack("text")
	GiveBack("mslider", function(b) b.item, b.onSet = nil, nil end)
end

-- ---------------------------------------------------------------------------
-- Tests and tools: open an item's screen by its row key (ns.CustomRows) and item key
-- ---------------------------------------------------------------------------
function SP:IconScreenOpen(rowKey, itemKey)
	local row = ns.CustomRows and ns.CustomRows[rowKey]
	if not row then return false, "no row " .. tostring(rowKey) end
	local def = DefOf(row)
	if not def or not def.menu then return false, "that row has no menu" end
	if not IconScreen:On() then
		if self.opt then self.opt.iconScreens = true end
	end
	IconScreen:Open(row, itemKey)
	return true
end
function SP:IconScreenClose() IconScreen:Close() end
-- the item keys of a row, in its order (tools: a render of every item's screen)
function SP:IconScreenItems(rowKey)
	local row = ns.CustomRows and ns.CustomRows[rowKey]
	local def = DefOf(row)
	if not (def and def.list) then return {} end
	local out, keys = {}, {}
	Call(def.list, out)
	for _, it in ipairs(out) do keys[#keys + 1] = it.key end
	return keys
end
