//
// PortCloser — sends signals to release a listening port.
//

import Darwin
import Foundation

enum PortCloser {
    /// Sends SIGTERM to the process owning the port, escalating to SIGKILL
    /// if it is still alive shortly after.
    static func close(_ port: PortInfo) {
        guard port.user == NSUserName() else {
            // Not ours to signal.
            return
        }

        let pid = pid_t(port.pid)
        _ = Darwin.kill(pid, SIGTERM)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if Darwin.kill(pid, 0) == 0 {
                _ = Darwin.kill(pid, SIGKILL)
            }
        }
    }
}
