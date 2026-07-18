Config = {}

Config.Debug = false

Config.Commands = {
    emergency = '911',
    calls = '911calls',
    waypoint = '911wp',
    clear = '911clear',
    focus = 'simple911focus'
}

Config.Focus = {
    defaultKey = 'N',
    helpText = 'Focus active 911 call notifications'
}

Config.Access = {
    acePermission = 'simple911.responder',
    allowEveryoneWhenDebug = true
}

Config.CallSettings = {
    cooldownSeconds = 20,
    maxMessageLength = 500,
    historyLimit = 25,
    activeCallSeconds = 300,
    showCallerName = true,
    showCallerServerId = false
}

Config.OnScene = {
    enabled = true,
    radius = 75.0,
    checkIntervalMs = 1000,
    notifyUnit = true
}

Config.Notifications = {
    useNuiPopup = true,
    popupDuration = 12000,
    showChatMessage = true,
    notifyCaller = true,

    chatTemplate = [[
        <div style="padding: 8px 10px; margin: 3px 0; background: rgba(15, 23, 42, 0.92); border-left: 3px solid #ef4444; border-radius: 5px;">
            <div style="font-weight: 800; color: #f87171; margin-bottom: 3px;">911 CALL #{0}</div>
            <div style="color: #fca5a5; font-size: 12px; margin-bottom: 3px;">{1}</div>
            <div style="color: #f8fafc; font-size: 13px;">{2}</div>
            <div style="color: #94a3b8; font-size: 11px; margin-top: 5px;">Press [{3}] to interact • /{4} {0} to set a waypoint</div>
        </div>
    ]]
}

Config.Sound = {
    enabled = true,
    name = 'TIMER_STOP',
    soundSet = 'HUD_MINI_GAME_SOUNDSET'
}

Config.Blip = {
    enabled = true,
    sprite = 280,
    color = 1,
    scale = 0.95,
    flash = true,
    flashInterval = 500,
    shortRange = false,
    durationSeconds = 300,
    radius = {
        enabled = true,
        size = 75.0,
        color = 1,
        alpha = 80
    }
}

Config.Messages = {
    usage = 'Usage: /911 <message>',
    empty = 'Please include a message with your 911 call.',
    cooldown = 'Please wait %s second(s) before making another 911 call.',
    submitted = 'Your 911 call has been sent to emergency responders.',
    callerUnitResponding = 'A responder has accepted your 911 call and is en route.',
    callerAdditionalUnit = 'An additional responder has attached to your 911 call.',
    callerOnScene = 'Emergency responders have arrived on scene for your 911 call.',
    callerResolved = 'Your 911 call has been closed by emergency responders.',
    noPermission = 'You do not have permission to view 911 calls.',
    noCalls = 'There are no recent 911 calls.',
    noVisibleCalls = 'There are no active 911 cards to interact with.',
    invalidCall = 'That 911 call could not be found.',
    waypointSet = 'Waypoint set for 911 call #%s.',
    callsCleared = 'Your local 911 call history has been cleared.',
    focusEnabled = '911 call interaction enabled. Press the focus key again or Escape to return to the game.',
    focusDisabled = '911 call interaction closed.',
    becamePrimary = 'You are now the primary unit for 911 call #%s.',
    attached = 'You are now attached to 911 call #%s.',
    detached = 'You have detached from 911 call #%s.',
    alreadyPrimary = 'You are already the primary unit for this call.',
    alreadyAttached = 'You are already attached to this call.',
    primaryOnlyClose = 'Only the primary unit can close this callout.',
    callClosedForAll = '911 call #%s was closed by %s.',
    onScene = 'You have arrived on scene for 911 call #%s.'
}

Config.Discord = {
    enabled = false,
    webhook = '',
    username = 'Simple911',
    avatarUrl = ''
}
