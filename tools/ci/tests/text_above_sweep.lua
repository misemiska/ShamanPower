-- client: both
-- Cooldown numbers and the time texts sit above the sweeps on every icon (3.0.9.2): the cooldown
-- widget above the sweep bar, the pulse bar and the progress bar; the addon's texts above the widget.
local SP = ShamanPower
local function lvl(f) return f and f:GetFrameLevel() end
local function above(name, f, cd)
	check(name, f ~= nil and cd ~= nil and lvl(f) > lvl(cd), name .. ": " .. tostring(lvl(f)) .. " over " .. tostring(lvl(cd)))
end

-- the totem bar's buttons
local btn = SP.totemButtons and SP.totemButtons[1]
if btn and btn.cooldown then
	local cd = btn.cooldown
	above("totem: cooldown text over the widget", btn.cooldownText and btn.cooldownText:GetParent(), cd)
	local pulse = SP.pulseOverlays and SP.pulseOverlays[1]
	if pulse and pulse.wipeFrame then above("totem: widget over the pulse bar", cd, pulse.wipeFrame) end
	if pulse and pulse.iconTimeText then above("totem: pulse time over the widget", pulse.iconTimeText:GetParent(), cd) end
	local bars = SP.totemProgressBars and SP.totemProgressBars[1]
	if bars and bars.textHost then above("totem: duration texts over the widget", bars.textHost, cd) end
	local sweep = SP:TotemEngineSweepBar(btn, false)
	if sweep then
		above("totem: widget over the sweep bar", cd, sweep)
		above("totem: text still over the widget after the sweep", btn.cooldownText:GetParent(), cd)
		sweep:Hide()
	end
	if btn.keybindText then above("totem: keybind over the widget", btn.keybindText:GetParent(), cd) end
else
	skip("no totem bar buttons here")
end

-- the cooldown bar
local cb = SP.cooldownButtons and SP.cooldownButtons[1]
if cb and cb.cooldown then
	above("cooldown bar: time text over the widget", cb.timeText and cb.timeText:GetParent(), cb.cooldown)
	above("cooldown bar: on-icon text over the widget", cb.iconText and cb.iconText:GetParent(), cb.cooldown)
end

-- Ready Reminders
local f
local entry = SP.ReadyReminderSpells and SP.ReadyReminderSpells[1]
if entry and SP.CreateReadyReminderFrame then f = SP:CreateReadyReminderFrame(entry) end
if f then above("ready reminder: number over the widget", f.count:GetParent(), f.cooldown) end
finish()
