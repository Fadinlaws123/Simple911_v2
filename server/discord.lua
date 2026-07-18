local TrackedCalls = {}

local function webhookConfigured()
    return Config.Discord
        and type(Config.Discord.webhook) == 'string'
        and Config.Discord.webhook ~= ''
end

local function discordEnabled()
    return webhookConfigured() and Config.Discord.enabled ~= false
end

local function baseWebhookUrl()
    return (Config.Discord.webhook or ''):gsub('%?.*$', '')
end

local function webhookCreateUrl()
    return baseWebhookUrl() .. '?wait=true'
end

local function log(message)
    print(('[Simple911 Discord] %s'):format(message))
end

local function statusMeta(status, closedBy)
    if closedBy then return 'CLOSED', 9807270, '🔒', 'Incident Closed' end
    if status == 'onscene' then return 'ON SCENE', 5763719, '🟢', 'Units On Scene' end
    if status == 'enroute' then return 'EN ROUTE', 3447003, '🔵', 'Response In Progress' end
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

    local maximum = (Config.Discord and Config.Discord.maxActivityEntries) or 8
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

    return {
        author = { name = 'Simple911 • Live Emergency Incident' },
        title = ('%s %s • Call #%s'):format(statusIcon, statusLabel, call.id),
        description = table.concat({
            ('### %s'):format(statusTitle),
            '',
            ('> **%s**'):format(details),
            '',
            ('**📍 Location**\n%s'):format(location)
        }, '\n'),
        color = color,
        fields = {
            { name = '👤 Caller', value = ('**%s**\n`Server ID: %s`'):format(caller, callerId), inline = true },
            { name = '🕒 Received', value = formatTimestamp(call.createdAt), inline = true },
            { name = '📡 Current Status', value = ('**%s**'):format(statusLabel), inline = true },
            { name = '🚓 Primary Unit', value = ('**%s**'):format(primary), inline = true },
            { name = '👥 Attached', value = ('**%s unit(s)**'):format(attachedCount), inline = true },
            { name = '🧭 Response Overview', value = responseSummary(call, closedBy), inline = true },
            { name = '👮 Responding Units', value = attachedNames(call), inline = false },
            { name = '📜 Activity Timeline', value = activityText(activity), inline = false }
        },
        footer = {
            text = closedBy
                and ('Simple911 • Call #%s • Closed'):format(call.id)
                or ('Simple911 • Call #%s • Live record updates automatically'):format(call.id)
        },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }
end

