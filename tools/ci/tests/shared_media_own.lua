-- client: both
-- SharedMedia's table is every addon's: ShamanPower adds its Blizzard sounds only under free names and
-- plays its own entry whatever another addon put under the same name
local SP = ShamanPower
local LSM = LibStub("LibSharedMedia-3.0")
local mine = SP:GetSoundFile("Raid Warning")
check("Raid Warning resolves", mine ~= nil and mine ~= "")
local keep = LSM.MediaTable.sound["Raid Warning"]
LSM.MediaTable.sound["Raid Warning"] = "Interface\\AddOns\\SomeOtherAddon\\raidwarning.ogg"   -- another addon's
checkEq("ours plays ours under a shared name", SP:GetSoundFile("Raid Warning"), mine)
LSM.MediaTable.sound["Raid Warning"] = keep
checkEq("an unknown saved name falls back to Raid Warning", SP:GetSoundFile("No Such Sound Anywhere"), mine)
finish()
