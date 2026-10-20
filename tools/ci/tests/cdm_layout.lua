-- client: forever
-- Set Up The Cooldown Manager / the shield dialog (3.0.9.2): ShamanPower's layout tracks only the
-- shields you know; every other cooldown and buff of the game's catalog is out of sight, spells not
-- learned yet included; a ShamanPower layout made before is rebuilt whole; the switch runs the setup
-- unless that layout is active and whole (the game's own layout tracking your shield is not enough).
local SP = ShamanPower
if not SP.ShieldGoneSetup then skip("no Shield Charges module") end
local LS_CID, WS_CID = 200311, 200312
local LS_ID, WS_ID = 324, 52127
for _, set in ipairs(SP.ShieldAuraSets or {}) do
	if set.name == "Lightning Shield" and set.ids[1] then LS_ID = set.ids[1] end
	if set.name == "Water Shield" and set.ids[1] then WS_ID = set.ids[1] end
end
-- a stand-in Cooldown Manager: the store kept as a table behind a key string
local store, saved, n = {}, nil, 0
local realC, realE, realKnows = C_CooldownViewer, C_EncodingUtil, SPCompat.KnowsSpellID
C_EncodingUtil = {
	SerializeCBOR = function(t) n = n + 1; store["k" .. n] = t; return "k" .. n end,
	CompressString = function(s) return s end, DecompressString = function(s) return s end,
	EncodeBase64 = function(s) return s end, DecodeBase64 = function(s) return s end,
	DeserializeCBOR = function(s) return store[s] end,
}
local learned = { [0] = { 11, 12 }, [1] = { 21 }, [2] = { LS_CID, 31 }, [3] = { 41 } }
local unlearned = { [0] = { 13 }, [1] = { 22 }, [2] = { WS_CID }, [3] = {} }
C_CooldownViewer = {
	IsCooldownViewerAvailable = function() return true end,
	GetLayoutData = function() return saved end,
	SetLayoutData = function(s) saved = s end,
	GetCooldownViewerCategorySet = function(cat, all)
		local out = {}
		for _, id in ipairs(learned[cat] or {}) do out[#out + 1] = id end
		if all then for _, id in ipairs(unlearned[cat] or {}) do out[#out + 1] = id end end
		return out
	end,
	GetCooldownViewerCooldownInfo = function(id)
		if id == LS_CID then return { spellID = LS_ID } elseif id == WS_CID then return { spellID = WS_ID } end
		return { spellID = 1000 + id }
	end,
}
local realCat = Enum.CooldownViewerCategory
Enum.CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3, HiddenActive = -1, HiddenPassive = -2 }
SPCompat.KnowsSpellID = function(id) if id == LS_ID then return true end if id == WS_ID then return false end return realKnows and realKnows(id) end
__sim.W.fireEvent("SPELLS_CHANGED")   -- (the known-shield answers are kept until the spells change)

local function active()
	local data = store[(saved or ""):gsub("^1|", "")]
	local tag
	for t in pairs(data[2]) do tag = t end
	local id = data[2][tag]
	return data[4][id], data[3][tag][id]
end
local function where(layout, cid)
	for cat, ids in pairs(layout[2] or {}) do for _, x in ipairs(ids) do if x == cid then return cat end end end
end

local ok, why = SP:ShieldGoneSetup()
check("setup works: " .. tostring(why), ok)
if not ok then finish() return end
local name, layout = active()
checkEq("ShamanPower's layout is active", name, "ShamanPower")
checkEq("Lightning Shield in Tracked Buffs", where(layout, LS_CID), 2)
checkEq("a learned cooldown out of sight", where(layout, 11), -1)
checkEq("a cooldown not learned yet out of sight too", where(layout, 13), -1)
checkEq("another buff out of sight", where(layout, 31), -2)
checkEq("a bar out of sight", where(layout, 41), -2)
check("Water Shield (not known) not tracked", where(layout, WS_CID) ~= 2)
check("the layout reads as whole", SP:ShieldGoneLayoutComplete())

-- the layout made before, with the game's icons back in it: set up again, it is whole again
layout[2][0] = { 11, 12 }
for _, cat in ipairs({ -1 }) do layout[2][cat] = { 13 } end
check("a layout with the game's icons back is not whole", not SP:ShieldGoneLayoutComplete())
SP:ShieldGoneSetup()
name, layout = active()
checkEq("rebuilt: a learned cooldown out of sight again", where(layout, 11), -1)
check("rebuilt: whole", SP:ShieldGoneLayoutComplete())

-- the switch: shields tracked by the game's own layout is not enough
local offered = false
local realOffer, realReady = SP.ShieldGoneOffer, SP.ShieldGoneCdmReady
SP.ShieldGoneOffer = function() offered = true end
SP.ShieldGoneCdmReady = function() return true end
saved = nil
local sw = SP.options.args.fluffy and nil
local function findArg(t)
	if type(t) ~= "table" then return nil end
	if t.shieldcharges_cdm then return t.shieldcharges_cdm end
	for _, v in pairs(t) do if type(v) == "table" then local r = findArg(v.args or (v ~= t and nil)) if r then return r end end end
end
sw = findArg(SP.options.args)
if sw then
	SP.opt.cdmHideShieldIcon = false
	sw.set(nil, true)
	check("the switch offers the setup when ShamanPower's layout isn't up", offered)
	SP:ShieldGoneSetup()
	offered = false
	SP.opt.cdmHideShieldIcon = false
	sw.set(nil, true)
	check("the switch only hides the icon once the layout is whole", not offered and SP.opt.cdmHideShieldIcon == true)
else
	skip("no Set Up The Cooldown Manager switch found")
end
SP.ShieldGoneOffer, SP.ShieldGoneCdmReady = realOffer, realReady
C_CooldownViewer, C_EncodingUtil, SPCompat.KnowsSpellID = realC, realE, realKnows
Enum.CooldownViewerCategory = realCat
finish()
