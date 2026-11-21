//
// PortoController — the status-bar icon and its menu.
//
// The menu lists every open listening port; each port has a submenu
// with a "✕ Close" action to release the port.
//

import AppKit
import Foundation

final class PortoController: NSObject, NSMenuDelegate {
    static let shared = PortoController()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private var ports: [PortInfo] = []
    private var menuIsOpen = false

    func start() {
        statusItem.menu = menu
        menu.delegate = self
        updateTitle()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, !self.menuIsOpen else { return }
            self.refresh()
        }
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

        let quitItem = NSMenuItem(title: "Quit Porto", action: #selector(quitAction(_:)), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func updateTitle() {
        statusItem.button?.title = ports.isEmpty ? "🔌" : "🔌 \(ports.count)"
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

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        refresh()
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
        refresh()
    }
}