-- client: both
-- The Profiles page's rows are ShamanPower's own: AceDBOptions-3.0 hands every addon one shared rows
-- table, so anything added or renamed there leaked both ways (RXPGuides' buttons on our page, our
-- Share / Built-in Layouts rows on theirs). OwnProfileArgs keeps a copy of the library's rows only.
local SP = ShamanPower
local ADBO = LibStub("AceDBOptions-3.0")
-- the shared table, as any other addon gets it
local other = LibStub("AceDB-3.0"):New("SPCI_OtherAddonDB")
local shared = ADBO:GetOptionsTable(other).args
local ours = SP.options.args.profiles.args
check("our rows are not the shared table", ours ~= shared)
ShamanPowerConfig:Open({ "profiles" })
__sim.advance(0.3)
check("our Share rows are on our page", ours.spExport ~= nil and ours.spImport ~= nil)
local leaked = {}
for k in pairs(shared) do if type(k) == "string" and k:find("^sp") then leaked[#leaked + 1] = k end end
checkEq("none of our rows reach other addons' pages", table.concat(leaked, ","), "")
check("our wording stays ours (the shared Use Profile row keeps the library's name)", ours.choose and shared.choose and ours.choose ~= shared.choose)
-- another addon adding a row to the shared table (RXPGuides' Reload guides and UI)
shared.reloadUI = { order = 0, type = "execute", name = "Reload guides and UI", func = function() end }
shared.resetGuideProgress = { order = 0.1, type = "execute", name = "Reset Guide Progress", func = function() end }
check("another addon's rows never show on ours", ours.reloadUI == nil and ours.resetGuideProgress == nil)
shared.reloadUI, shared.resetGuideProgress = nil, nil
check("the library's own rows are all here", ours.current and ours.choose and ours.new and ours.copyfrom and ours.delete and ours.reset)
finish()
