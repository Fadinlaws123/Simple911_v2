local Calls = {}
local NextCallId = 1000
local Cooldowns = {}
local PanicCooldowns = {}
local OnDuty = {}
local UnitProfiles = {}
local LastCallBySource = {}

local function findById(list, id)
    for _, item in ipairs(list or {}) do if item.id == id then return item end end
end

local function getService(id) return findById(Config.Services, id) end
local function getTemplate(service, id) return service and findById(service.templates, id) end
local function getDepartment(id) return findById(Config.Departments, id) end
local function getUnitStatus(id) return findById(Config.UnitStatuses, id) end

local function sanitizeText(value, maxLength)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[\r\n]+', ' '):gsub('%s+', ' ')
    value = value:match('^%s*(.-)%s*$') or ''
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function isResponder(source)
    if Config.Debug and Config.ResponderAccess.allowEveryoneWhenDebug then return true end
    return IsPlayerAceAllowed(tostring(source), Config.ResponderAccess.acePermission)
end

local function isDispatcher(source)
    if Config.Debug and Config.ResponderAccess.allowEveryoneWhenDebug then return true end
    return IsPlayerAceAllowed(tostring(source), Config.ResponderAccess.dispatcherAcePermission)
end

local function defaultDepartment(source)
    return isDispatcher(source) and Config.Dispatch.dispatcherDepartment or (Config.Departments[1] and Config.Departments[1].id or 'police')
end

local function getUnitProfile(source)
    if not UnitProfiles[source] then
        local departmentId = defaultDepartment(source)
        local department = getDepartment(departmentId)
        UnitProfiles[source] = {
            callsign = ('%s-%s'):format(Config.CallSettings.defaultCallsignPrefix, source),
            name = GetPlayerName(source) or ('Responder %s'):format(source),
            department = departmentId,
            status = 'available',
            radio = department and department.defaultRadio or '',
            coords = nil
        }
    end
    UnitProfiles[source].name = GetPlayerName(source) or UnitProfiles[source].name
    return UnitProfiles[source]
end

local function canReceiveDispatch(source)
    return isResponder(source) and OnDuty[source] == true
end

local function contains(list, value)
    for _, item in ipairs(list or {}) do if item == value then return true end end
    return false
end

local function recipientEligible(source, call)
    if not canReceiveDispatch(source) then return false end
    local profile = getUnitProfile(source)
    if profile.department == Config.Dispatch.dispatcherDepartment then return true end
    return contains(call.departments, profile.department)
end

local function hasDispatcherOnDuty()
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if canReceiveDispatch(source) and getUnitProfile(source).department == Config.Dispatch.dispatcherDepartment then return true end
    end
    return false
end

local function shouldNotifyNewCall(source, call)
    if not recipientEligible(source, call) then return false end
    if Config.Dispatch.dispatcherPriorityRouting and hasDispatcherOnDuty() then
        return getUnitProfile(source).department == Config.Dispatch.dispatcherDepartment
    end
    return true
end

local function countEligibleUnits(call)
    local count = 0
    for _, playerId in ipairs(GetPlayers()) do
        if recipientEligible(tonumber(playerId), call) then count = count + 1 end
    end
    return count
end

