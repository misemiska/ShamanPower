-- client: both
-- Keybinds Still Work Even If Icon Is Turned Off (General > Keybinds): the main switch and its three
-- places (Totem Bar, Totem Flyouts, Cooldown Bar). On: a key keeps casting with its icon turned off.
-- Off: it does nothing while the icon is off.
local SP = ShamanPower
local o = SP.opt
local saved = {}
local function keep(k) if saved[k] == nil then saved[k] = { v = o[k] } end end
for _, k in ipairs({ "keybindsWorkWhenOff", "keysOffTotemBar", "keysOffFlyouts", "keysOffCdbar", "totemBarShowEarth",
	"showDropAllButton", "flyoutTotems", "cdbarShowShields", "cdbarShowNS", "cdbarShowImbues", "keysWhenOffMigrated3091" }) do keep(k) end

-- the keys as Blizzard's Key Bindings (or Keybind Mode) would have them; where SetupKeybindings points them
local keys = {
	SHAMANPOWER_EARTH_TOTEM = "SHIFT-1", SHAMANPOWER_DROPALL = "SHIFT-2", SHAMANPOWER_FIRE_TOTEM = "SHIFT-3",
	SHAMANPOWER_CD_SHIELD = "SHIFT-8", SHAMANPOWER_CD_NS = "SHIFT-9", SHAMANPOWER_CD_IMBUE = "SHIFT-0",
	["CLICK ShamanPowerFlyout1Btn2:LeftButton"] = "CTRL-1",
	["CLICK ShamanPowerShieldFlyout1:LeftButton"] = "CTRL-2",
}
local pointed = {}
local realKey, realOverride = GetBindingKey, SetOverrideBindingClick
GetBindingKey = function(action) return keys[action] end
SetOverrideBindingClick = function(_, _, key, name) pointed[key] = name end
local function setup() wipe(pointed); SP:SetupKeybindings() end

