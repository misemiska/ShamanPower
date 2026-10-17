-- ShamanPowerCountdown.lua (3.0.9.1, sheet A49): Countdown Colors. The numbers that count a cooldown
-- down change color as it runs, by the share of the cooldown's own length that is left (the owner,
-- 2026-10-17: every cooldown goes through all three colors, a 6 s shock and a 3 min cooldown alike):
-- the first color while more than half is left, the second from the half mark down, the third under a
-- quarter. (OmniCC's seconds-left rule was tried and dropped the same day: under it a short cooldown
-- never reaches the first color.) The colors come as a preset (ShamanPower: red / yellow / green, or White / Yellow /
-- Red), One Color the Whole Time (the Totem Bar's Cooldown Text Color, for a player who wants their
-- purple to stay purple), or Custom (three swatches, the first of them the Totem Bar's Cooldown Text
-- Color). Each bar has its own switch, off to start: nothing changes until a player turns one on.
-- Totem Bar, Cooldown Bar: the addon's own text is painted by its bucket on each pass (TBC
-- Anniversary, and Forever out of a fight). WoW: Forever in a fight: the time is a secret, so the
-- game writes the text itself from a duration object (a duration text binding on the addon's own
-- text) and colors it through a color curve on the time left in percent: the same rule, kept by the game. Ready Reminders bind the same way (ShamanPower_ReadyReminders.lua).
local SP = ShamanPower
if not SP then return end

local DEF = { { 1, 1, 1 }, { 1, 0.85, 0.15 }, { 0.35, 1, 0.4 } }
SP.COUNTDOWN_PRESETS = {
	{ "shamanpower", "ShamanPower (red / yellow / green)", { { 1, 0.25, 0.25 }, { 1, 0.85, 0.15 }, { 0.35, 1, 0.4 } } },
	{ "wyr", "White / Yellow / Red", { { 1, 1, 1 }, { 1, 1, 0.1 }, { 1, 0.1, 0.1 } } },
	{ "solid", "One Color the Whole Time" },
	{ "custom", "Custom" },
}
-- Two sets of the same shape (the owner, 2026-10-17): "cd" = Cooldown Numbers, the number a cooldown
-- counts down with; "buff" = Buff Timers, a buff's, a shield's, an imbue's or a totem's time left.
-- Each has its own preset, three colors and three switches. A set of nil is "cd".
local SETS = {
	cd = { preset = "countdownPreset", first = "totemCooldownTextColor", mid = "countdownColorMid", last = "countdownColorEnd",
		switches = { totem = "totemBarCountdownColors", cdbar = "cdbarCountdownColors", ready = "readyCountdownColors" } },
	buff = { preset = "buffTimerPreset", first = "buffTimerColorStart", mid = "buffTimerColorMid", last = "buffTimerColorEnd",
		switches = { totem = "totemBarBuffTimerColors", cdbar = "cdbarBuffTimerColors", ready = "readyBuffTimerColors" } },
}
local function SetOf(set) return SETS[set or "cd"] or SETS.cd end
SP.COUNTDOWN_SETS = SETS
SP.COUNTDOWN_SWITCHES = SETS.cd.switches
SP.BUFF_TIMER_SWITCHES = SETS.buff.switches
local version = 1

function SP:CountdownVersion() return version end
function SP:CountdownOn(bar, set)
	local o = self.opt
	return o ~= nil and o[SetOf(set).switches[bar]] == true
end
function SP:CountdownPreset(set)
	local p = self.opt and self.opt[SetOf(set).preset]
	if p == "wyr" or p == "solid" or p == "custom" then return p end
	return "shamanpower"
end
function SP:CountdownSolid(set) return self:CountdownPreset(set) == "solid" end
local function PresetColors(p)
	for _, pr in ipairs(SP.COUNTDOWN_PRESETS) do if pr[1] == p then return pr[3] end end
	return nil