local function addTimeline(call, event, actor, text)
    call.timeline = call.timeline or {}
    call.timeline[#call.timeline + 1] = { event = event, actor = actor, text = text, time = os.time() }
end

local function addConversation(call, direction, author, text)
    call.conversation = call.conversation or {}
    call.conversation[#call.conversation + 1] = { direction = direction, author = author, text = text, time = os.time() }
end

local function publicUnits(units)
    local list = {}
    for source, unit in pairs(units or {}) do
        list[#list + 1] = { source = source, callsign = unit.callsign, name = unit.name, status = unit.status, department = unit.department, radio = unit.radio }
    end
    table.sort(list, function(a, b) return a.callsign < b.callsign end)
    return list
end

local function publicCall(call)
    return {
        id = call.id, serviceId = call.serviceId, serviceLabel = call.serviceLabel, templateId = call.templateId,
        title = call.title, code = call.code, category = call.category, priority = call.priority, message = call.message,
        callerName = call.callerName, anonymous = call.anonymous, location = call.location, coords = call.coords,
        status = call.status, claimedBy = call.claimedBy, claimedByName = call.claimedByName, departments = call.departments,
        assignedUnits = publicUnits(call.assignedUnits), notes = call.notes or {}, timeline = call.timeline or {}, conversation = call.conversation or {},
        createdAt = call.createdAt, updatedAt = call.updatedAt, resolvedByName = call.resolvedByName,
        blip = call.blip, metadata = call.metadata
    }
end

local function getCallListFor(source)
    local list = {}
    for _, call in pairs(Calls) do
        if recipientEligible(source, call) then list[#list + 1] = publicCall(call) end
    end
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
            local p = getUnitProfile(source)
            local activeCalls = 0
            for _, call in pairs(Calls) do if call.status ~= 'resolved' and call.assignedUnits and call.assignedUnits[source] then activeCalls = activeCalls + 1 end end
            list[#list + 1] = { source = source, callsign = p.callsign, name = p.name, activeCalls = activeCalls, department = p.department, status = p.status, radio = p.radio, coords = p.coords }
        end
    end
    table.sort(list, function(a, b) return a.callsign < b.callsign end)
    return list
end

local function syncResponders()
    local units = getUnitRoster()
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if canReceiveDispatch(source) then
            TriggerClientEvent('simple911:client:syncDispatch', source, getCallListFor(source), units, getUnitProfile(source))
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
    PerformHttpRequest(Config.Discord.webhook, function() end, 'POST', json.encode({
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil,
        embeds = {{ title = title, description = description, color = color or 3447003, footer = { text = 'Simple911 v2' }, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') }}
    }), { ['Content-Type'] = 'application/json' })
end

local function buildCall(source, service, template, data)
    local now = os.time()
    NextCallId = NextCallId + 1
    local anonymous = source and service.allowAnonymous and data.anonymous == true
    local playerName = source and (GetPlayerName(source) or ('Player %s'):format(source)) or sanitizeText(data.callerName or 'System', 80)
    local call = {
        id = NextCallId, source = source, serviceId = service.id, serviceLabel = service.label, templateId = template.id,
        title = sanitizeText(data.title or template.label, 80), code = sanitizeText(data.code or template.code or service.shortLabel, 24),
        category = sanitizeText(data.category or template.category, 60), priority = tonumber(data.priority) or template.priority,
        message = sanitizeText(data.message or template.message, Config.CallSettings.maxMessageLength),
        callerName = anonymous and Config.CallSettings.anonymousLabel or playerName, anonymous = anonymous or false,
        location = sanitizeText(data.location or 'Unknown Location', 120), coords = data.coords, status = 'unassigned',
        departments = data.departments or template.departments or { Config.Dispatch.dispatcherDepartment },
        claimedBy = nil, claimedByName = nil, assignedUnits = {}, notes = {}, timeline = {}, conversation = {},
        createdAt = now, updatedAt = now, blip = data.blip, metadata = data.metadata
    }
    addTimeline(call, 'created', call.callerName, ('%s call created'):format(call.code))
    return call
end

local function createAndBroadcastCall(source, service, template, data)
    local call = buildCall(source, service, template, data)
    Calls[call.id] = call
    if source then LastCallBySource[source] = call.id end

    local eligible = countEligibleUnits(call)
    if source then
        notify(source, ('Your %s call #%s has been submitted.'):format(service.shortLabel, call.id), 'success')
        if eligible == 0 and Config.CallSettings.tellCallerWhenNoUnits then
            notify(source, 'No matching responders are currently available. Your call has been queued.', 'info')
            if not Config.CallSettings.queueCallsWhenNoUnits then Calls[call.id] = nil return nil end
        end
    end

    for _, playerId in ipairs(GetPlayers()) do
        local responder = tonumber(playerId)
        if shouldNotifyNewCall(responder, call) then TriggerClientEvent('simple911:client:newCall', responder, publicCall(call)) end
    end
    syncResponders()
    sendDiscordLog(('New %s Call #%s'):format(service.shortLabel, call.id), ('**Code:** %s\n**Type:** %s\n**Location:** %s\n**Caller:** %s\n**Details:** %s'):format(call.code, call.title, call.location, call.callerName, call.message), 15158332)
    return call
end

RegisterNetEvent('simple911:server:createCall', function(data)
    local source = source
    if type(data) ~= 'table' then return end
    local service = getService(data.serviceId)
    local template = getTemplate(service, data.templateId)
    if not service or not template or template.hiddenFromCaller then return notify(source, 'That call type is not available.', 'error') end
    local now = os.time()
    if Config.Cooldown.enabled and Cooldowns[source] and now - Cooldowns[source] < Config.Cooldown.seconds then
        return notify(source, ('Please wait %s seconds before creating another call.'):format(Config.Cooldown.seconds - (now - Cooldowns[source])), 'error')
    end
    local activeCount = 0
    for _, call in pairs(Calls) do if call.status ~= 'resolved' then activeCount = activeCount + 1 end end
    if activeCount >= Config.CallSettings.maxActiveCalls then return notify(source, 'Dispatch is currently at maximum call capacity.', 'error') end
    local message = sanitizeText(data.message, Config.CallSettings.maxMessageLength)
    if message == '' then return notify(source, 'Please provide details for your call.', 'error') end
    local coords = data.coords
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then coords = nil end
    Cooldowns[source] = now
    createAndBroadcastCall(source, service, template, { message = message, anonymous = data.anonymous, location = data.location, coords = coords })
end)

RegisterNetEvent('simple911:server:requestDispatch', function()
    local source = source
    if canReceiveDispatch(source) then TriggerClientEvent('simple911:client:syncDispatch', source, getCallListFor(source), getUnitRoster(), getUnitProfile(source)) end
end)

RegisterNetEvent('simple911:server:setDuty', function(state)
    local source = source
    if not isResponder(source) then return notify(source, 'You do not have permission to access dispatch.', 'error') end
    OnDuty[source] = state == true
    getUnitProfile(source)
    TriggerClientEvent('simple911:client:dutyChanged', source, OnDuty[source])
    syncResponders()
end)

RegisterNetEvent('simple911:server:setUnitProfile', function(data)
    local source = source
    if not canReceiveDispatch(source) or type(data) ~= 'table' then return end
    local profile = getUnitProfile(source)
    if data.callsign ~= nil then
        local value = sanitizeText(data.callsign, 24):upper()
        if value ~= '' then profile.callsign = value end
    end
    if data.department ~= nil and getDepartment(data.department) then
        profile.department = data.department
        local dept = getDepartment(data.department)
        if profile.radio == '' then profile.radio = dept.defaultRadio or '' end
    end
    if data.status ~= nil and getUnitStatus(data.status) then profile.status = data.status end
    if data.radio ~= nil then profile.radio = sanitizeText(data.radio, 24):upper() end
    syncResponders()
end)

RegisterNetEvent('simple911:server:updateUnitLocation', function(coords)
    local source = source
    if not canReceiveDispatch(source) or type(coords) ~= 'table' then return end
    if type(coords.x) == 'number' and type(coords.y) == 'number' and type(coords.z) == 'number' then getUnitProfile(source).coords = coords end
end)

RegisterNetEvent('simple911:server:updateCall', function(callId, action, payload)
    local source = source
    if not canReceiveDispatch(source) then return end
    callId = tonumber(callId)
    local call = callId and Calls[callId]
    if not call or not recipientEligible(source, call) then return end
    local profile = getUnitProfile(source)
    local actor = ('%s (%s)'):format(profile.callsign, profile.name)
    call.assignedUnits = call.assignedUnits or {}

    if action == 'claim' or action == 'respond' then
        if call.status == 'resolved' then return end
        if not Config.Dispatch.allowMultipleUnits then call.assignedUnits = {} end
        local unitStatus = action == 'respond' and 'enroute' or 'assigned'
        call.assignedUnits[source] = { callsign = profile.callsign, name = profile.name, status = unitStatus, department = profile.department, radio = profile.radio }
        if not call.claimedBy then call.claimedBy = source call.claimedByName = profile.callsign end
        if action == 'respond' then
            call.status = 'responding' profile.status = 'enroute'
            addTimeline(call, 'responding', actor, 'Unit responding')
            notifyCaller(call, ('A responder is en route to call #%s.'):format(call.id), 'success')
        elseif call.status == 'unassigned' then
            call.status = 'claimed'
            addTimeline(call, 'claimed', actor, 'Unit assigned')
            notifyCaller(call, ('Your call #%s has been assigned.'):format(call.id), 'info')
        end
    elseif action == 'onscene' then
        if not call.assignedUnits[source] then return end
        call.assignedUnits[source].status = 'onscene' profile.status = 'onscene' call.status = 'responding'
        addTimeline(call, 'onscene', actor, 'Unit arrived on scene')
        notifyCaller(call, ('A responder has arrived at call #%s.'):format(call.id), 'success')
    elseif action == 'unclaim' then
        call.assignedUnits[source] = nil
        profile.status = 'available'
        addTimeline(call, 'unassigned_unit', actor, 'Unit removed from call')
        if call.claimedBy == source then
            call.claimedBy = nil call.claimedByName = nil
            for assignedSource, unit in pairs(call.assignedUnits) do call.claimedBy = assignedSource call.claimedByName = unit.callsign break end
        end
        if next(call.assignedUnits) == nil then call.status = 'unassigned' end
    elseif action == 'resolve' then
        if call.status == 'resolved' then return end
        call.status = 'resolved' call.resolvedBy = source call.resolvedByName = profile.callsign
        for assignedSource in pairs(call.assignedUnits) do if UnitProfiles[assignedSource] then UnitProfiles[assignedSource].status = 'available' end end
        addTimeline(call, 'resolved', actor, 'Call resolved')
        notifyCaller(call, ('Your call #%s has been marked resolved.'):format(call.id), 'success')
        SetTimeout(Config.CallSettings.resolvedRetentionSeconds * 1000, function() if Calls[callId] and Calls[callId].status == 'resolved' then Calls[callId] = nil syncResponders() end end)
    elseif action == 'note' then
        local note = sanitizeText(payload and payload.note, Config.CallSettings.maxNoteLength)
        if note == '' then return end
        call.notes[#call.notes + 1] = { text = note, author = actor, time = os.time() }
        addTimeline(call, 'note', actor, note)
        if Config.Discord.logNotes then sendDiscordLog(('Note added to Call #%s'):format(call.id), ('**%s:** %s'):format(actor, note), 5793266) end
    elseif action == 'messageCaller' then
        local text = sanitizeText(payload and payload.message, Config.CallSettings.maxChatMessageLength)
        if text == '' then return end
        addConversation(call, 'toCaller', actor, text)
        addTimeline(call, 'caller_message', actor, 'Message sent to caller')
        if call.source and GetPlayerName(call.source) then TriggerClientEvent('simple911:client:callerMessage', call.source, call.id, actor, text) end
        if Config.Discord.logCallerChat then sendDiscordLog(('Dispatcher Message | Call #%s'):format(call.id), ('**%s:** %s'):format(actor, text), 3447003) end
    elseif action == 'priority' and Config.CallSettings.allowPriorityChanges then
        local priority = tonumber(payload and payload.priority)
        if priority ~= 1 and priority ~= 2 and priority ~= 3 then return end
        call.priority = priority
        addTimeline(call, 'priority', actor, ('Priority changed to %s'):format(priority))
    else return end

    call.updatedAt = os.time()
    if Config.Discord.logStatusChanges and action ~= 'note' and action ~= 'messageCaller' then sendDiscordLog(('Call #%s Updated'):format(call.id), ('**Action:** %s\n**Unit:** %s\n**Status:** %s'):format(action, actor, call.status), 3447003) end
    syncResponders()
end)

RegisterNetEvent('simple911:server:replyToCall', function(text)
    local source = source
    local call = Calls[LastCallBySource[source]]
    if not call or call.source ~= source or call.status == 'resolved' then return notify(source, 'You do not have an active call.', 'error') end
    text = sanitizeText(text, Config.CallSettings.maxChatMessageLength)
    if text == '' then return notify(source, ('Use /%s followed by your message.'):format(Config.Commands.replyToCall), 'error') end
    local author = call.anonymous and Config.CallSettings.anonymousLabel or (GetPlayerName(source) or 'Caller')
    addConversation(call, 'fromCaller', author, text)
    addTimeline(call, 'caller_reply', author, 'Caller sent an update')
    call.updatedAt = os.time()
    for _, playerId in ipairs(GetPlayers()) do
        local responder = tonumber(playerId)
        if recipientEligible(responder, call) then TriggerClientEvent('simple911:client:notify', responder, ('Caller update on #%s: %s'):format(call.id, text), 'info') end
    end
    syncResponders()
end)

RegisterNetEvent('simple911:server:requestCallStatus', function()
    local source = source
    local call = Calls[LastCallBySource[source]]
    if not call or call.source ~= source then return notify(source, 'You do not have a tracked call.', 'error') end
    local units = #publicUnits(call.assignedUnits)
    notify(source, ('Call #%s | %s | %s | %s unit(s) assigned'):format(call.id, call.code, call.status, units), 'info')
end)

RegisterNetEvent('simple911:server:cancelLastCall', function()
    local source = source
    if not Config.CallSettings.allowCallerCancel then return end
    local call = Calls[LastCallBySource[source]]
    if not call or call.source ~= source or call.status == 'resolved' then return notify(source, 'You do not have an active call to cancel.', 'error') end
    call.status = 'resolved' call.resolvedByName = 'Caller'
    addTimeline(call, 'cancelled', call.callerName, 'Call cancelled by caller')
    notify(source, ('Call #%s cancelled.'):format(call.id), 'success')
    syncResponders()
end)

RegisterNetEvent('simple911:server:panic', function(data)
    local source = source
    if not Config.Panic.enabled or not canReceiveDispatch(source) then return end
    local now = os.time()
    if PanicCooldowns[source] and now - PanicCooldowns[source] < Config.Cooldown.panicSeconds then return end
    PanicCooldowns[source] = now
    local service = getService(Config.Panic.serviceId)
    local template = getTemplate(service, Config.Panic.templateId)
    if not service or not template then return end
    local profile = getUnitProfile(source)
    local location = type(data) == 'table' and data.location or 'Unknown Location'
    local coords = type(data) == 'table' and data.coords or nil
    createAndBroadcastCall(nil, service, template, {
        title = 'Responder Panic / Distress', code = Config.Panic.code, priority = 1, departments = Config.Panic.departments,
        message = ('%s activated an emergency distress signal.'):format(profile.callsign), callerName = profile.callsign,
        location = location, coords = coords, metadata = { responderSource = source, callsign = profile.callsign }
    })
end)

AddEventHandler('playerDropped', function()
    local source = source
    Cooldowns[source] = nil PanicCooldowns[source] = nil OnDuty[source] = nil UnitProfiles[source] = nil
    for _, call in pairs(Calls) do
        if call.assignedUnits and call.assignedUnits[source] then
            call.assignedUnits[source] = nil
            addTimeline(call, 'unit_disconnected', 'System', 'Assigned unit disconnected')
            if next(call.assignedUnits) == nil and call.status ~= 'resolved' then call.status = 'unassigned' end
        end
    end
    syncResponders()
end)

exports('CreateCall', function(data)
    if type(data) ~= 'table' then return false, 'invalid_data' end
    local service = getService(data.serviceId)
    local template = getTemplate(service, data.templateId)
    if not service or not template then return false, 'invalid_type' end
    local call = createAndBroadcastCall(nil, service, template, data)
    return call ~= nil, call and call.id or 'no_units'
end)

exports('CustomAlert', function(data)
    if type(data) ~= 'table' then return false, 'invalid_data' end
    local service = getService(data.serviceId or '911')
    local template = getTemplate(service, data.templateId or 'other')
    if not service or not template then return false, 'invalid_type' end
    local call = createAndBroadcastCall(nil, service, template, {
        title = data.title or data.message or 'Custom Alert', code = data.code or 'ALERT', category = data.category or 'Custom',
        priority = data.priority or 2, departments = data.departments or template.departments, message = data.message or 'Custom dispatch alert',
        callerName = data.callerName or 'System', location = data.location or 'Unknown Location', coords = data.coords,
        blip = data.blip, metadata = data.metadata
    })
    return call ~= nil, call and call.id or 'no_units'
end)
