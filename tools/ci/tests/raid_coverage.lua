-- client: forever
-- Raid Coverage (ShamanPower_RaidCoverage.lua): its own settings, the seven totems, on / off, rules, copy, reset; Party Coverage untouched
local SP = ShamanPower
if not SPCompat.FOREVER then skip("Forever only") end
if not SP.RaidCoverageOpts then skip("Raid Coverage not loaded") end
local partyBefore = SP.opt.coverage and SP.opt.coverage.enabled
check("off to start", SP:RaidCoverageOn() == false and not SP:RaidWatchAnyOn())
checkEq("seven raid-wide totems", #SP.RAID_COVERAGE_TOTEMS, 7)
checkEq("Windfury default", SP:RaidWatchPreset("4:1"), "melee")
checkEq("Flametongue default", SP:RaidWatchPreset("2:5"), "ranged")
checkEq("Fire Resistance default", SP:RaidWatchPreset("3:6"), "everyone")
SP:RaidCoverageOpts().enabled = true
SP:RaidWatchSetOn("4:1", true)
check("on: the switch and a cell", SP:RaidCoverageOn() and SP:RaidWatchOn("4:1"))
check("the panel exists", SP:CreateRaidCoverageFrame() ~= nil and ShamanPowerRaidCoverage ~= nil)
check("its own frame, not Totem Coverage's", ShamanPowerRaidCoverage ~= SP.coverageFrame)
SP:RaidWatchToggle("4:1", "classes", "WARRIOR")
checkEq("a pick makes it Custom", SP:RaidWatchPreset("4:1"), "custom")
SP:RaidWatchCopy("4:1", "all")
check("copied to all, on / off not copied", SP:RaidWatchPicked("3:6", "classes", "WARRIOR") and not SP:RaidWatchOn("3:6"))
SP:RaidWatchReset("4:1")
check("reset: default rule, still on", SP:RaidWatchPreset("4:1") == "melee" and SP:RaidWatchOn("4:1"))
checkEq("roster outside a raid", #SP:RaidCoverageRoster(), 0)
check("Party Coverage's settings untouched", (SP.opt.coverage and SP.opt.coverage.enabled) == partyBefore and (SP.opt.coverage == nil or SP.opt.coverage.raid == nil))
SP:RaidCoverageResetPage()
check("Reset Page: off again, rules gone", not SP:RaidCoverageOn() and not SP:RaidWatchAnyOn() and SP:RaidWatchPreset("4:1") == "melee" and not SP:RaidWatchPicked("3:6", "classes", "WARRIOR"))
finish()
