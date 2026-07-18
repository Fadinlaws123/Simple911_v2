local Calls = {}
local NextCallId = 1000
local Cooldowns = {}
local OnDuty = {}

local function getService(serviceId)
    for _, service in ipairs(Config.Services) do
        if service.id == serviceId then return service end
    end
end

local function getTemplate(service, templateId)
    if not service then return nil end
    for _, template in ipairs(service.templates or {}) do
        if template.id == templateId then return template end
    end
end

local function isResponder(source)
    if Config.Debug and Config.ResponderAccess.allowEveryoneWhenDebug then return true end
    return IsPlayerAceAllowed(tostring(source), Config.ResponderAccess.acePermission)
end

local function canReceiveDispatch(source)
    return isResponder(source) and OnDuty[source] == true
end

local function sanitizeText(value, maxLength)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[\r\n]+', ' '):gsub('%s+', ' ')
    value = value:match('^%s*(.-)%s*$') or ''
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function publicCall(call)
    return {
        id = call.id,
        serviceId = call.serviceId,
        serviceLabel = call.serviceLabel,
        templateId = call.templateId,
        title = call.title,
        category = call.category,
        priority = call.priority,
        message = call.message,
        callerName = call.callerName,
        anonymous = call.anonymous,
        location = call.location,
        coords = call.coords,
        status = call.status,
        claimedBy = call.claimedBy,
        claimedByName = call.claimedByName,
        createdAt = call.createdAt,
        updatedAt = call.updatedAt
    }
end

