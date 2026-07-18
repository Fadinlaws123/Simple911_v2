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

local function statusMeta(status, closedBy)
    if closedBy then
        return 'CLOSED', 9807270, '🔒', 'Incident Closed'
    elseif status == 'onscene' then
        return 'ON SCENE', 5763719, '🟢', 'Units On Scene'
    elseif status == 'enroute' then
        return 'EN ROUTE', 3447003, '🔵', 'Response In Progress'
    end
    return 'AWAITING UNIT', 15158332, '🔴', 'Awaiting Response'
end

local function formatTimestamp(timestamp)
    if not timestamp then return 'Unknown' end
    return ('<t:%s:F>\n<t:%s:R>'):format(timestamp, timestamp)
end

local function attachedNames(call)
    local units = call.attachedUnits or {}
    if #units == 0 then return '`None`' end

    local names = {}
    for _, unit in ipairs(units) do
        names[#names + 1] = ('• **%s**'):format(unit.name or ('ID %s'):format(unit.source or '?'))
    end
    return table.concat(names, '\n')
end

local function activityText(activity)
    if not activity or #activity == 0 then return '> No activity recorded yet.' end

    local maximum = Config.Discord.maxActivityEntries or 8
    local first = math.max(1, #activity - maximum + 1)
    local lines = {}
    for index = first, #activity do
        lines[#lines + 1] = activity[index]
    end

    if first > 1 then
        table.insert(lines, 1, ('*%s earlier event(s) hidden*'):format(first - 1))
    end

    return table.concat(lines, '\n')
end

local function responseSummary(call, closedBy)
    local primary = call.primaryUnit and call.primaryUnit.name or 'Unassigned'
    local attachedCount = #(call.attachedUnits or {})

    local lines = {
        ('**Primary Unit**\n%s'):format(primary),
        '',
        ('**Attached Units**\n%s'):format(attachedCount)
    }

    if call.onSceneBy then
        lines[#lines + 1] = ''
        lines[#lines + 1] = ('**On Scene Confirmed By**\n%s'):format(call.onSceneBy.name or 'Unknown Unit')
    end

    if closedBy then
        lines[#lines + 1] = ''
        lines[#lines + 1] = ('**Closed By**\n%s'):format(closedBy)
    end

    return table.concat(lines, '\n')
end

local function mainEmbed(call, activity, closedBy)
    local statusLabel, color, statusIcon, statusTitle = statusMeta(call.status, closedBy)
    local caller = call.callerName or 'Unknown Caller'
    local callerId = call.callerId and tostring(call.callerId) or 'N/A'
    local location = call.location or 'Unknown Location'
    local details = call.message or 'No details provided.'
    local primary = call.primaryUnit and call.primaryUnit.name or 'Unassigned'
    local attachedCount = #(call.attachedUnits or {})

    local description = table.concat({
        ('## %s 911 CALL #%s'):format(statusIcon, call.id),
        ('### %s'):format(statusTitle),
        '',
        ('> **%s**'):format(details),
        '',
        ('**📍 Location**\n%s'):format(location)
    }, '\n')

    local fields = {
        {
            name = '👤 Caller',
            value = ('**%s**\n`Server ID: %s`'):format(caller, callerId),
            inline = true
        },
        {
            name = '🕒 Received',
            value = formatTimestamp(call.createdAt),
            inline = true
        },
        {
            name = '📡 Current Status',
            value = ('**%s**'):format(statusLabel),
            inline = true
        },
        {
            name = '🚓 Primary Unit',
            value = ('**%s**'):format(primary),
            inline = true
        },
        {
            name = '👥 Attached',
            value = ('**%s unit(s)**'):format(attachedCount),
            inline = true
        },
        {
            name = '🧭 Response Overview',
            value = responseSummary(call, closedBy),
            inline = true
        },
        {
            name = '👮 Responding Units',
            value = attachedNames(call),
            inline = false
        },
        {
            name = '📜 Activity Timeline',
            value = activityText(activity),
            inline = false
        }
    }

    return {
        author = {
            name = 'Simple911 • Live Emergency Incident'
        },
        title = ('%s %s'):format(statusIcon, statusLabel),
        description = description,
        color = color,
        fields = fields,
        footer = {
            text = closedBy
                and ('Simple911 • Call #%s • Closed'):format(call.id)
                or ('Simple911 • Call #%s • Live record updates automatically'):format(call.id)
        },
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

local function activityTime()
    return os.time()
end

local function addActivity(tracked, icon, text)
    local timestamp = activityTime()
    tracked.activity[#tracked.activity + 1] = ('%s <t:%s:T> • %s'):format(icon or '•', timestamp, text)
end

local function snapshot(call)
    return {
        data = call,
        status = call.status,
        primarySource = call.primaryUnit and tostring(call.primaryUnit.source) or nil,
        primaryName = call.primaryUnit and call.primaryUnit.name or nil,
        attached = unitMap(call.attachedUnits),
        messageId = nil,
        activity = { ('📞 <t:%s:T> • 911 call received'):format(call.createdAt or os.time()) }
    }
end

local function processChanges(tracked, call)
    local currentPrimarySource = call.primaryUnit and tostring(call.primaryUnit.source) or nil
    local currentPrimaryName = call.primaryUnit and call.primaryUnit.name or nil
    local currentAttached = unitMap(call.attachedUnits)

    if tracked.primarySource ~= currentPrimarySource and currentPrimarySource then
        addActivity(tracked, '🚓', ('%s became the Primary Unit'):format(currentPrimaryName or 'Unknown Unit'))
    elseif tracked.primarySource and not currentPrimarySource then
        addActivity(tracked, '⚪', 'Primary Unit assignment was cleared')
    elseif tracked.primarySource and currentPrimarySource and tracked.primarySource ~= currentPrimarySource then
        addActivity(tracked, '🔄', ('Primary Unit transferred to %s'):format(currentPrimaryName or 'Unknown Unit'))
    end

    for source, name in pairs(currentAttached) do
        if not tracked.attached[source] then
            addActivity(tracked, '➕', ('%s attached to the incident'):format(name))
        end
    end

    for source, name in pairs(tracked.attached) do
        if not currentAttached[source] then
            addActivity(tracked, '➖', ('%s detached from the incident'):format(name))
        end
    end

    if tracked.status ~= call.status then
        if call.status == 'enroute' then
            addActivity(tracked, '🔵', 'Response status changed to En Route')
        elseif call.status == 'onscene' then
            addActivity(tracked, '🟢', ('%s confirmed units On Scene'):format(call.onSceneBy and call.onSceneBy.name or currentPrimaryName or 'A responder'))
        end
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
                    addActivity(tracked, '🔒', ('Incident closed by %s'):format(closedBy))
                    editLiveMessage(tracked, tracked.data, closedBy)
                    TrackedCalls[callId] = nil
                end
            end
        end
    end
end)
