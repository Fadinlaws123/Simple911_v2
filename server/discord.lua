local TrackedCalls = {}

local function discordEnabled()
    return Config.Discord and Config.Discord.enabled and type(Config.Discord.webhook) == 'string' and Config.Discord.webhook ~= ''
end

local function webhookUrl(base, wait)
    if wait then
        return base .. (base:find('?', 1, true) and '&wait=true' or '?wait=true')
    end
    return base
end

local function statusMeta(status)
    if status == 'onscene' then
        return 'ON SCENE', 5763719
    elseif status == 'enroute' then
        return 'EN ROUTE', 3447003
    end
    return 'AWAITING UNIT', 15158332
end

local function attachedNames(call)
    local names = {}
    for _, unit in ipairs(call.attachedUnits or {}) do
        names[#names + 1] = unit.name or ('ID %s'):format(unit.source or '?')
    end
    return #names > 0 and table.concat(names, '\n') or 'None'
end

local function activityText(activity)
    if not activity or #activity == 0 then return '• Call created' end

    local first = math.max(1, #activity - ((Config.Discord.maxActivityEntries or 8) - 1))
    local lines = {}
    for index = first, #activity do
        lines[#lines + 1] = activity[index]
    end
    return table.concat(lines, '\n')
end

local function mainEmbed(call, activity, closedBy)
    local statusLabel, color = statusMeta(call.status)
    if closedBy then
        statusLabel = 'CLOSED'
        color = 9807270
    end

    local fields = {
        { name = 'Status', value = ('**%s**'):format(statusLabel), inline = true },
        { name = 'Location', value = call.location or 'Unknown Location', inline = true },
        { name = 'Caller', value = call.callerName or 'Unknown Caller', inline = true },
        { name = 'Call Details', value = call.message or 'No details provided.', inline = false },
        { name = 'Primary Unit', value = call.primaryUnit and call.primaryUnit.name or 'Unassigned', inline = true },
        { name = 'Attached Units', value = attachedNames(call), inline = true },
        { name = 'Activity', value = activityText(activity), inline = false }
    }

    if call.status == 'onscene' and call.onSceneBy then
        fields[#fields + 1] = { name = 'On Scene Confirmed By', value = call.onSceneBy.name or 'Unknown Unit', inline = true }
    end

    if closedBy then
        fields[#fields + 1] = { name = 'Closed By', value = closedBy, inline = true }
    end

    return {
        title = ('🚨 911 Call #%s'):format(call.id),
        description = closedBy and 'This emergency call has been closed.' or 'Live emergency call record. This embed updates as responders handle the call.',
        color = color,
        fields = fields,
        footer = { text = 'Simple911 • Live Call Record' },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }
end

local function request(url, method, payload, callback)
    PerformHttpRequest(url, function(statusCode, body)
        if callback then callback(statusCode, body) end
    end, method, json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function createLiveMessage(call, tracked)
    request(webhookUrl(Config.Discord.webhook, true), 'POST', {
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil,
        embeds = { mainEmbed(call, tracked.activity) }
    }, function(statusCode, body)
        if statusCode >= 200 and statusCode < 300 and body and body ~= '' then
            local ok, decoded = pcall(json.decode, body)
            if ok and decoded and decoded.id and TrackedCalls[call.id] then
                TrackedCalls[call.id].messageId = decoded.id
            end
        end
    end)
end

local function editLiveMessage(tracked, call, closedBy)
    if not tracked.messageId then return end

    request(('%s/messages/%s'):format(Config.Discord.webhook, tracked.messageId), 'PATCH', {
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil,
        embeds = { mainEmbed(call, tracked.activity, closedBy) }
    })
end

local function unitMap(units)
    local map = {}
    for _, unit in ipairs(units or {}) do
        map[tostring(unit.source)] = unit.name
    end
    return map
end

local function addActivity(tracked, text)
    tracked.activity[#tracked.activity + 1] = ('• %s'):format(text)
end

local function snapshot(call)
    return {
        data = call,
        status = call.status,
        primarySource = call.primaryUnit and tostring(call.primaryUnit.source) or nil,
        primaryName = call.primaryUnit and call.primaryUnit.name or nil,
        attached = unitMap(call.attachedUnits),
        messageId = nil,
        activity = { '• Call created' }
    }
end

local function processChanges(tracked, call)
    local currentPrimarySource = call.primaryUnit and tostring(call.primaryUnit.source) or nil
    local currentPrimaryName = call.primaryUnit and call.primaryUnit.name or nil
    local currentAttached = unitMap(call.attachedUnits)

    if tracked.primarySource ~= currentPrimarySource and currentPrimarySource then
        addActivity(tracked, ('%s became the Primary Unit'):format(currentPrimaryName or 'Unknown Unit'))
    elseif tracked.primarySource and not currentPrimarySource then
        addActivity(tracked, 'Primary Unit cleared')
    end

    for source, name in pairs(currentAttached) do
        if not tracked.attached[source] then
            addActivity(tracked, ('%s attached to the call'):format(name))
        end
    end

    for source, name in pairs(tracked.attached) do
        if not currentAttached[source] then
            addActivity(tracked, ('%s detached from the call'):format(name))
        end
    end

    if tracked.status ~= call.status and call.status == 'onscene' then
        addActivity(tracked, ('%s arrived On Scene'):format(call.onSceneBy and call.onSceneBy.name or currentPrimaryName or 'A responder'))
    end

    tracked.data = call
    tracked.status = call.status
    tracked.primarySource = currentPrimarySource
    tracked.primaryName = currentPrimaryName
    tracked.attached = currentAttached
end

CreateThread(function()
    while true do
        Wait((Config.Discord and Config.Discord.syncIntervalMs) or 1000)

        if not discordEnabled() then
            TrackedCalls = {}
        else
            local currentCalls = exports[GetCurrentResourceName()]:GetActiveCalls() or {}
            local seen = {}

            for _, call in ipairs(currentCalls) do
                seen[call.id] = true
                local tracked = TrackedCalls[call.id]

                if not tracked then
                    tracked = snapshot(call)
                    TrackedCalls[call.id] = tracked
                    createLiveMessage(call, tracked)
                else
                    processChanges(tracked, call)
                    editLiveMessage(tracked, call)
                end
            end

            for callId, tracked in pairs(TrackedCalls) do
                if not seen[callId] then
                    local closedBy = tracked.primaryName or 'System / Expired'
                    addActivity(tracked, ('Call closed by %s'):format(closedBy))
                    editLiveMessage(tracked, tracked.data, closedBy)
                    TrackedCalls[callId] = nil
                end
            end
        end
    end
end)
