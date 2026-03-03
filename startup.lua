local log = require("lib.log")
local thread = require("lib.thread")

thread.add(function()
    shell.run("main")
end)

thread.run()
