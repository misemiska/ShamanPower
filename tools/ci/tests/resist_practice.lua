-- client: forever
-- Raid Resistance practice (Forever only): two pretend shamans; Frost and Nature requests make the pick weigh
-- taking Flametongue / Windfury off the melee practice shaman (the raid-wide cost path)
local SP = ShamanPower
if not SPCompat.FOREVER then skip("Forever only") end
if not SP.CanRequestResist then skip("Resist module not loaded") end
local ok, err = pcall(SP.SetResistPractice, SP, true)
check("practice on", ok, err)
check("practice active", SP:ResistPracticeActive())
for _, key in ipairs({ "frost", "nature", "fire" }) do
	local okn, errn = pcall(SP.SetResistNeeded, SP, key, true)
	check(key .. " requested", okn and errn ~= false, errn)
	__sim.advance(0.5)
	local oks, status = pcall(SP.GetResistStatus, SP, key)
	check(key .. " status reads", oks, status)
	check(key .. " marked needed", SP:IsResistNeeded(key))
end
local okl, errl = pcall(SP.GetResistPracticeLine, SP)
check("practice line", okl, errl)
for _, key in ipairs({ "frost", "nature", "fire" }) do pcall(SP.SetResistNeeded, SP, key, false) end
pcall(SP.SetResistPractice, SP, false)
check("practice off", not SP:ResistPracticeActive())
finish()
