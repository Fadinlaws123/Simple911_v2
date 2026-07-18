<div align="center">

# 🚨 Simple911 v2

### A modern, standalone-first 911 call system built to keep emergency calls simple for civilians and useful for responders.

</div>

---

## 📖 About

**Simple911 v2** is a complete rebuild of the original Simple911 resource.

The goal is simple: keep the familiar `/911 <message>` experience without turning the resource into a full dispatch terminal or MDT. Civilians can quickly report an emergency, while authorized responders receive everything they need to view, respond to, track, and manage active calls.

Calls include automatic location detection, interactive responder cards, map blips, unit assignments, on-scene detection, caller updates, Discord logging, and a dedicated recent-calls interface for managing incidents that may have been missed.

The resource is designed to work standalone while remaining configurable and integration-friendly for servers that want to connect it with other systems.

---

## ✨ Features

### 📞 Emergency Calls

- Simple `/911 <message>` command
- Automatic street and cross-street detection
- Configurable caller name and server ID display
- Server-side cooldowns and message validation
- Templated responder chat notifications
- Configurable caller status notifications

### 🚓 Responder Call System

- Modern interactive incoming-call cards
- Configurable interaction keybind
- Respond and automatically set a waypoint
- Primary unit assignment shared across responders
- Additional responding units can attach and detach
- Unit information synchronizes across connected responder clients
- Calls transition through clear response states
- Automatic **On Scene** detection when responders reach the call area
- Close active callouts directly from the responder interface
- Call cards automatically update as incident information changes

### 🗂️ Recent 911 Calls

Use `/911calls` to open a dedicated interface for current and recent emergency calls.

- Scrollable call list supporting multiple active incidents
- Status-based call cards and visual styling
- View location, call details, primary unit, and attached responders
- Respond to unassigned calls
- Attach to or detach from existing calls
- Set waypoints to active incidents
- Close calls when authorized
- Quickly recover calls if the original notification was missed

### 🗺️ Map & Location Features

- Temporary emergency call blips
- Configurable radius blips
- Configurable flashing emergency blips
- Automatic waypoint placement when responding
- `/911wp [call ID]` waypoint command
- Configurable blip appearance, duration, and radius
- Automatic proximity detection for on-scene responders

### 🔊 Alerts & Notifications

- Configurable emergency alert sound
- Modern responder notification UI
- Optional templated chat alerts
- Caller notifications when responders accept or update a call
- Configurable notification behavior

### 📡 Discord Logging

Simple911 includes an enhanced Discord incident logging system designed to provide a useful live record of emergency calls without spamming multiple duplicate embeds.

- Detailed incident embeds
- Caller and location information
- Current call status
- Primary unit tracking
- Attached responder tracking
- Response overview
- Incident activity timeline
- Existing incident embeds update as calls progress
- Final incident information remains available after a call is closed
- Configurable webhook username and avatar

A `911discordtest` server-console command is also included for testing the configured Discord webhook.

### 🔌 Integrations

- Standalone-first design
- ACE-based responder permissions
- `CreateCall` server export for external resources
- `GetActiveCalls` server export for integrations
- Designed to remain focused on emergency calls rather than becoming a full CAD/MDT

### 🔄 Version Checker

Simple911 includes a built-in version checker that runs when the resource starts.

- Displays the installed and latest available version
- Notifies server owners when an update is available
- Shows the latest changelog information
- Provides the configured download link
- Includes SimpleDevelopments project and support information
- Never stops the resource if the version service is unavailable

---

## 📥 Installation

### 1. Download the Resource

Download the latest version of Simple911 v2 and extract the downloaded ZIP file.

### 2. Add it to Your Server

Move the `Simple911_v2` folder into your FiveM server's resources directory.

For example:

```text
resources/[standalone]/Simple911_v2
```

### 3. Configure the Resource

Open `config.lua` and configure Simple911 for your server before starting the resource.

### 4. Add Responder Permissions

Simple911 uses ACE permissions by default to determine who can receive and interact with emergency calls.

Example:

```cfg
add_ace group.admin simple911.responder allow
```

Replace `group.admin` with the appropriate ACE group used by your server.

### 5. Start Simple911

Add the following to your `server.cfg`:

```cfg
ensure Simple911_v2
```

Restart your server or start the resource manually.

---

## 🎮 Commands

| Command | Description |
| --- | --- |
| `/911 <message>` | Creates a new emergency call. |
| `/911calls` | Opens the recent and active 911 calls interface. |
| `/911wp` | Sets a waypoint to the newest locally received call. |
| `/911wp <call ID>` | Sets a waypoint to a specific emergency call. |
| `/911clear` | Clears locally stored calls and Simple911 blips. |
| `911discordtest` | Tests the Discord webhook from the server console. |

Example emergency call:

```text
/911 There is a red Sultan shooting at people outside the gas station
```

---

## ⚙️ Configuration

Simple911 is designed to be easy to configure from `config.lua`.

Configuration options include:

- Command names
- Responder permissions
- Interaction keybinds
- Call cooldowns
- Message limits
- Call history and duration
- Caller information visibility
- Responder notifications
- Caller notifications
- Chat templates
- Alert sounds
- Blip appearance and behavior
- On-scene detection
- Discord webhook logging
- Version checker settings

---

## 🔌 Server Exports

### CreateCall

Other server resources can create a Simple911 emergency call without requiring a player to use `/911`.

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

Other resources can retrieve the currently active Simple911 calls.

```lua
local calls = exports.Simple911_v2:GetActiveCalls()
```

---

## 📋 Requirements

- FiveM server
- No framework required
- No database required
- No additional dependencies required

---

## 🛠️ Support

If you find a bug, include any relevant client or server console errors and clear steps to reproduce the issue when reporting it.

Simple911 v2 is actively being developed, so testing is recommended before deploying new versions to a production server.

---

## 🌐 SimpleDevelopments

Simple911 v2 is developed by **SimpleDevelopments** as the next generation of the original Simple911 resource.

SimpleDevelopments creates FiveM scripts, Discord bots, custom development, liveries, vehicles, and other community resources.

---

<div align="center">

### Keep it Simple. Keep it SimpleDevelopments.

⭐ **If you find Simple911 useful, consider starring the repository.**

</div>
