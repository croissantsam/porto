# Porto

A macOS menu bar app that shows your open TCP ports and lets you close them with a click.

![Porto menu](https://github.com/user-attachments/assets/porto-menu.png)

## Features

- **Menu bar icon** showing the count of open ports (`🔌 N`)
- **Click to expand** — each port shows as a submenu with a **✕ Close** action
- **Auto-refresh** — menu updates every time you open it; background timer updates the count every 2s
- **Filters Apple system processes** — hides `rapportd`, `ControlCenter`, `postgres`, and 40+ other macOS daemons
- **Safe close** — sends `SIGTERM` then escalates to `SIGKILL` after 0.4s
- **Only your processes** — won't touch ports owned by other users
- **No Dock icon** — pure menu bar app (`LSUIElement`)

## Requirements

- macOS 12+
- Xcode Command Line Tools (`xcode-select --install`)

## Quick Start (Development)

```bash
cd PortBar
swift run Porto                # Run the menu bar app
swift run Porto --dump-ports   # List ports to terminal (debug)
```

## Build the .app Bundle

```bash
cd PortBar
./scripts/build_app.sh
```

This creates `Porto.app` in the `PortBar` folder. Double-click to run, or drag to `/Applications`.

## How It Works

| Component | Purpose |
|-----------|---------|
| `PortoApp.swift` | `@main` entry point; handles `--dump-ports` flag |
| `PortoController.swift` | Status bar item, menu, auto-refresh timer |
| `PortDiscoverer.swift` | Runs `lsof -nP -iTCP -sTCP:LISTEN`, parses output, filters Apple daemons |
| `PortCloser.swift` | Sends `SIGTERM` → `SIGKILL` to the owning PID |

The menu structure:
```
🔌 5 ▾
  [::1]:3000 — node ▸
    ✕ Close
  127.0.0.1:5432 — postgres ▸
    ✕ Close
  *:8080 — python3 ▸
    ✕ Close
  ───
  Quit Porto
```

## Versioning & Releases

The GitHub Actions workflow (`.github/workflows/release.yml`) runs on every push to `main`:

1. **Determines version**:
   - Tagged `v*` → uses tag (e.g., `v1.2.0` → version `1.2.0`)
   - Untagged → `0.0.<commit-count>-<short-sha>` (e.g., `0.0.42-d9f3048`)
2. Builds release binary
3. Assembles `Porto.app` with versioned `Info.plist`
4. Zips it → `Porto-macos.zip`
5. Creates a GitHub Release with the zip as an asset
6. Also uploads the zip as a workflow artifact (30-day retention)

**To cut a proper release:**
```bash
git tag v1.0.0
git push origin v1.0.0
```

## Project Structure

```
PortBar/
├── Package.swift                    # SwiftPM package (name: "Porto")
├── README.md                        # This file
├── .gitignore
├── scripts/
│   ├── build_app.sh                 # Builds Porto.app locally
│   └── generate_info_plist.sh       # Generates versioned Info.plist (Python)
├── Sources/Porto/
│   ├── PortoApp.swift               # @main entry
│   ├── PortoController.swift        # Menu bar + menu logic
│   ├── PortDiscoverer.swift         # lsof parsing + Apple process filter
│   └── PortCloser.swift             # SIGTERM/SIGKILL
└── Porto.app/                       # Built bundle (after build_app.sh)
```

## License

MIT — do whatever you want.