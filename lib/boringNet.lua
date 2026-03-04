---@class boringNet.message
---@field type boringNet.messageType
---@field requestId number
---@field data string|number|boolean|nil|table

local log = require("lib.log")
local thread = require("lib.thread")

local out = {}

---@enum boringNet.messageType
out.messageType = {
    SEND = "send",
    ACK = "ack"
}

--- 检查一个表是否为消息
---@param mTable any
---@return boolean
local function isMessage(mTable)
    if type(mTable) ~= "table" then
        return false
    end
    ---@cast mTable table
    if not mTable.type or not mTable.requestId then
        return false
    end
    ---@cast mTable {type:unknown,requestId:unknown,data:unknown}
    if type(mTable.type) ~= "string" or type(mTable.requestId) ~= "number" then
        return false
    end
    ---@cast mTable boringNet.message
    return true
end

--- 广播
---@param data string|number|boolean|nil|table
---@param protocol? string
---@return number[]|nil receivers
function out.broadcast(data, protocol)
    local debugData
    if type(data) ~= "table" then
        debugData = tostring(data)
    else
        debugData = textutils.serialise(data, { allow_repetitions = true })
    end

    log.debug(("Will broadcast \"%s\" under protocol: \"%s\""):format(debugData, protocol))

    local requestId = math.random()
    ---@type boringNet.message
    local sendMessage = { type = out.messageType.SEND, requestId = requestId, data = data }
    rednet.broadcast(sendMessage, protocol)
    local receivers = {}
    thread.add(function()
        parallel.waitForAny(function()
            while true do
                local senderId, message = rednet.receive(protocol)
                if not isMessage(message) then
                    log.debug(("Receive a message but it isn't a legal message"))
                    goto continue
                end
                ---@cast message boringNet.message
                if message.type ~= out.messageType.ACK then
                    log.debug(("Receive a message but it isn't a ack message"))
                    goto continue
                end
                if message.requestId ~= requestId then
                    log.debug(("Receive a ack message but is isn't request one"))
                    goto continue
                end

                log.debug(("Success send a message: %s to %d"):format(debugData, senderId))
                table.insert(receivers, senderId)
                ::continue::
            end
        end, function()
            os.sleep(2)
        end)
    end)
    if not next(receivers) then
        return nil
    end
    return receivers
end

--- 发送
---@param id number
---@param data string|number|boolean|nil|table
---@param protocol? string
---@return boolean
function out.send(id, data, protocol)
    local debugData
    if type(data) ~= "table" then
        debugData = tostring(data)
    else
        debugData = textutils.serialise(data, { allow_repetitions = true })
    end

    log.debug(("Will send \"%s\" to %d under protocol: \"%s\""):format(debugData, id, protocol))

    local requestId = math.random()
    ---@type boringNet.message
    local sendMessage = { type = out.messageType.SEND, requestId = requestId, data = data }
    rednet.send(id, sendMessage, protocol)
    for i = 1, 3, 1 do
        local done = false
        thread.add(function()
            parallel.waitForAny(function()
                while true do
                    local senderId, message = rednet.receive(protocol)
                    if senderId ~= id then
                        goto continue
                    end
                    if not isMessage(message) then
                        log.debug(("Receive a message but it isn't a legal message"))
                        goto continue
                    end
                    ---@cast message boringNet.message
                    if message.type ~= out.messageType.ACK then
                        log.debug(("Receive a message: %s but it isn't a ack message"):format(textutils.serialise(
                        message)))
                        goto continue
                    end
                    if message.requestId ~= requestId then
                        log.debug(("Receive a ack message but is isn't request one"))
                        goto continue
                    end

                    log.debug(("Success send a message: %s to %d"):format(debugData, id))

                    done = true
                    ::continue::
                end
            end, function()
                os.sleep(1)
            end)
        end)
        if done then
            return true
        end
    end
    return false
end

--- 接收
---@param protocol? string
---@param timeout? number
---@return number|nil senderId
---@return string|number|boolean|nil|table message
---@return string|nil protocol
function out.receive(protocol, timeout)
    local sender, data, prl
    parallel.waitForAny(function()
        while true do
            local senderId, message, pl = rednet.receive(protocol)
            if not isMessage(message) then
                goto continue
            end
            ---@cast message boringNet.message
            rednet.send(senderId,
                { type = out.messageType.ACK, requestId = message.requestId } --[[@as boringNet.message]],
                pl)
            if type(message.data) ~= "table" then
                log.debug(("Success receive a message: %s from %d"):format(tostring(message.data), senderId))
            else
                log.debug(("Success receive a message: %s from %d"):format(tostring(message.data), senderId))
            end
            sender = senderId
            data = message.data
            prl = pl
            break
            ::continue::
        end
    end, function()
        os.sleep(timeout or (7 ^ 4))
    end)
    return sender, data, prl
end

return out
