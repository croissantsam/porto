//
// PuertoController — the status-bar icon and its menu.
//
// The menu lists every open listening port; each port has a submenu
// with a "✕ Close" action to release the port.
//

import AppKit
import Foundation

final class PuertoController: NSObject, NSMenuDelegate {
    static let shared = PuertoController()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private var ports: [PortInfo] = []
    private var menuIsOpen = false

    private var availableUpdate: AppUpdate?
    private var isCheckingForUpdates = false
    private var isDownloadingUpdate = false
    private let aboutWindow = AboutWindowController()

    /// Monochrome menu-bar glyph; rendered as a template image so it follows
    /// the light/dark menu bar like every other status item.
    private let statusIcon: NSImage? = PuertoController.makeStatusIcon()

    /// Cached so the 2-second menu refresh doesn't query ServiceManagement each time.
    private var launchAtLoginEnabled = LaunchAtLogin.isEnabled

    private static func makeStatusIcon() -> NSImage? {
        // SF Symbols need macOS 11+; older systems fall back to the emoji title.
        guard #available(macOS 11.0, *) else { return nil }

        guard let symbol = NSImage(
            systemSymbolName: "powerplug",
            accessibilityDescription: "Open ports"
        ) else { return nil }

        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = symbol.withSymbolConfiguration(configuration) ?? symbol
        image.isTemplate = true
        return image
    }

