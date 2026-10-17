-- client: both
-- Totem Plates (A54): keys, a totem's own settings, copy, reset, where, the Hide in Raids carry-over
local SP = ShamanPower
local key, name = SP:TotemPlateKeyForSpell(8177)
checkEq("Grounding key", key, "totem_grounding_totem")
checkEq("Grounding name", name, "Grounding Totem")
check("unknown spell", SP:TotemPlateKeyForSpell(12345) == nil)
SP:EnsureProfileTable("totemPlates")
SP:SetTotemPlateOwn(key, "important", true)
check("Important", SP:TotemPlateImportant(key))
SP:SetTotemPlateOwn(key, "size", 52)
checkEq("own size", SP:TotemPlateOwn(key).size, 52)
local tremor = SP:TotemPlateKeyForSpell(8143)
SP:CopyTotemPlateImportant(key, tremor)
check("Copy Important To", SP:TotemPlateImportant(tremor))
check("copy leaves the size alone", SP:TotemPlateOwn(tremor).size == nil)
SP:SetTotemPlateHidden(tremor, true)
check("hidden", SP:TotemPlateHidden(tremor))
SP:ResetTotemPlate(tremor)
check("reset", not SP:TotemPlateImportant(tremor) and not SP:TotemPlateHidden(tremor))
SP:ResetTotemPlate(key)
check("allowed here", SP:TotemPlatesAllowedHere() == true)
local s = SP.opt.totemPlates
s.enabled, s.hideInRaid, s.hideInRaidSet3091 = true, nil, nil
SP:InitializeTotemPlates()
checkEq("carry-over: a profile with plates on keeps them in raids", s.hideInRaid, false)
s.enabled, s.hideInRaid, s.hideInRaidSet3091 = false, nil, nil
SP:InitializeTotemPlates()
checkEq("fresh setup: Hide in Raids on", s.hideInRaid, nil)
s.enabled = nil
finish()
