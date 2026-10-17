-- client: anniversary
-- The weapon imbue flyout offers every imbue you know (Dexter's report)
local SP = ShamanPower
if SPCompat.FOREVER then skip("Anniversary only") end
local known = 0
for i = 1, 4 do if SP:GetHighestRankImbue(i) then known = known + 1 end end
if known == 0 then skip("no imbue known in the sim") end
if SP.weaponImbueButton and SP.RebuildWeaponImbueFlyout then SP:RebuildWeaponImbueFlyout() end
local fl = SP.weaponImbueFlyout
check("flyout built", fl ~= nil and fl.buttons ~= nil)
if fl and fl.buttons then checkEq("every known imbue in the flyout", #fl.buttons, known) end
finish()
