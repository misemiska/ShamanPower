-- client: anniversary
-- Red X When It's Gone on the imbue: its own switch (the Gone animation off), cleared when the imbue is back, cleared when switched off
local SP = ShamanPower
local b
for _, x in ipairs(SP.cooldownButtons or {}) do if x.spellType == "weaponImbue" then b = x end end
if not b then skip("no imbue button on the cooldown bar") end
local orig = GetWeaponEnchantInfo
local state = { true, 600000, 0, 1, false, 0, 0, nil }
GetWeaponEnchantInfo = function() return unpack(state, 1, 8) end
local keepGone, keepMark, keepStays = SP:CdItemOwnOpt(7, "cueGone"), SP:CdItemOwnOpt(7, "cueMark"), SP:CdItemOwnOpt(7, "cueMarkStays")
SP:SetCdItemOpt(7, "cueGone", false)   -- the animation OFF
SP:SetCdItemOpt(7, "cueMark", true)
SP:SetCdItemOpt(7, "cueMarkStays", true)
__sim.advance(0.2)
SP:UpdateCooldownButtons(); __sim.advance(0.3)
check("the imbue is seen with the animation off", b._cueMain == true)
state[1] = false
SP:UpdateCooldownButtons(); __sim.advance(0.5)
check("gone: the X plays with the animation off", b.spCue ~= nil and b.spCue.markHold:IsPlaying())
check("kept", b.spCue.markHoldStay:GetDuration() > 100)
state[1] = true
SP:UpdateCooldownButtons(); __sim.advance(0.3)
check("imbue back: the X is gone", not b.spCue.markHold:IsPlaying())
state[1] = false
SP:UpdateCooldownButtons(); __sim.advance(0.3)
check("gone again: the X again", b.spCue.markHold:IsPlaying())
SP:SetCdItemOpt(7, "cueMark", false)
__sim.advance(0.2)
check("Red X switched off: the X on the button goes", not b.spCue.markHold:IsPlaying())
SP:SetCdItemOpt(7, "cueMark", true); SP:SetCdItemOpt(7, "cueMarkStays", false)
state[1] = true; SP:UpdateCooldownButtons(); __sim.advance(0.2)
state[1] = false; SP:UpdateCooldownButtons(); __sim.advance(0.2)
check("Keep off: the X fades after 4.5 s", b.spCue.markHold:IsPlaying() and b.spCue.markHoldStay:GetDuration() < 10)
-- both switches off: nothing stays
SP:SetCdItemOpt(7, "cueMark", false)
__sim.advance(0.2)
SP:UpdateCooldownButtons(); __sim.advance(0.2)
check("both off: no X, no state", not b.spCue.markHold:IsPlaying() and b._cueMain == nil)
-- the totem bar's carry-over: on only where the effect was on
local o = SP.opt
local kd, km, ks = o.totemCueDestroyed, o.totemCueDestroyedMark, o.totemCueDestroyedMarkSet3091
o.totemCueDestroyed, o.totemCueDestroyedMark, o.totemCueDestroyedMarkSet3091 = true, nil, nil
SP:CueMarkCarryOver()
check("carry-over: effect on + old default = X on", o.totemCueDestroyedMark == true)
o.totemCueDestroyed, o.totemCueDestroyedMark, o.totemCueDestroyedMarkSet3091 = nil, nil, nil
SP:CueMarkCarryOver()
check("carry-over: effect off = X off", o.totemCueDestroyedMark == false)
o.totemCueDestroyed, o.totemCueDestroyedMark, o.totemCueDestroyedMarkSet3091 = kd, km, ks
GetWeaponEnchantInfo = orig
SP:SetCdItemOpt(7, "cueGone", keepGone); SP:SetCdItemOpt(7, "cueMark", keepMark); SP:SetCdItemOpt(7, "cueMarkStays", keepStays)
finish()
