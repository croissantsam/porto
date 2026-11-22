//
// AboutWindowController — the "About Puerto" window.
//

import AppKit

final class AboutWindowController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    private static let website = "https://croissantlabs.com/en/apps/puerto"

    private var window: NSWindow?
    private var wasAccessory = false

    func show() {
        if window == nil {
            window = makeWindow()
        }

        // Accessory apps can't reliably own a key window; switch to a regular
        // app while the About window is open, then switch back on close.
        wasAccessory = NSApp.activationPolicy() == .accessory
        if wasAccessory { NSApp.setActivationPolicy(.regular) }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.center()
    }

    // MARK: - Window

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Puerto"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 300))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        window.contentView = content

        let iconView = NSImageView()
        iconView.image = appIcon()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: "Puerto")
        nameLabel.font = .boldSystemFont(ofSize: 24)
        nameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: versionString())
        versionLabel.font = .systemFont(ofSize: 13)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let copyrightLabel = NSTextField(labelWithString: "© 2026 CroissantLabs")
        copyrightLabel.font = .systemFont(ofSize: 11)
        copyrightLabel.textColor = .tertiaryLabelColor
        copyrightLabel.alignment = .center

        let stack = NSStackView(views: [
            iconView,
            nameLabel,
            versionLabel,
            copyrightLabel,
            makeLinkView(),
        ])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),

            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),
        ])

        return window
    }

    private func makeLinkView() -> NSTextView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 320, height: 20))
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false

        let title = "croissantlabs.com/en/apps/puerto"
        let attributed = NSMutableAttributedString(string: title)
        let range = NSRange(location: 0, length: (title as NSString).length)
        attributed.addAttribute(.link, value: Self.website, range: range)
        attributed.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
        attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        attributed.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: range)
        textView.textStorage?.setAttributedString(attributed)

        textView.widthAnchor.constraint(equalToConstant: 320).isActive = true
        textView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return textView
    }

    private func appIcon() -> NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }

    private func versionString() -> String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(shortVersion) (\(build))"
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if wasAccessory {
            NSApp.setActivationPolicy(.accessory)
            wasAccessory = false
        }
    }

    // MARK: - NSTextViewDelegate

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = link as? URL {
            NSWorkspace.shared.open(url)
        } else if let string = link as? String, let url = URL(string: string) {
            NSWorkspace.shared.open(url)
        }
        return true
    }
}