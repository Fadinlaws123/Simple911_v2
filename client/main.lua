local Calls = {}
local Blips = {}
local VisibleCards = {}
local OnSceneReported = {}
local Focused = false

local function notify(message, kind)
    SendNUIMessage({ action = 'toast', message = message, kind = kind or 'info' })
end

local function getConfiguredFocusKey()
    return string.upper(tostring(Config.Focus.defaultKey or 'N'))
end

local function hasVisibleCards()
    for callId, visible in pairs(VisibleCards) do
        if visible and Calls[callId] then return true end
    end
    return false
end

local function isAssignedToCall(call)
    local serverId = GetPlayerServerId(PlayerId())
    if call.primaryUnit and tonumber(call.primaryUnit.source) == serverId then return true end
    for _, unit in ipairs(call.attachedUnits or {}) do
        if tonumber(unit.source) == serverId then return true end
    end
    return false
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

local function removeCallBlips(callId)
    local list = Blips[callId]
    if not list then return end
    for _, blip in ipairs(list) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    Blips[callId] = nil
end

local function addCallBlip(call)
    if not Config.Blip.enabled or not call.coords then return end
    removeCallBlips(call.id)

    local created = {}
    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, Config.Blip.shortRange)
    if Config.Blip.flash and call.status == 'new' then SetBlipFlashes(blip, true) end
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
        local current = Calls[call.id]
        if current and current.status == 'new' then removeCallBlips(call.id) end
    end)
end

local function setWaypoint(callId)
    callId = tonumber(callId)
    local call = callId and Calls[callId]
    if not call or not call.coords then
        notify(Config.Messages.invalidCall, 'error')
        return false
    end
    SetNewWaypoint(call.coords.x, call.coords.y)
    notify(Config.Messages.waypointSet:format(call.id), 'success')
    return true
end

local function setFocus(state)
    if state and not hasVisibleCards() then
        Focused = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'setFocusState', focused = false })
        notify(Config.Messages.noVisibleCalls, 'error')
        return false
    end

    Focused = state == true
    SetNuiFocus(Focused, Focused)
    SendNUIMessage({ action = 'setFocusState', focused = Focused })
    return true
end

local function toggleFocus()
    if Focused then
        setFocus(false)
        notify(Config.Messages.focusDisabled, 'info')
        return
    end
    if setFocus(true) then notify(Config.Messages.focusEnabled, 'info') end
end

local function sendCallToUi(action, call, duration)
    SendNUIMessage({
        action = action,
        call = call,
        duration = duration or Config.Notifications.popupDuration,
        showCallerName = Config.CallSettings.showCallerName,
        showCallerServerId = Config.CallSettings.showCallerServerId,
        selfServerId = GetPlayerServerId(PlayerId()),
        focusKey = getConfiguredFocusKey()
    })
end

local function sendResponderChatCall(call)
    if not Config.Notifications.showChatMessage then return end
    TriggerEvent('chat:addMessage', {
        template = Config.Notifications.chatTemplate,
        multiline = true,
        args = {
            tostring(call.id),
            tostring(call.location or 'Unknown Location'),
            tostring(call.message or ''),
            getConfiguredFocusKey(),
            Config.Commands.waypoint
        }
    })
end

RegisterCommand(Config.Commands.focus, function() toggleFocus() end, false)

RegisterCommand('+simple911_interact_card', function() toggleFocus() end, false)
RegisterCommand('-simple911_interact_card', function() end, false)
RegisterKeyMapping('+simple911_interact_card', Config.Focus.helpText, 'keyboard', Config.Focus.defaultKey)

RegisterCommand(Config.Commands.emergency, function(_, args)
    local message = table.concat(args, ' ')
    if message == '' then return notify(Config.Messages.usage, 'error') end

    local location, coords = getLocationData()
    TriggerServerEvent('simple911:server:createCall', { message = message, location = location, coords = coords })
end, false)

RegisterCommand(Config.Commands.calls, function()
    TriggerServerEvent('simple911:server:requestCalls')
end, false)

RegisterCommand(Config.Commands.waypoint, function(_, args)
    if args[1] then return setWaypoint(args[1]) end
    local newest
    for _, call in pairs(Calls) do if not newest or call.id > newest.id then newest = call end end
    if newest then setWaypoint(newest.id) else notify(Config.Messages.noCalls, 'error') end
end, false)

RegisterCommand(Config.Commands.clear, function()
    Calls = {}
    VisibleCards = {}
    OnSceneReported = {}
    for callId in pairs(Blips) do removeCallBlips(callId) end
    setFocus(false)
    SendNUIMessage({ action = 'syncCalls', calls = {} })
    SendNUIMessage({ action = 'clearCards' })
    notify(Config.Messages.callsCleared, 'success')
end, false)

