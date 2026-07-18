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

local function publicCall(call)
    return {
        id = call.id,
        message = call.message,
        callerName = call.callerName,
        callerId = call.callerId,
        location = call.location,
        coords = call.coords,
        createdAt = call.createdAt,
        expiresAt = call.expiresAt
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

local function sendCallToResponders(call)
    for _, playerId in ipairs(GetPlayers()) do
        local responder = tonumber(playerId)
        if isResponder(responder) then
            TriggerClientEvent('simple911:client:receiveCall', responder, publicCall(call))
        end
    end
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
        expiresAt = now + Config.CallSettings.activeCallSeconds
    }

    Calls[call.id] = call
    Cooldowns[source] = now

    if Config.Notifications.notifyCaller then
        notify(source, Config.Messages.submitted, 'success')
    end

    sendCallToResponders(call)
    sendDiscordLog(call)

    SetTimeout(Config.CallSettings.activeCallSeconds * 1000, function()
        if Calls[call.id] then Calls[call.id] = nil end
    end)
end)

RegisterNetEvent('simple911:server:requestCalls', function()
    local source = source
    if not isResponder(source) then
        notify(source, Config.Messages.noPermission, 'error')
        return
    end
    TriggerClientEvent('simple911:client:syncCalls', source, getRecentCalls())
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
        expiresAt = now + Config.CallSettings.activeCallSeconds
    }

    Calls[call.id] = call
    sendCallToResponders(call)
    sendDiscordLog(call)

    SetTimeout(Config.CallSettings.activeCallSeconds * 1000, function()
        if Calls[call.id] then Calls[call.id] = nil end
    end)

    return true, call.id
end)

exports('GetActiveCalls', function()
    return getRecentCalls()
end)
