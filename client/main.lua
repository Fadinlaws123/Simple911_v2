local uiOpen = false
local onDuty = false
local calls = {}
local units = {}
local selfUnit = nil
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

local function publicServices()
    local result = {}
    for _, service in ipairs(Config.Services) do
        local copy = {
            id = service.id,
            label = service.label,
            shortLabel = service.shortLabel,
            command = service.command,
            description = service.description,
            accent = service.accent,
            allowAnonymous = service.allowAnonymous,
            templates = {}
        }
        for _, template in ipairs(service.templates or {}) do
            if not template.hiddenFromCaller then copy.templates[#copy.templates + 1] = template end
        end
        result[#result + 1] = copy
    end
    return result
end

local function openCaller(serviceId)
    local location, coords = getLocationData()
    setFocus(true)
    SendNUIMessage({ action = 'openCaller', serviceId = serviceId, services = publicServices(), location = location, coords = coords, maxMessageLength = Config.CallSettings.maxMessageLength })
end

local function openDispatch()
    setFocus(true)
    SendNUIMessage({
        action = 'openDispatch', calls = calls, units = units, selfUnit = selfUnit, onDuty = onDuty,
        settings = Config.Dispatch, departments = Config.Departments, unitStatuses = Config.UnitStatuses
    })
    if onDuty then TriggerServerEvent('simple911:server:requestDispatch') end
end

local function closeUi()
    setFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function removeCallBlip(callId)
    local item = callBlips[callId]
    if not item then return end
    if item.point and DoesBlipExist(item.point) then RemoveBlip(item.point) end
    if item.radius and DoesBlipExist(item.radius) then RemoveBlip(item.radius) end
    callBlips[callId] = nil
end

local function createCallBlip(call)
    if not call.coords then return end
    local settings = call.blip or {}
    local point = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(point, settings.sprite or Config.Blips.sprite)
    SetBlipColour(point, settings.color or Config.Blips.color)
    SetBlipScale(point, settings.scale or Config.Blips.scale)
    SetBlipAsShortRange(point, settings.shortRange ~= nil and settings.shortRange or Config.Blips.shortRange)
    if (settings.flash == true) or (Config.Blips.flashPriorityOne and call.priority == 1) then SetBlipFlashes(point, true) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('%s | P%s | #%s %s'):format(call.code or call.serviceId, call.priority, call.id, call.title))
    EndTextCommandSetBlipName(point)

    local radius
    if tonumber(settings.radius) and tonumber(settings.radius) > 0 then
        radius = AddBlipForRadius(call.coords.x, call.coords.y, call.coords.z, tonumber(settings.radius) + 0.0)
        SetBlipColour(radius, settings.color or Config.Blips.color)
        SetBlipAlpha(radius, tonumber(settings.radiusAlpha) or 80)
    end

    callBlips[call.id] = { point = point, radius = radius }
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
            if not callBlips[call.id] then createCallBlip(call) end
        end
    end
    for callId in pairs(callBlips) do if not active[callId] then removeCallBlip(callId) end end
end

local function playDispatchSound(call)
    if not Config.Sounds.enabled then return end
    local sound = call.priority == 1 and Config.Sounds.priorityOne or Config.Sounds.normal
    if sound and sound.name and sound.set then PlaySoundFrontend(-1, sound.name, sound.set, true) end
end

for _, service in ipairs(Config.Services) do
    RegisterCommand(service.command, function() openCaller(service.id) end, false)
end

RegisterCommand(Config.Commands.dispatch, function() openDispatch() end, false)
RegisterCommand(Config.Commands.toggleDuty, function() TriggerServerEvent('simple911:server:setDuty', not onDuty) end, false)
RegisterCommand(Config.Commands.cancelLastCall, function() TriggerServerEvent('simple911:server:cancelLastCall') end, false)
RegisterCommand(Config.Commands.replyToCall, function(_, args) TriggerServerEvent('simple911:server:replyToCall', table.concat(args, ' ')) end, false)
RegisterCommand(Config.Commands.callStatus, function() TriggerServerEvent('simple911:server:requestCallStatus') end, false)
RegisterCommand(Config.Commands.panic, function()
    local location, coords = getLocationData()
    TriggerServerEvent('simple911:server:panic', { location = location, coords = coords })
end, false)

RegisterNUICallback('close', function(_, cb) closeUi() cb({ ok = true }) end)
RegisterNUICallback('submitCall', function(data, cb)
    local location, coords = getLocationData()
    TriggerServerEvent('simple911:server:createCall', { serviceId = data.serviceId, templateId = data.templateId, message = data.message, anonymous = data.anonymous == true, location = location, coords = coords })
    closeUi()
    cb({ ok = true })
end)
RegisterNUICallback('dispatchAction', function(data, cb)
    if data.action == 'waypoint' then
        local callId = tonumber(data.callId)
        for _, call in ipairs(calls) do
            if call.id == callId and call.coords then SetNewWaypoint(call.coords.x, call.coords.y) notify(('Waypoint set for call #%s.'):format(call.id), 'success') break end
        end
    else
        TriggerServerEvent('simple911:server:updateCall', data.callId, data.action, data.payload or {})
    end
    cb({ ok = true })
end)
RegisterNUICallback('toggleDuty', function(_, cb) TriggerServerEvent('simple911:server:setDuty', not onDuty) cb({ ok = true }) end)
RegisterNUICallback('setUnitProfile', function(data, cb) TriggerServerEvent('simple911:server:setUnitProfile', data or {}) cb({ ok = true }) end)

RegisterNetEvent('simple911:client:notify', function(message, kind) notify(message, kind) end)
RegisterNetEvent('simple911:client:callerMessage', function(callId, author, text)
    notify(('Call #%s | %s: %s'):format(callId, author, text), 'info')
end)
RegisterNetEvent('simple911:client:dutyChanged', function(state)
    onDuty = state == true
    notify(onDuty and 'You are now on dispatch duty.' or 'You are now off dispatch duty.', onDuty and 'success' or 'info')
    if not onDuty then calls = {} units = {} selfUnit = nil end
    updateBlips()
    SendNUIMessage({ action = 'dutyChanged', onDuty = onDuty })
end)
RegisterNetEvent('simple911:client:syncDispatch', function(serverCalls, serverUnits, serverSelfUnit)
    calls = serverCalls or {}
    units = serverUnits or {}
    selfUnit = serverSelfUnit
    updateBlips()
    SendNUIMessage({ action = 'syncDispatch', calls = calls, units = units, selfUnit = selfUnit })
end)
RegisterNetEvent('simple911:client:newCall', function(call)
    if Config.Notifications.newCall then notify(('%s | Priority %s | #%s %s'):format(call.code or call.serviceId, call.priority, call.id, call.title), 'emergency') end
    playDispatchSound(call)
end)

CreateThread(function()
    while true do
        Wait(0)
        if uiOpen and IsControlJustReleased(0, 322) then closeUi() end
    end
end)

CreateThread(function()
    while true do
        Wait(math.max(5, Config.Dispatch.unitLocationUpdateSeconds) * 1000)
        if onDuty then
            local _, coords = getLocationData()
            TriggerServerEvent('simple911:server:updateUnitLocation', coords)
        end
    end
end)
