-- client: both
-- Ready Reminders' spell list (reviewer item 4)
local keys = {}
for _, e in ipairs(ShamanPower.ReadyReminderSpells or {}) do keys[e.key] = true end
check("Lightning Bolt in the list", keys.lightningbolt == true)
check("Water Shield no longer in the list", keys.watershield ~= true)
check("Stoneclaw Totem in the list", keys.stoneclaw == true)
check("Reincarnation in the list", keys.reincarnation == true)
for _, id in ipairs({ 5730, 20608 }) do
	check("spell " .. id .. " exists on this client (" .. tostring(GetSpellInfo(id)) .. ")", GetSpellInfo(id) ~= nil)
end
finish()
