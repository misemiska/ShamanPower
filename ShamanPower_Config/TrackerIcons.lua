-- ShamanPower_Config :: TrackerIcons
-- A18 (3.0.8 alpha): four smaller pages as icon rows on the shared icon row (IconRow.lua),
-- the owner's approved answers on the A18 sheet:
--   Party Buff Tracker > Coverage (WoW: Forever): Totems to Watch. One icon per totem the
--     coverage list can watch, a step between the elements (the Party Strip's row). Click:
--     watch it or stop watching it. Right-click: its own icon size (used while Place Each
--     Totem Freely is on; gray with the reason while it is off, the sizes stay saved), Copy
--     Icon Size To..., Reset Icon Size. The blue corner: it's watched (the Party Strip's).
--   Totem Range Tracker: Totems to Track. Clicks only (no menu): a click tracks a totem or
--     stops tracking it. The blue corner: it's on the overlay.
--   Pop-Out Trackers: one icon per tracker you have popped out. A click opens its menu (no
--     on / off): Scale, Opacity, Hide Background, Flyout Direction (a totem button), Open Its
--     Settings Panel, Copy / Paste Settings, Copy Settings To..., Return It to the Bar, Reset
--     This Tracker. The blue corner: it has settings of its own. Nothing popped out: an empty
--     slot and a hint. In a fight the menu still opens, gray, saying why (pop-outs are
--     protected: their settings wait for the fight's end, as the old rows did).
--   Raid Cooldowns (TBC Anniversary): Bloodlust or Heroism, Mana Tide Totem, Drums of Battle.
--     A click opens its menu: who casts it and who may call for it (the raid's assignments,
--     sent to the raid as the old rows sent them). The blue corner: someone is assigned.
--     WoW: Forever (only Mana Tide) keeps its two rows (ShamanPowerOptions.lua).
-- Every value is the one the old rows read and wrote: no new saved settings.
local _, ns = ...
local Core = ns.Core
local SP = ShamanPower
if not (Core and SP and ns.IconRow) then return end

local Menu = ns.IconRow.Menu
local Choice, Slider = Menu.Choice, Menu.Slider
-- 3.0.9: a row's `pic` / `words` are picture hints for the icon's own screen (IconScreen.lua); the menus ignore them
local SEP = { separator = true }
local B, E = "|cff3FA9F5", "|r"   -- the captions' action words (the settings' blue)
local QUESTION = 134400

local function Report(err) geterrorhandler()(err) end
local function Red(text) print("|cff0070ddShamanPower|r: |cffe64a4a" .. text .. "|r") end

local function SpellTexture(id)
	if not id then return nil end
	if C_Spell and C_Spell.GetSpellTexture then
		local t = C_Spell.GetSpellTexture(id)
		if t then return t end
	end
	if GetSpellTexture then
		local t = GetSpellTexture(id)
		if t then return t end
	end
	return (select(3, GetSpellInfo(id)))
end
local function Label(id, fallback)
	if SPCompat and SPCompat.SpellLabel then return SPCompat.SpellLabel(id, fallback) end
	return fallback
end
-- a spell's own name in the client's language (nil when it has none it can read)
local function SpellName(id)
	local n
	if C_Spell and C_Spell.GetSpellName then n = C_Spell.GetSpellName(id)
	elseif GetSpellInfo then n = GetSpellInfo(id) end
	if (issecretvalue and issecretvalue(n)) or type(n) ~= "string" or n == "" then return nil end
	return n
end

-- a change made in one of these rows: the icons now, then the page (its onChanged tells
-- AceConfig, so an open picker or settings panel follows; the watcher below skips that one)
local busy = false
local function Changed(row, keep)
	busy = true
	local ok, err = pcall(row.Changed, row, keep)
	busy = false
	if not ok then Report(err) end
end
-- a slider's value: saved, the icons and the preview follow; never a redraw of the page under a drag
local function SliderChanged(row)
	row:Repaint()
	local cfg = _G.ShamanPowerConfig
	if cfg and cfg.PreviewChanged then cfg:PreviewChanged() end
end
-- the items changed (a tracker went back to its bar): the page lays the row out again
local function Relayout(row)
	if row:ListChanged() then
		local cfg = _G.ShamanPowerConfig
		if cfg and cfg.RefreshCurrent then cfg:RefreshCurrent() end
	end
end

