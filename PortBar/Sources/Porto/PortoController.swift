//
// PortoController — the status-bar icon and its menu.
//
// The menu lists every open listening port; clicking a row closes the
// port by signalling the process that owns it.
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
                // Clicking a row closes the port.
                let item = NSMenuItem(
                    title: port.description,
                    action: #selector(closePort(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = port
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(
            title: "⟳ Refresh",
            action: #selector(refreshItemAction(_:)),
            keyEquivalent: ""
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

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

    @objc private func refreshItemAction(_ sender: NSMenuItem) {
        refresh()
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