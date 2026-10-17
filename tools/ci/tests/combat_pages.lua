-- client: both
-- The settings pages open in a fight without an error
__sim.setCombat(true)
__sim.advance(0.3)
check("in combat", InCombatLockdown())
for _, p in ipairs({ { "buttons", "auto_button" }, { "fluffy", "cdbar_page" }, { "fluffy", "coverage_section" }, { "fluffy", "readyreminders_section" }, { "fluffy", "totemplates_section" } }) do
	local ok, err = pcall(function() ShamanPowerConfig:Open(p) end)
	check("open in a fight: " .. p[2], ok, err)
	__sim.advance(0.3)
end
__sim.setCombat(false)
__sim.advance(0.3)
check("out of combat", not InCombatLockdown())
finish()
