-- client: both
-- Totem Range Tracker (3.0.9.2): each tracked totem's own look from its right-click menu. Unset, an
-- icon looks as the overlay always drew it; set, its own size, look for each moment and effects.
local SP = ShamanPower
if not (SP.SPRangeLoaded and SP.SPRangeDemo and SP.SPRangeIconOpt) then skip("no Totem Range Tracker here") end
SP:InitSPRange()
local rt = SP.opt.rangeTracker
local keepIcons, keepTracked = rt.icons, {}
for k, v in pairs(ShamanPower_RangeTracker.tracked) do keepTracked[k] = v end
rt.icons = nil
local ids = {}
for _, t in ipairs(SP.TrackableTotems) do if #ids < 3 then ids[#ids + 1] = t.id end end
for _, t in ipairs(SP.TrackableTotems) do ShamanPower_RangeTracker.tracked[t.id] = false end
for _, id in ipairs(ids) do ShamanPower_RangeTracker.tracked[id] = true end
SP:SPRangeDemo(true)
local frame = SP.spRangeFrame
local a, b = frame.totemButtons[ids[1]], frame.totemButtons[ids[2]]
check("the preview built the tracked totems", a ~= nil and b ~= nil)
-- unset: today's look
SP:SPRangePaint(a, "outofrange")
check("out of range, unset: the red film as always", a.rangeOverlay:IsShown() and a.icon:IsDesaturated())
SP:SPRangePaint(a, "missing")
check("missing, unset: gray as always", a.icon:IsDesaturated() and not a.rangeOverlay:IsShown())
SP:SPRangePaint(a, "inrange")
check("in range, unset: no effect", not (a.spGlow and a.spGlow:IsShown()))
local w0 = frame:GetWidth()
-- its own
SP:SetSPRangeIconOpt(ids[1], "oorLook", "gray")
a = frame.totemButtons[ids[1]]
SP:SPRangePaint(a, "outofrange")
check("its own Out of Range look: Gray, no red film", not a.rangeOverlay:IsShown() and a.icon:IsDesaturated())
SP:SetSPRangeIconOpt(ids[1], "inEffect", "glow")
a = frame.totemButtons[ids[1]]
SP:SPRangePaint(a, "inrange")
check("its own In Range glow", a.spGlow ~= nil and a.spGlow:IsShown())
SP:SetSPRangeIconOpt(ids[1], "oorEffect", "glow")
SP:SetSPRangeIconOpt(ids[1], "oorGlowShape", "proc")
a = frame.totemButtons[ids[1]]
SP:SPRangePaint(a, "outofrange")
check("When Out of Range: its own Glow Shape, Proc Glow", a.spProc == true and a.spFxShape == "proc")
SP:SPRangePaint(a, "inrange")
check("When In Range keeps its own (the plain glow)", a.spFxShape ~= "proc")
SP:SetSPRangeIconOpt(ids[1], "iconSize", 56)
a = frame.totemButtons[ids[1]]
checkEq("its own size", a.spSize, 56)
check("the overlay grew for it", frame:GetWidth() > w0)
local b2 = frame.totemButtons[ids[2]]
checkEq("the others keep the page's size", b2.spSize, rt.iconSize or 36)
SP:SetSPRangeIconOpt(ids[2], "showName", false)
check("its own Show Name off", not frame.totemButtons[ids[2]].nameText:IsShown())
check("the first still shows its name", frame.totemButtons[ids[1]].nameText:IsShown() == not rt.hideNames)
SP:SPRangeDemo(false)
rt.icons = keepIcons
for k, v in pairs(keepTracked) do ShamanPower_RangeTracker.tracked[k] = v end
finish()