end
local function Col(c, d)
	if type(c) == "table" then return c.r or c[1] or d[1], c.g or c[2] or d[2], c.b or c[3] or d[3] end
	return d[1], d[2], d[3]
end
-- the n-th color (1: more than half left, 2: half and under, 3: under a quarter) under the preset in use
function SP:CountdownColorN(n, set)
	local K = SetOf(set)
	local p, o = self:CountdownPreset(set), self.opt
	if p == "solid" then return Col(o and o[K.first], DEF[1]) end
	local pc = PresetColors(p)
	if pc then
		local c = pc[n] or pc[1]
		return c[1], c[2], c[3]
	end
	if n == 1 then return Col(o and o[K.first], DEF[1]) end
	if n == 2 then return Col(o and o[K.mid], DEF[2]) end
	return Col(o and o[K.last], DEF[3])
end
-- the bands, as a share of the total: the second color from the half mark down (a 6 s shock reads "3" in
-- the second color, not the first), the third under a quarter
SP.COUNTDOWN_HALF, SP.COUNTDOWN_LAST = 0.5, 0.25
function SP:CountdownBucket(remaining, total, set)
	if self:CountdownSolid(set) or not remaining or not total or total <= 0 then return 1 end
	local f = remaining / total
	if f > SP.COUNTDOWN_HALF then return 1 elseif f > SP.COUNTDOWN_LAST then return 2 end
	return 3
end
function SP:CountdownColor(remaining, total, set)
	local b = self:CountdownBucket(remaining, total, set)
	local r, g, bl = self:CountdownColorN(b, set)
	return r, g, bl, b
end
function SP:CountdownBase(bar, set)
	if bar == "totem" and (set or "cd") == "cd" then
		local c = self.opt and self.opt.totemCooldownTextColor
		return Col(c, DEF[1])
	end
	return 1, 1, 1
end
-- a text the addon writes itself: its color by what is left (only when the bucket changes); a bar
-- switched off puts the text's own color back
function SP:CountdownPaint(fs, bar, remaining, total, set)
	if not fs then return end
	if not self:CountdownOn(bar, set) then
		if fs.spCdBucket then
			fs.spCdBucket = nil
			fs:SetTextColor(self:CountdownBase(bar, set))
		end
		return
	end
	local bucket = self:CountdownBucket(remaining, total, set)
	if fs.spCdBucket == bucket and fs.spCdV == version then return end
	fs.spCdBucket, fs.spCdV = bucket, version
	fs:SetTextColor(self:CountdownColorN(bucket, set))
end
function SP:CountdownPaintTexts(bar, remaining, total, ...)
	for i = 1, select("#", ...) do
		local fs = select(i, ...)
		if fs then self:CountdownPaint(fs, bar, remaining, total) end
	end
end
-- the same for a time left (Buff Timers)
function SP:CountdownPaintTimerTexts(bar, remaining, total, ...)
	for i = 1, select("#", ...) do
		local fs = select(i, ...)
		if fs then self:CountdownPaint(fs, bar, remaining, total, "buff") end
	end
end
function SP:CountdownPaintCdbar(btn, remaining, total, set)
	for _, fs in ipairs({ btn.timeText, btn.insideText, btn.outsideText, btn.iconText }) do
		self:CountdownPaint(fs, "cdbar", remaining, total, set)
	end
end

-- Settings
function SP:SetCountdownPreset(p, set)
	self.opt[SetOf(set).preset] = p
	self:CountdownChanged()
end
-- a swatch edited: the colors in use become the three swatches (Custom), then the one edited changes
function SP:SetCountdownColor(n, r, g, b, set)
	local o, K = self.opt, SetOf(set)
	if self:CountdownPreset(set) ~= "custom" then
		local c = {}
		for i = 1, 3 do c[i] = { self:CountdownColorN(i, set) } end
		o[K.first] = { r = c[1][1], g = c[1][2], b = c[1][3] }
		o[K.mid] = { r = c[2][1], g = c[2][2], b = c[2][3] }
		o[K.last] = { r = c[3][1], g = c[3][2], b = c[3][3] }
		o[K.preset] = "custom"
	end
	local key = (n == 1 and K.first) or (n == 2 and K.mid) or K.last
	o[key] = { r = r, g = g, b = b }
	self:CountdownChanged()
