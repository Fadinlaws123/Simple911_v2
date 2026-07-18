Config = {}

Config.Debug = false
Config.Locale = 'en'

Config.Commands = {
    dispatch = 'dispatch',
    toggleDuty = '911duty',
    cancelLastCall = 'cancel911'
}

Config.ResponderAccess = {
    acePermission = 'simple911.responder',
    allowEveryoneWhenDebug = true
}

Config.Cooldown = {
    enabled = true,
    seconds = 20
}

Config.CallSettings = {
    maxMessageLength = 500,
    maxNoteLength = 280,
    maxActiveCalls = 100,
    resolvedRetentionSeconds = 900,
    anonymousLabel = 'Anonymous Caller',
    allowCallerCancel = true,
    allowPriorityChanges = true,
    defaultCallsignPrefix = 'UNIT'
}

Config.Dispatch = {
    showResolvedCalls = true,
    showUnitRoster = true,
    allowMultipleUnits = true,
    requireClaimBeforeResponding = false,
    notifyCallerOnStatusChange = true
}

Config.Blips = {
    enabled = true,
    sprite = 280,
    color = 1,
    scale = 0.9,
    routeColor = 1,
    shortRange = false
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
            { id = 'shots_fired', label = 'Shots Fired', category = 'Police', priority = 1, message = 'I am reporting shots fired near {street}. ' },
            { id = 'robbery', label = 'Robbery in Progress', category = 'Police', priority = 1, message = 'I am reporting a robbery in progress near {street}. ' },
            { id = 'reckless_driver', label = 'Reckless Driver', category = 'Police', priority = 2, message = 'I am reporting a reckless driver near {street}. ' },
            { id = 'medical', label = 'Medical Emergency', category = 'EMS', priority = 1, message = 'I need medical assistance near {street}. ' },
            { id = 'collision', label = 'Vehicle Collision', category = 'Fire / EMS', priority = 2, message = 'I am reporting a vehicle collision near {street}. ' },
            { id = 'fire', label = 'Fire', category = 'Fire', priority = 1, message = 'I am reporting a fire near {street}. ' },
            { id = 'other', label = 'Other Emergency', category = 'Other', priority = 2, message = 'I need emergency assistance near {street}. ' }
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
            { id = 'tow', label = 'Tow Required', category = 'Service', priority = 3, message = 'A tow service is required near {street}. ' },
            { id = 'disabled_vehicle', label = 'Disabled Vehicle', category = 'Traffic', priority = 3, message = 'There is a disabled vehicle near {street}. ' },
            { id = 'road_hazard', label = 'Road Hazard', category = 'Traffic', priority = 3, message = 'I am reporting a road hazard near {street}. ' },
            { id = 'noise', label = 'Noise Complaint', category = 'Police', priority = 3, message = 'I would like to report a noise complaint near {street}. ' },
            { id = 'other', label = 'Other Non-Emergency', category = 'Other', priority = 3, message = 'I need non-emergency assistance near {street}. ' }
        }
    }
}

Config.Notifications = {
    newCall = true,
    statusChanges = true,
    unitChanges = true
}

Config.Discord = {
    enabled = false,
    webhook = '',
    username = 'Simple911',
    avatarUrl = '',
    logStatusChanges = true,
    logNotes = false
}
