-- Appearance > Visibility > Cooldown Bar Auto-Hide (3.0.9): Hide Out of Combat for the cooldown bar, as the totem bar has it,
-- with Fade Instead of Hide, Faded Opacity, Smooth Fade and Show When I Have a Target. Off by default;
-- off, nothing here touches the bar.
--
-- Hiding. The bar's buttons take clicks in a fight, so Show is protected the moment one starts: the
-- bar is hidden by a secure state driver ("[combat] show; hide", with "[@target,harm]" in front when
-- Show When I Have a Target is on), the way Out Of The Way (ShamanPowerTown.lua) hides it. The game's
-- own secure code then shows it as the fight starts and hides it as the fight ends, and brings it up
-- for an attackable target. Out Of The Way's hide for this bar goes through here too, so the one
-- driver carries both reasons (TownApplyCooldownBar hands over to ApplyCooldownBarVisibility).
--
-- Fading. Alpha is never protected: Fade Instead of Hide multiplies the bar's opacity
-- (UpdateCooldownBarOpacity asks CdBarAlphaMul) out of a fight, and the events below put it back
-- at full the moment a fight starts (PLAYER_REGEN_DISABLED comes before the lockdown) or a target
-- you can attack is picked. Smooth Fade glides between the two over a fifth of a second, out of a
-- fight only, as the totem bar's does.
local SP = ShamanPower

local FADE_TIME = 0.2
local driven = {}   -- [bar frame] = the driver's condition while one is registered

local function yes(v)
	if issecretvalue and issecretvalue(v) then return false end
	return v == true
end

local function fighting()
	return InCombatLockdown() or yes(UnitAffectingCombat("player"))
end

local function targetLifts()
	local o = SP.opt
	return o and o.cdbarShowWithTarget == true and yes(UnitExists("target")) and yes(UnitCanAttack("player", "target"))
end

-- Hide Out of Combat applies right now (out of a fight, no attackable target): a hide or a fade
local function ruleApplies()
	local o = SP.opt
	if not (o and o.cdbarHideOutOfCombat == true) then return false end
	if SP.IsOff and SP:IsOff() then return false end
	if fighting() then return false end
	if targetLifts() then return false end
	return true
end

function SP:CdBarFadeAlpha()
	local v = tonumber(self.opt and self.opt.cdbarFadeOpacity) or 0.25
	if v > 1 then v = v / 100 end
	if v < 0 then v = 0 elseif v > 1 then v = 1 end
	return v
end

-- what the bar's opacity is multiplied by: the faded opacity while Hide Out of Combat fades it, else 1
function SP:CdBarAlphaMul()
	local o = self.opt
	if o and o.cdbarFadeInsteadOfHide == true and ruleApplies() then return self:CdBarFadeAlpha() end
	return 1
end

-- the state driver on the bar: cond = the macro conditional that shows it, nil = none
function SP:CdBarDrive(bar, cond)
	if not bar then return end
	if cond then
		if driven[bar] ~= cond and RegisterStateDriver then
			driven[bar] = cond
			pcall(RegisterStateDriver, bar, "visibility", cond)
		end
	elseif driven[bar] then
		driven[bar] = nil
		if UnregisterStateDriver then pcall(UnregisterStateDriver, bar, "visibility") end
	end
end

-- the condition a hide needs, or nil: Hide Out of Combat (no fade) and Out Of The Way (its own Hide)
local function hideCondition(self)
	local o = self.opt
	local ooc = o and o.cdbarHideOutOfCombat == true and o.cdbarFadeInsteadOfHide ~= true
	local town = self.TownHides and self:TownHides("cd") and not self:TownFades()
	if ooc then
		if o.cdbarShowWithTarget == true then return "[combat][@target,harm] show; hide" end
		return "[combat] show; hide"
	end
	if town then return "[combat] show; hide" end
	return nil
end

