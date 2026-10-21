-- client: both
-- A newer AceDBOptions-3.0 loading after ShamanPower (another addon's copy: MINOR 17 in Questie, BigWigs and
-- others, 2026-10) runs the library's upgrade, which sets every Profiles page's rows to its one shared
-- table. A player's page (3.0.9.3, WoW: Forever) lost Export, Import, Built-in Layouts and our wording
-- that way. SP:KeepOwnProfileArgs puts ours back each time an addon finishes loading.
local SP = ShamanPower
local ADBO = LibStub("AceDBOptions-3.0")
local profiles = SP.options.args.profiles
local ours = profiles.args
check("our rows are in place to start", ours.spExport ~= nil and ours.spImport ~= nil)
-- what the newer copy's file runs when it loads (AceDBOptions-3.0, "upgrade existing tables")
local newer = { desc = { order = 1, type = "description", name = "You can change the active database profile." } }
local reached = false
for _, tbl in pairs(ADBO.optionTables) do
	tbl.args = newer
	if tbl == profiles then reached = true end
end
check("the upgrade reaches our page, as in the player's game", reached and profiles.args == newer)
__sim.W.fireEvent("ADDON_LOADED", "SomeAddonWithNewerAce3")
check("our rows are back once that addon has loaded", profiles.args == ours)
check("Export and Import are on the page again", profiles.args.spExport ~= nil and profiles.args.spImport ~= nil)
check("the newer copy's own table gets none of ours", newer.spExport == nil and newer.spShareHeader == nil)
ShamanPowerConfig:Open({ "profiles" })
__sim.advance(0.3)
check("the page draws Export This Profile", __sim.find("Export This Profile") ~= nil)
check("the page draws Import as New Profile", __sim.find("Import as New Profile") ~= nil)
check("the library's plain wording is not on our page", __sim.frameWithText("You can change the active database profile.") == nil)
-- the newest library's rows: our copy leaves out its widths (our page lays them out in two columns)
local wide = {}
for k, row in pairs(ours) do if type(row) == "table" and row.width ~= nil and not k:find("^sp") and k ~= "copy_apply" and k ~= "delete_apply" then wide[#wide + 1] = k end end
checkEq("no library widths on our rows", table.concat(wide, ","), "")
-- its profile-name check holds on our page: a 60-letter name is turned down (AceDB-3.0 39 would throw)
local row = __sim.frameWithText("New Profile Name")
local eb
local function visit(f)
	if eb or not f then return end
	if __sim.ST[f] and __sim.ST[f].type == "EditBox" then eb = f return end
	for _, c in ipairs((__sim.ST[f] and __sim.ST[f].children) or {}) do visit(c) end
end
visit(row)
check("the New Profile Name box is on the page", eb ~= nil)
if eb then
	local before = SP.db:GetCurrentProfile()
	eb:SetText(string.rep("a", 60))
	__sim.W.runScript(eb, "OnEnterPressed")
	checkEq("a 60-letter name is turned down", SP.db:GetCurrentProfile(), before)
	eb:SetText("SPCI New")
	__sim.W.runScript(eb, "OnEnterPressed")
	checkEq("a good name makes the profile", SP.db:GetCurrentProfile(), "SPCI New")
	SP.db:SetProfile(before)
	SP.db:DeleteProfile("SPCI New", true)
end
finish()
