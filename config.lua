Config = {}

Config.Debug = false
Config.Locale = 'en'

Config.Commands = {
    dispatch = 'dispatch',
    toggleDuty = '911duty',
    cancelLastCall = 'cancel911',
    replyToCall = '911reply',
    callStatus = '911status',
    panic = 'panic'
}

Config.ResponderAccess = {
    acePermission = 'simple911.responder',
    dispatcherAcePermission = 'simple911.dispatcher',
    allowEveryoneWhenDebug = true
}

Config.Cooldown = {
    enabled = true,
    seconds = 20,
    panicSeconds = 30
}

Config.CallSettings = {
    maxMessageLength = 500,
    maxNoteLength = 280,
    maxChatMessageLength = 280,
    maxActiveCalls = 100,
    resolvedRetentionSeconds = 900,
    anonymousLabel = 'Anonymous Caller',
    allowCallerCancel = true,
    allowPriorityChanges = true,
    defaultCallsignPrefix = 'UNIT',
    queueCallsWhenNoUnits = true,
    tellCallerWhenNoUnits = true
}

Config.Dispatch = {
    showResolvedCalls = true,
    showUnitRoster = true,
    allowMultipleUnits = true,
    requireClaimBeforeResponding = false,
    notifyCallerOnStatusChange = true,
    dispatcherPriorityRouting = true,
    dispatcherDepartment = 'dispatch',
    unitLocationUpdateSeconds = 10
}

Config.UnitStatuses = {
    { id = 'available', label = 'Available' },
    { id = 'busy', label = 'Busy' },
    { id = 'enroute', label = 'En Route' },
    { id = 'onscene', label = 'On Scene' },
    { id = 'unavailable', label = 'Unavailable' }
}

Config.Departments = {
    { id = 'police', label = 'Police', defaultRadio = 'LEO' },
    { id = 'fire', label = 'Fire', defaultRadio = 'FIRE' },
    { id = 'ems', label = 'EMS', defaultRadio = 'EMS' },
    { id = 'tow', label = 'Tow / Service', defaultRadio = 'SERVICE' },
    { id = 'dispatch', label = 'Dispatch', defaultRadio = 'DISPATCH' }
}

Config.Blips = {
    enabled = true,
    sprite = 280,
    color = 1,
    scale = 0.9,
    routeColor = 1,
    shortRange = false,
    flashPriorityOne = true,
    defaultDurationSeconds = 300
}

Config.Sounds = {
    enabled = true,
    priorityOne = { name = 'TIMER_STOP', set = 'HUD_MINI_GAME_SOUNDSET' },
    normal = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' }
}

Config.Panic = {
    enabled = true,
    serviceId = '911',
    templateId = 'officer_distress',
    code = '10-99',
    departments = { 'police', 'dispatch' }
}

Config.Services = {
    {
        id = '911',
        label = 'Emergency Services',
        shortLabel = '911',
        command = '911',
        description = 'Request Police, Fire, or EMS assistance.',
        accent = '#ef4444',
        allowAnonymous = true,
        templates = {
            { id = 'shots_fired', label = 'Shots Fired', code = '10-71', category = 'Police', priority = 1, departments = { 'police', 'dispatch' }, message = 'I am reporting shots fired near {street}. ' },
            { id = 'robbery', label = 'Robbery in Progress', code = '10-31', category = 'Police', priority = 1, departments = { 'police', 'dispatch' }, message = 'I am reporting a robbery in progress near {street}. ' },
            { id = 'reckless_driver', label = 'Reckless Driver', code = '10-94', category = 'Police', priority = 2, departments = { 'police', 'dispatch' }, message = 'I am reporting a reckless driver near {street}. ' },
            { id = 'medical', label = 'Medical Emergency', code = 'MED-1', category = 'EMS', priority = 1, departments = { 'ems', 'fire', 'dispatch' }, message = 'I need medical assistance near {street}. ' },
            { id = 'collision', label = 'Vehicle Collision', code = 'MVC', category = 'Fire / EMS', priority = 2, departments = { 'police', 'fire', 'ems', 'dispatch' }, message = 'I am reporting a vehicle collision near {street}. ' },
            { id = 'fire', label = 'Structure / Vehicle Fire', code = 'FIRE-1', category = 'Fire', priority = 1, departments = { 'fire', 'ems', 'dispatch' }, message = 'I am reporting a fire near {street}. ' },
            { id = 'officer_distress', label = 'Officer in Distress', code = '10-99', category = 'Police', priority = 1, departments = { 'police', 'dispatch' }, hiddenFromCaller = true, message = 'Emergency assistance requested by an officer near {street}.' },
            { id = 'other', label = 'Other Emergency', code = '911', category = 'Other', priority = 2, departments = { 'police', 'fire', 'ems', 'dispatch' }, message = 'I need emergency assistance near {street}. ' }
        }
    },
    {
        id = '311',
        label = 'Non-Emergency Services',
        shortLabel = '311',
        command = '311',
        description = 'Request non-emergency public safety assistance.',
        accent = '#3b82f6',
        allowAnonymous = true,
        templates = {
            { id = 'tow', label = 'Tow Required', code = 'SERVICE', category = 'Service', priority = 3, departments = { 'tow', 'dispatch' }, message = 'A tow service is required near {street}. ' },
            { id = 'disabled_vehicle', label = 'Disabled Vehicle', code = 'ROAD', category = 'Traffic', priority = 3, departments = { 'police', 'tow', 'dispatch' }, message = 'There is a disabled vehicle near {street}. ' },
            { id = 'road_hazard', label = 'Road Hazard', code = 'HAZARD', category = 'Traffic', priority = 3, departments = { 'police', 'tow', 'dispatch' }, message = 'I am reporting a road hazard near {street}. ' },
            { id = 'noise', label = 'Noise Complaint', code = 'NOISE', category = 'Police', priority = 3, departments = { 'police', 'dispatch' }, message = 'I would like to report a noise complaint near {street}. ' },
            { id = 'other', label = 'Other Non-Emergency', code = '311', category = 'Other', priority = 3, departments = { 'police', 'tow', 'dispatch' }, message = 'I need non-emergency assistance near {street}. ' }
        }
    }
}

Config.Notifications = {
    newCall = true,
    statusChanges = true,
    unitChanges = true,
    callerMessages = true
}

Config.Discord = {
    enabled = false,
    webhook = '',
    username = 'Simple911',
    avatarUrl = '',
    logStatusChanges = true,
    logNotes = false,
    logCallerChat = false
}
