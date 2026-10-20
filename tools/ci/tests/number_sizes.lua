-- client: both
-- Number Sizes (3.0.9.3): Appearance > Fonts & Textures, every cooldown number and time left
-- in one place (the owner: "a place to look for a general setup"). Totem Bar Cooldown Numbers
-- is new; the time left texts are their pages' own settings; Ready Reminders' page sizes,
-- with an icon's own size (its right-click menu) still winning.
local SP = ShamanPower
local o = SP.opt
local a = SP.options.args.settings.args.settings_fonts.args
for _, k in ipairs({ "sizes_header", "size_totem_cd", "size_totem_time", "size_totem_pulse", "size_cdbar_time",
	"size_ready_cd", "size_ready_time", "sizes_reset" }) do
	check("Fonts & Textures has " .. k, a[k] ~= nil)
end
checkEq("0 reads Auto", SP.OptionSliderFormat[a.size_totem_cd](0), "Auto")
checkEq("a size reads as itself", SP.OptionSliderFormat[a.size_totem_cd](14), "14")

-- Totem Bar Cooldown Numbers: the bar's buttons and the flyouts'
local btn = SP.totemButtons and SP.totemButtons[1]
local fs = btn and btn.cooldownText
check("a totem button has its cooldown number", fs ~= nil)
if fs then
	local _, design = fs:GetFont()
	a.size_totem_cd.set(nil, 17)
	checkEq("saved", o.totemCooldownTextSize, 17)
	checkEq("the button's number takes 17", select(2, fs:GetFont()), 17)
	local fly = SP.totemFlyouts and SP.totemFlyouts[1]
	local fb = fly and fly.buttons and fly.buttons[1]
	if fb and fb.cooldownText then checkEq("a flyout button's number takes 17", select(2, fb.cooldownText:GetFont()), 17) end
	SP:RefreshFonts()
	checkEq("a font change keeps the size", select(2, fs:GetFont()), 17)
	a.size_totem_cd.set(nil, 0)
	checkEq("Auto: nothing saved", o.totemCooldownTextSize, nil)
	checkEq("Auto: back to the design's size", select(2, fs:GetFont()), design)
end

-- the time left texts: the same settings as on their pages
local keep = { o.durationTextSize, o.pulseTextSize, o.cdbarDurationTextSize }
a.size_totem_time.set(nil, 12); checkEq("Totem Bar Time Left = durationTextSize", o.durationTextSize, 12)
a.size_totem_pulse.set(nil, 11); checkEq("Totem Bar Pulse Time = pulseTextSize", o.pulseTextSize, 11)
a.size_cdbar_time.set(nil, 13); checkEq("Cooldown Bar Time Text = cdbarDurationTextSize", o.cdbarDurationTextSize, 13)
checkEq("Totem Bar Time Left reads it back", a.size_totem_time.get(), 12)
o.durationTextLocation = "none"
check("grayed while the totem bar hides its time left", a.size_totem_time.disabled() == true)

-- Ready Reminders: the page's size; an icon's own wins
if SP.ReadyReminderSetPageOpt then
	local key
	for _, e in ipairs(SP.ReadyReminderSpells or {}) do if e.key then key = e.key break end end
	a.size_ready_cd.set(nil, 22)
	checkEq("the page's Countdown size", SP:ReadyReminderPageOpt("textSize"), 22)
	if key then
		checkEq("an icon without its own uses it", SP:ReadyReminderIconOpt(key, "textSize"), 22)
		SP:ReadyReminderSetIconOpt(key, "textSize", 9)
		checkEq("an icon's own size wins", SP:ReadyReminderIconOpt(key, "textSize"), 9)
		SP:ReadyReminderSetIconOpt(key, "textSize", nil)
	end
	a.size_ready_time.set(nil, 15)
	checkEq("the page's Time Left size", SP:ReadyReminderPageOpt("buffTimeSize"), 15)
else
	skip("Ready Reminders is not loaded")
end

-- Reset Number Sizes
a.sizes_reset.func()
checkEq("reset: totem numbers Auto", o.totemCooldownTextSize, nil)
checkEq("reset: totem time left 8", o.durationTextSize, 8)
if SP.ReadyReminderSetPageOpt then
	checkEq("reset: Ready Reminders Countdown Auto", SP:ReadyReminderPageOpt("textSize"), 0)
	checkEq("reset: Ready Reminders Time Left Auto", SP:ReadyReminderPageOpt("buffTimeSize"), 0)
end
o.durationTextSize, o.pulseTextSize, o.cdbarDurationTextSize = keep[1], keep[2], keep[3]
finish()
