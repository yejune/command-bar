# CommandBar

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**The Essential Tool for the Vibe Coding Era**

In the age of AI-assisted development, you're constantly copying commands, API calls, and code snippets. CommandBar captures everything, makes it instantly reusable, and keeps your workflow flowing.

[한국어](README.ko.md)

---

## Why CommandBar?

**The Problem**: AI generates commands and code faster than you can organize them. You copy the same curl commands, repeat the same git workflows, and lose track of what worked.

**The Solution**: CommandBar turns chaos into a system:
- **Save once, run forever** - Every command becomes a reusable button
- **Smart clipboard** - Auto-captures everything you copy (up to 10,000 items)
- **Execution history** - Never lose track of what you ran and when
- **Parameters** - Add variables to commands for flexibility
- **Always accessible** - Floats on top, ready when you need it

---

## Installation

### Homebrew (Recommended)
```bash
brew tap yejune/command-bar
brew install --cask command-bar
```

### Download DMG
1. Download DMG from [Releases](https://github.com/yejune/command-bar/releases)
2. Open DMG and drag CommandBar to Applications
3. First run: Right-click → Open (bypass Gatekeeper)

### Build from Source
```bash
git clone https://github.com/yejune/command-bar.git
cd command-bar
make build
```

---

## Quick Start

### 1. Add Your First Command

Click `+` → Enter a title → Choose execution type → Save

**Example**: Save a frequently used curl command
```
Title: Check Server Status
Type: Script
Command: curl -s https://api.example.com/health
```

### 2. Run Commands

- **Double-click** to run immediately
- **Right-click** → Run for options
- **Enter key** to run selected item

### 3. Use Parameters

Make commands flexible with `{parameterName}` syntax:

```bash
# Simple text input
echo "Hello {name}"

# Dropdown selection
git checkout {branch:main|develop|feature}

# Mixed parameters
curl -X {method:GET|POST} https://api.example.com/{endpoint}
```

When you run the command, CommandBar prompts for each parameter.

---

## Execution Types

| Type | Use Case | Features |
|------|----------|----------|
| **Terminal** | Interactive commands | Opens in iTerm2/Terminal, output saved to history |
| **Script** | Quick scripts with output | Parameter prompts, resizable result window |
| **Background** | Monitoring & automation | Silent execution, auto-repeat (10min to 7days) |
| **Schedule** | Reminders & alerts | Date/time picker, repeat options, pre-alerts |
| **API** | REST API testing | All HTTP methods, headers, body, file upload |

---

## Clipboard Manager

CommandBar automatically captures everything you copy:

- **Auto-capture**: Monitors clipboard in real-time
- **Search**: Find any copied text instantly
- **Favorites**: Star important clips for quick access
- **Calendar filter**: Browse by date
- **Send to Notes**: Export to Apple Notes app

**Tip**: In the vibe coding workflow, you're constantly copying AI-generated code. CommandBar keeps it all searchable and organized.

---

## API Testing

Built-in REST client for testing endpoints:

```
Method: POST
URL: https://api.example.com/users/{userId}
Headers:
  Authorization: Bearer {token}
  Content-Type: application/json
Body:
  {"name": "{userName}", "role": "admin"}
```

**Features**:
- GET, POST, PUT, DELETE, PATCH methods
- Custom headers and query parameters
- JSON, Form Data, Multipart body types
- File upload support with auto MIME detection
- Response saved to history

---

## Schedule & Reminders

Never miss a deadline:

- **Real-time countdown**: Shows "2 hours 30 min remaining"
- **Pre-alerts**: Notifications at 1hr, 30min, 10min, 5min, 1min before
- **Repeat options**: Daily, weekly, monthly
- **Visual feedback**: Shake animation when time arrives

---

## Window Features

| Feature | Description |
|---------|-------------|
| **Always on top** | Toggle to keep window visible |
| **Opacity control** | Adjust background transparency |
| **Auto-hide** | Hide when focus lost (toggle in titlebar) |
| **Position memory** | Remembers size and location |
| **Edge snap** | Quick buttons for left/right positioning |

---

## Data Organization

| Feature | Description |
|---------|-------------|
| **Groups** | Color-coded folders for commands |
| **Favorites** | Star icon for quick filtering |
| **Drag & drop** | Reorder commands and groups |
| **Trash** | Recover deleted items |
| **Pagination** | Choose 30, 50, or 100 items per page |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `↑` `↓` | Navigate items |
| `Enter` | Run selected command |
| `Delete` | Delete selected item |
| `Esc` | Close dialogs |

---

## Data Storage

All data stored locally in SQLite:
```
~/.command_bar/command_bar.db
```

**Backup**: Simply copy this file to backup all commands, history, and settings.

---

## Multi-language

- English, Korean, Japanese
- Export/Import custom language packs

---

## Requirements

- macOS 14.0+
- Swift 5.9+ (for building from source)

---

## License

MIT

---

## Tips for Vibe Coding

1. **Save AI-generated commands immediately** - When Claude/GPT gives you a useful command, save it before you forget
2. **Use parameters for flexibility** - Instead of saving 10 similar commands, save one with `{variables}`
3. **Check clipboard history** - That code snippet you copied 2 hours ago? It's still there
4. **Group by project** - Create color-coded groups for different projects
5. **Background monitoring** - Set up health checks for your dev servers
