local Calls = {}
local Blips = {}

local function notify(message, kind)
    SendNUIMessage({ action = 'toast', message = message, kind = kind or 'info' })
end

local function getLocationData()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local crossing = crossingHash and crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or ''
    local location = street ~= '' and street or 'Unknown Location'
    if crossing ~= '' then location = ('%s / %s'):format(location, crossing) end
    return location, { x = coords.x, y = coords.y, z = coords.z }
end

local function addCallBlip(call)
    if not Config.Blip.enabled or not call.coords then return end

    if Blips[call.id] then
        for _, blip in ipairs(Blips[call.id]) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
    end

    local created = {}
    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, Config.Blip.shortRange)
    if Config.Blip.flash then SetBlipFlashes(blip, true) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('911 Call #%s'):format(call.id))
    EndTextCommandSetBlipName(blip)
    created[#created + 1] = blip

    if Config.Blip.radius.enabled then
        local radius = AddBlipForRadius(call.coords.x, call.coords.y, call.coords.z, Config.Blip.radius.size)
        SetBlipColour(radius, Config.Blip.radius.color)
        SetBlipAlpha(radius, Config.Blip.radius.alpha)
        created[#created + 1] = radius
    end

    Blips[call.id] = created

    SetTimeout(Config.Blip.durationSeconds * 1000, function()
        if Blips[call.id] then
            for _, current in ipairs(Blips[call.id]) do
                if DoesBlipExist(current) then RemoveBlip(current) end
            end
            Blips[call.id] = nil
        end
    end)
end

local function setWaypoint(callId)
    callId = tonumber(callId)
    local call = callId and Calls[callId]
    if not call or not call.coords then
        notify(Config.Messages.invalidCall, 'error')
        return
    end

    SetNewWaypoint(call.coords.x, call.coords.y)
    notify(Config.Messages.waypointSet:format(call.id), 'success')
end

RegisterCommand(Config.Commands.emergency, function(_, args)
    local message = table.concat(args, ' ')
    if message == '' then
        notify(Config.Messages.usage, 'error')
        return
    end

    local location, coords = getLocationData()
    TriggerServerEvent('simple911:server:createCall', {
        message = message,
        location = location,
        coords = coords
    })
end, false)

RegisterCommand(Config.Commands.calls, function()
    TriggerServerEvent('simple911:server:requestCalls')
end, false)

RegisterCommand(Config.Commands.waypoint, function(_, args)
    if args[1] then
        setWaypoint(args[1])
        return
    end

    local newest
    for _, call in pairs(Calls) do
        if not newest or call.id > newest.id then newest = call end
    end

    if newest then setWaypoint(newest.id) else notify(Config.Messages.noCalls, 'error') end
end, false)

RegisterCommand(Config.Commands.clear, function()
    Calls = {}
    for callId, list in pairs(Blips) do
        for _, blip in ipairs(list) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        Blips[callId] = nil
    end
    SendNUIMessage({ action = 'syncCalls', calls = {} })
    notify(Config.Messages.callsCleared, 'success')
end, false)

RegisterNetEvent('simple911:client:notify', function(message, kind)
    notify(message, kind)
end)

RegisterNetEvent('simple911:client:receiveCall', function(call)
    Calls[call.id] = call
    addCallBlip(call)

    if Config.Sound.enabled then
        PlaySoundFrontend(-1, Config.Sound.name, Config.Sound.soundSet, true)
    end

    if Config.Notifications.useNuiPopup then
        SendNUIMessage({
            action = 'newCall',
            call = call,
            duration = Config.Notifications.popupDuration,
            showCallerName = Config.CallSettings.showCallerName,
            showCallerServerId = Config.CallSettings.showCallerServerId
        })
    end

    if Config.Notifications.showChatMessage then
        TriggerEvent('chat:addMessage', {
            color = { 255, 70, 70 },
            multiline = true,
            args = { ('911 #%s'):format(call.id), ('%s | %s'):format(call.location, call.message) }
        })
    end
end)

RegisterNetEvent('simple911:client:syncCalls', function(serverCalls)
    Calls = {}
    for _, call in ipairs(serverCalls or {}) do Calls[call.id] = call end
    SendNUIMessage({
        action = 'openCalls',
        calls = serverCalls or {},
        showCallerName = Config.CallSettings.showCallerName,
        showCallerServerId = Config.CallSettings.showCallerServerId
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCalls' })
    cb({ ok = true })
end)

RegisterNUICallback('waypoint', function(data, cb)
    setWaypoint(data.callId)
    cb({ ok = true })
end)