    func start() {
        statusItem.menu = menu
        menu.delegate = self

        if let statusIcon {
            let button = statusItem.button
            button?.image = statusIcon
            button?.imagePosition = .imageLeading
            button?.imageScaling = .scaleProportionallyDown
        }

        updateTitle()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, !self.menuIsOpen else { return }
            self.refresh()
        }
        checkForUpdates()
    }

    func refresh() {
        ports = PortDiscoverer.ports()
        rebuildMenu()
        updateTitle()
    }

    // MARK: - Menu

    private func rebuildMenu() {
        menu.removeAllItems()

        if ports.isEmpty {
            let none = NSMenuItem(title: "No open ports", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        } else {
            for port in ports {
                // Parent item: shows port info, has submenu
                let parentItem = NSMenuItem(title: port.description, action: nil, keyEquivalent: "")
                // Don't disable - we want normal text color. No action = click does nothing.

                let submenu = NSMenu()
                let closeItem = NSMenuItem(
                    title: "✕ Close",
                    action: #selector(closePort(_:)),
                    keyEquivalent: ""
                )
                closeItem.target = self
                closeItem.representedObject = port
                submenu.addItem(closeItem)

                parentItem.submenu = submenu
                menu.addItem(parentItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(
            title: "About Puerto…",
            action: #selector(showAbout(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        if LaunchAtLogin.isSupported {
            let loginItem = NSMenuItem(
                title: "Launch at Login",
                action: #selector(toggleLaunchAtLogin(_:)),
                keyEquivalent: ""
            )
            loginItem.target = self
            loginItem.state = launchAtLoginEnabled ? .on : .off
            menu.addItem(loginItem)
        }

        if let availableUpdate {
            let updateItem = NSMenuItem(
                title: isDownloadingUpdate
                    ? "Updating to v\(availableUpdate.version)…"
                    : "⬇  Update available — v\(availableUpdate.version)",
                action: #selector(downloadUpdateAction(_:)),
                keyEquivalent: ""
            )
            updateItem.target = self
            updateItem.isEnabled = !isDownloadingUpdate
            menu.addItem(updateItem)
        }

        let checkItem = NSMenuItem(
            title: isCheckingForUpdates ? "Checking for updates…" : "Check for Updates…",
            action: #selector(checkForUpdatesAction(_:)),
            keyEquivalent: ""
        )
        checkItem.target = self
        checkItem.isEnabled = !isCheckingForUpdates
        menu.addItem(checkItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Puerto", action: #selector(quitAction(_:)), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func updateTitle() {
        guard let button = statusItem.button else { return }

        if statusIcon != nil {
            // Template icon carries the glyph; the title is just the count.
            button.title = ports.isEmpty ? "" : "\(ports.count)"
        } else {
            button.title = ports.isEmpty ? "🔌" : "🔌 \(ports.count)"
        }
    }

    // MARK: - Actions

    @objc private func closePort(_ sender: NSMenuItem) {
        guard let port = sender.representedObject as? PortInfo else { return }
        sender.isEnabled = false
        PortCloser.close(port)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refresh()
        }
    }

    @objc private func quitAction(_ sender: NSMenuItem) {
        NSApp.terminate(self)
    }

    // MARK: - Updates

    private func checkForUpdates(manual: Bool = false) {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        rebuildMenuIfHidden()

        UpdateChecker.check { [weak self] result in
            guard let self else { return }
            self.isCheckingForUpdates = false

            switch result {
            case .upToDate:
                self.availableUpdate = nil
                if manual {
                    self.showAlert(
                        title: "Puerto is up to date",
                        message: "You're running version \(UpdateChecker.currentVersion ?? "—"), the latest release."
                    )
                }
            case .updateAvailable(let update):
                self.availableUpdate = update
                // Ask first — never install without the user's say-so.
                self.showUpdateAvailableAlert(for: update)
            case .failed(let message):
                if manual {
                    self.showAlert(title: "Couldn't check for updates", message: message)
                }
            }

            self.rebuildMenuIfHidden()
        }
    }

    private func rebuildMenuIfHidden() {
        guard !menuIsOpen else { return }   // menuWillOpen refreshes anyway
        rebuildMenu()
    }

    /// Runs a modal alert. Accessory apps can't reliably own a modal window, so
    /// temporarily switch to a regular app while it's up.
    private func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let wasAccessory = NSApp.activationPolicy() == .accessory
        if wasAccessory { NSApp.setActivationPolicy(.regular) }
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if wasAccessory { NSApp.setActivationPolicy(.accessory) }
        return response
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        _ = runAlert(alert)
    }

    /// Shown at startup (and after a manual check) when a newer release exists.
    /// Nothing is downloaded or installed until the user chooses "Install Update".
    private func showUpdateAvailableAlert(for update: AppUpdate) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Puerto \(update.version) is available"
        alert.informativeText = "A new version of Puerto is ready to install. Update now?"
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")

        guard runAlert(alert) == .alertFirstButtonReturn else { return }
        downloadUpdate(update)
    }

    private func downloadUpdate(_ update: AppUpdate) {
        guard !isDownloadingUpdate else { return }

        isDownloadingUpdate = true
        rebuildMenuIfHidden()

        UpdateInstaller.downloadAndInstall(update) { [weak self] result in
            guard let self else { return }
            self.isDownloadingUpdate = false

            switch result {
            case .success:
                // The relaunch script starts the new build once this process exits.
                NSApp.terminate(self)
            case .failure(let error):
                self.showAlert(title: "Couldn't install the update", message: error.localizedDescription)
                self.rebuildMenuIfHidden()
            }
        }
    }

    @objc private func downloadUpdateAction(_ sender: NSMenuItem) {
        guard let availableUpdate else { return }
        downloadUpdate(availableUpdate)
    }

    @objc private func checkForUpdatesAction(_ sender: NSMenuItem) {
        checkForUpdates(manual: true)
    }

    @objc private func showAbout(_ sender: NSMenuItem) {
        aboutWindow.show()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let shouldEnable = !LaunchAtLogin.isEnabled

        do {
            let needsApproval = try LaunchAtLogin.setEnabled(shouldEnable)
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
            if shouldEnable && needsApproval {
                showLaunchAtLoginApprovalAlert()
            }
        } catch {
            showAlert(
                title: "Couldn't change Launch at Login",
                message: error.localizedDescription
            )
        }

        rebuildMenuIfHidden()
    }

    private func showLaunchAtLoginApprovalAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Allow Puerto to launch at login"
        alert.informativeText = """
        Puerto was added to your login items, but macOS needs your approval.
        Open System Settings → General → Login Items & Extensions and turn on Puerto.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        guard runAlert(alert) == .alertFirstButtonReturn else { return }
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        refresh()
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
        refresh()
    }
}