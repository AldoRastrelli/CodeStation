<p align="center">
  <img src="assets/codestation.jpg" alt="CodeStation" width="600"/>
</p>

---

A macOS terminal multiplexer built with **SwiftUI** and **SwiftTerm**.

## Features

- **Multi-terminal grid layout** — Run multiple terminal sessions side by side in a configurable grid
- **Environments** — Organize terminals into named environments, each with its own set of sessions
- **Custom Prompt Buttons** — Create reusable command buttons that appear on each terminal header; tap to instantly send commands
- **Per-terminal collapse** — Expand or collapse the prompt buttons bar independently on each terminal
- **Notifications** — Get notified when long-running commands finish or when a terminal is waiting for input
- **Zoom controls** — Adjust terminal font size globally with keyboard shortcuts

## Getting Started

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+

### Build

```bash
xcodebuild -project CodeStation.xcodeproj -scheme CodeStation -configuration Release build
```

### Create DMG

```bash
xcodebuild -project CodeStation.xcodeproj -scheme CodeStation -configuration Release archive -archivePath build/CodeStation.xcarchive \
  && xcodebuild -exportArchive -archivePath build/CodeStation.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/export \
  && hdiutil create -volname CodeStation -srcfolder build/export/CodeStation.app -ov -format UDZO build/CodeStation.dmg
```

## Custom Prompt Buttons

Create buttons via **Settings > Custom Prompts** or the **+** button on any terminal header. Each button has:

- **Title** — Short label displayed on the button
- **Color** — Choose from blue, red, green, purple, orange, or pink
- **Prompt** — The command text sent to the terminal when tapped

Buttons are shared across all terminals and persisted between sessions.

## Architecture

```
CodeStation/
├── App/                    # App entry point, ContentView, BoardView, Settings
├── Grid/                   # Terminal grid layout
├── Model/                  # Data models (Environment, TerminalSession, PromptButton)
├── Resources/              # Asset catalog (icons, images)
├── Services/               # Persistence, Notifications
├── Sidebar/                # Sidebar navigation
├── Terminal/               # Terminal views and headers
├── Utilities/              # String constants, shell utilities, hooks
└── ViewModels/             # MVVM view models
```

## License

MIT