end
-- a switch, a preset or a color changed: every countdown starts over with the new colors
function SP:CountdownChanged()
	version = version + 1
	self.countdownCurves, self.countdownFormatters = nil, nil
	-- the totem texts' time left (Buff Timers): their own color back, a theme's repainted
	for element = 1, 4 do
		local bars = self.totemProgressBars and self.totemProgressBars[element]
		if bars then
			for _, k in ipairs({ "insideTextTop", "insideTextBottom", "aboveBarText", "belowBarText", "iconText" }) do
				local fs = bars[k]
				if fs and fs.spCdBucket then fs.spCdBucket = nil; fs:SetTextColor(1, 1, 1) end
			end
			if self.ThemePaintDurationBars then self:ThemePaintDurationBars(element, false) end
		end
	end
	if self.ApplyTotemCooldownTextColor then self:ApplyTotemCooldownTextColor() end   -- the totem texts' own color, the engine restyled
	for element = 1, 4 do
		local btn = self.totemButtons and self.totemButtons[element]
		if btn then btn._engineCDKey = nil end   -- the engine feeds start over (a binding on or off)
		local flyout = self.totemFlyouts and self.totemFlyouts[element]
		if flyout and flyout.buttons then for _, b in ipairs(flyout.buttons) do b._engineCDKey = nil end end
		local copies = self.RowsCopies and self:RowsCopies(element)
		if copies then for i = 1, #copies do copies[i]._engineCDKey = nil end end
	end
	if self.ResetEngineBarCooldowns then self:ResetEngineBarCooldowns() end
	for _, btn in ipairs(self.cooldownButtons or {}) do
		for _, k in ipairs({ "timeText", "insideText", "outsideText", "iconText", "insideText2", "outsideText2", "iconText2" }) do
			local fs = btn[k]
			if fs and fs.spCdBucket then fs.spCdBucket = nil; fs:SetTextColor(1, 1, 1) end
		end
	end
	if self.RunOutResetLooks then self:RunOutResetLooks() end
	if self.ReadyCountdownChanged then self:ReadyCountdownChanged() end
	if self.RebuildShieldChargeContainer then self:RebuildShieldChargeContainer() end   -- the game-drawn shield's time color
end

-- WoW: Forever: the game writes and colors the text from a duration object (a secret in a fight)
local function Util() return C_DurationUtil end
-- the curve runs on the time left in percent (RemainingPercent), the rule's own measure
local function Prop() return Enum and Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty.RemainingPercent end
function SP:CountdownCurveProperty() return Prop() end
-- the scale the BINDING's percent runs on. A duration's own GetRemainingPercent answers 0..1, but a text
-- binding's RemainingPercent property runs 0..100 (measured in game on WoW: Forever 1.60.1.70425,
-- 2026-10-17: a curve point at 2 colored a binding with 99.7% left). Scaled by the getter, every line
-- sat in the last half percent: white to the end, then a flash of the last color. Measured here once on
-- a binding of our own (not a secret: our own duration), 100 when the measure cannot be taken.
local bindScale, bindMeasured, bindNoApi, probeText
local function BindScale()
	if bindScale then return bindScale end
	bindScale = 100
	local D, CU = Util(), C_CurveUtil
	if not (D and D.CreateDurationTextBinding and D.CreateDuration and CU and CU.CreateColorCurve and CreateColor and Prop()) then
		bindNoApi = true
		return bindScale
	end
	pcall(function()
		local c = CU.CreateColorCurve()
		c:SetType(Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step or 1)
		c:AddPoint(0, CreateColor(0, 1, 0, 1))
		c:AddPoint(2, CreateColor(1, 0, 0, 1))   -- 0..1: below 2 (green); 0..100: above it (red)
		local d = D.CreateDuration()
		d:SetTimeFromStart(GetTime() - 2, 800)
		probeText = probeText or UIParent:CreateFontString()
		local b = D.CreateDurationTextBinding()
		b:SetFontString(probeText)
		b:SetDuration(d)
		b:SetTextColorCurve(c, Prop())
		local r = b:GetFormattedTextColor():GetRGB()
		if type(r) == "number" and not (issecretvalue and issecretvalue(r)) then bindScale = (r > 0.5) and 100 or 1; bindMeasured = true end
		b:SetEnabled(false)
	end)
	return bindScale
