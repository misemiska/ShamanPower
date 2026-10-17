-- client: both
-- Every module loaded, the settings window there
check("ShamanPower loaded", ShamanPower ~= nil)
check("profile", type(ShamanPower.opt) == "table")
check("SPCompat", SPCompat ~= nil)
for _, k in ipairs({ "PartyRangeLoaded", "SPRangeLoaded", "TotemPlatesLoaded", "ReadyRemindersLoaded", "ShieldChargesLoaded",
	"TremorReminderLoaded", "ReactiveTotemsLoaded", "ESTrackerLoaded", "ExpiringAlertsLoaded", "RaidCooldownsLoaded", "TargetTrackerLoaded" }) do
	if k == "ESTrackerLoaded" and ShamanPower.ESTrackerUnavailable then
		check("ES Tracker stays off where there is no Earth Shield", ShamanPower[k] == nil)
	else
		check("module " .. k, ShamanPower[k] == true)
	end
end
check("settings window", ShamanPowerConfig ~= nil and ShamanPowerConfig.Open ~= nil)
finish()
