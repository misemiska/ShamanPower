-- client: both
-- Profiles: Copy Settings to This Profile and Delete Selected Profile (the two-step buttons in
-- ShamanPower_Config/Share.lua) call AceDBOptions' handlers, which it names by string.
local SP = ShamanPower
ShamanPowerConfig:Open({ "profiles" })
__sim.advance(0.3)
local args = SP.options.args.profiles.args
local db = SP.db
local first = db:GetCurrentProfile()
db:SetProfile("SPCI Other")
db.profile.spciMarker = 4242
db:SetProfile(first)
db.profile.spciMarker = nil
check("both buttons are there", args.copy_apply and args.delete_apply)
args.copyfrom.set({}, "SPCI Other")
local ok, err = pcall(args.copy_apply.func)
check("Copy Settings to This Profile runs", ok, err)
checkEq("the picked profile's settings are copied", db.profile.spciMarker, 4242)
args.delete.set({}, "SPCI Other")
ok, err = pcall(args.delete_apply.func)
check("Delete Selected Profile runs", ok, err)
local still = false
for _, name in ipairs(db:GetProfiles()) do if name == "SPCI Other" then still = true end end
check("the picked profile is deleted", not still)
checkEq("the profile in use stays", db:GetCurrentProfile(), first)
finish()
