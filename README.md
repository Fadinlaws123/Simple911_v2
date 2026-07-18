# Simple911 v2

A modern, standalone-first emergency call and dispatch resource for FiveM.

> **Development build:** the standalone core is ready for in-game testing, but this is not yet a production release.

## Current Features

- Configurable 911, 311, and custom call services
- Config-driven templated emergency messages
- Modern NUI caller form
- Automatic street and cross-street detection
- Optional anonymous calls
- Server-side validation, cooldowns, and active-call limits
- Caller cancellation with `/cancel911`
- Caller notifications when a call is assigned, responded to, or resolved
- Advanced live responder dispatch workspace
- Search and filter calls by status, priority, and ownership
- Multi-unit call assignment
- Custom responder callsigns
- Live on-duty unit roster and active-call counts
- Join, respond, leave, waypoint, resolve, and reprioritize actions
- Shared responder notes
- Per-call event timeline and history
- Resolved-call retention for dispatch review
- Server-authoritative call state and responder actions
- ACE-based responder permissions
- On-duty/off-duty dispatch state
- Live call blips for responders
- Optional Discord webhook logging for calls and status changes
- Server exports for creating and reading calls from other resources

## Installation

1. Place the resource in your server's resources directory as `Simple911_v2`.
2. Add `ensure Simple911_v2` to your `server.cfg`.
3. Give responders the `simple911.responder` ACE permission. See `server.cfg.example`.
4. Restart the resource/server.

## Default Commands

- `/911` - Open the emergency call form.
- `/311` - Open the non-emergency call form.
- `/dispatch` - Open the responder dispatch center.
- `/911duty` - Toggle responder dispatch duty.
- `/cancel911` - Cancel your latest active call.

## Quick Standalone Test

```cfg
add_ace group.admin simple911.responder allow
```

Then test:

1. Go on duty with `/911duty`.
2. Open `/dispatch` and set a callsign.
3. Submit calls using `/911` and `/311`.
4. Test joining, responding, leaving, reprioritizing, adding notes, setting waypoints, and resolving calls.
5. Use `/cancel911` from the caller side.
6. Test with two players where possible to verify multi-unit assignment, live syncing, roster updates, and shared notes.

## Configuration

Most customization lives in `config.lua`, including services, commands, templates, priorities, cooldowns, message limits, responder permissions, multi-unit behavior, call retention, blips, and Discord logging.

Additional services can be added by creating another entry in `Config.Services`. The caller UI automatically reads configured services and templates.

## Exports

### CreateCall

Creates a dispatch call from another server resource.

```lua
local success, callId = exports.Simple911_v2:CreateCall({
    serviceId = '911',
    templateId = 'shots_fired',
    message = 'Automatic panic alarm activation.',
    callerName = 'Alarm System',
    location = 'Mission Row',
    coords = { x = 425.1, y = -979.5, z = 30.7 }
})
```

### GetCall

```lua
local call = exports.Simple911_v2:GetCall(callId)
```

### GetActiveCalls

```lua
local calls = exports.Simple911_v2:GetActiveCalls()
```

## Integrations

The standalone core is being tested first. Optional QBCore, ESX, and ND_Core bridges will be added after the core call lifecycle is stable, keeping framework-specific logic isolated from the main resource.

## Development Status

This repository is under active development. Please report reproducible issues with console errors and the steps needed to trigger them.
