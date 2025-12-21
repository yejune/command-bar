# CommandBar

Command launcher and schedule reminder app for macOS

[한국어](README.ko.md)

## Installation

### Download (Recommended)
1. Download DMG from [Releases](https://github.com/yejune/command-bar/releases)
2. Open DMG and drag CommandBar to Applications
3. First run: Right-click → Open (bypass Gatekeeper)

### Build from Source
```bash
swift build -c release
cp .build/release/CommandBar CommandBar.app/Contents/MacOS/CommandBar
cp -r CommandBar.app /Applications/
```

## Features

### 1. Terminal Command Execution
- Execute commands in iTerm2 or Terminal
- Double-click or right-click menu to run

### 2. Background Command Execution
- Run commands in background without terminal
- Results displayed in list
- Auto-repeat with interval setting
- Countdown display until next execution
- Interval presets: 10min, 1hr, 6hr, 12hr, 24hr, 7days

### 3. Script Execution
- Parameter support: `{paramName}` format
- Option selection: `{paramName:option1|option2|option3}` format
- Parameter values required at execution
- Results shown in resizable window
- Auto-escape shell special characters (`"`, `$`, `` ` ``, `\`)
- Smart quotes auto-conversion

```bash
# Examples
echo "Hello {name}"                    # name text input
curl -X {method:GET|POST|PUT} {url}    # method dropdown, url text input
git checkout {branch:main|develop}     # branch dropdown selection
```

### 4. Schedule Reminders
- Set date/time for reminders
- Repeat options: daily, weekly, monthly
- Real-time countdown display (1 day, 2 hours, 30 seconds...)
- Pre-alerts: 1 hour, 30 min, 10 min, 5 min, 1 min before
- Shake effect when time comes
- Click to acknowledge:
  - One-time: shows checkmark
  - Repeating: auto-resets to next occurrence

### 5. History
- Saves all execution records (max 100)
- Record types: executed, background, script, schedule alert, pre-alert, added, deleted, restored, removed
- Detail view: shows executed command + output

## Usage

### Add Command
1. Click `+` button
2. Enter title
3. Select execution type:
   - **Terminal**: choose iTerm2 / Terminal
   - **Background**: set interval (0 for manual)
   - **Script**: supports `{name}` parameters
   - **Schedule**: set date/time, pre-alerts

### Run Command
- Double-click
- Right-click → Run

### Edit/Delete Command
- Right-click → Edit/Delete

### Reorder
- Drag and drop

### Bottom Buttons
- 📄 Command list
- ➕ Add command
- 🕐 History
- 🗑 Trash
- ⚙️ Settings

### Settings
- Always on top
- Export/Import settings (JSON)

## Keyboard Shortcuts

- `↑/↓`: Select item
- `Enter`: Run selected item
- `Delete`: Delete selected item

## Background Command Examples

| Command | Description | Interval |
|---------|-------------|----------|
| `date +%H:%M:%S` | Current time | 1s |
| `uptime` | System uptime | 60s |
| `df -h \| head -2` | Disk usage | 300s |
| `curl -s "wttr.in/Seoul?format=3"` | Seoul weather | 3600s |

## Data Storage

- Config: `~/.command_bar/app.json`
- History: `~/.command_bar/history.json`

## Requirements

- macOS 14.0+
- Swift 5.9+