end
-- the support code's reading: the scale in use and whether it was measured (false: 100 assumed);
-- nil where the game has no duration text bindings (Anniversary)
function SP:CountdownScale()
	local s = BindScale()
	if bindNoApi then return nil end
	return s, bindMeasured == true
end
function SP:CountdownCurve(set)
	set = set or "cd"
	self.countdownCurves = self.countdownCurves or {}
	local c = self.countdownCurves[set]
	if c then return c end
	local CU = C_CurveUtil
	if not (CU and CU.CreateColorCurve and CreateColor) then return nil end
	local ok, curve = pcall(CU.CreateColorCurve)
	if not (ok and curve) then return nil end
	local step = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step or 1
	pcall(curve.SetType, curve, step)
	local s = BindScale()   -- the binding's scale (0..100 on WoW: Forever), not the getter's
	local r1, g1, b1 = self:CountdownColorN(1, set)
	local r2, g2, b2 = self:CountdownColorN(2, set)
	local r3, g3, b3 = self:CountdownColorN(3, set)
	-- a step curve holds a point's color up to the next point: the third color below a quarter, the second
	-- up to (and at) the half mark, the first above it (a hair past it, so the half mark itself is the second)
	if not (pcall(curve.AddPoint, curve, 0, CreateColor(r3, g3, b3, 1))
		and pcall(curve.AddPoint, curve, SP.COUNTDOWN_LAST * s, CreateColor(r2, g2, b2, 1))
		and pcall(curve.AddPoint, curve, SP.COUNTDOWN_HALF * s + 0.0001 * s, CreateColor(r1, g1, b1, 1))) then return nil end
	self.countdownCurves[set] = curve
	return curve
end
-- the text as the addon writes it: the totem bar's (tenths under 10 s, whole seconds, "2m") and the
-- cooldown bar's (seconds, m:ss, then minutes and hours)
function SP:CountdownFormatter(kind)
	self.countdownFormatters = self.countdownFormatters or {}
	local f = self.countdownFormatters[kind]
	if f ~= nil then return f or nil end
	local S = C_StringUtil
	local ok, made = false, nil
	if S and S.CreateNumericRuleFormatter then ok, made = pcall(S.CreateNumericRuleFormatter) end
	if not (ok and made and made.AddBreakpoint) then self.countdownFormatters[kind] = false return nil end
	local R = Enum and Enum.NumericRuleFormatRounding or {}
	local up, down = R.Up or 1, R.Down or 2
	local good
	if kind == "ready" then
		-- Ready Reminders' own form: whole seconds up to a minute, then "2m" (rounded up, as the addon writes it)
		good = pcall(made.AddBreakpoint, made, { threshold = 0, step = 1, rounding = up, format = "%d" })
		pcall(made.AddBreakpoint, made, { threshold = 60, format = "%dm", components = { { div = 60, step = 1, rounding = up } } })
	elseif kind == "totem" then
		good = pcall(made.AddBreakpoint, made, { threshold = 0, step = 0.1, rounding = down, format = "%.1f" })
		if not good then good = pcall(made.AddBreakpoint, made, { threshold = 0, step = 1, rounding = up, format = "%d" }) end
		good = good and pcall(made.AddBreakpoint, made, { threshold = 10, step = 1, rounding = down, format = "%d" })
		pcall(made.AddBreakpoint, made, { threshold = 60, format = "%dm", components = { { div = 60, step = 1, rounding = up } } })
	else
		good = pcall(made.AddBreakpoint, made, { threshold = 0, step = 1, rounding = down, format = "%d" })
		pcall(made.AddBreakpoint, made, { threshold = 60, format = "%d:%02d", components = { { div = 60, step = 1, rounding = down }, { mod = 60, step = 1, rounding = down } } })
		pcall(made.AddBreakpoint, made, { threshold = 600, format = "%dm", components = { { div = 60, step = 1, rounding = down } } })
		pcall(made.AddBreakpoint, made, { threshold = 3600, format = "%dh", components = { { div = 3600, step = 1, rounding = down } } })
	end
	if not good then self.countdownFormatters[kind] = false return nil end
	self.countdownFormatters[kind] = made
	return made
