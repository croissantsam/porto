//
// PortDiscoverer — finds the open listening ports with `lsof`.
//

import Foundation

struct PortInfo: Hashable, Comparable {
    let port: Int
    let host: String
    let command: String
    let pid: Int
    let user: String

    var description: String {
        "\(host):\(port) — \(command)"
    }

    static func < (lhs: PortInfo, rhs: PortInfo) -> Bool {
        (lhs.port, lhs.pid) < (rhs.port, rhs.pid)
    }
}

enum PortDiscoverer {
    /// Returns the TCP ports currently in the LISTEN state, sorted by port.
    static func ports() -> [PortInfo] {
        guard let lsofPath = lsofPath() else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: lsofPath)
        process.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN"]
        process.standardError = FileHandle.nullDevice

        let output = Pipe()
        process.standardOutput = output

        do {
            try process.run()
        } catch {
            return []
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return parse(text)
    }

    static func parse(_ text: String) -> [PortInfo] {
        var result: [PortInfo] = []
        var seen = Set<String>()

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasSuffix("(LISTEN)") else { continue }

            // Extract the lsof NAME tail, e.g. "TCP [::1]:3000 (LISTEN)".
            let nameTail: String
            if let range = trimmed.range(of: "TCP ", options: .backwards),
               range.lowerBound > trimmed.startIndex {
                nameTail = String(trimmed[range.lowerBound...])
            } else {
                nameTail = trimmed
            }

            // The line starts with the lsof columns: COMMAND PID USER ...
            let tokens = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard tokens.count >= 3,
                  let pid = Int(String(tokens[1])),
                  let port = port(from: nameTail) else { continue }

            // One row per (process, port).
            guard seen.insert("\(pid):\(port)").inserted else { continue }

            result.append(PortInfo(
                port: port,
                host: host(from: nameTail),
                command: unescape(String(tokens[0])),
                pid: pid,
                user: String(tokens[2])
            ))
        }

        return result.sorted()
    }

    private static func unescape(_ text: String) -> String {
        // lsof escapes spaces in command names as `\x20`.
        text.replacingOccurrences(of: "\\x20", with: " ")
    }

    // MARK: - Parsing

    /// Parses the trailing `TCP *:3010 (LISTEN)` part of an lsof line into the port number.
    private static func port(from name: String) -> Int? {
        let base = name.dropLast("(LISTEN)".count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = base.lastIndex(of: ":"), colon > base.startIndex else { return nil }
        let digits = base[base.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(digits), port > 0 else { return nil }
        return port
    }

    private static func host(from name: String) -> String {
        let base = name.dropLast("(LISTEN)".count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = base.lastIndex(of: ":"), colon > base.startIndex else { return "localhost" }
        var host = String(base[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("TCP ") {
            host = String(host.dropFirst("TCP ".count))
        }
        host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        return host.isEmpty ? "*" : host
    }

    private static func lsofPath() -> String? {
        for candidate in ["/usr/sbin/lsof", "/usr/bin/lsof", "/bin/lsof", "lsof"] {
            if candidate.contains("/") {
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            } else if !candidate.isEmpty {
                // Fall back to the bare name; Process throws if it is missing.
                return candidate
            }
        }
        return nil
    }
}