-- the Smooth Fade glide: the real alpha is already set (the source of truth); an Alpha animation
-- plays from the old value to it. Out of a fight only.
local function playFade(frame, fromAlpha)
	if not (frame and fromAlpha and frame.CreateAnimationGroup and frame:IsShown()) then return end
	local toAlpha = frame:GetAlpha()
	if math.abs(fromAlpha - toAlpha) < 0.01 then return end
	local ag = frame.spCdFadeAG
	if not ag then
		ag = frame:CreateAnimationGroup()
		ag.fade = ag:CreateAnimation("Alpha")
		ag.fade:SetDuration(FADE_TIME)
		ag.fade:SetSmoothing("IN_OUT")
		frame.spCdFadeAG = ag
	end
	ag:Stop()
	ag.fade:SetFromAlpha(fromAlpha)
	ag.fade:SetToAlpha(toAlpha)
	ag:Play()
end

local function stopFade(frame)
	if frame and frame.spCdFadeAG then frame.spCdFadeAG:Stop() end
end

-- The bar as its rules say, now: the driver on or off (out of a fight only: a driver change is a
-- Show or Hide), and the opacity (any time). Called by the bar's own passes (UpdateCooldownBar,
-- a reposition, Out Of The Way) and by the events below.
function SP:ApplyCooldownBarVisibility(glide)
	local bar = self.cooldownBar
	if not bar then return end
	local on = self.opt.showCooldownBar and not self:IsOff() and self.cooldownButtons and #self.cooldownButtons > 0
	local cond = on and hideCondition(self) or nil
	if not InCombatLockdown() then
		self:CdBarDrive(bar, cond)
		local controller = self.ControllerHidesCooldownBar and self:ControllerHidesCooldownBar()
		if on and not cond then
			bar:SetShown(not controller)
		elseif on then
			-- the rule's answer now, by hand: the driver acts only when its condition changes, and a
			-- layout pass (UpdateCooldownBar, a reposition) has just shown the bar
			local show = fighting() or (self.opt.cdbarHideOutOfCombat == true and targetLifts())
			bar:SetShown(show and not controller)
		end
	end
	local before = glide and self.opt.cdbarFadeSmooth ~= false and not fighting() and bar:IsShown() and bar:GetAlpha() or nil
	if not before then stopFade(bar) end
	self:UpdateCooldownBarOpacity()
	if before then playFade(bar, before) end
end

-- a setting changed: everything again, no glide
function SP:RefreshCooldownBarVisibility()
	self:ApplyCooldownBarVisibility(false)
end

-- a reposition shows the bar: the rules have the last word
if type(SP.UpdateCooldownBarPosition) == "function" then
	hooksecurefunc(SP, "UpdateCooldownBarPosition", function(self)
		if self.opt and self.opt.cdbarHideOutOfCombat == true then self:ApplyCooldownBarVisibility(false) end
	end)
end

-- The fade rule reacts to events, not a timer: combat start (before lockdown: full alpha now), combat
-- end, a target change, and the target turning attackable (or not) without a target change. Idle when
-- the option is off. The hide rule needs none of this: the driver is the game's own.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
if events.RegisterUnitEvent then events:RegisterUnitEvent("UNIT_FACTION", "player", "target") else events:RegisterEvent("UNIT_FACTION") end
events:SetScript("OnEvent", function(_, event, unit)
	local o = SP.opt
	local active = o ~= nil and o.cdbarHideOutOfCombat == true
	-- (a driver left from the option switched off in a fight comes off at the fight's end)
	if not SP.cooldownBar or not (active or next(driven)) then return end
	if (event == "PLAYER_TARGET_CHANGED" or event == "UNIT_FACTION") and not (active and o.cdbarShowWithTarget == true) then return end
	if event == "UNIT_FACTION" and unit ~= "target" and unit ~= "player" then return end
	if event == "PLAYER_REGEN_DISABLED" then stopFade(SP.cooldownBar) end
	SP:ApplyCooldownBarVisibility(event ~= "PLAYER_REGEN_DISABLED")
end)
