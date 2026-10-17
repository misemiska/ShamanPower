-- client: both
-- Drop All's Start Over After (reviewer item 12)
local SP = ShamanPower
checkEq("default 15", SP:DropAllResetSetting(), 15)
checkEq("prefix at 15", SP:DropAllResetPrefix(), "reset=combat/15")
checkEq("button built with 15", SP:DropAllResetSeconds(), 15)
SP.opt.dropAllResetSeconds = 0
checkEq("Never: plain reset", SP:DropAllResetPrefix(), "reset=combat")
SP:UpdateDropAllButton()
checkEq("Never: 0 seconds once the button is rebuilt", SP:DropAllResetSeconds(), 0)
SP.opt.dropAllResetSeconds = 30
checkEq("30 seconds", SP:DropAllResetPrefix(), "reset=combat/30")
SP:UpdateDropAllButton()
checkEq("30 seconds on the button", SP:DropAllResetSeconds(), 30)
SP.opt.dropAllResetSeconds = nil
SP:UpdateDropAllButton()
finish()