local function request(url, method, payload, callback)
    PerformHttpRequest(url, function(statusCode, body, headers)
        log(('%s request returned HTTP %s'):format(method, tostring(statusCode)))

        if statusCode < 200 or statusCode >= 300 then
            log(('Discord response: %s'):format(body or '<empty response>'))
        end

        if callback then callback(statusCode, body, headers) end
    end, method, json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function unitMap(units)
    local map = {}
    for _, unit in ipairs(units or {}) do
        map[tostring(unit.source)] = unit.name
    end
    return map
end

local function addActivity(tracked, icon, text)
    tracked.activity[#tracked.activity + 1] = ('%s <t:%s:T> • %s'):format(icon or '•', os.time(), text)
end

local function snapshot(call)
    return {
        data = call,
        status = call.status,
        primarySource = call.primaryUnit and tostring(call.primaryUnit.source) or nil,
        primaryName = call.primaryUnit and call.primaryUnit.name or nil,
        attached = unitMap(call.attachedUnits),
        messageId = nil,
        creating = false,
        pendingEdit = false,
        pendingCloseBy = nil,
        activity = { ('📞 <t:%s:T> • 911 call received'):format(call.createdAt or os.time()) }
    }
end

local function processChanges(tracked, call)
    local oldPrimarySource = tracked.primarySource
    local currentPrimarySource = call.primaryUnit and tostring(call.primaryUnit.source) or nil
    local currentPrimaryName = call.primaryUnit and call.primaryUnit.name or nil
    local currentAttached = unitMap(call.attachedUnits)

    if oldPrimarySource ~= currentPrimarySource then
        if oldPrimarySource and currentPrimarySource then
            addActivity(tracked, '🔄', ('Primary Unit transferred to %s'):format(currentPrimaryName or 'Unknown Unit'))
        elseif currentPrimarySource then
            addActivity(tracked, '🚓', ('%s became the Primary Unit'):format(currentPrimaryName or 'Unknown Unit'))
        else
            addActivity(tracked, '⚪', 'Primary Unit assignment was cleared')
        end
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

local function editLiveMessage(tracked, call, closedBy)
    if not tracked.messageId then
        tracked.pendingEdit = true
        tracked.pendingCloseBy = closedBy or tracked.pendingCloseBy
        tracked.data = call
        return
    end

    request(('%s/messages/%s'):format(baseWebhookUrl(), tracked.messageId), 'PATCH', {
        username = Config.Discord.username or 'Simple911',
        avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil,
        embeds = { mainEmbed(call, tracked.activity, closedBy) }
    })
end

local function createLiveMessage(call, tracked)
    if tracked.creating or tracked.messageId then return end

    if not discordEnabled() then
        log(('Call #%s was not logged because Discord logging is disabled or no webhook is configured.'):format(call.id))
        return
    end

    tracked.creating = true
    log(('Creating Discord log for call #%s...'):format(call.id))

    request(webhookCreateUrl(), 'POST', {
        username = Config.Discord.username or 'Simple911',
        avatar_url = Config.Discord.avatarUrl ~= '' and Config.Discord.avatarUrl or nil,
        embeds = { mainEmbed(call, tracked.activity) }
    }, function(statusCode, body)
        tracked.creating = false

        if statusCode >= 200 and statusCode < 300 and body and body ~= '' then
            local ok, decoded = pcall(json.decode, body)
            if ok and decoded and decoded.id then
                tracked.messageId = decoded.id
                log(('Created Discord log for call #%s as message %s.'):format(call.id, decoded.id))

                if tracked.pendingEdit then
                    tracked.pendingEdit = false
                    local closeBy = tracked.pendingCloseBy
                    tracked.pendingCloseBy = nil
                    editLiveMessage(tracked, tracked.data, closeBy)
                end
                return
            end
        end

        log(('Failed to create Discord log for call #%s. HTTP %s. Body: %s'):format(call.id, tostring(statusCode), body or '<empty>'))
    end)
end

AddEventHandler('simple911:discord:createCall', function(call)
    log(('Received create event for call #%s.'):format(call and call.id or '?'))
    if not discordEnabled() or type(call) ~= 'table' or not call.id then return end

    local tracked = snapshot(call)
    TrackedCalls[call.id] = tracked
    createLiveMessage(call, tracked)
end)

AddEventHandler('simple911:discord:updateCall', function(call)
    if not discordEnabled() or type(call) ~= 'table' or not call.id then return end

    local tracked = TrackedCalls[call.id]
    if not tracked then
        tracked = snapshot(call)
        TrackedCalls[call.id] = tracked
        createLiveMessage(call, tracked)
        return
    end

    processChanges(tracked, call)
    editLiveMessage(tracked, call)
end)

AddEventHandler('simple911:discord:closeCall', function(call, closedBy)
    if not discordEnabled() or type(call) ~= 'table' or not call.id then return end

    local tracked = TrackedCalls[call.id]
    if not tracked then
        tracked = snapshot(call)
        TrackedCalls[call.id] = tracked
        createLiveMessage(call, tracked)
    end

    processChanges(tracked, call)
    addActivity(tracked, '🔒', ('Incident closed by %s'):format(closedBy or 'System'))
    editLiveMessage(tracked, call, closedBy or 'System')

    SetTimeout(10000, function()
        TrackedCalls[call.id] = nil
    end)
end)

RegisterCommand('911discordtest', function(source)
    if source ~= 0 then
        log('The 911discordtest command can only be run from the server console.')
        return
    end

    if not discordEnabled() then
        log('Discord test aborted: logging is disabled or no webhook is configured.')
        return
    end

    local now = os.time()
    local testCall = {
        id = 9999,
        callerName = 'Simple911 Test',
        callerId = 0,
        message = 'This is a Simple911 Discord webhook test.',
        location = 'Webhook Diagnostics',
        createdAt = now,
        status = 'new',
        primaryUnit = nil,
        attachedUnits = {},
        onSceneBy = nil
    }

    local tracked = snapshot(testCall)
    createLiveMessage(testCall, tracked)
end, true)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    log('discord.lua loaded successfully.')

    if not Config.Discord then
        log('WARNING: Config.Discord does not exist.')
        return
    end

    if not webhookConfigured() then
        log('WARNING: No Discord webhook is configured.')
        return
    end

    if Config.Discord.enabled == false then
        log('WARNING: Discord logging is explicitly disabled in config.lua.')
        return
    end

    log('Discord logging is enabled and a webhook is configured.')
end)
