-- client: both
-- Every settings row's get / hidden / disabled / name / values runs without an error
local SP = ShamanPower
local n, bad = 0, {}
local function walk(group, path, depth, handler)
	if depth > 8 or type(group) ~= "table" or type(group.args) ~= "table" then return end
	handler = group.handler or handler
	for k, o in pairs(group.args) do
		if type(o) == "table" then
			local info = {}
			for i, v in ipairs(path) do info[i] = v end
			info[#info + 1] = k
			info.option, info.arg, info.type, info.handler, info.options = o, o.arg, o.type, o.handler or handler, SP.options
			for _, fn in ipairs({ "get", "hidden", "disabled", "name", "desc", "values" }) do
				if type(o[fn]) == "function" then
					n = n + 1
					local ok, err = pcall(o[fn], info)
					if not ok then bad[#bad + 1] = table.concat(info, ".") .. "." .. fn .. ": " .. tostring(err) end
				end
			end
			if o.type == "group" then walk(o, info, depth + 1, handler) end
		end
	end
end
walk(SP.options, {}, 0, SP.options.handler)
check("settings rows run (" .. n .. " calls)", #bad == 0, table.concat(bad, " | "):sub(1, 700))
finish()