local function getCallList()
    local list = {}
    for _, call in pairs(Calls) do list[#list + 1] = publicCall(call) end
    table.sort(list, function(a, b) return a.id > b.id end)
    return list
end

local function syncResponders()
    local calls = getCallList()
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if canReceiveDispatch(source) then
            TriggerClientEvent('simple911:client:syncCalls', source, calls)
        end
    end
end

local function notify(source, message, kind)
    TriggerClientEvent('simple911:client:notify', source, message, kind or 'info')
end

local function sendDiscordLog(title, description, color)
    if not Config.Discord.enabled or Config.Discord.webhook == '' then return end
    PerformHttpRequest(Config.Discord.webhook, function() end, 'POST', json.encode({
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil,
        embeds = {{
            title = title,
            description = description,
            color = color or 3447003,
            footer = { text = 'Simple911 v2' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }), { ['Content-Type'] = 'application/json' })
end

RegisterNetEvent('simple911:server:createCall', function(data)
    local source = source
    if type(data) ~= 'table' then return end

    local service = getService(data.serviceId)
    local template = getTemplate(service, data.templateId)
    if not service or not template then
        notify(source, 'That call type is not available.', 'error')
        return
    end

    local now = os.time()
    if Config.Cooldown.enabled and Cooldowns[source] and now - Cooldowns[source] < Config.Cooldown.seconds then
        local remaining = Config.Cooldown.seconds - (now - Cooldowns[source])
        notify(source, ('Please wait %s seconds before creating another call.'):format(remaining), 'error')
        return
    end

    local activeCount = 0
    for _, call in pairs(Calls) do
        if call.status ~= 'resolved' then activeCount = activeCount + 1 end
    end
    if activeCount >= Config.CallSettings.maxActiveCalls then
        notify(source, 'Dispatch is currently at maximum call capacity.', 'error')
        return
    end

    local message = sanitizeText(data.message, Config.CallSettings.maxMessageLength)
    if message == '' then
        notify(source, 'Please provide details for your call.', 'error')
        return
    end

    local location = sanitizeText(data.location, 120)
    if location == '' then location = 'Unknown Location' end

    local coords = data.coords
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then
        coords = nil
    end

    NextCallId = NextCallId + 1
    local anonymous = service.allowAnonymous and data.anonymous == true
    local playerName = GetPlayerName(source) or ('Player %s'):format(source)

    local call = {
        id = NextCallId,
        source = source,
        serviceId = service.id,
        serviceLabel = service.label,
        templateId = template.id,
        title = template.label,
        category = template.category,
        priority = template.priority,
        message = message,
        callerName = anonymous and Config.CallSettings.anonymousLabel or playerName,
        anonymous = anonymous,
        location = location,
        coords = coords,
        status = 'unassigned',
        claimedBy = nil,
        claimedByName = nil,
        createdAt = now,
        updatedAt = now
    }

    Calls[call.id] = call
    Cooldowns[source] = now

    notify(source, ('Your %s call #%s has been submitted.'):format(service.shortLabel, call.id), 'success')

    for _, playerId in ipairs(GetPlayers()) do
        local responder = tonumber(playerId)
        if canReceiveDispatch(responder) then
            TriggerClientEvent('simple911:client:newCall', responder, publicCall(call))
        end
    end

    sendDiscordLog(('New %s Call #%s'):format(service.shortLabel, call.id), ('**Type:** %s\n**Location:** %s\n**Caller:** %s\n**Details:** %s'):format(call.title, call.location, call.callerName, call.message), 15158332)
end)

RegisterNetEvent('simple911:server:requestCalls', function()
    local source = source
    if not canReceiveDispatch(source) then return end
    TriggerClientEvent('simple911:client:syncCalls', source, getCallList())
end)

RegisterNetEvent('simple911:server:setDuty', function(state)
    local source = source
    if not isResponder(source) then
        notify(source, 'You do not have permission to access dispatch.', 'error')
        return
    end
    OnDuty[source] = state == true
    TriggerClientEvent('simple911:client:dutyChanged', source, OnDuty[source])
    if OnDuty[source] then
        TriggerClientEvent('simple911:client:syncCalls', source, getCallList())
    end
end)

RegisterNetEvent('simple911:server:updateCallStatus', function(callId, action)
    local source = source
    if not canReceiveDispatch(source) then return end

    callId = tonumber(callId)
    local call = callId and Calls[callId]
    if not call then return end

    local responderName = GetPlayerName(source) or ('Responder %s'):format(source)
    if action == 'claim' then
        if call.status == 'resolved' then return end
        if call.claimedBy and call.claimedBy ~= source then
            notify(source, ('Call #%s is already claimed by %s.'):format(call.id, call.claimedByName or 'another responder'), 'error')
            return
        end
        call.claimedBy = source
        call.claimedByName = responderName
        call.status = 'claimed'
    elseif action == 'respond' then
        if call.status == 'resolved' then return end
        if call.claimedBy and call.claimedBy ~= source then return end
        call.claimedBy = source
        call.claimedByName = responderName
        call.status = 'responding'
    elseif action == 'unclaim' then
        if call.claimedBy ~= source then return end
        call.claimedBy = nil
        call.claimedByName = nil
        call.status = 'unassigned'
    elseif action == 'resolve' then
        if call.status == 'resolved' then return end
        call.status = 'resolved'
        call.updatedAt = os.time()
        call.resolvedBy = source
        call.resolvedByName = responderName
        SetTimeout(Config.CallSettings.resolvedRetentionSeconds * 1000, function()
            if Calls[callId] and Calls[callId].status == 'resolved' then
                Calls[callId] = nil
                syncResponders()
            end
        end)
    else
        return
    end

    call.updatedAt = os.time()
    syncResponders()
end)

AddEventHandler('playerDropped', function()
    local source = source
    Cooldowns[source] = nil
    OnDuty[source] = nil
    for _, call in pairs(Calls) do
        if call.claimedBy == source and call.status ~= 'resolved' then
            call.claimedBy = nil
            call.claimedByName = nil
            call.status = 'unassigned'
            call.updatedAt = os.time()
        end
    end
    syncResponders()
end)

exports('CreateCall', function(data)
    if type(data) ~= 'table' then return false, 'invalid_data' end
    local service = getService(data.serviceId)
    local template = getTemplate(service, data.templateId)
    if not service or not template then return false, 'invalid_type' end

    NextCallId = NextCallId + 1
    local now = os.time()
    Calls[NextCallId] = {
        id = NextCallId,
        source = nil,
        serviceId = service.id,
        serviceLabel = service.label,
        templateId = template.id,
        title = template.label,
        category = template.category,
        priority = template.priority,
        message = sanitizeText(data.message or template.message, Config.CallSettings.maxMessageLength),
        callerName = sanitizeText(data.callerName or 'System', 80),
        anonymous = false,
        location = sanitizeText(data.location or 'Unknown Location', 120),
        coords = data.coords,
        status = 'unassigned',
        createdAt = now,
        updatedAt = now
    }
    syncResponders()
    return true, NextCallId
end)
