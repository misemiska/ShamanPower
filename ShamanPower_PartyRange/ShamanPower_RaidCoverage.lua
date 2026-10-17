-- ShamanPower_RaidCoverage.lua (3.0.9.1): Raid Coverage, its own feature on WoW: Forever.
-- Its own tab (Party Buff Tracker > Raid Coverage), its own panel (ShamanPowerRaidCoverage), its own
-- cells and settings (opt.raidCoverage). Party Coverage (ShamanPower_PartyRange.lua) is untouched:
-- the two run side by side, both on, one on, or none on. Nothing here draws on the party cells and
-- nothing of the party's draws here.
-- In a raid, each raid-wide totem you have down and turned on (Strength of Earth, Grace of Air,
-- Windfury, Flametongue, Fire / Frost / Nature Resistance) gets a cell: the totem's icon, under it
-- who it watches and how many of them have the buff ("Melee · 7/9"), then the names of the ones who
-- do not (red), or everyone it watches with the names in class color (Only Show Who Is Missing off).
-- Out of a fight the answers are reads (UnitHasBuff). In a fight buffs cannot be read on Forever,
-- so the names stay red and the game draws the answer per person: an engine aura slot per watched
-- player (NewPartyAuraSlot, the party's own way) whose child covers the red name with the panel's
-- color, or writes the name in class color, built out of a fight.
local SP = ShamanPower
if not SP then return end
if not (SPCompat and SPCompat.FOREVER) then return end   -- raid-wide totems are WoW: Forever's (the 10-15 patch)

SP.RAID_COVERAGE_TOTEMS = { { 1, 1 }, { 4, 2 }, { 4, 1 }, { 2, 5 }, { 3, 6 }, { 2, 6 }, { 4, 6 } }   -- the icon row's order
local RAID_DEFAULT_PRESET = { ["4:1"] = "melee", ["4:2"] = "melee", ["1:1"] = "melee", ["2:5"] = "ranged" }   -- the resistances: everyone
SP.RAID_WATCH_PRESETS = { { "melee", "Melee" }, { "ranged", "Ranged" }, { "tanks", "Tanks" }, { "healers", "Healers" },
	{ "everyone", "Everyone" }, { "custom", "Custom" } }
local ELEMENT_LABELS = { "Earth", "Fire", "Water", "Air" }
local GetRaidRosterInfoC = (SPCompat and SPCompat.GetRaidRosterInfo) or GetRaidRosterInfo
local raidUnits = {}
for i = 1, 40 do raidUnits[i] = "raid" .. i end
local function Public(v) if issecretvalue and issecretvalue(v) then return nil end return v end

-- ---------------------------------------------------------------------------
-- Settings (the profile: opt.raidCoverage)
-- ---------------------------------------------------------------------------
local function Opts()
	local o = SP.opt
	if not o then return {} end
	o.raidCoverage = o.raidCoverage or {}
	return o.raidCoverage
end
function SP:RaidCoverageOpts() return Opts() end
function SP:RaidCoverageEnabled() return Opts().enabled == true end
function SP:RaidCoverageOn() return self:RaidCoverageEnabled() and not self:IsOff() end
function SP:RaidCoverageMissingOnly() return Opts().missingOnly ~= false end
function SP:RaidCoverageShowsCount() return Opts().showCount ~= false end
function SP:RaidCoverageNoNames() return Opts().noNames == true end   -- Don't Show Names: the icon and its line only
local function IconSize() return Opts().iconSize or 36 end
local function FontSize() return Opts().fontSize or 9 end
local function RowH() return FontSize() + 3 end
local function Opacity() return Opts().opacity or 1 end
-- the line under a cell (Ranged · 1/1): Text Color, the panel's soft gray to start
function SP:RaidCoverageCaptionRGB()
	local c = Opts().captionColor
	if type(c) == "table" then return c.r or 0.62, c.g or 0.68, c.b or 0.76 end
	return 0.62, 0.68, 0.76
end

-- one totem's cell on or off: the icon's click on the Raid Coverage tab (all off to start)
function SP:RaidWatchRule(key)
	local r = Opts()
	r.watch = r.watch or {}
	local rule = r.watch[key]
	if not rule then rule = {}; r.watch[key] = rule end
	return rule
end
-- (reads never make an entry: a fresh profile stays empty until a click)
local function RuleOf(key) local w = Opts().watch; return w and w[key] or nil end
function SP:RaidWatchOn(key) local r = RuleOf(key); return r ~= nil and r.on == true end
function SP:RaidWatchSetOn(key, on)
	self:RaidWatchRule(key).on = on and true or nil
	self:RaidCoverageChanged()
end
function SP:RaidWatchAnyOn()
	for _, t in ipairs(SP.RAID_COVERAGE_TOTEMS) do if self:RaidWatchOn(t[1] .. ":" .. t[2]) then return true end end
	return false
end
-- Who a totem watches: { preset = "melee" | "ranged" | "tanks" | "healers" | "everyone" | "custom",
-- classes = { WARRIOR = true }, specs = { ["PALADIN:retribution"] = true }, people = { ["Garrosh"] = true } }.
-- No entry: the totem's own default preset. (Tanks and Healers are Watch choices; there is no separate roles pick.)
function SP:RaidWatchPreset(key) local r = RuleOf(key); return (r and r.preset) or RAID_DEFAULT_PRESET[key] or "everyone" end
function SP:RaidWatchLabel(key)
	local p = self:RaidWatchPreset(key)
	for _, c in ipairs(SP.RAID_WATCH_PRESETS) do if c[1] == p then return c[2] end end
	return "Everyone"
end
function SP:SetRaidWatchPreset(key, preset)
	self:RaidWatchRule(key).preset = preset
	self:RaidCoverageChanged()
end
function SP:RaidWatchPicked(key, section, id)
	local r = RuleOf(key)
	local t = r and r[section]
	return t and t[id] == true or false
end
function SP:RaidWatchToggle(key, section, id, on)
	local rule = self:RaidWatchRule(key)
	rule[section] = rule[section] or {}
	if on == nil then on = not rule[section][id] end
	rule[section][id] = on and true or nil
	if not next(rule[section]) then rule[section] = nil end
	rule.preset = "custom"
	self:RaidCoverageChanged()
end
function SP:RaidWatchCopy(from, to)
	local src = self:RaidWatchRule(from)
	local function copy(t)
		if not t then return nil end
		local c = {}
		for k, v in pairs(t) do c[k] = v end
		return c
	end
	local r = Opts()
	r.watch = r.watch or {}
	for _, t in ipairs(SP.RAID_COVERAGE_TOTEMS) do
		local key = t[1] .. ":" .. t[2]
		if key ~= from and (to == "all" or to == key) then
			local on = r.watch[key] and r.watch[key].on   -- (on / off is the icon's click, never copied)
			r.watch[key] = { on = on, preset = src.preset, classes = copy(src.classes), specs = copy(src.specs), people = copy(src.people) }
		end
	end
	self:RaidCoverageChanged()
end
function SP:RaidWatchReset(key)
	local r = Opts()
	if r.watch then
		local on = r.watch[key] and r.watch[key].on   -- (its cell stays on or off as it was)
		r.watch[key] = on and { on = true } or nil
	end
	self:RaidCoverageChanged()
end
-- Reset Page Settings on the tab: every totem off and watching its own default, the look as it came
function SP:RaidCoverageResetPage()
	local o = SP.opt
	if o then o.raidCoverage = nil end
	self:RaidCoverageChanged()
end

-- ---------------------------------------------------------------------------
-- Who is watched: roles, specs, the presets, a Custom rule
-- ---------------------------------------------------------------------------
-- a raid member's role: the one picked in the group tool; a raid Main Tank counts as a Tank
local function RoleOf(unit, raidRole)
	local r = UnitGroupRolesAssigned and Public(UnitGroupRolesAssigned(unit))
	if r ~= "TANK" and r ~= "HEALER" and r ~= "DAMAGER" then r = nil end
	if not r and raidRole == "MAINTANK" then r = "TANK" end
	return r
end
-- the spec, as far as it matters here (melee or not): a druid by its power type, a shaman by its own
-- ShamanPower SPEC line, paladin and priest by the role
local function SpecOf(unit, name, class, role)
	if class == "DRUID" then
		local power = UnitPowerType and Public(UnitPowerType(unit))
		if power == 1 or power == 3 or role == "TANK" then return "feral" end
		if role == "HEALER" then return "restoration" end
		if SP.IsDruidFeral and SP:IsDruidFeral(unit) then return "feral" end
		return "balance"
	elseif class == "SHAMAN" then
		local info = SP.AllShamans and name and SP.AllShamans[name]
		local spec = info and info.spec
		if spec == "enh" then return "enhancement" elseif spec == "ele" then return "elemental" elseif spec == "resto" then return "restoration" end
		if role == "HEALER" then return "restoration" end
		if SP.IsShamanEnhancement and SP:IsShamanEnhancement(unit) then return "enhancement" end
		return nil   -- a damage shaman of unknown spec: the melee and the ranged presets both watch it
	elseif class == "PALADIN" then
		if role == "HEALER" then return "holy" elseif role == "TANK" then return "protection" end
		return "retribution"
	elseif class == "PRIEST" then
		if role == "HEALER" then return "holy" end
		return "shadow"
	end
	return nil
end
local MELEE_CLASS = { WARRIOR = true, ROGUE = true }
local RANGED_CLASS = { MAGE = true, WARLOCK = true, HUNTER = true }
local function PresetWatches(preset, role, class, spec)
	if preset == "everyone" then return true end
	if preset == "tanks" then return role == "TANK" end
	if preset == "healers" then return role == "HEALER" end
	if preset == "melee" then
		if MELEE_CLASS[class] then return true end
		if class == "PALADIN" then return spec ~= "holy" end
		if class == "SHAMAN" then return spec == "enhancement" or spec == nil end
		if class == "DRUID" then return spec == "feral" end
		return false
	end
	if preset == "ranged" then
		if RANGED_CLASS[class] then return true end
		if class == "PRIEST" then return spec == "shadow" end
		if class == "SHAMAN" then return spec == "elemental" or spec == nil end
		if class == "DRUID" then return spec == "balance" end
		return false
	end
	return true
end
-- Custom: a name picked is always watched; a section with nothing picked does not narrow the list
-- (nothing picked anywhere but names: those names alone)
local function RuleWatches(rule, preset, name, role, class, spec)
	if preset ~= "custom" then return PresetWatches(preset, role, class, spec) end
	local people, classes, specs = rule.people, rule.classes, rule.specs
	if people and name and people[name] then return true end
	if not (classes or specs) then return not people end
	if classes and class and classes[class] then return true end
	if specs and class and spec and specs[class .. ":" .. spec] then return true end
	return false
end

-- the raid as it is now, read out of a fight: everyone but you (your own totem's buff on you is the
-- totem bar's business). Dead and offline are read again on every pass (PersonCounts).
function SP:RaidCoverageRoster()
	local list = {}
	if not IsInRaid() then return list end
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	for i = 1, math.min(n, 40) do
		local unit = raidUnits[i]
		if Public(UnitExists(unit)) and not Public(UnitIsUnit(unit, "player")) then
			local name, _, subgroup, _, _, class, _, _, _, raidRole = GetRaidRosterInfoC(i)
			name, class = Public(name), Public(class)
			if name and Ambiguate then name = Ambiguate(name, "short") end
			list[#list + 1] = { unit = unit, name = name, class = class, group = Public(subgroup), role = RoleOf(unit, Public(raidRole)) }
		end
	end
	return list
end
local function PersonCounts(unit)
	if UnitIsConnected and Public(UnitIsConnected(unit)) == false then return false end
	if UnitIsDeadOrGhost and Public(UnitIsDeadOrGhost(unit)) == true then return false end
	return true
end
-- the buff a totem gives, every rank (the engine's aura filter)
local function BuffMap(element, index)
	local map = {}
	local base = SP.TotemBuffSpellIDs and SP.TotemBuffSpellIDs[element] and SP.TotemBuffSpellIDs[element][index]
	if base then for _, id in ipairs((SP.TotemBuffRanks and SP.TotemBuffRanks[base]) or { base }) do map[id] = true end end
	return map
end

-- ---------------------------------------------------------------------------
-- The panel and its cells
-- ---------------------------------------------------------------------------
local frame
local function NewRow(btn)
	local row = CreateFrame("Frame", nil, btn)
	row.spNoHoverWalk = true   -- holds the engine's name display: the settings-cog hover walk stays out
	local t = row:CreateFontString(nil, "OVERLAY")
	SP:SetSPFont(t, "labels", FontSize(), "OUTLINE")
	t:SetPoint("LEFT", row, "LEFT", 2, 0)
	t:SetPoint("RIGHT", row, "RIGHT", -2, 0)
	t:SetJustifyH("CENTER")
	t:SetWordWrap(false)
	t:SetTextColor(1, 0.25, 0.25)
	row.text = t
	row:Hide()
	return row
end
local function NewCell(key, element, index)
	local btn = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	SP:ApplyPanelBackdrop(btn)
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	btn.icon = icon
	local overlay = btn:CreateTexture(nil, "OVERLAY")
	overlay:SetAllPoints(icon)
	overlay:SetColorTexture(0.3, 0, 0, 0.6)
	overlay:Hide()
	btn.missingOverlay = overlay
	local cap = btn:CreateFontString(nil, "OVERLAY")
	SP:SetSPFont(cap, "labels", 8, "OUTLINE")
	cap:SetPoint("TOP", btn, "BOTTOM", 0, -1)
	cap:SetTextColor(SP:RaidCoverageCaptionRGB())
	btn.caption = cap
	btn.raidKey, btn.element, btn.index = key, element, index
	btn.rrows, btn.rslots = {}, {}
	btn.cellLabel = (SP.GetTotemName and SP:GetTotemName(element, index)) or ELEMENT_LABELS[element]
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Raid Coverage: " .. self.cellLabel, 1, 0.82, 0)
		GameTooltip:AddLine("Watches: " .. SP:RaidWatchLabel(self.raidKey), 0.7, 0.7, 0.7)
		if Opts().freeCells then GameTooltip:AddLine("ALT+drag to move", 0.7, 0.7, 0.7) end
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- Place Each Totem Freely: the cell on its own, ALT+drag to move, its spot kept (Unlock UI boxes it too)
	btn.spMoverLabel = "Raid Coverage: " .. btn.cellLabel
	btn:SetMovable(true)
	btn:SetClampedToScreen(true)
	btn:RegisterForDrag("LeftButton")
	btn:SetScript("OnDragStart", function(self)
		if Opts().freeCells and IsAltKeyDown() then self:StartMoving() end
	end)
	btn:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if Opts().freeCells then
			local o = Opts()
			o.cells = o.cells or {}
			o.cells[self.raidKey] = o.cells[self.raidKey] or {}
			o.cells[self.raidKey].position = SP:SavePositionRecord(self)
		end
	end)
	btn:Hide()
	return btn
end
-- Place Each Totem Freely: a cell on its own (under UIParent), at its saved spot, or spread in a row to start
local freeOrder = 0
local function PlaceFree(btn)
	if btn:GetParent() ~= UIParent then
		btn:SetParent(UIParent)
		btn:SetFrameStrata("MEDIUM")
	end
	btn:EnableMouse(true)
	if not btn.freePlaced then
		btn.freePlaced = true
		local o = Opts()
		local rec = o.cells and o.cells[btn.raidKey] and o.cells[btn.raidKey].position
		if not SP:ApplyPositionRecord(btn, rec) then
			if not btn.freeSlot then freeOrder = freeOrder + 1; btn.freeSlot = freeOrder end
			btn:ClearAllPoints()
			btn:SetPoint("CENTER", UIParent, "CENTER", (btn.freeSlot - 4) * 70, 40)
		end
	end
end
local function ReturnToPanel(btn)
	if frame and btn:GetParent() ~= frame then btn:SetParent(frame) end
	btn:EnableMouse(false)
	btn.freePlaced = nil
end
function SP:RaidCoverageFreeCells() return Opts().freeCells == true end
-- the cells turned on (Unlock UI's boxes with Place Each Totem Freely)
function SP:RaidCoverageFreeCellList()
	local out = {}
	local f = self:CreateRaidCoverageFrame()
	for _, t in ipairs(SP.RAID_COVERAGE_TOTEMS) do
		local key = t[1] .. ":" .. t[2]
		if self:RaidWatchOn(key) and f.cells[key] then out[#out + 1] = f.cells[key] end
	end
	return out
end
-- one cell's spot back (Unlock UI's Reset on its box), or the panel's
function SP:ResetRaidCoverageCellPosition(btn)
	local o = Opts()
	if o.freeCells and btn and btn.raidKey then
		if o.cells and o.cells[btn.raidKey] then o.cells[btn.raidKey].position = nil end
		btn.freePlaced = nil
	else
		self:ResetRaidCoveragePosition()
	end
	self:RaidCoverageChanged()
end
-- every spot back (Reset All Positions): the panel's and each cell's
function SP:ResetRaidCoveragePositions()
	local o = Opts()
	o.position = nil
	for _, c in pairs(o.cells or {}) do if type(c) == "table" then c.position = nil end end
	if frame then
		frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		for _, btn in pairs(frame.cells) do btn.freePlaced, btn.freeSlot = nil, nil end
		freeOrder = 0
	end
	self:RaidCoverageChanged()
end
function SP:CreateRaidCoverageFrame()
	if frame then return frame end
	local o = Opts()
	frame = CreateFrame("Frame", "ShamanPowerRaidCoverage", UIParent, "BackdropTemplate")
	frame:SetSize(150, 60)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	SP:ApplyPanelBackdrop(frame, nil, "mod.coverage-colors")   -- (the coverage panels' colors on Appearance > Themes)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOP", frame, "TOP", 0, -6)
	title:SetText("Raid Coverage")
	SP:SetSPFont(title, "labels", 11, "", STANDARD_TEXT_FONT)
	title:SetShadowOffset(1, -1)
	title:SetTextColor(0.902, 0.918, 0.941)
	frame.title = title
	local settingsBtn = CreateFrame("Button", nil, frame)
	settingsBtn:SetSize(14, 14)
	settingsBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	SP:StyleSettingsButton(settingsBtn)
	settingsBtn:SetScript("OnClick", function() SP:OpenFrameSettings("raidcoverage", frame) end)
	settingsBtn:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Raid Coverage settings", 1, 1, 1)
		GameTooltip:Show()
	end)
	settingsBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
	frame.settingsBtn = settingsBtn
	frame.spMoverLabel = "Raid Coverage"
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if not self:IsMovable() then return end
		if Opts().hideBorder and not IsAltKeyDown() then return end
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Opts().position = SP:SavePositionRecord(self)
	end)
	frame:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" and Opts().hideBorder then SP:OpenFrameSettings("raidcoverage", self) end
	end)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Raid Coverage", 1, 0.82, 0)
		GameTooltip:AddLine(" ")
		if Opts().hideBorder then
			GameTooltip:AddLine("ALT+drag to move", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("Right-click for settings", 0.7, 0.7, 0.7)
		else
			GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
		end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	if not self:ApplyPositionRecord(frame, o.position) then frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end
	frame.cells = {}
	for _, t in ipairs(SP.RAID_COVERAGE_TOTEMS) do
		local key = t[1] .. ":" .. t[2]
		frame.cells[key] = NewCell(key, t[1], t[2])
	end
	frame:Hide()
	if SP.ThemeBoxesRefresh then SP:ThemeBoxesRefresh() end   -- (the cells' icons in the theme's boxes)
	return frame
end
function SP:ResetRaidCoveragePosition()
	Opts().position = nil
	if frame then frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end
end
-- the look: the panel's background and border (Hide Background), its opacity, the cells' size
local function ApplyLook()
	if not frame then return end
	local o = Opts()
	if o.hideBorder then
		frame:SetBackdropColor(0, 0, 0, 0)
		frame:SetBackdropBorderColor(0, 0, 0, 0)
		frame.title:Hide()
		frame.settingsBtn:Hide()
	else
		SP:ApplyPanelBackdrop(frame, nil, "mod.coverage-colors")
		frame.title:Show()
		frame.settingsBtn:Show()
	end
	frame:SetAlpha(Opacity())
	local size = IconSize()
	for _, btn in pairs(frame.cells) do
		btn:SetSize(size + 6, size + 6)
		btn.icon:SetSize(size, size)
		SP:SetSPFont(btn.caption, "labels", math.max(7, math.floor(FontSize() * 0.9)), "OUTLINE")
		btn.caption:SetTextColor(SP:RaidCoverageCaptionRGB())
	end
end

-- ---------------------------------------------------------------------------
-- The rows under a cell: the people it watches, read out of a fight; the engine's answer per person
-- ---------------------------------------------------------------------------
local function RetireSlot(slot)
	if slot and slot.container then
		pcall(slot.container.SetEnabled, slot.container, false)
		slot.container:SetAlpha(0)
		if not InCombatLockdown() then slot.container:Hide() end
	end
end
-- the game's answer for one watched person: a patch of the panel's color over the red name (Only
-- Show Who Is Missing: only the missing stay in sight), else the name in class color
local function BuildCover(element, index, unit, row, missingOnly, name, r, g, b)
	if not SP.NewPartyAuraSlot then return nil end
	local fontSize = FontSize()
	return (SP.NewPartyAuraSlot(row, unit, "raidcover", BuffMap(element, index), function(button)
		button:ClearAllPoints()
		button:SetAllPoints(row)
		if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
		if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, false) end
		if missingOnly then
			local c = button:CreateTexture(nil, "OVERLAY")
			c:SetAllPoints(button)
			local bg = SP.PANEL_BG or { 0, 0, 0, 1 }
			local br, bgg, bb = bg[1], bg[2], bg[3]
			if frame and frame.GetBackdropColor then
				local r1, g1, b1 = frame:GetBackdropColor()
				if r1 then br, bgg, bb = r1, g1, b1 end
			end
			-- no panel behind the names (Hide Background): nothing to cover with; the names stay as reads leave them
			c:SetColorTexture(br, bgg, bb, Opts().hideBorder and 0 or 1)
		else
			local t = button:CreateFontString(nil, "OVERLAY")
			SP:SetSPFont(t, "labels", fontSize, "OUTLINE")
			if SP.SPFontGameOwned then SP:SPFontGameOwned(t) end
			t:SetPoint("LEFT", button, "LEFT", 2, 0)
			t:SetPoint("RIGHT", button, "RIGHT", -2, 0)
			t:SetJustifyH("CENTER")
			t:SetWordWrap(false)
			t:SetTextColor(r, g, b)
			t:SetText(name)
		end
	end, 5))
end
local function ClassColor(class)
	local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if color and SP.ThemeClassColor then color = SP:ThemeClassColor("mod.coverage-dots-class", class, color) or color end
	if color then return color.r, color.g, color.b end
	return 0.4, 1, 0.4
end
local function BuildRows(btn, people)
	local fontSize, missingOnly = FontSize(), SP:RaidCoverageMissingOnly()
	local look = fontSize .. "|" .. tostring(missingOnly) .. "|" .. tostring(Opts().hideBorder)
	for i, p in ipairs(people) do
		local row = btn.rrows[i]
		if not row then row = NewRow(btn); btn.rrows[i] = row end
		local cr, cg, cb = ClassColor(p.class)
		local key = (p.name or "?") .. "|" .. tostring(p.class) .. "|" .. p.unit .. "|" .. look
		local slot = btn.rslots[i]
		if not slot or slot.key ~= key then
			RetireSlot(slot)
			SP:SetSPFont(row.text, "labels", fontSize, "OUTLINE")
			row.text:SetText(p.name or "?")
			row:SetSize(math.max(btn:GetWidth(), math.ceil(row.text:GetStringWidth()) + 10), RowH())
			local container = BuildCover(btn.element, btn.index, p.unit, row, missingOnly, p.name or "?", cr, cg, cb)
			slot = { container = container, key = key, unit = p.unit, enabled = nil }
			btn.rslots[i] = slot
		end
		row.cr, row.cg, row.cb = cr, cg, cb
		row:Hide()
	end
	for i = #people + 1, #btn.rrows do
		btn.rrows[i]:Hide()
		RetireSlot(btn.rslots[i])
		btn.rslots[i] = nil
	end
end
local function RetireCell(btn)
	for i = 1, #btn.rrows do btn.rrows[i]:Hide(); RetireSlot(btn.rslots[i]); btn.rslots[i] = nil end
	btn.people = nil
	if btn:IsShown() then btn:Hide() end
end
-- the engine's answers on a cell: lit in a fight (buffs unreadable), off while reads answer
local function Engine(btn, on)
	for _, slot in pairs(btn.rslots) do
		if slot.container and slot.enabled ~= on then
			slot.enabled = on
			pcall(slot.container.SetEnabled, slot.container, on)
			if on then pcall(slot.container.UpdateAllAuras, slot.container) end
			slot.container:SetAlpha(on and 1 or 0)
		end
	end
end
-- Rows for every cell turned on: who it watches, read now. Out of combat only (a roster change in a
-- fight is read again at its end).
function SP:RebuildRaidCoverage()
	if not frame then
		if not self:RaidCoverageOn() then return end
		self:CreateRaidCoverageFrame()
	end
	if InCombatLockdown() then self._raidCovPending = true return end
	self._raidCovPending = nil
	if not (self:RaidCoverageOn() and IsInRaid()) then
		for _, btn in pairs(frame.cells) do RetireCell(btn) end
		return
	end
	local roster = self:RaidCoverageRoster()
	for key, btn in pairs(frame.cells) do
		if self:RaidWatchOn(key) then
			local rule, preset = self:RaidWatchRule(key), self:RaidWatchPreset(key)
			local people = {}
			for _, p in ipairs(roster) do
				if RuleWatches(rule, preset, p.name, p.role, p.class, SpecOf(p.unit, p.name, p.class, p.role)) then people[#people + 1] = p end
			end
			btn.people = people
			BuildRows(btn, people)
		else
			RetireCell(btn)
		end
	end
end
-- the rows a cell shows, stacked under its caption; how much room they take
local function PlaceRows(btn, rows)
	local rowH, capH = RowH(), 13
	for j, row in ipairs(rows) do
		row:ClearAllPoints()
		row:SetPoint("TOP", btn, "BOTTOM", 0, -capH - (j - 1) * rowH)
		row:Show()
	end
	return capH + #rows * rowH
end
-- side by side (or stacked: Layout), each cell with the room its caption and rows need; the panel grows to fit
local function Layout(shown)
	local o = Opts()
	local size = IconSize()
	local cellW, cellH, padding = size + 6, size + 6, 6
	if o.vertical then
		local y, width = -20, cellW + 24
		for _, btn in ipairs(shown) do
			if btn.capW then width = math.max(width, btn.capW + 24) end
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, y)
			y = y - (cellH + (btn.room or 0) + 4 + padding)
		end
		frame:SetSize(math.max(80, width), -y + 8)
	else
		local x, tallest = 12, cellH
		for _, btn in ipairs(shown) do
			local slotW = math.max(cellW, btn.capW or 0)
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", frame, "TOPLEFT", x + (slotW - cellW) / 2, -20)
			x = x + slotW + padding
			tallest = math.max(tallest, cellH + (btn.room or 0) + 4)
		end
		frame:SetSize(math.max(80, x - padding + 12), tallest + 26)
	end
end
-- Unlock UI and the settings preview: the panel with sample cells (Windfury with two names missing,
-- Strength of Earth with everyone covered), so there is something to put the box on and to look at
local DEMO = {
	{ key = "4:1", element = 4, index = 1, label = "Melee", n = 9, missing = { { "Nazgrim", "WARRIOR" }, { "Uther", "PALADIN" } } },
	{ key = "1:1", element = 1, index = 1, label = "Melee", n = 9, missing = {} },
}
function SP:RaidCoverageDemo(on)
	local f = self:CreateRaidCoverageFrame()
	if on then
		self.raidCoverageDemoActive = true
		if f.settingsBtn then f.settingsBtn:Hide() end
		ApplyLook()
		local shown = {}
		for _, btn in pairs(f.cells) do
			for i = 1, #btn.rrows do btn.rrows[i]:Hide() end
			Engine(btn, false)
			btn:Hide()
		end
		for _, d in ipairs(DEMO) do
			local btn = f.cells[d.key]
			if btn then
				local icon = self.GetTotemIcon and self:GetTotemIcon(d.element, d.index)
				if icon then btn.icon:SetTexture(icon) end
				btn.drows = btn.drows or {}
				local rows = {}
				for i, p in ipairs(self:RaidCoverageNoNames() and {} or d.missing) do
					local row = btn.drows[i]
					if not row then row = NewRow(btn); btn.drows[i] = row end
					SP:SetSPFont(row.text, "labels", FontSize(), "OUTLINE")
					row.text:SetText(p[1])
					row.text:SetTextColor(1, 0.25, 0.25)
					row:SetSize(math.max(btn:GetWidth(), math.ceil(row.text:GetStringWidth()) + 10), RowH())
					rows[#rows + 1] = row
				end
				for i = #d.missing + 1, #(btn.drows) do btn.drows[i]:Hide() end
				btn.caption:SetText(self:RaidCoverageShowsCount() and (d.label .. " \194\183 " .. (d.n - #d.missing) .. "/" .. d.n) or d.label)
				if #d.missing == 0 then btn:SetBackdropBorderColor(0, 1, 0, 1); btn.missingOverlay:Hide()
				else btn:SetBackdropBorderColor(0.8, 0, 0, 1); btn.missingOverlay:Show() end
				btn.room = PlaceRows(btn, rows)
				btn.capW = math.ceil(btn.caption:GetStringWidth() or 0) + 6
				shown[#shown + 1] = btn
			end
		end
		if Opts().freeCells and self.unlockDemoAll then
			-- the unlock movers: every cell turned on at its own spot, with the sample rows
			f:Hide()
			for _, btn in ipairs(shown) do btn:Hide() end
			for _, btn in ipairs(self:RaidCoverageFreeCellList()) do
				if not btn.room then
					btn.caption:SetText(self:RaidCoverageShowsCount() and "Melee \194\183 9/9" or "Melee")
					btn:SetBackdropBorderColor(0, 1, 0, 1); btn.missingOverlay:Hide()
					btn.room = PlaceRows(btn, {})
				end
				PlaceFree(btn)
				btn:SetAlpha(Opacity())
				btn:Show()
			end
			return
		end
		for _, btn in pairs(f.cells) do ReturnToPanel(btn) end
		Layout(shown)
		for _, btn in ipairs(shown) do btn:Show() end
		f.sig = nil
		if not f:IsShown() then f:Show() end
	else
		self.raidCoverageDemoActive = nil
		for _, btn in pairs(f.cells) do
			for i = 1, #(btn.drows or {}) do btn.drows[i]:Hide() end
			btn.room = nil
			btn:Hide()
		end
		if f.settingsBtn and not Opts().hideBorder then f.settingsBtn:Show() end
		f.sig = nil
		f:Hide()
		self:UpdateRaidCoverage()
	end
end

-- The pass: each cell turned on whose totem you have down, its count line, border and rows
function SP:UpdateRaidCoverage()
	if not frame then return end
	if self.raidCoverageDemoActive then return end   -- (Unlock UI / a preview: the sample cells stay)
	if not (self:RaidCoverageOn() and IsInRaid()) or (self.PartyBuffOff and self:PartyBuffOff()) then
		if frame:IsShown() then frame:Hide() end
		return
	end
	if self._raidCovPending and not InCombatLockdown() then self:RebuildRaidCoverage() end
	ApplyLook()
	local blind = SPCompat.AurasUnreadable and SPCompat.AurasUnreadable()
	local missingOnly, showCount, noNames = self:RaidCoverageMissingOnly(), self:RaidCoverageShowsCount(), self:RaidCoverageNoNames()
	local shown, sig = {}, {}
	for _, t in ipairs(SP.RAID_COVERAGE_TOTEMS) do
		local element, index = t[1], t[2]
		local btn = frame.cells[element .. ":" .. index]
		local people = btn and btn.people
		local want = false
		if people and self:RaidWatchOn(btn.raidKey) then
			local haveTotem, _, _, _, icon = self:GetElementTotemInfo(element)
			local buffName, totemIndex
			if haveTotem then buffName, totemIndex = self:GetActiveTotemBuffName(element) end
			want = (haveTotem and buffName and totemIndex == index) and true or false
			if want then
				if icon ~= nil and not issecretvalue(icon) and btn.iconTex ~= icon then btn.iconTex = icon; btn.icon:SetTexture(icon) end
				local label = self:RaidWatchLabel(btn.raidKey)
				local rows, n, missing = {}, 0, 0
				if blind then
					-- in a fight: nothing to read; every watched name in red and the game covers the ones that have it
					-- (Don't Show Names: no rows, the game's answer stays off)
					for i, p in ipairs(people) do
						local row = btn.rrows[i]
						if row and PersonCounts(p.unit) and not noNames then
							n = n + 1
							row.text:SetTextColor(1, 0.25, 0.25)
							rows[#rows + 1] = row
						elseif row then row:Hide() end
					end
					Engine(btn, not noNames)
					btn.caption:SetText(label)
					btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
					btn.missingOverlay:Hide()
				else
					for i, p in ipairs(people) do
						local row = btn.rrows[i]
						if row and PersonCounts(p.unit) then
							n = n + 1
							local has = self:UnitHasBuff(p.unit, buffName, element)
							if not has then missing = missing + 1 end
							if noNames or (has and missingOnly) then
								row:Hide()
							else
								if has then row.text:SetTextColor(row.cr, row.cg, row.cb) else row.text:SetTextColor(1, 0.25, 0.25) end
								rows[#rows + 1] = row
							end
						elseif row then row:Hide() end
					end
					Engine(btn, false)
					btn.caption:SetText(showCount and (label .. " \194\183 " .. (n - missing) .. "/" .. n) or label)
					if missing == 0 then
						btn:SetBackdropBorderColor(0, 1, 0, 1)
						btn.missingOverlay:Hide()
					else
						btn:SetBackdropBorderColor(0.8, 0, 0, 1)
						btn.missingOverlay:Show()
					end
				end
				btn.room = PlaceRows(btn, rows)
				btn.capW = math.ceil(btn.caption:GetStringWidth() or 0) + 6
				shown[#shown + 1] = btn
				sig[#sig + 1] = btn.raidKey .. "=" .. #rows .. "/" .. btn.room
			end
		end
		if btn and not want then
			for i = 1, #btn.rrows do btn.rrows[i]:Hide() end
			Engine(btn, false)
			if btn:IsShown() then btn:Hide() end
		end
	end
	if Opts().freeCells then
		-- no panel: every cell turned on shows or hides on its own, where it was put
		if frame:IsShown() then frame:Hide() end
		frame.sig = nil
		for _, btn in pairs(frame.cells) do
			local wanted = false
			for _, b in ipairs(shown) do if b == btn then wanted = true break end end
			if wanted then
				PlaceFree(btn)
				btn:SetAlpha(Opacity())
				if not btn:IsShown() then btn:Show() end
			elseif btn:IsShown() then btn:Hide() end
		end
		return
	end
	for _, btn in pairs(frame.cells) do if btn.freePlaced then ReturnToPanel(btn) end end
	if #shown == 0 then if frame:IsShown() then frame:Hide() end; frame.sig = nil; return end
	local s = table.concat(sig, ";") .. "|" .. IconSize() .. tostring(Opts().vertical)
	if frame.sig ~= s then frame.sig = s; Layout(shown) end
	for _, btn in ipairs(shown) do btn:SetAlpha(1); if not btn:IsShown() then btn:Show() end end
	if not frame:IsShown() then frame:Show() end
end

-- ---------------------------------------------------------------------------
-- When it runs: its own pass twice a second while on and in a raid; the roster and the rows read
-- again when the group changes and when a fight ends
-- ---------------------------------------------------------------------------
local ticking = false
local function SetTicking(on)
	if on == ticking then return end
	ticking = on
	if not SP.updateSystem then return end
	if not (SP.updateSystem.subsystems and SP.updateSystem.subsystems.raidCoverage) then
		SP:RegisterUpdateSubsystem("raidCoverage", 0.5, function() SP:UpdateRaidCoverage() end)
	end
	if on then SP:EnableUpdateSubsystem("raidCoverage") else SP:DisableUpdateSubsystem("raidCoverage") end
end
function SP:RaidCoverageChanged()
	local on = self:RaidCoverageOn() and IsInRaid()
	if on and not frame then self:CreateRaidCoverageFrame() end
	if frame then
		if on then self:RebuildRaidCoverage() else for _, btn in pairs(frame.cells) do RetireCell(btn) end end
		frame.sig = nil
		self:UpdateRaidCoverage()
	end
	SetTicking(on and true or false)
	if LibStub and LibStub("AceConfigRegistry-3.0", true) then LibStub("AceConfigRegistry-3.0"):NotifyChange("ShamanPower") end
end
local events = CreateFrame("Frame")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TOTEM_UPDATE")
events:SetScript("OnEvent", function(_, event)
	if not SP.opt then return end
	if event == "PLAYER_TOTEM_UPDATE" then
		if ticking then SP:UpdateRaidCoverage() end
		return
	end
	SP:RaidCoverageChanged()
end)
-- the profile switched: the frame follows the new settings
if SP.OnProfileChanged then
	hooksecurefunc(SP, "OnProfileChanged", function() if SP.opt then SP:RaidCoverageChanged() end end)
end
-- Unlock UI's box and the settings preview (ShamanPowerPreview.lua): the panel with its sample cells
if SP.RegisterPreview then
	SP:RegisterPreview("raidcoverage", {
		frame = function() return SP:CreateRaidCoverageFrame() end,
		demo = "SP:RaidCoverageDemo",
		pad = 24,
		pane = { maxScale = 1.6 },
	})
end
