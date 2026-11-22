# Puerto

A macOS menu bar app that shows your open TCP ports and lets you close them with a click.

![Puerto menu](https://github.com/user-attachments/assets/puerto-menu.png)

## Features

- **Menu bar icon** — a monochrome template plug glyph with the count of open ports; it flips between black and white to match the menu bar
- **App icon** — custom plug icon for Finder, the Dock, and the app switcher
- **Click to expand** — each port shows as a submenu with a **✕ Close** action
- **Auto-refresh** — menu updates every time you open it; background timer updates the count every 2s
- **In-app updates** — checks GitHub for a newer release at launch, then downloads, verifies, and installs it from the menu before relaunching
- **Launch at Login** — menu-bar toggle that registers Puerto as a login item (macOS 13+)
- **Filters Apple system processes** — hides `rapportd`, `ControlCenter`, and 40+ other macOS daemons
- **Safe close** — sends `SIGTERM` then escalates to `SIGKILL` after 0.4s
- **Only your processes** — won't touch ports owned by other users
- **No Dock icon** — pure menu bar app (`LSUIElement`)

## Requirements

- macOS 12+
- Xcode Command Line Tools (`xcode-select --install`)

## Quick Start (Development)

```bash
cd Puerto
swift run Puerto                # Run the menu bar app
swift run Puerto --dump-ports   # List ports to terminal (debug)
swift run Puerto --check-updates  # Print the latest release / update result (debug)
```

## Build the .app Bundle

```bash
cd Puerto
./scripts/build_app.sh
```

This creates `Puerto.app` in the `Puerto` folder. Double-click to run, or drag to `/Applications`.

## Install with Homebrew

```bash
brew tap croissantsam/tap
brew trust --cask croissantsam/tap/puerto   # Homebrew 7+ requires trusting third-party taps
brew install --cask puerto
```

Later upgrades:

```bash
brew upgrade --cask puerto
```

The cask lives in [`croissantsam/homebrew-tap`](https://github.com/croissantsam/homebrew-tap)
and is bumped automatically whenever a release is published (see below).

## How It Works

| Component | Purpose |
|-----------|---------|
| `PuertoApp.swift` | `@main` entry point; handles `--dump-ports` / `--check-updates` flags |
| `PuertoController.swift` | Status bar item, menu, auto-refresh timer, update menu items |
| `PortDiscoverer.swift` | Runs `lsof -nP -iTCP -sTCP:LISTEN`, parses output, filters Apple daemons |
| `PortCloser.swift` | Sends `SIGTERM` → `SIGKILL` to the owning PID |
| `UpdateChecker.swift` | Fetches the latest GitHub release and compares versions |
| `UpdateInstaller.swift` | Downloads the release zip, verifies its SHA-256, swaps in the new bundle, relaunches |
| `LaunchAtLogin.swift` | Registers/unregisters the app as a login item (`SMAppService`, macOS 13+) |

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
  ✓ Launch at Login
  ⬇ Update available — v1.2.3   (only when a newer release exists)
  Check for Updates…
  ───
  Quit Puerto
```

## Versioning & Releases

The GitHub Actions workflow (`.github/workflows/release.yml`) runs on every push to `main`:

1. **Determines version**:
   - Tagged `v*` → uses tag (e.g., `v1.2.0` → version `1.2.0`)
   - Untagged → `0.0.<commit-count>-<short-sha>` (e.g., `0.0.42-d9f3048`)
2. Builds release binary
3. Assembles `Puerto.app` with versioned `Info.plist`
4. Zips it → `Puerto-macos.zip`
5. Creates a GitHub Release with the zip as an asset
6. Also uploads the zip as a workflow artifact (30-day retention)
7. Bumps the `puerto` cask in [`croissantsam/homebrew-tap`](https://github.com/croissantsam/homebrew-tap)
   with the new version and checksum (needs a `HOMEBREW_TAP_TOKEN` repo secret —
   a fine-grained PAT with **Contents: read/write** on the tap repo; the step
   skips itself if the secret is absent)

Builds run on `macos-latest`, which tracks the newest GitHub-hosted macOS image,
so the newest Xcode/Swift toolchain is used without a pinned `setup-swift` step.
A weekly **Toolchain check** workflow compares the runner's Swift with the latest
swift.org release and opens a tracking issue when they differ.

**To cut a proper release:**
```bash
git tag v1.0.0
git push origin v1.0.0
```

## Project Structure

```
Puerto/
├── Package.swift                    # SwiftPM package (name: "Puerto")
├── README.md                        # This file
├── .gitignore
├── scripts/
│   ├── build_app.sh                 # Builds Puerto.app locally
│   ├── generate_info_plist.sh       # Generates versioned Info.plist (Python)
│   └── make_app_icon.swift          # Draws Resources/AppIcon.icns
├── Resources/
│   ├── AppIcon.icns                 # App icon (all sizes)
│   └── AppIcon.png                  # 1024×1024 master
├── Sources/Puerto/
│   ├── PuertoApp.swift              # @main entry
│   ├── PuertoController.swift       # Menu bar + menu logic
│   ├── PortDiscoverer.swift         # lsof parsing + Apple process filter
│   ├── PortCloser.swift             # SIGTERM/SIGKILL
│   ├── UpdateChecker.swift          # GitHub release check
│   ├── UpdateInstaller.swift        # Download/verify/swap/relaunch
│   └── LaunchAtLogin.swift          # SMAppService login-item toggle
└── Puerto.app/                      # Built bundle (after build_app.sh)
```

## Regenerating the App Icon

```bash
cd Puerto
swift scripts/make_app_icon.swift
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
```

## License

MIT — do whatever you want.