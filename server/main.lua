local Calls = {}
local NextCallId = 0
local Cooldowns = {}

local function isResponder(source)
    if Config.Debug and Config.Access.allowEveryoneWhenDebug then return true end
    return IsPlayerAceAllowed(tostring(source), Config.Access.acePermission)
end

local function sanitize(value, maxLength)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[\r\n]+', ' '):gsub('%s+', ' ')
    value = value:match('^%s*(.-)%s*$') or ''
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function responderProfile(source)
    return {
        source = source,
        name = GetPlayerName(source) or ('Responder %s'):format(source)
    }
end

local function attachedList(call)
    local list = {}
    for source, unit in pairs(call.attachedUnits or {}) do
        list[#list + 1] = {
            source = source,
            name = unit.name
        }
    end
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    return list
end

local function publicCall(call)
    return {
        id = call.id,
        message = call.message,
        callerName = call.callerName,
        callerId = call.callerId,
        location = call.location,
        coords = call.coords,
        createdAt = call.createdAt,
        expiresAt = call.expiresAt,
        status = call.primaryUnit and 'enroute' or 'new',
        primaryUnit = call.primaryUnit,
        attachedUnits = attachedList(call)
    }
end

local function getRecentCalls()
    local list = {}
    for _, call in pairs(Calls) do list[#list + 1] = publicCall(call) end
    table.sort(list, function(a, b) return a.id > b.id end)
    while #list > Config.CallSettings.historyLimit do table.remove(list) end
    return list
end

local function notify(source, message, kind)
    TriggerClientEvent('simple911:client:notify', source, message, kind or 'info')
end

local function sendDiscordLog(call)
    if not Config.Discord.enabled or Config.Discord.webhook == '' then return end
    PerformHttpRequest(Config.Discord.webhook, function() end, 'POST', json.encode({
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil,
        embeds = {{
            title = ('911 Call #%s'):format(call.id),
            description = ('**Caller:** %s\n**Location:** %s\n**Message:** %s'):format(call.callerName, call.location, call.message),
            color = 15158332,
            footer = { text = 'Simple911 v2' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }), { ['Content-Type'] = 'application/json' })
end

local function forEachResponder(callback)
    for _, playerId in ipairs(GetPlayers()) do
        local responder = tonumber(playerId)
        if isResponder(responder) then callback(responder) end
    end
end

local function sendCallToResponders(call)
    local data = publicCall(call)
    forEachResponder(function(responder)
        TriggerClientEvent('simple911:client:receiveCall', responder, data)
    end)
end

local function broadcastCallUpdate(call)
    local data = publicCall(call)
    forEachResponder(function(responder)
        TriggerClientEvent('simple911:client:updateCall', responder, data)
    end)
end

local function broadcastCallClosed(callId, closedBy)
    forEachResponder(function(responder)
        TriggerClientEvent('simple911:client:callClosed', responder, callId, closedBy)
    end)
end

local function promoteAttachedUnit(call)
    local nextSource, nextUnit
    for source, unit in pairs(call.attachedUnits or {}) do
        nextSource = source
        nextUnit = unit
        break
    end

    if nextSource then
        call.attachedUnits[nextSource] = nil
        call.primaryUnit = {
            source = nextSource,
            name = nextUnit.name
        }
        return true
    end

    call.primaryUnit = nil
    return false
end

RegisterNetEvent('simple911:server:createCall', function(data)
    local source = source
    if type(data) ~= 'table' then return end

    local now = os.time()
    local lastCall = Cooldowns[source]
    if lastCall and now - lastCall < Config.CallSettings.cooldownSeconds then
        local remaining = Config.CallSettings.cooldownSeconds - (now - lastCall)
        notify(source, Config.Messages.cooldown:format(remaining), 'error')
        return
    end

    local message = sanitize(data.message, Config.CallSettings.maxMessageLength)
    if message == '' then
        notify(source, Config.Messages.empty, 'error')
        return
    end

    local coords = data.coords
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then
        coords = nil
    end

    NextCallId = NextCallId + 1
    local callerName = GetPlayerName(source) or ('Player %s'):format(source)
    local location = sanitize(data.location, 120)
    if location == '' then location = 'Unknown Location' end

    local call = {
        id = NextCallId,
        callerSource = source,
        callerName = callerName,
        callerId = source,
        message = message,
        location = location,
        coords = coords,
        createdAt = now,
        expiresAt = now + Config.CallSettings.activeCallSeconds,
        primaryUnit = nil,
        attachedUnits = {}
    }

    Calls[call.id] = call
    Cooldowns[source] = now

    if Config.Notifications.notifyCaller then
        notify(source, Config.Messages.submitted, 'success')
    end

    sendCallToResponders(call)
    sendDiscordLog(call)

    SetTimeout(Config.CallSettings.activeCallSeconds * 1000, function()
        local current = Calls[call.id]
        if current and not current.primaryUnit then
            Calls[call.id] = nil
            broadcastCallClosed(call.id, 'Expired')
        end
    end)
end)

RegisterNetEvent('simple911:server:respondToCall', function(callId)
    local source = source
    if not isResponder(source) then return end

    callId = tonumber(callId)
    local call = callId and Calls[callId]
    if not call then return notify(source, Config.Messages.invalidCall, 'error') end

    if call.primaryUnit and call.primaryUnit.source == source then
        return notify(source, Config.Messages.alreadyPrimary, 'info')
    end

    if call.attachedUnits[source] then
        return notify(source, Config.Messages.alreadyAttached, 'info')
    end

    local unit = responderProfile(source)
    if not call.primaryUnit then
        call.primaryUnit = unit
        notify(source, Config.Messages.becamePrimary:format(callId), 'success')
    else
        call.attachedUnits[source] = unit
        notify(source, Config.Messages.attached:format(callId), 'success')
    end

    broadcastCallUpdate(call)
end)

RegisterNetEvent('simple911:server:detachFromCall', function(callId)
    local source = source
    if not isResponder(source) then return end

    callId = tonumber(callId)
    local call = callId and Calls[callId]
    if not call then return notify(source, Config.Messages.invalidCall, 'error') end

    if call.primaryUnit and call.primaryUnit.source == source then
        local oldName = call.primaryUnit.name
        local promoted = promoteAttachedUnit(call)
        notify(source, Config.Messages.detached:format(callId), 'success')
        if promoted then
            broadcastCallUpdate(call)
        else
            call.primaryUnit = nil
            broadcastCallUpdate(call)
        end
        return
    end

    if call.attachedUnits[source] then
        call.attachedUnits[source] = nil
        notify(source, Config.Messages.detached:format(callId), 'success')
        broadcastCallUpdate(call)
    end
end)

RegisterNetEvent('simple911:server:closeCall', function(callId)
    local source = source
    if not isResponder(source) then return end

    callId = tonumber(callId)
    local call = callId and Calls[callId]
    if not call then return notify(source, Config.Messages.invalidCall, 'error') end

    if not call.primaryUnit or call.primaryUnit.source ~= source then
        return notify(source, Config.Messages.primaryOnlyClose, 'error')
    end

    local closedBy = call.primaryUnit.name
    Calls[callId] = nil
    broadcastCallClosed(callId, closedBy)
end)

RegisterNetEvent('simple911:server:requestCalls', function()
    local source = source
    if not isResponder(source) then
        notify(source, Config.Messages.noPermission, 'error')
        return
    end
    TriggerClientEvent('simple911:client:syncCalls', source, getRecentCalls())
end)

AddEventHandler('playerDropped', function()
    local source = source
    Cooldowns[source] = nil

    for _, call in pairs(Calls) do
        local changed = false
        if call.primaryUnit and call.primaryUnit.source == source then
            promoteAttachedUnit(call)
            changed = true
        elseif call.attachedUnits and call.attachedUnits[source] then
            call.attachedUnits[source] = nil
            changed = true
        end

        if changed then broadcastCallUpdate(call) end
    end
end)

exports('CreateCall', function(data)
    if type(data) ~= 'table' then return false, 'invalid_data' end

    local message = sanitize(data.message, Config.CallSettings.maxMessageLength)
    if message == '' then return false, 'invalid_message' end

    NextCallId = NextCallId + 1
    local now = os.time()
    local call = {
        id = NextCallId,
        callerSource = nil,
        callerName = sanitize(data.callerName or 'System', 80),
        callerId = nil,
        message = message,
        location = sanitize(data.location or 'Unknown Location', 120),
        coords = data.coords,
        createdAt = now,
        expiresAt = now + Config.CallSettings.activeCallSeconds,
        primaryUnit = nil,
        attachedUnits = {}
    }

    Calls[call.id] = call
    sendCallToResponders(call)
    sendDiscordLog(call)

    SetTimeout(Config.CallSettings.activeCallSeconds * 1000, function()
        local current = Calls[call.id]
        if current and not current.primaryUnit then
            Calls[call.id] = nil
            broadcastCallClosed(call.id, 'Expired')
        end
    end)

    return true, call.id
end)

exports('GetActiveCalls', function()
    return getRecentCalls()
end)