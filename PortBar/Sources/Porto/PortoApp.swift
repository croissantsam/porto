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

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        PortoController.shared.start()
        app.run()
    }
}