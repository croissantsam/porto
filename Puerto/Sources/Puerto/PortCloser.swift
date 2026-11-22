//
// PortCloser — sends signals to release a listening port.
//

import Darwin
import Foundation

enum PortCloser {
    /// How long to wait after SIGTERM before escalating to SIGKILL, so a
    /// database or dev server gets time to shut down cleanly.
    private static let escalationDelay: TimeInterval = 2.0

    /// Sends SIGTERM to the process owning the port, escalating to SIGKILL
    /// if the same process still owns the LISTEN socket shortly after.
    static func close(_ port: PortInfo) {
        guard port.user == NSUserName() else {
            // Not ours to signal.
            return
        }

        let pid = pid_t(port.pid)
        _ = Darwin.kill(pid, SIGTERM)

        // Off the main thread: the re-check shells out to lsof.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + escalationDelay) {
            guard stillOwnsPort(port: port, pid: pid) else {
                return
            }
            _ = Darwin.kill(pid, SIGKILL)
        }
    }

    /// True when `pid` still owns a LISTEN socket on `port` — i.e. the kernel
    /// hasn't recycled the PID for a different process. Re-resolve via lsof
    /// right before escalating: the original process may have exited by now.
    private static func stillOwnsPort(port: PortInfo, pid: pid_t) -> Bool {
        PortDiscoverer.ports().contains { $0.port == port.port && $0.pid == port.pid }
    }
}
