-- client: both
-- Ready Reminders' spell list (reviewer item 4)
local keys = {}
for _, e in ipairs(ShamanPower.ReadyReminderSpells or {}) do keys[e.key] = true end
check("Lightning Bolt in the list", keys.lightningbolt == true)
check("Water Shield no longer in the list", keys.watershield ~= true)
finish()
