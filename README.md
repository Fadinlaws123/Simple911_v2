<div align="center">

# 🚨 Simple911 v2

### A modern, standalone-first 911 call system built to keep emergency calls simple for civilians and useful for responders.

<p>
  <a href="https://simpledevelopments.org/store">
    <img src="https://img.shields.io/badge/Explore_Our_Store-5865F2?style=for-the-badge&logo=googlechrome&logoColor=white" />
  </a>
  <a href="https://discord.gg/RquDVTfDwu">
    <img src="https://img.shields.io/badge/Join_Our_Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" />
  </a>
  <a href="https://github.com/Fadinlaws123/Simple911_v2">
    <img src="https://img.shields.io/badge/View_on_GitHub-181717?style=for-the-badge&logo=github&logoColor=white" />
  </a>
</p>

<p>
  <img src="https://img.shields.io/badge/FiveM-Standalone-FF6B35?style=flat-square&logo=fivem&logoColor=white" />
  <img src="https://img.shields.io/badge/Framework-No_Dependency-238636?style=flat-square" />
  <img src="https://img.shields.io/badge/Status-Release_Ready-238636?style=flat-square" />
  <img src="https://img.shields.io/github/stars/Fadinlaws123/Simple911_v2?style=flat-square&logo=github&label=Stars" />
</p>

</div>

---

## 📖 About

**Simple911 v2** is a complete rebuild of the original Simple911 resource.

The goal is simple: keep the familiar `/911 <message>` experience without turning the resource into a full dispatch terminal or MDT. Civilians can quickly report an emergency, while authorized responders receive everything they need to view, respond to, track, and manage active calls.

Calls include automatic location detection, interactive responder cards, map blips, unit assignments, on-scene detection, caller updates, Discord logging, and a dedicated recent-calls interface for managing incidents that may have been missed.

The resource is designed to work standalone while remaining configurable and integration-friendly for servers that want to connect it with other systems.

---

## 📸 Preview

### 🗂️ 911 Calls Interface

View and manage active incidents through the `/911calls` panel. Responders can quickly see call details, current status, assigned units, and available actions from one place.

<div align="center">

<img width="100%" alt="Simple911 active calls interface" src="https://github.com/user-attachments/assets/35b2b44f-e07d-4f30-b733-acab46f9657a" />

</div>

#### Call Statuses

<table>
  <tr>
    <td align="center" width="50%">
      <strong>🚓 En Route</strong><br><br>
      <img width="100%" alt="Simple911 en route call status" src="https://github.com/user-attachments/assets/2abdcb99-6ac5-476f-89dd-cca4bb961bc1" />
    </td>
    <td align="center" width="50%">
      <strong>🟢 On Scene</strong><br><br>
      <img width="100%" alt="Simple911 on scene call status" src="https://github.com/user-attachments/assets/60176a7c-2948-4496-aa99-f80392a984fd" />
    </td>
  </tr>
</table>

### 🚨 Responder Call Cards

Incoming 911 calls appear as lightweight responder cards that update live as units respond and arrive on scene.

<div align="center">

<img width="390" alt="Simple911 incoming responder call card" src="https://github.com/user-attachments/assets/bc20b8d8-e1af-46e7-a09e-0b37580d6eff" />

</div>

#### Card Statuses

<table>
  <tr>
    <td align="center" width="50%">
      <strong>🚓 En Route</strong><br><br>
      <img width="100%" alt="Simple911 en route responder card" src="https://github.com/user-attachments/assets/d69ab132-7bb8-49be-8d6e-25c56a03ad84" />
    </td>
    <td align="center" width="50%">
      <strong>🟢 On Scene</strong><br><br>
      <img width="100%" alt="Simple911 on scene responder card" src="https://github.com/user-attachments/assets/3d13b3e2-1e52-4405-aed1-6cde22b89134" />
    </td>
  </tr>
</table>

### 📡 Live Discord Incident Logs

Each 911 call creates one detailed Discord incident log that updates throughout the entire response lifecycle instead of flooding the channel with separate messages.

<table>
  <tr>
    <td align="center" width="50%">
      <strong>🔴 New 911 Call</strong><br><br>
      <img width="100%" alt="Simple911 new Discord incident log" src="https://github.com/user-attachments/assets/3c8bc371-b4ca-487d-a024-0375ccb470ea" />
    </td>
    <td align="center" width="50%">
      <strong>🔵 Unit En Route</strong><br><br>
      <img width="100%" alt="Simple911 unit en route Discord incident log" src="https://github.com/user-attachments/assets/c4a91f11-6f6f-4298-a220-4c21703b3782" />
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <strong>🟢 Unit On Scene</strong><br><br>
      <img width="100%" alt="Simple911 unit on scene Discord incident log" src="https://github.com/user-attachments/assets/bf7a5510-719a-4660-9e05-6e221330c117" />
    </td>
    <td align="center" width="50%">
      <strong>🔒 Call Closed</strong><br><br>
      <img width="100%" alt="Simple911 closed Discord incident log" src="https://github.com/user-attachments/assets/b24724a1-dfbb-4ccd-b125-1edb98ba2338" />
    </td>
  </tr>
</table>

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

Simple911 v2 is release-ready and actively maintained. Testing new versions before deploying them to a production server is still recommended, because software remains software and enjoys finding creative ways to behave differently on someone else's server.

---

## 🌐 SimpleDevelopments

Simple911 v2 is developed by **SimpleDevelopments** as the next generation of the original Simple911 resource.

SimpleDevelopments creates FiveM scripts, Discord bots, custom development, liveries, vehicles, and other community resources.

---

<div align="center">

### Keep it Simple. Keep it SimpleDevelopments.

⭐ **If you find Simple911 useful, consider starring the repository.**

</div>
