--
-- log.lua
--
-- Copyright (c) 2016 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--
---@class log
---@field usecolor boolean
---@field outfile string
---@field level "trace"|"debug"|"info"|"warn"|"error"|"fatal"
---@field trace fun(...:string|number)
---@field debug fun(...:string|number)
---@field info fun(...:string|number)
---@field warn fun(...:string|number)
---@field error fun(...:string|number)
---@field fatal fun(...:string|number)
local log = { _version = "0.1.0" }

log.usecolor = true
log.outfile = nil
log.level = "trace"

local ansi = {
    blue   = "\27[34m",
    cyan   = "\27[36m",
    green  = "\27[32m",
    yellow = "\27[33m",
    red    = "\27[31m",
    purple = "\27[35m",
    white  = "\27[0m",
}

local backend = {
    write = function(str)
        if write then
            write(str)
        else
            io.write(str)
        end
    end,
    setColor = function(color)
        if colors then
            term.setTextColor(colors[color])
        else
            io.write(ansi[color])
        end
    end,
    reSetColor = function()
        if colors then
            term.setTextColor(colors.white)
        else
            io.write(ansi.white)
        end
    end
}

local modes = {
    { name = "trace", color = "blue", },
    { name = "debug", color = "cyan", },
    { name = "info",  color = "green", },
    { name = "warn",  color = "yellow", },
    { name = "error", color = "red", },
    { name = "fatal", color = "purple", },
}

---@type table<number,table>
local levels = {}
for i, v in ipairs(modes) do
    levels[v.name] = i
end


local round = function(x, increment)
    increment = increment or 1
    x = x / increment
    return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end


local _tostring = tostring

local tostring = function(...)
    local t = {}
    for i = 1, select('#', ...) do
        local x = select(i, ...)
        if type(x) == "number" then
            x = round(x, .01)
        end
        t[#t + 1] = _tostring(x)
    end
    return table.concat(t, " ")
end


for i, x in ipairs(modes) do
    local nameupper = x.name:upper()
    ---@diagnostic disable-next-line: assign-type-mismatch
    log[x.name] = function(...)
        -- Return early if we're below the log level
        if i < levels[log.level] then
            return
        end

        local msg = tostring(...)
        local info = debug.getinfo(2, "Sl")
        local lineinfo = info.short_src .. ":" .. info.currentline

        --local tempColor = term.getTextColor()
        if log.usecolor then
            backend.setColor(x.color)
        end
        backend.write(("[%-6s%s] "):format(nameupper, os.date("%H:%M:%S")))
        backend.reSetColor()
        backend.write(("%s: %s\n"):format(lineinfo, msg))

        --[[
        -- Output to console
        print(string.format("%s[%-6s%s]%s %s: %s",
            log.usecolor and x.color or "",
            nameupper,
            os.date("%H:%M:%S"),
            log.usecolor and "\27[0m" or "",
            lineinfo,
            msg))
        ]]

        -- Output to log file
        if log.outfile then
            local fp = io.open(log.outfile, "a")
            local str = string.format("[%-6s%s] %s: %s\n",
                nameupper, os.date(), lineinfo, msg)
            ---@cast fp -nil 调用者需要确保传入的日志文件存在
            fp:write(str)
            fp:close()
        end
    end
end


return log
