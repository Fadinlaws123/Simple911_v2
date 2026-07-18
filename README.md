# Simple911 v2

A lightweight, standalone-first emergency call system for FiveM.

Simple911 v2 keeps the player experience simple: civilians use `/911 <message>`, and permitted responders receive a sound alert, an on-screen call notification, and a temporary map blip with quick waypoint controls.

## Features

- `/911 <message>` emergency calling
- Automatic street and cross-street detection
- Server-side cooldown and message validation
- ACE-based responder permissions
- Configurable alert sound
- Modern lightweight responder popup
- Temporary map blips
- Optional configurable radius blip
- Flashing emergency blips
- One-click waypoint button from the popup
- `/911wp [call ID]` waypoint command
- `/911calls` lightweight recent-call list
- `/911clear` to clear local call history and blips
- Configurable caller name/server ID visibility
- Optional chat alerts
- Optional Discord webhook logging
- `CreateCall` export for other resources
- `GetActiveCalls` export for integrations

## Installation

1. Place the resource in your server's resources directory as `Simple911_v2`.
2. Add `ensure Simple911_v2` to your `server.cfg`.
3. Give law enforcement or other responders the `simple911.responder` ACE permission.
4. Restart the resource/server.

Example:

```cfg
ensure Simple911_v2
add_ace group.admin simple911.responder allow
```

## Commands

- `/911 <message>` - Send a new emergency call.
- `/911calls` - Open the recent 911 call list.
- `/911wp` - Set a waypoint to the newest locally received call.
- `/911wp <call ID>` - Set a waypoint to a specific call.
- `/911clear` - Clear your locally stored calls and active Simple911 blips.

## Example

```text
/911 There is a red Sultan shooting at people outside the gas station
```

Permitted responders receive the caller's location, message, configurable caller information, alert sound, and map blip.

## Configuration

Everything is configured in `config.lua`, including:

- Commands
- ACE permission
- Call cooldown
- Maximum message length
- Call history length
- Call/blip duration
- Caller information visibility
- Popup notifications
- Chat messages
- Alert sounds
- Blip appearance and radius
- Discord logging

## Server Exports

### CreateCall

Other server resources can create a Simple911 call without requiring a player command.

```lua
local success, callId = exports.Simple911_v2:CreateCall({
    message = 'Silent alarm triggered at the bank.',
    callerName = 'Alarm System',
    location = 'Legion Square',
    coords = {
        x = 150.0,
        y = -1040.0,
        z = 29.0
    }
})
```

### GetActiveCalls

```lua
local calls = exports.Simple911_v2:GetActiveCalls()
```

## Development Direction

Simple911 is intentionally focused on emergency calling and responder alerts. Full CAD/MDT features should live in a separate resource and integrate with Simple911 through its exports/events rather than turning the 911 script itself into a terminal.

## Development Status

This is currently a development build. Test it in-game before using it on a production server and report reproducible issues with console errors and exact reproduction steps.
