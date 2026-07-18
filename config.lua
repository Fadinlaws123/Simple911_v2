Config = {}

Config.Debug = false

Config.Commands = {
    emergency = '911',
    calls = '911calls',
    waypoint = '911wp',
    clear = '911clear',
    focus = '911focus'
}

Config.Focus = {
    defaultKey = 'F6',
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

Config.Notifications = {
    useNuiPopup = true,
    popupDuration = 12000,
    showChatMessage = false,
    notifyCaller = true
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
    noPermission = 'You do not have permission to view 911 calls.',
    noCalls = 'There are no recent 911 calls.',
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
    callClosedForAll = '911 call #%s was closed by %s.'
}

Config.Discord = {
    enabled = false,
    webhook = '',
    username = 'Simple911',
    avatarUrl = ''
}