end
function SP:CountdownBind(fs, d, kind, set)
	if not (fs and d) then return false end
	set = set or "cd"
	local D = Util()
	if not (D and D.CreateDurationTextBinding) then return false end
	local bnd = fs.spCountdownBind
	if bnd == nil then
		local ok, made = pcall(D.CreateDurationTextBinding)
		if ok and made and pcall(made.SetFontString, made, fs) then
			if made.SetExpiredText then pcall(made.SetExpiredText, made, "") end
			bnd = made
		else
			bnd = false
		end
		fs.spCountdownBind = bnd
	end
	if not bnd then return false end
	if fs.spCountdownV ~= version or fs.spCountdownKind ~= kind or fs.spCountdownSet ~= set then
		fs.spCountdownV, fs.spCountdownKind, fs.spCountdownSet = version, kind, set
		local fmt = self:CountdownFormatter(kind)
		if fmt then pcall(bnd.SetFormatter, bnd, fmt) end
		local curve, P = self:CountdownCurve(set), Prop()
		if curve and P then pcall(bnd.SetTextColorCurve, bnd, curve, P)
		elseif bnd.ClearTextColorCurve then pcall(bnd.ClearTextColorCurve, bnd) end
	end
	if not pcall(bnd.SetDuration, bnd, d) then return false end
	pcall(bnd.SetEnabled, bnd, true)
	fs.spCountdownOn = true
	return true
end
function SP:CountdownUnbind(fs)
	if not (fs and fs.spCountdownOn) then return end
	fs.spCountdownOn = nil
	local bnd = fs.spCountdownBind
	if bnd then pcall(bnd.SetEnabled, bnd, false) end
	fs:SetText("")
end
-- the cooldown bar's engine-drawn time: the addon's own text (where Time Text Position puts it, or the
-- button's middle with Show Cooldown Text) written and colored by the game; the widget's numbers go
function SP:CountdownBindEngineBar(btn, d, textLocation, showText)
	local src
	if textLocation == "inside" then src = btn.insideText
	elseif textLocation == "outside" then src = btn.outsideText
	elseif textLocation == "icon" then src = btn.iconText
	elseif showText then src = btn.timeText end
	local on = self:CountdownOn("cdbar") and src and d
	for _, k in ipairs({ "timeText", "insideText", "outsideText", "iconText" }) do
		local fs = btn[k]
		if fs and not (on and fs == src) then self:CountdownUnbind(fs) end
	end
	if not on then return end
	if self:CountdownBind(src, d, "cdbar") then
		if btn.cooldown then btn.cooldown:SetHideCountdownNumbers(true) end
		src:Show()
	end
end
function SP:CountdownUnbindEngineBar(btn)
	for _, k in ipairs({ "timeText", "insideText", "outsideText", "iconText" }) do
		if btn[k] then self:CountdownUnbind(btn[k]) end
	end
end
