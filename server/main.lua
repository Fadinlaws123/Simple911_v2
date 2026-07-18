local Calls = {}
local NextCallId = 1000
local Cooldowns = {}
local OnDuty = {}
local UnitProfiles = {}
local LastCallBySource = {}

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

local function getUnitProfile(source)
    if not UnitProfiles[source] then
        UnitProfiles[source] = { callsign = ('%s-%s'):format(Config.CallSettings.defaultCallsignPrefix, source), name = GetPlayerName(source) or ('Responder %s'):format(source) }
    end
    UnitProfiles[source].name = GetPlayerName(source) or UnitProfiles[source].name
    return UnitProfiles[source]
end

local function addTimeline(call, event, actor, text)
    call.timeline = call.timeline or {}
    call.timeline[#call.timeline + 1] = { event = event, actor = actor, text = text, time = os.time() }
end

local function publicUnits(units)
    local list = {}
    for source, unit in pairs(units or {}) do
        list[#list + 1] = { source = source, callsign = unit.callsign, name = unit.name, status = unit.status }
    end
    table.sort(list, function(a, b) return a.callsign < b.callsign end)
    return list
end

local function publicCall(call)
    return {
        id = call.id, serviceId = call.serviceId, serviceLabel = call.serviceLabel, templateId = call.templateId,
        title = call.title, category = call.category, priority = call.priority, message = call.message,
        callerName = call.callerName, anonymous = call.anonymous, location = call.location, coords = call.coords,
        status = call.status, claimedBy = call.claimedBy, claimedByName = call.claimedByName,
        assignedUnits = publicUnits(call.assignedUnits), notes = call.notes or {}, timeline = call.timeline or {},
        createdAt = call.createdAt, updatedAt = call.updatedAt, resolvedByName = call.resolvedByName
    }
end

local function getCallList()
    local list = {}
    for _, call in pairs(Calls) do list[#list + 1] = publicCall(call) end
    table.sort(list, function(a, b)
        if a.status == 'resolved' and b.status ~= 'resolved' then return false end
        if a.status ~= 'resolved' and b.status == 'resolved' then return true end
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.id > b.id
    end)
    return list
end

local function getUnitRoster()
    local list = {}
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if canReceiveDispatch(source) then
            local profile = getUnitProfile(source)
            local activeCalls = 0
            for _, call in pairs(Calls) do if call.status ~= 'resolved' and call.assignedUnits and call.assignedUnits[source] then activeCalls = activeCalls + 1 end end
            list[#list + 1] = { source = source, callsign = profile.callsign, name = profile.name, activeCalls = activeCalls }
        end
    end
    table.sort(list, function(a, b) return a.callsign < b.callsign end)
    return list
end

local function syncResponders()
    local calls = getCallList()
    local units = getUnitRoster()
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if canReceiveDispatch(source) then
            TriggerClientEvent('simple911:client:syncDispatch', source, calls, units, getUnitProfile(source))
        end
    end
end

local function notify(source, message, kind)
    if source then TriggerClientEvent('simple911:client:notify', source, message, kind or 'info') end
end

local function notifyCaller(call, message, kind)
    if Config.Dispatch.notifyCallerOnStatusChange and call.source and GetPlayerName(call.source) then notify(call.source, message, kind) end
end

local function sendDiscordLog(title, description, color)
    if not Config.Discord.enabled or Config.Discord.webhook == '' then return end
    PerformHttpRequest(Config.Discord.webhook, function() end, 'POST', json.encode({ username = Config.Discord.username, avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil, embeds = {{ title = title, description = description, color = color or 3447003, footer = { text = 'Simple911 v2' }, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') }} }), { ['Content-Type'] = 'application/json' })
end

local function buildCall(source, service, template, data)
    local now = os.time()
    NextCallId = NextCallId + 1
    local anonymous = source and service.allowAnonymous and data.anonymous == true
    local playerName = source and (GetPlayerName(source) or ('Player %s'):format(source)) or sanitizeText(data.callerName or 'System', 80)
    local call = {
        id = NextCallId, source = source, serviceId = service.id, serviceLabel = service.label, templateId = template.id,
        title = template.label, category = template.category, priority = tonumber(data.priority) or template.priority,
        message = sanitizeText(data.message or template.message, Config.CallSettings.maxMessageLength),
        callerName = anonymous and Config.CallSettings.anonymousLabel or playerName, anonymous = anonymous or false,
        location = sanitizeText(data.location or 'Unknown Location', 120), coords = data.coords, status = 'unassigned',
        claimedBy = nil, claimedByName = nil, assignedUnits = {}, notes = {}, timeline = {}, createdAt = now, updatedAt = now
    }
    addTimeline(call, 'created', call.callerName, 'Call created')
    return call
end

RegisterNetEvent('simple911:server:createCall', function(data)
    local source = source
    if type(data) ~= 'table' then return end
    local service = getService(data.serviceId)
    local template = getTemplate(service, data.templateId)
    if not service or not template then return notify(source, 'That call type is not available.', 'error') end
    local now = os.time()
    if Config.Cooldown.enabled and Cooldowns[source] and now - Cooldowns[source] < Config.Cooldown.seconds then return notify(source, ('Please wait %s seconds before creating another call.'):format(Config.Cooldown.seconds - (now - Cooldowns[source])), 'error') end
    local activeCount = 0
    for _, call in pairs(Calls) do if call.status ~= 'resolved' then activeCount = activeCount + 1 end end
    if activeCount >= Config.CallSettings.maxActiveCalls then return notify(source, 'Dispatch is currently at maximum call capacity.', 'error') end
    local message = sanitizeText(data.message, Config.CallSettings.maxMessageLength)
    if message == '' then return notify(source, 'Please provide details for your call.', 'error') end
    local coords = data.coords
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then coords = nil end
    local call = buildCall(source, service, template, { message = message, anonymous = data.anonymous, location = data.location, coords = coords })
    Calls[call.id] = call
    Cooldowns[source] = now
    LastCallBySource[source] = call.id
    notify(source, ('Your %s call #%s has been submitted.'):format(service.shortLabel, call.id), 'success')
    for _, playerId in ipairs(GetPlayers()) do local responder = tonumber(playerId) if canReceiveDispatch(responder) then TriggerClientEvent('simple911:client:newCall', responder, publicCall(call)) end end
    syncResponders()
    sendDiscordLog(('New %s Call #%s'):format(service.shortLabel, call.id), ('**Type:** %s\n**Location:** %s\n**Caller:** %s\n**Details:** %s'):format(call.title, call.location, call.callerName, call.message), 15158332)
end)

RegisterNetEvent('simple911:server:requestDispatch', function()
    local source = source
    if not canReceiveDispatch(source) then return end
    TriggerClientEvent('simple911:client:syncDispatch', source, getCallList(), getUnitRoster(), getUnitProfile(source))
end)

RegisterNetEvent('simple911:server:setDuty', function(state)
    local source = source
    if not isResponder(source) then return notify(source, 'You do not have permission to access dispatch.', 'error') end
    OnDuty[source] = state == true
    getUnitProfile(source)
    TriggerClientEvent('simple911:client:dutyChanged', source, OnDuty[source])
    syncResponders()
end)

RegisterNetEvent('simple911:server:setCallsign', function(value)
    local source = source
    if not canReceiveDispatch(source) then return end
    local callsign = sanitizeText(value, 24):upper()
    if callsign == '' then return notify(source, 'Enter a valid callsign.', 'error') end
    getUnitProfile(source).callsign = callsign
    notify(source, ('Callsign updated to %s.'):format(callsign), 'success')
    syncResponders()
end)

RegisterNetEvent('simple911:server:updateCall', function(callId, action, payload)
    local source = source
    if not canReceiveDispatch(source) then return end
    callId = tonumber(callId)
    local call = callId and Calls[callId]
    if not call then return end
    local profile = getUnitProfile(source)
    local actor = ('%s (%s)'):format(profile.callsign, profile.name)
    call.assignedUnits = call.assignedUnits or {}

    if action == 'claim' or action == 'respond' then
        if call.status == 'resolved' then return end
        if not Config.Dispatch.allowMultipleUnits then call.assignedUnits = {} end
        call.assignedUnits[source] = { callsign = profile.callsign, name = profile.name, status = action == 'respond' and 'responding' or 'assigned' }
        if not call.claimedBy then call.claimedBy = source call.claimedByName = profile.callsign end
        if action == 'respond' then
            call.status = 'responding'
            addTimeline(call, 'responding', actor, 'Unit responding')
            notifyCaller(call, ('A responder is en route to call #%s.'):format(call.id), 'success')
        elseif call.status == 'unassigned' then
            call.status = 'claimed'
            addTimeline(call, 'claimed', actor, 'Call assigned')
            notifyCaller(call, ('Your call #%s has been assigned to a responder.'):format(call.id), 'info')
        end
    elseif action == 'unclaim' then
        call.assignedUnits[source] = nil
        addTimeline(call, 'unassigned_unit', actor, 'Unit removed from call')
        if call.claimedBy == source then
            call.claimedBy = nil call.claimedByName = nil
            for assignedSource, unit in pairs(call.assignedUnits) do call.claimedBy = assignedSource call.claimedByName = unit.callsign break end
        end
        if next(call.assignedUnits) == nil then call.status = 'unassigned' end
    elseif action == 'resolve' then
        if call.status == 'resolved' then return end
        call.status = 'resolved' call.resolvedBy = source call.resolvedByName = profile.callsign
        addTimeline(call, 'resolved', actor, 'Call resolved')
        notifyCaller(call, ('Your call #%s has been marked resolved.'):format(call.id), 'success')
        SetTimeout(Config.CallSettings.resolvedRetentionSeconds * 1000, function() if Calls[callId] and Calls[callId].status == 'resolved' then Calls[callId] = nil syncResponders() end end)
    elseif action == 'note' then
        local note = sanitizeText(payload and payload.note, Config.CallSettings.maxNoteLength)
        if note == '' then return end
        call.notes[#call.notes + 1] = { text = note, author = actor, time = os.time() }
        addTimeline(call, 'note', actor, note)
        if Config.Discord.logNotes then sendDiscordLog(('Note added to Call #%s'):format(call.id), ('**%s:** %s'):format(actor, note), 5793266) end
    elseif action == 'priority' and Config.CallSettings.allowPriorityChanges then
        local priority = tonumber(payload and payload.priority)
        if priority ~= 1 and priority ~= 2 and priority ~= 3 then return end
        call.priority = priority
        addTimeline(call, 'priority', actor, ('Priority changed to %s'):format(priority))
    else return end

    call.updatedAt = os.time()
    if Config.Discord.logStatusChanges and action ~= 'note' then sendDiscordLog(('Call #%s Updated'):format(call.id), ('**Action:** %s\n**Unit:** %s\n**Status:** %s'):format(action, actor, call.status), 3447003) end
    syncResponders()
end)

RegisterNetEvent('simple911:server:cancelLastCall', function()
    local source = source
    if not Config.CallSettings.allowCallerCancel then return end
    local callId = LastCallBySource[source]
    local call = callId and Calls[callId]
    if not call or call.source ~= source or call.status == 'resolved' then return notify(source, 'You do not have an active call to cancel.', 'error') end
    call.status = 'resolved' call.resolvedByName = 'Caller Cancelled' call.updatedAt = os.time()
    addTimeline(call, 'cancelled', call.callerName, 'Caller cancelled the call')
    notify(source, ('Call #%s has been cancelled.'):format(call.id), 'success')
    LastCallBySource[source] = nil
    syncResponders()
end)

AddEventHandler('playerDropped', function()
    local source = source
    Cooldowns[source] = nil OnDuty[source] = nil UnitProfiles[source] = nil
    for _, call in pairs(Calls) do
        if call.assignedUnits and call.assignedUnits[source] then
            call.assignedUnits[source] = nil
            if call.claimedBy == source then call.claimedBy = nil call.claimedByName = nil end
            if next(call.assignedUnits) == nil and call.status ~= 'resolved' then call.status = 'unassigned' end
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
    local call = buildCall(nil, service, template, data)
    Calls[call.id] = call
    syncResponders()
    return true, call.id
end)

exports('GetCall', function(callId) local call = Calls[tonumber(callId)] return call and publicCall(call) or nil end)
exports('GetActiveCalls', function() return getCallList() end)
