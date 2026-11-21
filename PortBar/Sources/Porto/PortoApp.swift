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

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        PortoController.shared.start()
        app.run()
    }
}