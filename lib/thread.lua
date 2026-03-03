local out = {}
---@type ({co:thread,filter:string|nil}|false)[]
local threads = {}

--- 添加一条协程
---@param func function
function out.add(func)
    local thread = coroutine.create(func)
    table.insert(threads, { co = thread, filter = nil })
end

--- 启动事件循环
function out.run()
    local event = { n = 0 }
    while true do
        for i = 1, #threads do
            local thread = threads[i]
            if not thread then
                goto continue
            end
            if thread.filter ~= nil and thread.filter ~= event[1] then
                goto continue
            end
            local ok, filterOrErr = coroutine.resume(thread.co, table.unpack(event, 1, event.n))
            if ok then
                thread.filter = filterOrErr
            else
                error(filterOrErr, 2)
            end

            if coroutine.status(thread.co) == "dead" then
                threads[i] = false
            end
            ::continue::
        end
        for i = #threads, 1, -1 do
            local thread = threads[i]
            if not thread then
                table.remove(threads, i)
            end
        end

        event = table.pack(os.pullEvent())
    end
end

return out
