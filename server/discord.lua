local TrackedCalls = {}

local function discordEnabled()
    return Config.Discord and Config.Discord.enabled and type(Config.Discord.webhook) == 'string' and Config.Discord.webhook ~= ''
end

local function auditWebhook()
    if Config.Discord.auditWebhook and Config.Discord.auditWebhook ~= '' then
        return Config.Discord.auditWebhook
    end
    return Config.Discord.webhook
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

local function mainEmbed(call, closedBy)
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
        { name = 'Attached Units', value = attachedNames(call), inline = true }
    }

    if call.status == 'onscene' and call.onSceneBy then
        fields[#fields + 1] = { name = 'On Scene Confirmed By', value = call.onSceneBy.name or 'Unknown Unit', inline = true }
    end

    if closedBy then
        fields[#fields + 1] = { name = 'Closed By', value = closedBy, inline = true }
    end

    return {
        title = ('🚨 911 Call #%s'):format(call.id),
        description = closedBy and 'This emergency call has been closed.' or 'Live emergency call status. This message updates as responders handle the call.',
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

local function createLiveMessage(call, callback)
    local payload = {
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil,
        embeds = { mainEmbed(call) }
    }

    request(webhookUrl(Config.Discord.webhook, true), 'POST', payload, function(statusCode, body)
        if statusCode >= 200 and statusCode < 300 and body and body ~= '' then
            local ok, decoded = pcall(json.decode, body)
            if ok and decoded and decoded.id then callback(decoded.id) end
        end
    end)
end

local function editLiveMessage(messageId, call, closedBy)
    if not messageId then return end
    local payload = {
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil,
        embeds = { mainEmbed(call, closedBy) }
    }
    request(('%s/messages/%s'):format(Config.Discord.webhook, messageId), 'PATCH', payload)
end

local function sendAudit(title, description, color)
    if not Config.Discord.logActions then return end
    local webhook = auditWebhook()
    if not webhook or webhook == '' then return end

    request(webhook, 'POST', {
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil,
        embeds = {{
            title = title,
            description = description,
            color = color or 3447003,
            footer = { text = 'Simple911 • Action Log' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    })
end

local function unitMap(units)
    local map = {}
    for _, unit in ipairs(units or {}) do
        map[tostring(unit.source)] = unit.name
    end
    return map
end

local function snapshot(call)
    return {
        data = call,
        status = call.status,
        primarySource = call.primaryUnit and tostring(call.primaryUnit.source) or nil,
        primaryName = call.primaryUnit and call.primaryUnit.name or nil,
        attached = unitMap(call.attachedUnits),
        messageId = nil
    }
end

local function processChanges(previous, call)
    local callId = call.id
    local currentPrimarySource = call.primaryUnit and tostring(call.primaryUnit.source) or nil
    local currentPrimaryName = call.primaryUnit and call.primaryUnit.name or nil
    local currentAttached = unitMap(call.attachedUnits)

    if previous.primarySource ~= currentPrimarySource and currentPrimarySource then
        sendAudit(
            ('🚓 Primary Unit Assigned • Call #%s'):format(callId),
            ('**%s** is now the primary unit.\n**Location:** %s'):format(currentPrimaryName or 'Unknown Unit', call.location or 'Unknown Location'),
            3447003
        )
    end

    for source, name in pairs(currentAttached) do
        if not previous.attached[source] then
            sendAudit(
                ('➕ Unit Attached • Call #%s'):format(callId),
                ('**%s** attached to the call.\n**Primary:** %s'):format(name, currentPrimaryName or 'Unassigned'),
                10181046
            )
        end
    end

    for source, name in pairs(previous.attached) do
        if not currentAttached[source] then
            sendAudit(
                ('➖ Unit Detached • Call #%s'):format(callId),
                ('**%s** detached from the call.'):format(name),
                9807270
            )
        end
    end

    if previous.status ~= call.status and call.status == 'onscene' then
        sendAudit(
            ('✅ Units On Scene • Call #%s'):format(callId),
            ('**Confirmed by:** %s\n**Location:** %s'):format(call.onSceneBy and call.onSceneBy.name or currentPrimaryName or 'Unknown Unit', call.location or 'Unknown Location'),
            5763719
        )
    end
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
                    createLiveMessage(call, function(messageId)
                        if TrackedCalls[call.id] then
                            TrackedCalls[call.id].messageId = messageId
                        end
                    end)
                else
                    processChanges(tracked, call)
                    editLiveMessage(tracked.messageId, call)
                    tracked.data = call
                    tracked.status = call.status
                    tracked.primarySource = call.primaryUnit and tostring(call.primaryUnit.source) or nil
                    tracked.primaryName = call.primaryUnit and call.primaryUnit.name or nil
                    tracked.attached = unitMap(call.attachedUnits)
                end
            end

            for callId, tracked in pairs(TrackedCalls) do
                if not seen[callId] then
                    local closedBy = tracked.primaryName or 'System / Expired'
                    editLiveMessage(tracked.messageId, tracked.data, closedBy)
                    sendAudit(
                        ('🔒 Call Closed • Call #%s'):format(callId),
                        ('**Closed by:** %s\n**Location:** %s'):format(closedBy, tracked.data.location or 'Unknown Location'),
                        9807270
                    )
                    TrackedCalls[callId] = nil
                end
            end
        end
    end
end)
