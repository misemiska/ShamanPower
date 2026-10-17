-- client: both
-- Countdown Colors (A49): presets, buckets, the Custom switch, the switches
local SP = ShamanPower
checkEq("default preset", SP:CountdownPreset(), "shamanpower")
checkEq("bucket 6/10", SP:CountdownBucket(6, 10), 1)
checkEq("bucket 3/10", SP:CountdownBucket(3, 10), 2)
checkEq("bucket 1/10", SP:CountdownBucket(1, 10), 3)
check("switches off to start", not SP:CountdownOn("totem") and not SP:CountdownOn("cdbar") and not SP:CountdownOn("ready"))
SP:SetCountdownPreset("solid")
checkEq("solid: one bucket", SP:CountdownBucket(1, 10), 1)
SP:SetCountdownPreset("wyr")
local r, g, b = SP:CountdownColorN(1)
check("white / yellow / red starts white", r == 1 and g == 1 and b == 1)
SP:SetCountdownColor(2, 0.5, 0.5, 1)
checkEq("a swatch edited: Custom", SP:CountdownPreset(), "custom")
checkEq("the edited color", (SP:CountdownColorN(2)), 0.5)
SP.opt.totemBarCountdownColors = true
SP:CountdownChanged()
check("totem bar switch", SP:CountdownOn("totem"))
if SPCompat.FOREVER then
	check("color curve", SP:CountdownCurve() ~= nil)
end
SP:SetCountdownPreset("shamanpower")
SP.opt.totemBarCountdownColors = nil
SP:CountdownChanged()
-- Buff Timers: its own preset, colors and switches, apart from the Cooldown Numbers' ones
checkEq("buff preset starts on ShamanPower", SP:CountdownPreset("buff"), "shamanpower")
SP:SetCountdownPreset("wyr", "buff")
checkEq("buff preset set alone", SP:CountdownPreset("buff"), "wyr")
checkEq("the cooldown preset untouched", SP:CountdownPreset(), "shamanpower")
SP:SetCountdownColor(2, 0.1, 0.2, 0.3, "buff")
checkEq("a buff swatch edited: Custom", SP:CountdownPreset("buff"), "custom")
checkEq("the cooldown colors untouched", (SP:CountdownColorN(2)), 1)
check("switches apart", not SP:CountdownOn("ready", "buff"))
SP.opt.readyBuffTimerColors = true
check("buff switch", SP:CountdownOn("ready", "buff") and not SP:CountdownOn("ready"))
SP.opt.readyBuffTimerColors = nil
SP:SetCountdownPreset("shamanpower", "buff")
SP:CountdownChanged()
if SPCompat.FOREVER then check("a curve per set", SP:CountdownCurve("buff") ~= nil and SP:CountdownCurve("buff") ~= SP:CountdownCurve()) end
-- the bands as a share of the total: the half mark itself is the second color, a quarter the third
checkEq("a 6 s shock at 3 s is the second (the half mark)", SP:CountdownBucket(3, 6), 2)
checkEq("a 6 s shock at 3.1 s is the first", SP:CountdownBucket(3.1, 6), 1)
checkEq("a 6 s shock at 1.5 s is the third (the quarter)", SP:CountdownBucket(1.5, 6), 3)
checkEq("a 6 s shock at 1.6 s is the second", SP:CountdownBucket(1.6, 6), 2)
checkEq("a 3 min cooldown at 2 min is the first", SP:CountdownBucket(120, 180), 1)
checkEq("a 3 min cooldown at 40 s is the third", SP:CountdownBucket(40, 180), 3)

finish()
