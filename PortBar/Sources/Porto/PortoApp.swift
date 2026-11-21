//
// PortoApp — entry point for the Porto menu bar app.
//

import AppKit
import Foundation

@main
struct PortoApp {
    static func main() {
        // Debug helper: print the discovered listening ports and exit.
        if ProcessInfo.processInfo.arguments.contains("--dump-ports") {
            for port in PortDiscoverer.ports() {
                print(port.description)
            }
            return
        }

        // Debug helper: print the result of the update check and exit.
        if ProcessInfo.processInfo.arguments.contains("--check-updates") {
            let version = UpdateChecker.currentVersion ?? "0.0.0"  // bundle version, or a dev placeholder
            UpdateChecker.check(versionOverride: version) { result in
                switch result {
                case .upToDate:
                    print("Up to date.")
                case .updateAvailable(let update):
                    print("Update available: \(update.tag) — \(update.htmlURL.absoluteString)")
                case .failed(let message):
                    print("Update check failed: \(message)")
                }
                exit(0)
            }
            RunLoop.main.run()
            return
        }

        // Debug helper: toggle the login item and print the result.
        if ProcessInfo.processInfo.arguments.contains("--launch-at-login") {
            print("supported=\(LaunchAtLogin.isSupported) enabled=\(LaunchAtLogin.isEnabled)")
            do {
                let needsApproval = try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
                print("toggled -> enabled=\(LaunchAtLogin.isEnabled) needsApproval=\(needsApproval)")
            } catch {
                print("failed: \(error.localizedDescription)")
            }
            return
        }

        // Debug helper: download and install the latest release, then exit.
        if ProcessInfo.processInfo.arguments.contains("--install-update") {
            UpdateChecker.check { result in
                switch result {
                case .updateAvailable(let update):
                    print("Update available: \(update.tag)")
                    UpdateInstaller.downloadAndInstall(update) { installResult in
                        switch installResult {
                        case .success:
                            print("Update installed; relaunching…")
                            exit(0)
                        case .failure(let error):
                            print("Install failed: \(error.localizedDescription)")
                            exit(1)
                        }
                    }
                case .upToDate:
                    print("Up to date.")
                    exit(0)
                case .failed(let message):
                    print("Update check failed: \(message)")
                    exit(1)
                }
            }
            RunLoop.main.run()
            return
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        PortoController.shared.start()
        app.run()
    }
}