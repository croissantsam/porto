//
// LaunchAtLogin — "Launch at Login" support via SMAppService.
//
// macOS 13+ exposes SMAppService.mainApp, which registers the app itself as a
// login item. Older systems have no supported API for this, so the menu item
// is hidden there.
//

import Foundation
import ServiceManagement

enum LaunchAtLoginError: LocalizedError {
    case unsupported
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Launch at Login requires macOS 13 or newer."
        case .registrationFailed(let message):
            return message
        }
    }
}

enum LaunchAtLogin {
    /// macOS 13+ only.
    static var isSupported: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    /// True when macOS has the app enabled as a login item.
    static var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// True when the app is registered but waiting for the user's approval
    /// in System Settings → General → Login Items & Extensions.
    static var requiresApproval: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .requiresApproval
    }

    /// Registers or unregisters the app as a login item.
    /// Returns true when macOS needs the user to approve it in System Settings.
    @discardableResult
    static func setEnabled(_ enabled: Bool) throws -> Bool {
        guard #available(macOS 13.0, *) else {
            throw LaunchAtLoginError.unsupported
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            throw LaunchAtLoginError.registrationFailed(error.localizedDescription)
        }

        return requiresApproval
    }
}