-- icons off: Earth, Drop All, a flyout totem (Earth's 2nd), the shield, Nature's Swiftness, the imbue
o.totemBarShowEarth, o.showDropAllButton = false, false
o.flyoutTotems = { earth_2 = false }
o.cdbarShowShields, o.cdbarShowNS, o.cdbarShowImbues = false, false, false
SP:UpdateMiniTotemBar(); SP:RecreateTotemFlyouts(); SP:RecreateCooldownBar()

-- main switch off: no key works with its icon off
o.keybindsWorkWhenOff = nil
setup()
check("off: Earth's key does nothing", pointed["SHIFT-1"] == nil)
check("off: Drop All's key does nothing", pointed["SHIFT-2"] == nil)
checkEq("off: Fire (icon on) still casts from its button", pointed["SHIFT-3"], "ShamanPowerTotemBtn2")
check("off: the shield's key does nothing", pointed["SHIFT-8"] == nil)
checkEq("off: the hidden flyout totem's key is blocked", pointed["CTRL-1"], "ShamanPowerKeyNone")
checkEq("off: the shield flyout's key is blocked", pointed["CTRL-2"], "ShamanPowerKeyNone")
local none = _G.ShamanPowerKeyNone
check("the blocking button does nothing", none and none:GetAttribute("type1") == nil and not none:IsShown())

-- main switch on, every place on (the default)
o.keybindsWorkWhenOff = true
setup()
checkEq("on: Earth's key casts from its hidden button", pointed["SHIFT-1"], "ShamanPowerTotemBtn1")
checkEq("on: Drop All's key casts from its hidden button", pointed["SHIFT-2"], "ShamanPowerAutoDropAll")
check("on: the hidden flyout totem's key is not blocked", pointed["CTRL-1"] == nil)
checkEq("on: the shield's key presses its stand-in", pointed["SHIFT-8"], "ShamanPowerKeyOnlyCD1")
checkEq("on: Nature's Swiftness's key presses its stand-in", pointed["SHIFT-9"], "ShamanPowerKeyOnlyCD4")
checkEq("on: the imbue's key presses its stand-in", pointed["SHIFT-0"], "ShamanPowerKeyOnlyCD7")
checkEq("on: the shield flyout's key presses its stand-in", pointed["CTRL-2"], "ShamanPowerKeyOnlyShield1")
local ns = _G.ShamanPowerKeyOnlyCD4
checkEq("the stand-in casts Nature's Swiftness", ns and ns:GetAttribute("spell1"), GetSpellInfo(16188))
check("the stand-in is never seen", ns and not ns:IsShown())
local imb = _G.ShamanPowerKeyOnlyCD7
check("the imbue's stand-in puts it on the main hand", imb and (imb:GetAttribute("macrotext1") or ""):find("/use 16", 1, true) ~= nil)
local sh = _G.ShamanPowerKeyOnlyCD1
local d = SP.ShieldSpells[SP:AssignedShieldIndex()]
checkEq("the shield's stand-in casts the shield you use", sh and sh:GetAttribute("spell1"), d and SPCompat.SpellName(d[1]))
local sf = _G.ShamanPowerKeyOnlyShield1
checkEq("the shield flyout's stand-in casts that shield", sf and sf:GetAttribute("spell1"), SPCompat.SpellName(SP.ShieldSpells[1][1]))

-- each place on its own
o.keysOffTotemBar = false
setup()
check("Totem Bar off: Earth's key does nothing", pointed["SHIFT-1"] == nil)
checkEq("Totem Bar off: the shield still uses its stand-in", pointed["SHIFT-8"], "ShamanPowerKeyOnlyCD1")
o.keysOffTotemBar = nil
o.keysOffFlyouts = false
setup()
checkEq("Totem Flyouts off: the hidden flyout totem's key is blocked", pointed["CTRL-1"], "ShamanPowerKeyNone")
checkEq("Totem Flyouts off: Earth still casts", pointed["SHIFT-1"], "ShamanPowerTotemBtn1")
o.keysOffFlyouts = nil
o.keysOffCdbar = false
setup()
check("Cooldown Bar off: the shield's key does nothing", pointed["SHIFT-8"] == nil)
checkEq("Cooldown Bar off: the shield flyout's key is blocked", pointed["CTRL-2"], "ShamanPowerKeyNone")
checkEq("Cooldown Bar off: Earth still casts", pointed["SHIFT-1"], "ShamanPowerTotemBtn1")
o.keysOffCdbar = nil

-- an item turned back on: its key goes to its real button again
o.cdbarShowNS = nil
wipe(pointed)
SP:RecreateCooldownBar()
local real = SP:GetCooldownButtonByCooldownType(4)
checkEq("turned back on: the key presses the real button", pointed["SHIFT-9"], real and real:GetName())

-- the update: a profile that had a Totem Bar icon or a flyout totem off keeps today's keys
o.keybindsWorkWhenOff, o.keysOffCdbar, o.keysWhenOffMigrated3091 = nil, nil, nil
SP:MigrateKeysWhenOff()
check("update: an icon off turns the switch on", o.keybindsWorkWhenOff == true)
check("update: the Cooldown Bar stays as it was (off)", o.keysOffCdbar == false)
check("update: Totem Bar and Totem Flyouts on", SP:KeysWhenOff("TotemBar") and SP:KeysWhenOff("Flyouts"))
o.keybindsWorkWhenOff, o.keysOffCdbar, o.keysWhenOffMigrated3091 = nil, nil, nil
o.totemBarShowEarth, o.showDropAllButton, o.flyoutTotems = nil, nil, nil
SP:MigrateKeysWhenOff()
check("update: nothing off, nothing changes", o.keybindsWorkWhenOff == nil)
o.keybindsWorkWhenOff, o.keysWhenOffMigrated3091 = false, nil
o.totemBarShowAir = false
SP:MigrateKeysWhenOff()
check("update: a player's own choice is kept", o.keybindsWorkWhenOff == false)
o.totemBarShowAir = nil

GetBindingKey, SetOverrideBindingClick = realKey, realOverride
for k, s in pairs(saved) do o[k] = s.v end
SP:UpdateMiniTotemBar(); SP:RecreateTotemFlyouts(); SP:RecreateCooldownBar()
finish()
