local uiOpen = false
local onDuty = false
local calls = {}
local units = {}
local callBlips = {}

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

local function setFocus(state)
    uiOpen = state
    SetNuiFocus(state, state)
end

local function openCaller(serviceId)
    local location, coords = getLocationData()
    setFocus(true)
    SendNUIMessage({
        action = 'openCaller',
        serviceId = serviceId,
        services = Config.Services,
        location = location,
        coords = coords,
        maxMessageLength = Config.CallSettings.maxMessageLength
    })
end

local function openDispatch()
    setFocus(true)
    SendNUIMessage({ action = 'openDispatch', calls = calls, units = units, onDuty = onDuty, settings = Config.Dispatch })
    if onDuty then TriggerServerEvent('simple911:server:requestDispatch') end
end

local function closeUi()
    setFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function removeCallBlip(callId)
    local blip = callBlips[callId]
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    callBlips[callId] = nil
end

local function updateBlips()
    if not Config.Blips.enabled or not onDuty then
        for callId in pairs(callBlips) do removeCallBlip(callId) end
        return
    end

    local active = {}
    for _, call in ipairs(calls) do
        if call.status ~= 'resolved' and call.coords then
            active[call.id] = true
            if not callBlips[call.id] or not DoesBlipExist(callBlips[call.id]) then
                local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
                SetBlipSprite(blip, Config.Blips.sprite)
                SetBlipColour(blip, Config.Blips.color)
                SetBlipScale(blip, Config.Blips.scale)
                SetBlipAsShortRange(blip, Config.Blips.shortRange)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(('P%s | #%s %s'):format(call.priority, call.id, call.title))
                EndTextCommandSetBlipName(blip)
                callBlips[call.id] = blip
            end
        end
    end

    for callId in pairs(callBlips) do
        if not active[callId] then removeCallBlip(callId) end
    end
end

for _, service in ipairs(Config.Services) do
    RegisterCommand(service.command, function() openCaller(service.id) end, false)
end

RegisterCommand(Config.Commands.dispatch, function() openDispatch() end, false)
RegisterCommand(Config.Commands.toggleDuty, function() TriggerServerEvent('simple911:server:setDuty', not onDuty) end, false)
RegisterCommand(Config.Commands.cancelLastCall, function() TriggerServerEvent('simple911:server:cancelLastCall') end, false)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('submitCall', function(data, cb)
    local location, coords = getLocationData()
    TriggerServerEvent('simple911:server:createCall', {
        serviceId = data.serviceId,
        templateId = data.templateId,
        message = data.message,
        anonymous = data.anonymous == true,
        location = location,
        coords = coords
    })
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('dispatchAction', function(data, cb)
    if data.action == 'waypoint' then
        local callId = tonumber(data.callId)
        for _, call in ipairs(calls) do
            if call.id == callId and call.coords then
                SetNewWaypoint(call.coords.x, call.coords.y)
                notify(('Waypoint set for call #%s.'):format(call.id), 'success')
                break
            end
        end
    else
        TriggerServerEvent('simple911:server:updateCall', data.callId, data.action, data.payload or {})
    end
    cb({ ok = true })
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    TriggerServerEvent('simple911:server:setDuty', not onDuty)
    cb({ ok = true })
end)

RegisterNUICallback('setCallsign', function(data, cb)
    TriggerServerEvent('simple911:server:setCallsign', data.callsign)
    cb({ ok = true })
end)

RegisterNetEvent('simple911:client:notify', function(message, kind)
    notify(message, kind)
end)

RegisterNetEvent('simple911:client:dutyChanged', function(state)
    onDuty = state == true
    notify(onDuty and 'You are now on dispatch duty.' or 'You are now off dispatch duty.', onDuty and 'success' or 'info')
    if not onDuty then calls = {} units = {} end
    updateBlips()
    SendNUIMessage({ action = 'dutyChanged', onDuty = onDuty })
end)

RegisterNetEvent('simple911:client:syncDispatch', function(serverCalls, serverUnits)
    calls = serverCalls or {}
    units = serverUnits or {}
    updateBlips()
    SendNUIMessage({ action = 'syncDispatch', calls = calls, units = units })
end)

RegisterNetEvent('simple911:client:newCall', function(call)
    if Config.Notifications.newCall then
        notify(('Priority %s | New %s call #%s: %s'):format(call.priority, call.serviceId, call.id, call.title), 'emergency')
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if uiOpen and IsControlJustReleased(0, 322) then closeUi() end
    end
end)
