local log = require("log")
local thread = require("thread")

thread.add(function()
    shell.run("main")
end)

thread.run()
