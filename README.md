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
make build
```

## Features

### 1. Terminal Command Execution
- Execute commands in iTerm2 or Terminal
- Runs in current terminal window
- Command output saved to history
- Double-click or right-click menu to run

### 2. Background Command Execution
- Run commands in background without terminal
- Results displayed in list
- Auto-repeat with interval setting
- Countdown display until next execution
- Remembers last execution time (resumes after app restart)
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

### 6. Clipboard
- Monitors clipboard history (max 10,000)
- Quick register as command
- Send to Apple Notes
- View full content in detail window

### 7. Groups
- Organize commands into groups with colors
- Filter by group in command list
- Drag and drop to reorder groups
- Group management page (folder icon in bottom bar)

### 8. Favorites
- Click star icon to toggle favorite
- Filter to show favorites only
- Works with group filter

### 9. API Requests
- One of five execution types (Terminal/Background/Script/Schedule/API)
- REST API testing functionality
- HTTP methods: GET, POST, PUT, DELETE, PATCH
- Configure headers, query parameters, and body data
- Parameter support: `{variableName}` format
  - Use in URL, headers, query parameters, and body
  - Prompts for values at execution time
  - Example: `https://api.example.com/users/{userId}`
- Body types:
  - JSON: Raw JSON format
  - Form Data: Key-value pairs
  - Multipart: File upload support
- File upload with automatic MIME type detection
- Save and view responses
- Response history tracking

### 10. Multi-language Support
- Korean, English, Japanese
- Export/Import custom language packs

## Usage

### Add Command
1. Click `+` button
2. Enter title
3. Select execution type:
   - **Terminal**: choose iTerm2 / Terminal
   - **Background**: set interval (0 for manual)
   - **Script**: supports `{name}` parameters
   - **Schedule**: set date/time, pre-alerts
   - **API**: configure HTTP request

### Run Command
- Double-click
- Right-click → Run

### Edit/Delete Command
- Right-click → Edit/Delete

### Reorder
- Drag and drop

### API Request Usage
1. Select **API** type when adding command
2. Configure request:
   - **Method**: GET, POST, PUT, DELETE, PATCH
   - **URL**: Enter endpoint URL (supports `{variableName}` parameters)
   - **Headers**: Add custom headers (key-value pairs, supports `{variableName}`)
   - **Query Parameters**: Add URL parameters (key-value pairs, supports `{variableName}`)
   - **Body**: Configure request body (supports `{variableName}`)
     - JSON: Raw JSON format
     - Form Data: Key-value pairs
     - Multipart: File upload with text parameters
3. Click **Send** or run command to execute
   - If using `{variableName}` parameters, you'll be prompted to enter values
4. View response in detail window:
   - Status code and response time
   - Response headers
   - Response body (formatted JSON or raw text)
5. Response saved to history for reference

### Bottom Buttons
- 📄 Command list
- ➕ Add command
- 📁 Group management
- 📋 Clipboard
- 🕐 History
- 🗑 Trash
- ⚙️ Settings

### Settings
- **General**: Always on top, Launch at login, Background opacity
- **History**: Max count
- **Clipboard**: Max count, Notes folder name
- **Backup**: Export/Import (JSON)
- **Language**: Korean/English/Japanese, Custom language pack

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

## API Request Examples

| Name | Method | URL | Description |
|------|--------|-----|-------------|
| Get Users | GET | `https://api.example.com/users` | Fetch user list |
| Get User by ID | GET | `https://api.example.com/users/{userId}` | Fetch specific user (prompts for userId) |
| Create User | POST | `https://api.example.com/users` | Create new user (JSON body) |
| Update User | PUT | `https://api.example.com/users/{userId}` | Update user data (prompts for userId) |
| Delete User | DELETE | `https://api.example.com/users/{userId}` | Delete user (prompts for userId) |
| Weather API | GET | `https://api.openweathermap.org/data/2.5/weather` | Get weather (query params: q, appid) |

### Example API Configuration

**GET Request with Query Parameters:**
- Method: GET
- URL: `https://api.github.com/users/octocat`
- Headers: `Accept: application/vnd.github.v3+json`

**GET Request with Variable Parameter:**
- Method: GET
- URL: `https://api.example.com/users/{userId}`
- Description: Prompts for userId value when executed

**POST Request with JSON Body:**
- Method: POST
- URL: `https://api.example.com/users`
- Headers: `Content-Type: application/json`
- Body (JSON):
  ```json
  {
    "name": "John Doe",
    "email": "john@example.com"
  }
  ```

**POST Request with Variable in Body:**
- Method: POST
- URL: `https://api.example.com/users`
- Headers: `Content-Type: application/json`
- Body (JSON):
  ```json
  {
    "name": "{userName}",
    "email": "{userEmail}"
  }
  ```
- Description: Prompts for userName and userEmail values when executed

**Multipart File Upload:**
- Method: POST
- URL: `https://api.example.com/upload`
- Body Type: Multipart
- Text Parameters: `description: My file`
- File Parameters: `file: /path/to/image.png`
- Description: Uploads file with automatic MIME type detection

## Data Storage

- Config: `~/.command_bar/app.json`
- History: `~/.command_bar/history.json`
- Clipboard: `~/.command_bar/clipboard.json`

## Requirements

- macOS 14.0+
- Swift 5.9+
