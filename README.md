# Simple911 v2

A standalone-first emergency call and advanced dispatch system for FiveM.

> **Development build:** the standalone core is ready for in-game testing, but this is not yet a production release.

## Current Features

### Caller System

- Configurable 911, 311, and completely custom call services
- Config-driven templated emergency messages and dispatch codes
- Modern NUI caller form
- Automatic street and cross-street detection
- Optional anonymous calls
- Server-side validation, cooldowns, and active-call limits
- Caller cancellation with `/cancel911`
- Caller call-status checks with `/911status`
- Two-way responder-to-caller messaging
- Caller replies with `/911reply <message>`
- Caller notifications when units are assigned, responding, on scene, or the call is resolved
- Optional queued-call handling and warnings when no matching responders are available

### Dispatch System

- Advanced live responder dispatch workspace
- Department-aware call routing
- Optional dispatcher-first routing when dedicated dispatchers are online
- Custom incident codes such as `10-71`, `10-31`, `MED-1`, and custom codes from integrations
- Search calls by code, type, location, caller, department, and message
- Filter calls by status, priority, and assigned ownership
- Multi-unit call assignment
- Join, respond, mark on scene, leave, waypoint, resolve, and reprioritize actions
- Shared responder notes
- Full per-call event timeline
- Two-way caller communication history stored with each incident
- Resolved-call retention for review
- Priority-aware map blips with optional flashing and radius blips
- Custom per-alert blip configuration
- Configurable dispatch sounds

### Unit Management

- Custom responder callsigns
- Configurable Police, Fire, EMS, Tow/Service, Dispatch, and additional custom departments
- Unit statuses: Available, Busy, En Route, On Scene, and Unavailable
- Configurable radio/channel identifiers
- Live on-duty unit roster
- Active-call counts per unit
- Periodic responder location synchronization for integrations and future map tooling
- Separate ACE permissions for responders and dedicated dispatchers

### Emergency & Integration Tools

- `/panic` responder distress system that generates a Priority 1 incident
- `CreateCall` server export for predefined call templates
- `CustomAlert` server export for fully custom automatic dispatch incidents
- Custom recipient departments
- Custom priority, code, title, category, metadata, coordinates, and blip settings
- Optional Discord webhook logging
- Server-authoritative incident state and responder actions

## Installation

1. Place the resource in your server's resources directory as `Simple911_v2`.
2. Add `ensure Simple911_v2` to your `server.cfg`.
3. Give responders the `simple911.responder` ACE permission. See `server.cfg.example`.
4. Optionally give dedicated dispatchers `simple911.dispatcher`.
5. Restart the resource/server.

## Default Commands

- `/911` - Open the emergency call form.
- `/311` - Open the non-emergency call form.
- `/dispatch` - Open the responder dispatch center.
- `/911duty` - Toggle responder dispatch duty.
- `/cancel911` - Cancel your latest active call.
- `/911reply <message>` - Send additional information to responders on your latest active call.
- `/911status` - Check the status of your latest tracked call.
- `/panic` - Send a responder distress alert.

## Quick Standalone Test

```cfg
add_ace group.admin simple911.responder allow
add_ace group.admin simple911.dispatcher allow
```

Then test:

1. Go on duty with `/911duty`.
2. Open `/dispatch`, configure your callsign, department, status, and radio.
3. Submit calls using `/911` and `/311`.
4. Test department routing with multiple responders in different departments.
5. Test joining, responding, marking on scene, leaving, reprioritizing, notes, waypoints, and resolving calls.
6. Send a message to the caller from the incident details panel and reply with `/911reply`.
7. Test `/panic` while on duty.
8. Use two or more players where possible to verify dispatcher-first routing, multi-unit assignments, unit states, and live synchronization.

## Configuration

Most customization lives in `config.lua`, including:

- Services and commands
- Templates and incident codes
- Recipient departments
- Unit departments and statuses
- Dispatcher-first routing
- Caller chat limits
- Cooldowns and call limits
- Panic/distress behavior
- Blips and sounds
- Discord logging

## Server Exports

### CreateCall

Creates a call using a configured service and template.

```lua
local success, callId = exports.Simple911_v2:CreateCall({
    serviceId = '911',
    templateId = 'shots_fired',
    message = 'Automatic gunshot detection triggered.',
    callerName = 'ShotSpotter',
    location = 'Mission Row',
    coords = { x = 425.1, y = -979.5, z = 30.7 }
})
```

### CustomAlert

Creates a fully customized dispatch alert for integrations with robbery, alarm, vehicle, panic, medical, and other resources.

```lua
local success, callId = exports.Simple911_v2:CustomAlert({
    title = 'Bank Silent Alarm',
    code = '10-90',
    category = 'Robbery',
    priority = 1,
    departments = { 'police', 'dispatch' },
    message = 'Silent alarm triggered at Fleeca Bank.',
    callerName = 'Alarm System',
    location = 'Legion Square',
    coords = { x = 150.0, y = -1040.0, z = 29.0 },
    blip = {
        sprite = 161,
        color = 1,
        scale = 1.1,
        flash = true,
        radius = 75.0
    },
    metadata = {
        alarmType = 'silent'
    }
})
```

## Framework Integrations

The standalone core remains the source of truth. Optional QBCore, ESX, Qbox, and ND_Core bridges can be layered on for automatic names, jobs, departments, and duty states without replacing the standalone dispatch engine.

## Development Status

This repository is under active development. Report reproducible issues with console errors and the exact steps needed to trigger them.