RegisterNetEvent('simple911:client:notify', function(message, kind)
    notify(message, kind)
end)

RegisterNetEvent('simple911:client:receiveCall', function(call)
    Calls[call.id] = call
    VisibleCards[call.id] = true
    OnSceneReported[call.id] = nil
    addCallBlip(call)

    if Config.Sound.enabled then PlaySoundFrontend(-1, Config.Sound.name, Config.Sound.soundSet, true) end
    if Config.Notifications.useNuiPopup then sendCallToUi('newCall', call, Config.Notifications.popupDuration) end
    sendResponderChatCall(call)

    SetTimeout(Config.Notifications.popupDuration, function()
        local current = Calls[call.id]
        if current and current.status == 'new' then
            VisibleCards[call.id] = nil
            if Focused and not hasVisibleCards() then setFocus(false) end
        end
    end)
end)

RegisterNetEvent('simple911:client:updateCall', function(call)
    Calls[call.id] = call
    VisibleCards[call.id] = true

    if call.status == 'enroute' then OnSceneReported[call.id] = nil end
    if call.status == 'onscene' then OnSceneReported[call.id] = true end

    if (call.status == 'enroute' or call.status == 'onscene') and call.coords and not Blips[call.id] then
        addCallBlip(call)
    end

    sendCallToUi('callUpdated', call, Config.Notifications.popupDuration)
end)

RegisterNetEvent('simple911:client:callClosed', function(callId, closedBy)
    callId = tonumber(callId)
    Calls[callId] = nil
    VisibleCards[callId] = nil
    OnSceneReported[callId] = nil
    removeCallBlips(callId)
    SendNUIMessage({ action = 'removeCall', callId = callId })

    if Focused and not hasVisibleCards() then setFocus(false) end
    notify(Config.Messages.callClosedForAll:format(callId, closedBy or 'Primary Unit'), 'success')
end)

RegisterNetEvent('simple911:client:syncCalls', function(serverCalls)
    Calls = {}
    for _, call in ipairs(serverCalls or {}) do Calls[call.id] = call end
    SendNUIMessage({
        action = 'openCalls',
        calls = serverCalls or {},
        showCallerName = Config.CallSettings.showCallerName,
        showCallerServerId = Config.CallSettings.showCallerServerId,
        selfServerId = GetPlayerServerId(PlayerId())
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    Focused = false
    SendNUIMessage({ action = 'setFocusState', focused = false })
    SendNUIMessage({ action = 'closeCalls' })
    cb({ ok = true })
end)

RegisterNUICallback('releaseFocus', function(_, cb)
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('cardHidden', function(data, cb)
    local callId = tonumber(data.callId)
    if callId then VisibleCards[callId] = nil end
    if Focused and not hasVisibleCards() then setFocus(false) end
    cb({ ok = true })
end)

RegisterNUICallback('waypoint', function(data, cb)
    setWaypoint(data.callId)
    cb({ ok = true })
end)

RegisterNUICallback('respondCall', function(data, cb)
    local callId = tonumber(data.callId)
    if not callId or not Calls[callId] then
        notify(Config.Messages.invalidCall, 'error')
        cb({ ok = false })
        return
    end
    setWaypoint(callId)
    TriggerServerEvent('simple911:server:respondToCall', callId)
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('attachCall', function(data, cb)
    local callId = tonumber(data.callId)
    if not callId or not Calls[callId] then
        notify(Config.Messages.invalidCall, 'error')
        cb({ ok = false })
        return
    end
    setWaypoint(callId)
    TriggerServerEvent('simple911:server:respondToCall', callId)
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('detachCall', function(data, cb)
    local callId = tonumber(data.callId)
    if callId then TriggerServerEvent('simple911:server:detachFromCall', callId) end
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('closeCallout', function(data, cb)
    local callId = tonumber(data.callId)
    if not callId or not Calls[callId] then
        notify(Config.Messages.invalidCall, 'error')
        cb({ ok = false })
        return
    end
    TriggerServerEvent('simple911:server:closeCall', callId)
    setFocus(false)
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        Wait(0)
        if Focused and IsControlJustReleased(0, 322) then setFocus(false) end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.OnScene.enabled and Config.OnScene.checkIntervalMs or 5000)

        if Config.OnScene.enabled then
            local playerCoords = GetEntityCoords(PlayerPedId())
            for callId, call in pairs(Calls) do
                if call.status == 'enroute' and call.coords and isAssignedToCall(call) and not OnSceneReported[callId] then
                    local callCoords = vector3(call.coords.x, call.coords.y, call.coords.z)
                    if #(playerCoords - callCoords) <= Config.OnScene.radius then
                        OnSceneReported[callId] = true
                        TriggerServerEvent('simple911:server:markOnScene', callId)
                    end
                end
            end
        end
    end
end)
