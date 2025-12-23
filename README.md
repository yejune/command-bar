# CommandBar

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Your Best Partner in the AI Era**

Register everything as reusable commands, smartly manage history and clipboard. The essential partner for vibe coding.

A powerful command launcher, clipboard manager, and schedule reminder for macOS.

[한국어](README.ko.md)

## Installation

### Download (Recommended)
1. Download DMG from [Releases](https://github.com/yejune/command-bar/releases)
2. Open DMG and drag CommandBar to Applications
3. First run: Right-click → Open (bypass Gatekeeper)

### Build from Source
```bash
make build
```

## Features

### Command Execution

| Type | Description |
|------|-------------|
| **Terminal** | Execute in iTerm2 or Terminal, output saved to history |
| **Background** | Run silently with auto-repeat intervals (10min, 1hr, 6hr, 12hr, 24hr, 7days) |
| **Script** | Parameter support with resizable result window |
| **Schedule** | Date/time reminders with repeat (daily/weekly/monthly) and pre-alerts |
| **API** | REST API testing with all HTTP methods |

### Script Parameters
```bash
echo "Hello {name}"                      # Text input
curl -X {method:GET|POST|PUT} {url}      # Dropdown + text input
git checkout {branch:main|develop}       # Dropdown selection
```
- Shell special characters auto-escaped (`"`, `$`, `` ` ``, `\`)
- Smart quotes auto-converted

### Schedule Reminders
- Real-time countdown display (1 day, 2 hours, 30 seconds...)
- Pre-alerts: 1 hour, 30 min, 10 min, 5 min, 1 min before
- Shake effect when time comes
- One-time: shows checkmark / Repeating: auto-resets to next occurrence

### API Requests
- HTTP methods: GET, POST, PUT, DELETE, PATCH
- Headers, query parameters, body configuration
- Parameter support: `{variableName}` in URL, headers, body
- Body types: JSON, Form Data, Multipart (file upload)
- Response saved to history

### Data Management

| Feature | Description |
|---------|-------------|
| **History** | Execution records with calendar date picker, text search |
| **Clipboard** | Auto-capture with favorites, calendar filter, send to Apple Notes |
| **Groups** | Organize commands with colors, drag & drop reorder |
| **Favorites** | Star icon toggle for commands and clipboard items |
| **Trash** | Deleted items recoverable |
| **Pagination** | Infinite scroll or paging mode (30/50/100 items) |

### Window Features
- Always on top option
- Background opacity control
- Auto-hide when focus lost (titlebar toggle button)
- Window position/size remembered
- Snap to left/right edge buttons
- Double-click behavior setting (run vs edit)

### Multi-language
- Korean, English, Japanese
- Export/Import custom language packs

## Usage

### Add Command
1. Click `+` button
2. Enter title
3. Select execution type and configure
4. Save

### Run Command
- Double-click
- Right-click → Run

### Edit/Delete
- Right-click → Edit/Delete

### Reorder
- Drag and drop

### Bottom Bar
📄 Commands | ➕ Add | 📁 Groups | 📋 Clipboard | 🕐 History | 🗑 Trash | ⚙️ Settings

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `↑/↓` | Navigate items |
| `Enter` | Run selected |
| `Delete` | Delete selected |

## Examples

### Background Commands
| Command | Description | Interval |
|---------|-------------|----------|
| `date +%H:%M:%S` | Current time | 1s |
| `uptime` | System uptime | 60s |
| `df -h \| head -2` | Disk usage | 300s |
| `curl -s "wttr.in/Seoul?format=3"` | Seoul weather | 3600s |

### API Requests

**GET with parameter:**
```
URL: https://api.example.com/users/{userId}
→ Prompts for userId at execution
```

**POST with JSON body:**
```
URL: https://api.example.com/users
Headers: Content-Type: application/json
Body: {"name": "{userName}", "email": "{userEmail}"}
→ Prompts for userName, userEmail at execution
```

**Multipart file upload:**
```
URL: https://api.example.com/upload
Body Type: Multipart
Text: description: My file
File: file: /path/to/image.png
→ MIME type auto-detected
```

## Data Storage

All data stored in SQLite database:
```
~/.command_bar/command_bar.db
```

## Requirements

- macOS 14.0+
- Swift 5.9+

## License

MIT
