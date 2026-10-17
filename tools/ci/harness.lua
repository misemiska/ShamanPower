-- sp-ci test harness (prepended to every test): check / checkEq / skip / finish.
-- A test ends with finish(), which hands the tally to the runner through the sim's error channel.
__ci = { passes = 0, fails = {} }
function check(name, cond, detail)
	if cond then __ci.passes = __ci.passes + 1
	else __ci.fails[#__ci.fails + 1] = name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or "") end
end
function checkEq(name, got, want) check(name, got == want, "got " .. tostring(got) .. ", wanted " .. tostring(want)) end
function skip(reason) error("SPCI|skip|" .. tostring(reason), 0) end
function finish() error("SPCI|" .. __ci.passes .. "|" .. table.concat(__ci.fails, " ;; "), 0) end