-- ===========================================================================
-- Party Buff Tracker > Coverage (WoW: Forever): Totems to Watch
-- ===========================================================================
-- the Coverage and Range rows: a step (the Party Strip's 14 px) before the first totem of each
-- element, so the elements read as groups on one line (IconRow's gapBefore)
local STEP = 14
local function MarkSteps(list)
	local prev
	for i, item in ipairs(list) do
		item.stepBefore = (i > 1 and item.element ~= prev) and STEP or nil
		prev = item.element
	end
end
local function StepBefore(item) return item.stepBefore or 0 end

local Coverage
do
	local function CO()
		SP.opt.coverage = SP.opt.coverage or {}
		return SP.opt.coverage
	end
	local function Free() return SP.opt.coverage and SP.opt.coverage.freeCells and true or false end
	local function ListSize() return (SP.opt.coverage and SP.opt.coverage.iconSize) or 36 end
	-- a totem's own size (keyed element * 100 + totem index, as the module and the old sliders keep it)
	local function OwnSize(key)
		local co = SP.opt.coverage
		local c = co and co.cells and co.cells[key]
		return c and c.iconSize or nil
	end
	local function SetOwnSize(key, v)
		local co = CO()
		if v == nil then
			local c = co.cells and co.cells[key]
			if c then c.iconSize = nil end   -- (its spot stays)
		else
			co.cells = co.cells or {}
			co.cells[key] = co.cells[key] or {}
			co.cells[key].iconSize = v
		end
		if SP.UpdateCoverageLayout then SP:UpdateCoverageLayout() end
	end
	local function Watched(item) return SP.CoverageWatches and SP:CoverageWatches(item.element, item.index) and true or false end
	local function SetWatched(item, on)
		if SP.SetCoverageWatch then SP:SetCoverageWatch(item.base, on) end
	end
	local function Learned(item) return SP.KnowsTotem and SP:KnowsTotem(item.element, item.index) and true or false end

	-- every totem the list can watch on this client, in element order (the old switches' list)
	local function Items(out)
		local buffs = SP.TotemBuffSpellIDs
		if type(buffs) ~= "table" then return end
		for element = 1, 4 do
			local idxs = {}
			for idx in pairs(buffs[element] or {}) do idxs[#idxs + 1] = idx end
			table.sort(idxs)
			for _, idx in ipairs(idxs) do
				local totem = SP.GetTotemSpell and SP:GetTotemSpell(element, idx)
				if totem and SPCompat and SPCompat.SpellExists and SPCompat.SpellExists(totem) then
					out[#out + 1] = { key = element * 100 + idx, element = element, index = idx, base = buffs[element][idx],
						totem = totem, name = SpellName(totem) or SP:GetTotemName(element, idx) }   -- (the Party Strip's names)
				end
			end
		end
	end
	local function Icon(item)
		local t = SpellTexture(item.totem)
		if not t and SP.GetTotemIcon then t = SP:GetTotemIcon(item.element, item.index) end
		return t or QUESTION
	end

	local function TipBody(item)
		local watched, learned = Watched(item), Learned(item)
		local t = watched and "It's in the coverage list." or "It's not in the coverage list."
		if not learned then
			t = t .. (watched and " You haven't learned it yet: it shows once you learn it."
				or " You haven't learned it yet. You can still watch it: it shows once you learn it.")
		end
		local own = OwnSize(item.key)
		if own then
			t = t .. " Its own icon size: " .. own .. (Free() and "." or " (used while Place Each Totem Freely is on).")
		end
		return t
	end

	-- Copy Icon Size To...: the other watched totems, then all of them. The size goes as it is: its own
	-- size, or none (the list's Icon Size), so every totem copied to reads the same
	local function CopyTo(from, to)
		local v = OwnSize(from.key)
		local list = {}
		Items(list)
		for _, x in ipairs(list) do
			if x.key ~= from.key and (to == "all" or to == x.key) and Watched(x) then SetOwnSize(x.key, v) end
		end
	end

	local function MenuItems(item)
		local r = {}
		local key = item.key
		local own = OwnSize(key)
		-- the totem itself
		local watched = Watched(item)
		r[#r + 1] = { text = watched and "Stop Watching This Totem" or "Watch This Totem",
			tip = "The same as a click on it.",
			onClick = function()
				SetWatched(item, not watched)
				Changed(Coverage, false)
			end }
		r[#r + 1] = SEP
		-- how it looks
		if Free() then
			r[#r + 1] = Slider("Size", 20, 80, 4, function() return OwnSize(key) or ListSize() end,
				function(v) SetOwnSize(key, v); SliderChanged(Coverage) end, nil, false,
				"This totem's own size in the coverage list while Place Each Totem Freely is on. The other totems keep theirs.",
				{ kind = "size" })
			r[#r].words = "its own size in the coverage list"
		else
			-- Place Each Totem Freely is off: one size for the list. Shown gray, saying why; a size
			-- set before stays saved for when it is on again
			local why = "Every totem uses the list's Icon Size (Appearance) while Place Each Totem Freely is off. Turn it on"
				.. " (Behavior) to give each totem its own spot and size."
			if own then why = why .. " This totem's own size (" .. own .. ") stays saved for then." end
			r[#r + 1] = { text = "Size", disabled = true, tip = why, value = function() return "Use List Size", false end }
			r[#r + 1] = { text = "Turn on Place Each Totem Freely under Behavior to set this totem's size.", disabled = true, tip = why }
		end
		-- copy and reset
		if Free() then
			r[#r + 1] = SEP
			r[#r + 1] = { text = "Copy & Reset", label = true }
			r[#r + 1] = { text = "Copy Size To...", subMaxHeight = 420,
				words = "this size onto another totem you watch, or all of them", sub = function()
				local o, list = {}, {}
				Items(list)
				for _, x in ipairs(list) do
					if x.key ~= key and Watched(x) then
						o[#o + 1] = { text = x.name, icon = Icon(x), onClick = function()
							CopyTo(item, x.key)
							Changed(Coverage, false)
						end }
					end
				end
				o[#o + 1] = SEP
				o[#o + 1] = { text = "All Totems", tip = "Every totem you watch gets this size.", onClick = function()
					CopyTo(item, "all")
					Changed(Coverage, false)
				end }
				return o
			end }
			r[#r + 1] = { text = "Reset Size", disabled = not own, tip = "Back to the list's Icon Size (Appearance).",
				onClick = function()
					SetOwnSize(key, nil)
					Changed(Coverage, false)
				end }
		end
		return r
	end

	Coverage = ns.IconRow.New({
		caption = B .. "CLICK" .. E .. " a totem to watch it or stop watching it. A blue corner: it's in the list. "
			.. B .. "RIGHT-CLICK" .. E .. " it for its own icon size. " .. B .. "Dark" .. E .. ": you haven't learned it yet"
			.. " (pick it now, it shows once you learn it).",
		hint = "Click: watch it or stop watching it\nRight-click: its icon size",
		list = function(out) Items(out); MarkSteps(out) end,
		textures = function(item, out)
			out[1] = Icon(item)
			return 1
		end,
		gapBefore = StepBefore,   -- (a step between the elements)
		shown = Watched,
		learned = Learned,
		hasOwn = Watched,   -- (A18 Q2: on Coverage the corner says it's watched, as on the Party Strip)
		tooltip = TipBody,
		toggle = function(item) SetWatched(item, not Watched(item)) end,
		menu = MenuItems,
	})
	ns.CustomRows.coverageIcons = Coverage

	-- Reset This Page (Party Buff Tracker; Window.lua calls it after the page's own rows): every totem
	-- watched again (as the old switches reset) and no totem keeps a size of its own (the list's Icon
	-- Size, reset by the page, for all). Where the cells sit stays.
	function SP.CoverageResetPage(sp)
		if InCombatLockdown() or not (sp.opt and sp.SetCoverageWatch) then return end
		local list = {}
		Items(list)
		for _, item in ipairs(list) do
			if not Watched(item) then SetWatched(item, true) end
		end
		local co = sp.opt.coverage
		for key, c in pairs(co and co.cells or {}) do
			if type(key) == "number" and key >= 100 and type(c) == "table" then c.iconSize = nil end
		end
		if sp.UpdateCoverageLayout then sp:UpdateCoverageLayout() end
	end
end

-- ===========================================================================
-- Party Buff Tracker > Raid Coverage (WoW: Forever, 3.0.9.1): the seven raid-wide totems of
-- ShamanPower_RaidCoverage.lua. A click turns the totem's cell on or off; a right-click opens its own screen: Watch (a preset), Roles, Classes (a
-- class whose specs matter opens to them), People (everyone in the raid now, Add a Name), Copy
-- Who It Watches To, Reset This Totem. The blue corner: a setup of its own (Custom).
-- The values live in opt.raidCoverage.watch (SP:RaidWatchRule, ShamanPower_RaidCoverage.lua).
-- ===========================================================================
local RaidCov
if SPCompat and SPCompat.FOREVER and SP.RaidWatchRule then
	local EKEY = { "earth", "fire", "water", "air" }
	local CLASSES = { { "WARRIOR", "Warriors" }, { "PALADIN", "Paladins" }, { "HUNTER", "Hunters" }, { "ROGUE", "Rogues" },
		{ "PRIEST", "Priests" }, { "SHAMAN", "Shamans" }, { "MAGE", "Mages" }, { "WARLOCK", "Warlocks" }, { "DRUID", "Druids" } }
	-- the specs that tell melee from not: the three hybrids
	local SPECS = {
		PALADIN = { { "holy", "Holy" }, { "protection", "Protection" }, { "retribution", "Retribution" } },
		SHAMAN = { { "elemental", "Elemental" }, { "enhancement", "Enhancement" }, { "restoration", "Restoration" } },
		DRUID = { { "balance", "Balance" }, { "feral", "Feral" }, { "restoration", "Restoration" } },
	}
	local function Key(item) return item.element .. ":" .. item.index end
	local function Items(out)
		for _, t in ipairs(SP.RAID_COVERAGE_TOTEMS or {}) do
			local totem = SP.GetTotemSpell and SP:GetTotemSpell(t[1], t[2])
			if totem and (not SPCompat.SpellExists or SPCompat.SpellExists(totem)) then
				out[#out + 1] = { key = t[1] * 100 + t[2], element = t[1], index = t[2], totem = totem,
					name = (SP.GetTotemName and SP:GetTotemName(t[1], t[2])) or SpellName(totem) or tostring(totem) }
			end
		end
	end
	local function Icon(item) return SpellTexture(item.totem) or QUESTION end
	local function Learned(item) return SP.KnowsTotem and SP:KnowsTotem(item.element, item.index) and true or false end
	local function ClassText(class, label)
		local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if col and col.colorStr then return "|c" .. col.colorStr .. label .. "|r" end
		return label
	end
	local function Preset(item) return SP:RaidWatchPreset(Key(item)) end
	local function PresetLabel(item) return SP:RaidWatchLabel(Key(item)) end
	local function Pick(item, section, id, text)
		return { text = text, selected = SP:RaidWatchPicked(Key(item), section, id), onClick = function()
			SP:RaidWatchToggle(Key(item), section, id)
			Changed(RaidCov, true)
			return true
		end }
	end
	local function CountPicked(item, section)
		local t = SP:RaidWatchRule(Key(item))[section]
		local n = 0
		for _ in pairs(t or {}) do n = n + 1 end
		return n
	end
	local function PickedValue(item, section, list)
		local n = CountPicked(item, section)
		if n == 0 then return "None", false end
		if n == 1 and list then
			for _, c in ipairs(list) do if SP:RaidWatchPicked(Key(item), section, c[1]) then return c[2], true end end
		end
		return n .. " picked", true
	end
	local function TipBody(item)
		local t = "Reaches the whole raid within 30 yards. Its cell in the Raid Coverage panel watches: " .. PresetLabel(item) .. "."
		if not Learned(item) then t = t .. " You haven't learned it yet: set it up now, it shows once you learn it." end
		return t
	end
	-- a name typed in (someone not in the raid right now): kept with the picks
	local function AddName(item)
		SP:ShowSPDialog({
			key = "raidWatchName",
			title = "Add a name",
			text = "Watch this player whatever their role or class, even when they are not in the raid right now.",
			input = { text = "", maxLetters = 24 },
			buttons = {
				{ text = "Add", onClick = function(dialog)
					local v = dialog and dialog.GetInput and dialog:GetInput() or ""
					v = tostring(v or ""):match("^%s*(.-)%s*$") or ""
					if v ~= "" then SP:RaidWatchToggle(Key(item), "people", v, true); Changed(RaidCov, false) end
				end },
				{ text = "Cancel" },
			},
		})
	end
	local function PeopleItems(item)
		local o, seen = {}, {}
		local roster = SP.RaidCoverageRoster and SP:RaidCoverageRoster() or {}
		table.sort(roster, function(a, b) return (a.group or 9) * 100 + (a.name or "") < (b.group or 9) * 100 + (b.name or "") end)
		for _, p in ipairs(roster) do
			if p.name and not seen[p.name] then
				seen[p.name] = true
				local label = ClassText(p.class, p.name)
				if p.group then label = "|cff5A6678G" .. p.group .. "|r  " .. label end
				o[#o + 1] = Pick(item, "people", p.name, label)
			end
		end
		-- names picked before, not in the raid now
		local people = SP:RaidWatchRule(Key(item)).people
		local extra = {}
		for name in pairs(people or {}) do if not seen[name] then extra[#extra + 1] = name end end
		table.sort(extra)
		if #extra > 0 then
			o[#o + 1] = { text = "Not in the raid now", label = true }
			for _, name in ipairs(extra) do o[#o + 1] = Pick(item, "people", name, name) end
		end
		if #o == 0 then o[#o + 1] = { text = "Nobody else in the raid right now.", disabled = true } end
		o[#o + 1] = SEP
		o[#o + 1] = { text = "Add a Name...", tip = "Watch someone by name whatever their role or class, even when they are not here now.",
			onClick = function() AddName(item) end }
		return o
	end
	local function ClassItems(item)
		local o = {}
		for _, c in ipairs(CLASSES) do
			local specs = SPECS[c[1]]
			if specs then
				o[#o + 1] = { text = ClassText(c[1], c[2]), tip = "All of them, or only the specs that matter to this totem.",
					value = function()
						if SP:RaidWatchPicked(Key(item), "classes", c[1]) then return "All", true end
						local names = {}
						for _, s in ipairs(specs) do if SP:RaidWatchPicked(Key(item), "specs", c[1] .. ":" .. s[1]) then names[#names + 1] = s[2] end end
						if #names == 0 then return "None", false end
						return table.concat(names, ", "), true
					end,
					sub = function()
						local items = { Pick(item, "classes", c[1], "All " .. c[2]), SEP }
						for _, s in ipairs(specs) do items[#items + 1] = Pick(item, "specs", c[1] .. ":" .. s[1], s[2]) end
						return items
					end }
			else
				o[#o + 1] = Pick(item, "classes", c[1], ClassText(c[1], c[2]))
			end
		end
		return o
	end
	local function CopyItems(item)
		local o, list = {}, {}
		Items(list)
		for _, x in ipairs(list) do
			if x.key ~= item.key then
				o[#o + 1] = { text = x.name, icon = Icon(x), onClick = function()
					SP:RaidWatchCopy(Key(item), Key(x))
					Changed(RaidCov, false)
				end }
			end
		end
		o[#o + 1] = SEP
		o[#o + 1] = { text = "All Raid-Wide Totems", tip = "Every raid-wide totem watches who this one watches.", onClick = function()
			SP:RaidWatchCopy(Key(item), "all")
			Changed(RaidCov, false)
		end }
		return o
	end
	local function MenuItems(item)
		local r = {}
		local key = item.key
		r[#r + 1] = { text = "Who It Watches", label = true }
		local presets = {}
		for _, c in ipairs(SP.RAID_WATCH_PRESETS or {}) do presets[#presets + 1] = { c[1], c[2] } end
		r[#r + 1] = Choice("Watch", presets, function() return Preset(item), Preset(item) == "custom" end,
			function(v) SP:SetRaidWatchPreset(Key(item), v); return Changed(RaidCov, true) end,
			"Who this totem's cell watches in a raid. Melee: warriors, rogues, protection and retribution paladins, enhancement"
			.. " shamans, feral druids. Ranged: mages, warlocks, hunters, shadow priests, balance druids, elemental shamans."
			.. " Tanks and Healers: the role each player picked in the group tool (a raid Main Tank counts as a Tank)."
			.. " Custom: exactly the classes, specs and people you pick below.", { kind = "none" })
		r[#r + 1] = { text = "Classes", tip = "A class, or for paladins, shamans and druids the specs that matter. Picking anything here sets Watch to Custom.",
			value = function()
				local n = CountPicked(item, "classes") + CountPicked(item, "specs")
				if n == 0 then return "None", false end
				return n .. " picked", true
			end,
			sub = function() return ClassItems(item) end }
		r[#r + 1] = { text = "People", tip = "Watch someone by name whatever their role or class. Picking anyone here sets Watch to Custom.",
			value = function() return PickedValue(item, "people") end,
			subMaxHeight = 420,
			sub = function() return PeopleItems(item) end }
		r[#r + 1] = SEP
		r[#r + 1] = { text = "Copy & Reset", label = true }
		r[#r + 1] = { text = "Copy Who It Watches To", words = "who this one watches onto another raid-wide totem, or all of them",
			sub = function() return CopyItems(item) end }
		r[#r + 1] = { text = "Reset This Totem", tip = "Back to its own default: " .. PresetLabel({ element = item.element, index = item.index, key = key }) .. " as it came.",
			onClick = function()
				SP:RaidWatchReset(Key(item))
				Changed(RaidCov, false)
			end }
		return r
	end
	RaidCov = ns.IconRow.New({
		caption = "These seven totems reach the whole raid. " .. B .. "CLICK" .. E .. " a totem to turn its raid cell on or off. "
			.. B .. "RIGHT-CLICK" .. E .. " it for who its cell watches: Everyone, Melee, Ranged, Tanks or Healers, or the classes, specs and people you pick."
			.. " A blue corner: a setup of its own. " .. B .. "Dark" .. E .. ": you haven't learned it yet.",
		hint = "Click: on / off  ·  Right-click: who it watches",
		list = Items,
		textures = function(item, out)
			out[1] = Icon(item)
			return 1
		end,
		shown = function(item) return SP.RaidWatchOn and SP:RaidWatchOn(Key(item)) or false end,
		learned = Learned,
		hasOwn = function(item) return Preset(item) == "custom" end,
		tooltip = TipBody,
		toggle = function(item)
			if SP.RaidWatchSetOn then SP:RaidWatchSetOn(Key(item), not SP:RaidWatchOn(Key(item))) end
			Changed(RaidCov, false)
		end,
		menu = MenuItems,
		menuElement = function(item) return EKEY[item.element] end,
	})
	ns.CustomRows.raidCoverageIcons = RaidCov
end

-- ===========================================================================
-- Totem Plates: Totems (3.0.9.1, sheet A54, both games). One icon per totem that can have a
-- plate, by element. Click: show or hide its plate. Right-click: its own screen: Mark as
-- Important (its plate glows), Glow Style, Glow Color, its own Size, Copy Important To, Reset.
-- The blue corner: it is Important. The values live in opt.totemPlates (ShamanPower_TotemPlates).
-- ===========================================================================
local Plates
do
	local EKEY = { "earth", "fire", "water", "air" }
	local ELEM = { "Earth", "Fire", "Water", "Air" }
	local GLOW_STYLES = { { "shape", "Use Glow Shape" }, { "default", "Square" }, { "round", "Round" }, { "proc", "Proc Glow" } }
	local function Key(item) return item.plateKey end
	local function Items(out)
		if not SP.TotemPlateKeyForSpell then return end
		for e = 1, 4 do
			local t = SP.Totems and SP.Totems[e] or {}
			local last = SP.GetTotemIndexLimit and SP:GetTotemIndexLimit(e) or 10
			for idx = 1, math.max(last, 10) do
				local id = t[idx]
				if id and (not (SPCompat and SPCompat.SpellExists) or SPCompat.SpellExists(id)) then
					local key, english = SP:TotemPlateKeyForSpell(id)
					if key then
						out[#out + 1] = { key = id, e = e, idx = idx, plateKey = key,
							name = (SP.GetTotemName and SP:GetTotemName(e, idx)) or SpellName(id) or english }
					end
				end
			end
		end
	end
	local function Hidden(item) return SP.TotemPlateHidden and SP:TotemPlateHidden(Key(item)) or false end
	local function Important(item) return SP.TotemPlateImportant and SP:TotemPlateImportant(Key(item)) or false end
	local function Own(item, name)
		local o = SP.TotemPlateOwn and SP:TotemPlateOwn(Key(item))
		return o and o[name]
	end
	local function Set(item, name, v) if SP.SetTotemPlateOwn then SP:SetTotemPlateOwn(Key(item), name, v) end end
	local function Learned(item) return not SP.KnowsTotem or SP:KnowsTotem(item.e, item.idx) end
	local function GlowColor(item)
		local c = Own(item, "glowColor")
		if type(c) == "table" then return c.r or c[1] or 1, c.g or c[2] or 0.2, c.b or c[3] or 0.2 end
		return 1, 0.2, 0.2
	end
	local function TipBody(item)
		local t = Hidden(item) and "Its plate is hidden." or "Its plate shows."
		if Important(item) then t = t .. " Important: its plate glows." end
		if not Learned(item) then t = t .. " You haven't learned it yet; the setting is kept for when you do." end
		return t
	end
	local function MenuItems(item)
		local r = {}
		local hidden = Hidden(item)
		r[#r + 1] = { text = hidden and "Show Its Plate" or "Hide Its Plate", tip = "The same as a click on it.", onClick = function()
			if SP.SetTotemPlateHidden then SP:SetTotemPlateHidden(Key(item), not hidden) end
			Changed(Plates, false)
		end }
		r[#r + 1] = SEP
		r[#r + 1] = { text = "Important", label = true }
		r[#r + 1] = Choice("Mark as Important", { { true, "On" }, { false, "Off" } },
			function() local v = Important(item); return v, v end,
			function(v) Set(item, "important", v or nil); return Changed(Plates, true) end,
			"Its plate glows, in the style and color below, so it stands out in a fight.", { kind = "none" })
		r[#r + 1] = Choice("Glow Style", GLOW_STYLES,
			function() local v = Own(item, "glowStyle") or "shape"; return v, v ~= "shape" end,
			function(v) Set(item, "glowStyle", v ~= "shape" and v or nil); return Changed(Plates, true) end,
			"Use Glow Shape follows General > Themes > Glow Shape. Or this totem's own: Square, Round, or Proc Glow (the one Ready Reminders use).", { kind = "none" })
		r[#r + 1] = { text = "Glow Color", tip = "The glow's color for this totem.", swatch = { GlowColor(item) }, onClick = function()
			if not SP.OpenColorPicker then return false end
			local before = Own(item, "glowColor")
			local r0, g0, b0 = GlowColor(item)
			SP:OpenColorPicker({
				r = r0, g = g0, b = b0, hasAlpha = false, title = (item.name or "Totem") .. " Glow Color",
				onChange = function(nr, ng, nb) Set(item, "glowColor", { r = nr, g = ng, b = nb }); Changed(Plates, false) end,
				onCancel = function() Set(item, "glowColor", before); Changed(Plates, false) end,
			})
			return false
		end }
		r[#r + 1] = SEP
		r[#r + 1] = { text = "Its Own Look", label = true }
		r[#r + 1] = Slider("Size", 20, 80, 2, function() return Own(item, "size") or (SP.opt.totemPlates and SP.opt.totemPlates.iconSize) or 40 end,
			function(v) Set(item, "size", v); SliderChanged(Plates) end, nil, false,
			"This totem's own icon size on its plate. The page's Icon Size for the rest.")
		r[#r + 1] = SEP
		r[#r + 1] = { text = "Copy & Reset", label = true }
		r[#r + 1] = { text = "Copy Important To", words = "its Important, glow style and color onto another totem, or all of them", subMaxHeight = 420, sub = function()
			local o, list = {}, {}
			Items(list)
			for _, x in ipairs(list) do
				if x.plateKey ~= Key(item) then
					o[#o + 1] = { text = x.name, icon = SpellTexture(x.key), onClick = function()
						if SP.CopyTotemPlateImportant then SP:CopyTotemPlateImportant(Key(item), x.plateKey) end
						Changed(Plates, false)
					end }
				end
			end
			o[#o + 1] = SEP
			o[#o + 1] = { text = "All Totems", onClick = function()
				if SP.CopyTotemPlateImportant then SP:CopyTotemPlateImportant(Key(item), "all") end
				Changed(Plates, false)
			end }
			return o
		end }
		r[#r + 1] = { text = "Reset This Totem", tip = "Its plate shows again, not Important, the page's size.", onClick = function()
			if SP.ResetTotemPlate then SP:ResetTotemPlate(Key(item)) end
			Changed(Plates, false)
		end }
		return r
	end
	Plates = ns.IconRow.New({
		caption = B .. "CLICK" .. E .. " a totem to show or hide its plate. " .. B .. "RIGHT-CLICK" .. E
			.. " it to mark it Important (its plate glows), for its glow and its own size. A blue corner: it is Important. "
			.. B .. "Dark" .. E .. ": you haven't learned it yet.",
		hint = "Click: show or hide its plate\nRight-click: Important, glow, size",
		list = Items,
		textures = function(item, out)
			out[1] = SpellTexture(item.key) or QUESTION
			return 1
		end,
		shown = function(item) return not Hidden(item) end,
		learned = Learned,
		hasOwn = Important,
		tooltip = TipBody,
		toggle = function(item) if SP.SetTotemPlateHidden then SP:SetTotemPlateHidden(Key(item), not Hidden(item)) end end,
		menu = MenuItems,
		group = function(item) return item.e end,
		groupLabelWidth = 56,
		groupGap = 2,
		groupLabel = function(holder, e)
			if not holder.box then
				holder.box = SP:CreateElementBox(holder, 10, EKEY[e])
				holder.box:SetPoint("LEFT", holder, "LEFT", 0, 0)
				holder.text = holder:CreateFontString(nil, "OVERLAY")
				holder.text:SetFontObject(Core.fonts.section)
				holder.text:SetPoint("LEFT", holder.box, "RIGHT", 7, 0)
				holder.text:SetJustifyH("LEFT")
			end
			holder.box:SetElement(EKEY[e])
			holder.text:SetText(ELEM[e]:upper())
		end,
		menuElement = function(item) return EKEY[item.e] end,
	})
	ns.CustomRows.plateIcons = Plates
end

-- ===========================================================================
-- Totem Range Tracker: Totems to Track (both games; clicks only)
-- ===========================================================================
local Range
do
	local function Tracked(id)
		local t = ShamanPower_RangeTracker and ShamanPower_RangeTracker.tracked
		return t and t[id] and true or false
	end
	local function SetTracked(id, on)
		if not SP.SPRangeLoaded then return end
		SP:InitSPRange()
		ShamanPower_RangeTracker.tracked[id] = on and true or false
		if SP.UpdateSPRangeConfigButtons then SP:UpdateSPRangeConfigButtons() end
		if SP.UpdateSPRangeFrame then SP:UpdateSPRangeFrame() end
	end

	Range = ns.IconRow.New({
		caption = B .. "CLICK" .. E .. " a totem to track it or stop tracking it. A blue corner: it's on the overlay."
			.. " The overlay watches the other shamans in your group, so every totem is here, learned or not.",
		hint = "Click: track it or stop tracking it",
		list = function(out)
			if not SP.SPRangeLoaded then return end
			for _, t in ipairs(SP.TrackableTotems or {}) do
				out[#out + 1] = { key = t.id, name = t.name or t.id, element = t.element, totem = t }
			end
			MarkSteps(out)
		end,
		textures = function(item, out)
			out[1] = (SP.TrackableTotemIcon and SP:TrackableTotemIcon(item.totem)) or QUESTION
			return 1
		end,
		gapBefore = StepBefore,   -- (a step between the elements)
		shown = function(item) return Tracked(item.key) end,
		hasOwn = function(item) return Tracked(item.key) end,   -- (A18 Q2: the corner says it's on the overlay)
		tooltip = function(item)
			if Tracked(item.key) then return "It's on the overlay." end
			return "It's not on the overlay."
		end,
		toggle = function(item) SetTracked(item.key, not Tracked(item.key)) end,
		-- no menu: a totem has nothing of its own to set here (A18 Q5)
	})
	ns.CustomRows.rangeIcons = Range

	-- Reset This Page (Totem Range Tracker): the tracked totems back to the module's own start
	-- (Windfury Totem and Grace of Air), as the old switches reset
	function SP.RangeTrackerResetPage(sp)
		if InCombatLockdown() or not sp.SPRangeLoaded then return end
		local md = sp.SUPPORT_MODULE_DEFAULTS and sp.SUPPORT_MODULE_DEFAULTS.ShamanPower_RangeTracker
		local def = md and md.tracked or { windfury = true, graceofair = true }
		sp:InitSPRange()
		local t = ShamanPower_RangeTracker.tracked
		for _, totem in ipairs(sp.TrackableTotems or {}) do t[totem.id] = def[totem.id] and true or false end
		if sp.UpdateSPRangeConfigButtons then sp:UpdateSPRangeConfigButtons() end
		if sp.UpdateSPRangeFrame then sp:UpdateSPRangeFrame() end
	end
end

-- ===========================================================================
-- Pop-Out Trackers (both games): one icon per popped-out tracker
-- ===========================================================================
local Popouts
do
	local ELEMENT_KEYS = { "totem_earth", "totem_fire", "totem_water", "totem_air" }
	local LOCKED = "Change these settings after combat."
	local LOCKED_TEXT = "Pop-Out Trackers can't change in combat - try again after the fight."

	local function Frames() return SP.poppedOutFrames or {} end
	local function IsTotem(key) return key:match("^totem_") ~= nil end
	local function Saved(key) return SP.opt.poppedOutSettings and SP.opt.poppedOutSettings[key] or nil end
	local function DefScale() return SP.opt.poppedOutDefaultScale or 1 end
	local function DefOpacity() return SP.opt.poppedOutDefaultOpacity or 1 end
	local function Hidden(key) local s = Saved(key); return s and s.hideFrame == true or false end

	-- its name: what the bars call it
	local function Name(key, frame)
		local el = key:match("^totem_(%a+)$")
		if el then return (el:gsub("^%l", string.upper)) .. " Totems" end
		local cd = tonumber(key:match("^cd_(%d+)$") or "")
		if cd == 1 then return "Lightning / Water Shield" end
		if cd == 6 then
			local alliance = UnitFactionGroup and UnitFactionGroup("player") == "Alliance"
			return alliance and Label(32182, "Heroism") or Label(2825, "Bloodlust")
		end
		if cd and SP.CooldownTypeLabels and SP.CooldownTypeLabels[cd] then return SP.CooldownTypeLabels[cd] end
		if key == "earthshield" then return Label(974, "Earth Shield") end
		if key == "dropall" then return "Drop All" end
		local sel, sidx = key:match("^single_(%d+)_(%d+)$")
		local spell = sel and SP.GetTotemSpell and SP:GetTotemSpell(tonumber(sel), tonumber(sidx))
		if spell and SpellName(spell) then return SpellName(spell) end   -- (the totem's own name: Windfury Totem)
		local title = frame and frame.title
		if type(title) == "string" and title ~= "" then return title end
		return key
	end
	-- its icon: what it shows on screen (the real button's), else the spell's
	local function Icon(key, frame)
		local b = frame and frame.button
		local tex = b and b.icon and b.icon.GetTexture and b.icon:GetTexture()
		if tex and not (issecretvalue and issecretvalue(tex)) then return tex end
		local el, idx = key:match("^single_(%d+)_(%d+)$")
		if el and SP.GetTotemIcon then return SP:GetTotemIcon(tonumber(el), tonumber(idx)) end
		local element = key:match("^totem_(%a+)$")
		if element and SP.ElementToID and SP.GetTotemIcon then
			local id = SP.ElementToID[element:upper()]
			if id then return SP:GetTotemIcon(id, 1) end
		end
		if key == "earthshield" then return SpellTexture(974) or QUESTION end
		if key == "dropall" then return 136024 end
		local cd = tonumber(key:match("^cd_(%d+)$") or "")
		if cd then
			for _, e in ipairs(SP.TrackedCooldowns or {}) do
				if e[5] == cd then return SpellTexture(e[1]) or QUESTION end
			end
		end
		return QUESTION
	end

	-- in the bars' order: the totem buttons, single totems, Drop All, the cooldown bar's items, Earth Shield
	local function Items(out)
		local frames = Frames()
		local seen = {}
		local function add(key)
			if frames[key] and not seen[key] then
				seen[key] = true
				out[#out + 1] = { key = key, name = Name(key, frames[key]) }
			end
		end
		for _, k in ipairs(ELEMENT_KEYS) do add(k) end
		local singles = {}
		for k in pairs(frames) do
			local el, idx = k:match("^single_(%d+)_(%d+)$")
			if el then singles[#singles + 1] = { k = k, n = tonumber(el) * 100 + tonumber(idx) } end
		end
		table.sort(singles, function(a, b) return a.n < b.n end)
		for _, x in ipairs(singles) do add(x.k) end
		add("dropall")
		for _, t in ipairs(SP.GetCooldownBarOrder and SP:GetCooldownBarOrder() or {}) do add("cd_" .. t) end
		add("earthshield")
		local rest = {}
		for k in pairs(frames) do if not seen[k] then rest[#rest + 1] = k end end
		table.sort(rest)
		for _, k in ipairs(rest) do add(k) end
	end

	local function HasOwn(key)
		local s = Saved(key)
		if not s then return false end
		return s.scale ~= nil or s.opacity ~= nil or s.hideFrame == true or (IsTotem(key) and s.flyoutDirection ~= nil)
	end

	-- Copy Settings: its four settings as they are now (a value of its own, or none: the default)
	local function Snapshot(key)
		local s = Saved(key) or {}
		return { scale = s.scale, opacity = s.opacity, hideFrame = s.hideFrame == true, flyoutDirection = s.flyoutDirection,
			totem = IsTotem(key) }
	end
	-- a snapshot onto a tracker, through the engine's own setters (they move and repaint it). Flyout
	-- Direction only between totem buttons (the only trackers that have it)
	local function Apply(snap, key)
		if InCombatLockdown() then return end
		if snap.scale ~= nil then
			SP:SetPopOutScale(key, snap.scale)
		elseif (Saved(key) or {}).scale ~= nil then
			SP:SetPopOutScale(key, DefScale())
			Saved(key).scale = nil
		end
		if snap.opacity ~= nil then
			SP:SetPopOutOpacity(key, snap.opacity)
		elseif (Saved(key) or {}).opacity ~= nil then
			SP:SetPopOutOpacity(key, DefOpacity())
			Saved(key).opacity = nil
		end
		if Hidden(key) ~= (snap.hideFrame and true or false) then SP:TogglePopOutFrame(key) end
		if snap.totem and IsTotem(key) then
			if snap.flyoutDirection ~= nil then
				SP:SetPopOutFlyoutDirection(key, snap.flyoutDirection)
			elseif (Saved(key) or {}).flyoutDirection ~= nil then
				SP:SetPopOutFlyoutDirection(key, nil)   -- back on the inherited direction: the setter lays the flyout out again
			end
		end
	end
	local RESET = { hideFrame = false, totem = true }   -- (no scale, opacity or direction of its own)

	local function TipBody(item)
		if HasOwn(item.key) then return "It has settings of its own (click to see them)." end
		return "It uses the default settings (click to change them)."
	end

	local function MenuItems(item)
		local key = item.key
		local lock = InCombatLockdown()
		local r = {}
		if lock then
			r[#r + 1] = { text = LOCKED, disabled = true,
				tip = "Pop-out trackers are protected in a fight, so their settings can't change until it ends." }
			r[#r + 1] = SEP
		end
		local function S() return Saved(key) or {} end
		r[#r + 1] = { text = "Appearance", label = true }
		local sc = Slider("Scale", 0.5, 3, 0.05, function() return S().scale or DefScale() end, function(v)
			if InCombatLockdown() then return end
			SP:SetPopOutScale(key, v)
			SliderChanged(Popouts)
		end, nil, true, "How big this tracker is.", { kind = "size" })
		sc.disabled = lock
		r[#r + 1] = sc
		local op = Slider("Opacity", 0.1, 1, 0.05, function() return S().opacity or DefOpacity() end, function(v)
			if InCombatLockdown() then return end
			SP:SetPopOutOpacity(key, v)
			SliderChanged(Popouts)
		end, nil, true, "How see-through this tracker is.", { kind = "opacity" })
		op.disabled = lock
		r[#r + 1] = op
		local hb = Choice("Hide Background And Border", { { true, "On" }, { false, "Off" } }, function()
			local v = Hidden(key)
			return v, v
		end, function(v)
			if InCombatLockdown() then return end
			if Hidden(key) ~= v then SP:TogglePopOutFrame(key) end
			Changed(Popouts, true)
			return true
		end, "Hide this tracker's background and border; its icon stays. ALT+drag still moves it.", { kind = "plain" })
		hb.words = "only the icon, no background or border"
		hb.disabled = lock
		r[#r + 1] = hb
		r[#r + 1] = SEP
		-- where it sits, and its panel
		r[#r + 1] = { text = "Position & Keys", label = true }
		if IsTotem(key) then
			local fd = Choice("Flyout Direction", { { "top", "Top" }, { "bottom", "Bottom" }, { "left", "Left" }, { "right", "Right" } },
				function() return S().flyoutDirection or "bottom", S().flyoutDirection ~= nil end, function(v)
					if InCombatLockdown() then return end
					SP:SetPopOutFlyoutDirection(key, v)
					Changed(Popouts, true)
					return true
				end, "Where this totem button's flyout opens.", { kind = "none" })
			fd.words = "where its flyout opens"
			fd.disabled = lock
			r[#r + 1] = fd
		end
		r[#r + 1] = { text = "Return to Bar", disabled = lock,
			tip = "Puts it back on its bar, as a middle-click on the tracker does.",
			onClick = function()
				if InCombatLockdown() then return end
				SP:ReturnPopOutToBar(key)
				Changed(Popouts, false)
				Relayout(Popouts)
			end }
		r[#r + 1] = { text = "Open Tracker Settings", disabled = lock,
			tip = "Opens the same settings panel as the tracker's cog (or SHIFT+middle-click on it).",
			onClick = function()
				local f = Frames()[key]
				if f and SP.ShowPopOutSettingsPanel then SP:ShowPopOutSettingsPanel(key, f) end
			end }
		r[#r + 1] = SEP
		-- copy and reset
		r[#r + 1] = { text = "Copy & Reset", label = true }
		r[#r + 1] = { text = "Copy Settings", disabled = lock, onClick = function()
			Popouts.clip = { from = key, name = item.name, snap = Snapshot(key) }
			return true
		end }
		local clip = Popouts.clip
		r[#r + 1] = { text = clip and ("Paste Settings  (from " .. clip.name .. ")") or "Paste Settings",
			disabled = lock or not clip or clip.from == key,
			onClick = function()
				if Popouts.clip then Apply(Popouts.clip.snap, key) end
				Changed(Popouts, true)
				return true
			end }
		r[#r + 1] = { text = "Copy Settings To...", disabled = lock, subMaxHeight = 420,
			words = "its settings onto another tracker, or all of them", sub = function()
			local o, list = {}, {}
			Items(list)
			for _, x in ipairs(list) do
				if x.key ~= key then
					o[#o + 1] = { text = x.name, icon = Icon(x.key, Frames()[x.key]), onClick = function()
						Apply(Snapshot(key), x.key)
						Changed(Popouts, false)
					end }
				end
			end
			o[#o + 1] = SEP
			o[#o + 1] = { text = "All Trackers", onClick = function()
				local snap = Snapshot(key)
				for _, x in ipairs(list) do if x.key ~= key then Apply(snap, x.key) end end
				Changed(Popouts, false)
			end }
			return o
		end }
		r[#r + 1] = { text = "Reset Tracker Appearance", disabled = lock or not HasOwn(key),
			tip = "Restore this tracker's default size, visibility, background, border, and flyout direction. Keep its position.",
			onClick = function()
				Apply(RESET, key)
				Changed(Popouts, false)
			end }
		return r
	end

	Popouts = ns.IconRow.New({
		caption = function()
			if next(Frames()) == nil then return "Each tracker you pop out shows up here, with its settings in its menu." end
			return B .. "CLICK" .. E .. " or " .. B .. "RIGHT-CLICK" .. E .. " a tracker for its settings: its size, opacity"
				.. " and background, or put it back on its bar. A blue corner: it has settings of its own."
		end,
		hint = "Click: its settings",
		empty = function()
			local how = " a totem button, a cooldown bar item" .. (SP.ESTrackerUnavailable and "" or ", Earth Shield")
				.. " or Drop All to pop it out as a tracker of its own."
			if SP.opt and SP.opt.enableMiddleClickPopOut == false then
				return "Nothing is popped out right now. Enable Middle-Click Pop-Out (above) is off: turn it on, then "
					.. B .. "MIDDLE-CLICK" .. E .. how
			end
			return "Nothing is popped out right now. " .. B .. "MIDDLE-CLICK" .. E .. how
		end,
		list = Items,
		textures = function(item, out)
			out[1] = Icon(item.key, Frames()[item.key])
			return 1
		end,
		shown = function() return true end,
		hasOwn = function(item) return HasOwn(item.key) end,
		tooltip = TipBody,
		clickMenu = true,   -- (A18 Q7: no on / off; a stray click never sends a tracker back)
		menu = MenuItems,
		locked = function() return InCombatLockdown() end,
		openLocked = true,   -- (in a fight the menu still opens: gray, saying why)
		onLocked = function() Red(LOCKED_TEXT) end,
	})
	ns.CustomRows.popoutIcons = Popouts

	-- a tracker popped out or returned while the page is open (a middle-click on the bars): the row follows
	local function Follow()
		C_Timer.After(0, function()
			local f = Popouts.frame
			if f and f:IsVisible() then Popouts:OnSettingsChanged() end
		end)
	end
	if type(SP.CreatePopOutFrame) == "function" then hooksecurefunc(SP, "CreatePopOutFrame", Follow) end
	if type(SP.ReturnPopOutToBar) == "function" then hooksecurefunc(SP, "ReturnPopOutToBar", Follow) end

	-- SP:PopOutOpenTrackerMenu(key): the settings window on Pop-Out Trackers with that tracker's menu open
	-- (Unlock UI: a right-click on a split Grid row's box)
	function SP.PopOutOpenTrackerMenu(_, key)
		local cfg = _G.ShamanPowerConfig
		if not (cfg and cfg.Open) then return end
		Popouts:QueueMenu(key)
		cfg:Open({ "fluffy", "popout_section" })
	end

	-- Reset This Page (Pop-Out Trackers): every tracker's Scale, Opacity, Hide Background and Flyout
	-- Direction back to the defaults, popped out now or not. Where each one sits stays.
	function SP.PopOutResetPage(sp)
		if InCombatLockdown() or not sp.opt then return end
		local frames = sp.poppedOutFrames or {}
		for key, s in pairs(sp.opt.poppedOutSettings or {}) do
			if type(s) == "table" then
				if frames[key] then
					Apply(RESET, key)
				else
					s.scale, s.opacity, s.hideFrame, s.flyoutDirection = nil, nil, nil, nil
				end
			end
		end
	end
end

-- ===========================================================================
-- Raid Cooldowns (TBC Anniversary): Bloodlust or Heroism, Mana Tide Totem, Drums of Battle
-- ===========================================================================
local Raid
do
	local NONE = ""
	local DRUMS_ICON = "Interface\\Icons\\INV_Misc_Drum_02"
	local function HasBL() return SPCompat and SPCompat.HasBloodlust and SPCompat.HasBloodlust() or false end
	local function HasDrums() return SPCompat and SPCompat.HasDrums and SPCompat.HasDrums() or false end
	local function Alliance() return UnitFactionGroup and UnitFactionGroup("player") == "Alliance" end
	local function Loaded() return SP.RaidCooldownsLoaded and SP.InitRaidCooldowns and true or false end
	local function DB()
		if not Loaded() then return nil end
		SP:InitRaidCooldowns()
		return ShamanPower_RaidCooldowns
	end
	local function CanAssign() return Loaded() and SP.CanAssignRaidCooldowns and SP:CanAssignRaidCooldowns() and true or false end
	local function Names(method)
		if not (Loaded() and SP[method]) then return {} end
		return SP[method](SP) or {}
	end
	-- sent to the raid, the caller buttons follow (as the old rows and the assignments window do)
	local function Sync()
		if SP.SendRaidCooldownSync then SP:SendRaidCooldownSync() end
		if SP.UpdateCallerButtons then SP:UpdateCallerButtons() end
	end

	local function Assigned(key)
		local db = DB()
		if not db then return false end
		if key == "bl" then
			local bl = db.bloodlust or {}
			return (bl.primary or bl.backup1 or bl.backup2 or bl.caller) and true or false
		elseif key == "mt" then
			for _, a in pairs(db.manatide or {}) do
				if type(a) == "table" and a.caller then return true end
			end
			return false
		end
		local d = db.drums or {}
		if d.caller then return true end
		for _, n in pairs(d.drummers or {}) do
			if n and n ~= "" then return true end
		end
		return false
	end

	-- a pick line: None, then the names (one assigned who left the group stays in the list)
	local function Pick(text, names, get, set, tip, lock)
		local list = { { NONE, "None" } }
		local cur = get()
		local found = cur == nil
		for _, n in ipairs(names) do
			list[#list + 1] = { n, n }
			if n == cur then found = true end
		end
		if not found then list[#list + 1] = { cur, cur } end
		local it = Choice(text, list, function()
			local v = get()
			return v or NONE, v ~= nil
		end, function(v)
			if not CanAssign() then return end
			set(v ~= NONE and v or nil)
			Sync()
			Changed(Raid, true)
			return true
		end, tip, { kind = "none" })
		it.disabled = lock
		return it
	end

	local function MenuItems(item)
		local r = {}
		local db = DB()
		local lock = not CanAssign()
		if not db then
			r[#r + 1] = { text = "Raid Cooldowns is not loaded", disabled = true,
				tip = "Turn on ShamanPower [Raid Cooldowns] in the AddOns list, then type /reload." }
			return r
		end
		if lock then
			r[#r + 1] = { text = "Only your raid leader or an assistant can change these", disabled = true }
			r[#r + 1] = SEP
		end
		r[#r + 1] = { text = "Behavior", label = true }
		local key = item.key
		if key == "bl" then
			local bl = db.bloodlust
			local shamans, members = Names("GetRaidShamans"), Names("GetRaidMembers")
			local function F(field) return function() return bl[field] end, function(v) bl[field] = v end end
			local g, s = F("primary")
			r[#r + 1] = Pick("Primary", shamans, g, s, "The shaman who casts " .. item.name .. " when it's called.", lock)
			g, s = F("backup1")
			r[#r + 1] = Pick("Backup 1", shamans, g, s, "Casts it if the primary is dead.", lock)
			g, s = F("backup2")
			r[#r + 1] = Pick("Backup 2", shamans, g, s, "Casts it if the primary and Backup 1 are dead.", lock)
			g, s = F("caller")
			r[#r + 1] = Pick("Caller", members, g, s, "Who may call for " .. item.name .. ", besides the raid leader and assistants.", lock)
		elseif key == "mt" then
			local mt = db.manatide
			local members = Names("GetRaidMembers")
			local tide = Names("GetManaTideShamans")
			if #tide == 0 then
				r[#r + 1] = { text = "No shaman in your group has " .. item.name, disabled = true }
			end
			for _, info in ipairs(tide) do
				local name = info.name
				r[#r + 1] = Pick(name .. "'s Caller  |cff8A94A6G" .. tostring(info.group) .. "|r", members,
					function() return mt[name] and mt[name].caller or nil end,
					function(v)
						mt[name] = mt[name] or {}
						mt[name].caller = v
					end, "Who may call " .. name .. "'s " .. item.name .. " (group " .. tostring(info.group) .. ").", lock)
			end
		else
			local drums = db.drums
			drums.drummers = drums.drummers or {}
			r[#r + 1] = Pick("Caller", Names("GetRaidMembers"), function() return drums.caller end,
				function(v) drums.caller = v end, "Who may call for Drums, besides the raid leader and assistants.", lock)
			r[#r + 1] = SEP
			local groups = SP.GetGroupMembers and SP:GetGroupMembers() or {}
			local ids = {}
			for g in pairs(groups) do ids[#ids + 1] = g end
			table.sort(ids)
			for _, g in ipairs(ids) do
				r[#r + 1] = Pick(IsInRaid() and ("Group " .. tostring(g) .. " Drummer") or "Party Drummer", groups[g],
					function() local n = drums.drummers[g]; if n == "" then return nil end return n end,
					function(v) drums.drummers[g] = v end, "Drums only reach the drummer's own group.", lock)
			end
		end
		r[#r + 1] = SEP
		r[#r + 1] = { text = "Clear Assignments", disabled = lock or not Assigned(key),
			tip = "Clear all assignments for this cooldown.",
			onClick = function()
				if not CanAssign() then return end
				if key == "bl" then
					local bl = db.bloodlust
					bl.primary, bl.backup1, bl.backup2, bl.caller = nil, nil, nil, nil
				elseif key == "mt" then
					for _, a in pairs(db.manatide) do if type(a) == "table" then a.caller = nil end end
				else
					db.drums.caller = nil
					wipe(db.drums.drummers or {})
				end
				Sync()
				Changed(Raid, false)
			end }
		return r
	end

	-- the item's assignments in a line or two (its tooltip)
	local function TipBody(item)
		local db = DB()
		if not db then return "Raid Cooldowns is not loaded." end
		local parts = {}
		if item.key == "bl" then
			local bl = db.bloodlust
			for _, f in ipairs({ { "primary", "Primary" }, { "backup1", "Backup 1" }, { "backup2", "Backup 2" }, { "caller", "Caller" } }) do
				if bl[f[1]] then parts[#parts + 1] = f[2] .. ": " .. bl[f[1]] end
			end
		elseif item.key == "mt" then
			for name, a in pairs(db.manatide) do
				if type(a) == "table" and a.caller then parts[#parts + 1] = name .. "'s caller: " .. a.caller end
			end
			table.sort(parts)
		else
			local d = db.drums
			if d.caller then parts[#parts + 1] = "Caller: " .. d.caller end
			local ids = {}
			for g, n in pairs(d.drummers or {}) do if n and n ~= "" then ids[#ids + 1] = g end end
			table.sort(ids)
			for _, g in ipairs(ids) do parts[#parts + 1] = "Group " .. tostring(g) .. ": " .. d.drummers[g] end
		end
		if #parts == 0 then return "No one is assigned yet." end
		return table.concat(parts, ". ") .. "."
	end

	Raid = ns.IconRow.New({
		caption = B .. "CLICK" .. E .. " a cooldown to choose who casts it and who may call for it. A blue corner: someone"
			.. " is assigned. Your raid leader and assistants set these; everyone else sees them.",
		hint = "Click: who casts it and who may call for it",
		list = function(out)
			if HasBL() then
				local alliance = Alliance()
				out[#out + 1] = { key = "bl", name = alliance and Label(32182, "Heroism") or Label(2825, "Bloodlust"),
					spell = alliance and 32182 or 2825 }
			end
			out[#out + 1] = { key = "mt", name = Label(16190, "Mana Tide Totem"), spell = 16190 }
			if HasDrums() then out[#out + 1] = { key = "dr", name = Label(35476, "Drums of Battle") } end
		end,
		textures = function(item, out)
			out[1] = item.spell and SpellTexture(item.spell) or DRUMS_ICON
			return 1
		end,
		shown = function() return true end,
		hasOwn = function(item) return Assigned(item.key) end,   -- (the corner: someone is assigned)
		tooltip = TipBody,
		clickMenu = true,   -- (A18 Q10: your raid's spells, not yours: no on / off)
		menu = MenuItems,
	})
	ns.CustomRows.raidIcons = Raid
end

-- ===========================================================================
-- Changed elsewhere while the page is open (the Totem Range Picker, a pop-out's own panel,
-- the Raid Cooldown Assignments window, Coverage's panel, a sync from the raid): the rows
-- shown follow. Only on a change notice, and only a row on screen does anything.
-- ===========================================================================
do
	local registry = _G.LibStub and _G.LibStub("AceConfigRegistry-3.0", true)
	if registry and registry.RegisterCallback then
		local rows = { Coverage, Range, Popouts, Raid }
		registry.RegisterCallback({}, "ConfigTableChange", function(_, appName)
			if appName ~= "ShamanPower" or busy then return end
			for _, row in ipairs(rows) do
				local f = row.frame
				if f and f:IsVisible() then
					local ok, err = pcall(row.OnSettingsChanged, row)
					if not ok then Report(err) end
				end
			end
		end)
	end
end
