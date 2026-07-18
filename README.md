# Simple911 v2

A modern, standalone-first emergency call and dispatch resource for FiveM.

> **Development build:** the standalone core is ready for initial in-game testing, but this is not yet a production release.

## Current Features

- Configurable 911, 311, and custom call services
- Config-driven templated emergency messages
- Modern NUI caller form
- Automatic street and cross-street detection
- Optional anonymous calls
- Server-side call validation and cooldowns
- Live responder dispatch panel
- Claim, respond, unclaim, waypoint, and resolve actions
- Server-authoritative call state
- ACE-based responder permissions
- On-duty/off-duty dispatch state
- Live call blips for responders
- Optional Discord webhook logging
- Server export for creating calls from other resources

## Installation

1. Place the resource in your server's resources directory as `Simple911_v2`.
2. Add `ensure Simple911_v2` to your `server.cfg`.
3. Give responders the `simple911.responder` ACE permission. See `server.cfg.example`.
4. Restart the resource/server.

## Default Commands

- `/911` - Open the emergency call form.
- `/311` - Open the non-emergency call form.
- `/dispatch` - Open the responder dispatch panel.
- `/911duty` - Toggle responder dispatch duty.

## Quick Standalone Test

For a local test server, grant your admin group responder access:

```cfg
add_ace group.admin simple911.responder allow
```

Then:

1. Join the server and run `/911duty` as a permitted player.
2. Submit a call with `/911` or `/311`.
3. Open `/dispatch` and test claim, respond, waypoint, unclaim, and resolve actions.
4. Test with two players if possible to verify live synchronization and call claiming.

## Configuration

Most server-owner customization lives in `config.lua`, including:

- Services and commands
- Call templates
- Categories and priorities
- Cooldowns and message limits
- Blip appearance
- ACE permission name
- Discord logging

Additional services can be added by creating another entry in `Config.Services`. The NUI reads configured services and templates automatically.

## Integrations

The standalone core is being tested first. Optional QBCore, ESX, and ND_Core bridges will be added after the core call lifecycle is stable, keeping framework-specific logic isolated from the main resource.

## Development Status

This repository is under active development. Please report reproducible issues with console errors and the steps needed to trigger them.
