-- client: forever
-- regime: secrets
-- In a fight WoW: Forever hides cooldown numbers: a totem's cooldown shows from the game's never-secret
-- flags, and "is it only the global cooldown" is read at the cooldown event. A totem cast while none of its
-- displays was read at that event (not the assigned one: its flyout closed, the Totem Rows' copies) must
-- still show its cooldown on the rows and the flyout (interslice's report, 3.0.9.2).
local SP = ShamanPower
local o = SP.opt
local W = __sim.W
if not SP:EngineCooldownsOn() then skip("no engine-drawn cooldowns on this client") end

local EARTHBIND, TREMOR = 2484, 8143
local keep = { o.totemRows, o.rowsKeepFlyouts }
o.rowsKeepFlyouts = true
SP:SetTotemRows(true)
__sim.advance(0.5)

local function inList(list, id)
	for _, b in ipairs(list or {}) do if b.spellID == id then return b end end
end
local flyout = SP.totemFlyouts[1]
local fb, rb = inList(flyout and flyout.buttons, EARTHBIND), inList(SP:RowsCopies(1), EARTHBIND)
local tremorRow = inList(SP:RowsCopies(1), TREMOR)
if not (fb and rb and tremorRow) then skip("no Earthbind flyout button or row copies here") end
check("Earthbind is not the assigned Earth totem", SP:GetTotemSpell(1, SP:AssignedIndex(1)) ~= EARTHBIND)

-- the game's answers: plain numbers out of a fight, secret ones in a fight; the flags never secret
local realGet, realDur, realBase = C_Spell.GetSpellCooldown, C_Spell.GetSpellCooldownDuration, GetSpellBaseCooldown
local ends, gcdUntil, fight = {}, 0, false
C_Spell.GetSpellCooldown = function(spell)
	local id = spell
	if type(id) ~= "number" then id = select(7, GetSpellInfo(spell)) end
	local now = GetTime()
	local own = id and ends[id] and ends[id] > now or false
	local gcd = now < gcdUntil
	local st, du = 0, 0
	if own then st, du = ends[id] - 15, 15 elseif gcd then st, du = gcdUntil - 1.5, 1.5 end
	if fight then st, du = __sim.secret("start"), __sim.secret("duration") end
	return { startTime = st, duration = du, isEnabled = true, isActive = (own or gcd) and true or false,
		isOnGCD = (gcd and not own) and true or false, modRate = 1 }
end
C_Spell.GetSpellCooldownDuration = function() return {} end
GetSpellBaseCooldown = function(id) if id == EARTHBIND then return 15000, 1000 end return 0, 1000 end

-- the flyout's own frames out (the sim draws no bar; a fight's end closes them): the button alone then opens
-- and closes it
local opened = {}
local function frameOut()
	local up = fb:GetParent()
	while up and up ~= UIParent do
		if not up:IsShown() then up:Show(); opened[#opened + 1] = up end
		up = up:GetParent()
	end
end

local function pass() SP:UpdateTotemCooldowns() end
local function running(b) return b._ecdRunning == true end
-- the game's order on a cast varies; evID: the event's spell (nil = all, as when it is hidden)
local function cast(id, eventFirst, evID)
	ends[id] = GetTime() + 15
	gcdUntil = GetTime() + 1.5
	if eventFirst then W.fireEvent("SPELL_UPDATE_COOLDOWN", evID, evID) end
	W.fireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-0-0-0-" .. id .. "-0", id)
	if not eventFirst then W.fireEvent("SPELL_UPDATE_COOLDOWN", evID, evID) end
	__sim.advance(0.05)
end

local function round(label, eventFirst, evID)
	frameOut()
	fight = true
	__sim.setCombat(true)
	fb:Show(); pass()   -- (the flyout open in the fight: Earthbind read ready there too)
	check(label .. ": ready before the cast (row)", not running(rb))
	check(label .. ": ready before the cast (flyout)", fb:IsVisible() and not running(fb))
	fb:Hide()   -- (the flyout closes with the click)
	cast(EARTHBIND, eventFirst, evID)
	pass()
	check(label .. ": the row shows Earthbind's cooldown", running(rb))
	check(label .. ": a ready totem's row shows no global cooldown", not running(tremorRow))
	__sim.advance(2); pass()
	check(label .. ": still cooling after the global cooldown (row)", running(rb))
	fb:Show(); pass()   -- (the flyout opened)
	check(label .. ": the flyout is open", fb:IsVisible())
	check(label .. ": the flyout shows Earthbind's cooldown", running(fb))
	fb:Hide()
	__sim.advance(14); pass()
	check(label .. ": ready again when it ends (row)", not running(rb))
	fight = false
	__sim.setCombat(false)
	__sim.advance(0.2)
end
round("event before the cast, its spell named", true, EARTHBIND)
round("event after the cast, its spell named", false, EARTHBIND)
round("event after the cast, its spell hidden", false, nil)

for i = #opened, 1, -1 do opened[i]:Hide() end
C_Spell.GetSpellCooldown, C_Spell.GetSpellCooldownDuration, GetSpellBaseCooldown = realGet, realDur, realBase
o.rowsKeepFlyouts = keep[2]
SP:SetTotemRows(keep[1] and true or false)
finish()
