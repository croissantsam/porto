//
// UpdateInstaller — downloads a release zip and swaps in the new app bundle.
//
// The download is checksum-verified against the digest GitHub reports for the
// asset. After the current process exits, a small script moves the new bundle
// into place, relaunches the app, and removes the old bundle.
//

import CommonCrypto
import Foundation

enum UpdateInstallerError: LocalizedError {
    case missingDownloadURL
    case notAnAppBundle
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case extractionFailed(String)
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingDownloadURL:
            return "The release doesn't include a Porto-macos.zip asset."
        case .notAnAppBundle:
            return "Porto isn't running from an app bundle, so it can't update itself."
        case .downloadFailed(let message):
            return "Download failed: \(message)."
        case .checksumMismatch(let expected, let actual):
            return "Checksum mismatch (expected \(expected.prefix(12))…, got \(actual.prefix(12))…)."
        case .extractionFailed(let message):
            return "Couldn't unpack the update: \(message)."
        case .installFailed(let message):
            return message
        }
    }
}

enum UpdateInstaller {
    /// Downloads the release zip and installs it, then relaunches the app.
    /// Completion runs on the main queue and is called before the app quits.
    static func downloadAndInstall(
        _ update: AppUpdate,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let downloadURL = update.downloadURL else {
            completion(.failure(UpdateInstallerError.missingDownloadURL))
            return
        }

        var request = URLRequest(url: downloadURL)
        request.setValue("Porto/\(UpdateChecker.currentVersion ?? "0")", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60

        URLSession.shared.dataTask(with: request) { data, response, error in
            let result: Result<Void, Error>

            if let error {
                result = .failure(error)
            } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                result = .failure(UpdateInstallerError.downloadFailed("HTTP \(http.statusCode)"))
            } else if let data {
                result = install(data: data, update: update)
            } else {
                result = .failure(UpdateInstallerError.downloadFailed("empty response"))
            }

            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    // MARK: - Install

    private static func install(data: Data, update: AppUpdate) -> Result<Void, Error> {
        let fm = FileManager.default
        let oldAppURL = Bundle.main.bundleURL

        guard oldAppURL.pathExtension == "app" else {
            return .failure(UpdateInstallerError.notAnAppBundle)
        }
        guard fm.isWritableFile(atPath: oldAppURL.deletingLastPathComponent().path) else {
            return .failure(UpdateInstallerError.installFailed(
                "\(oldAppURL.deletingLastPathComponent().path) isn't writable, so Porto can't replace itself."
            ))
        }

        let tempDir = fm.temporaryDirectory.appendingPathComponent("PortoUpdate-\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            return .failure(UpdateInstallerError.installFailed(error.localizedDescription))
        }

        // Verify the release checksum before touching the installed app.
        if let expected = update.sha256 {
            let actual = sha256Hex(data)
            if actual != expected {
                return .failure(UpdateInstallerError.checksumMismatch(expected: expected, actual: actual))
            }
        }

        let zipURL = tempDir.appendingPathComponent("Porto-macos.zip")
        do {
            try data.write(to: zipURL)
        } catch {
            return .failure(UpdateInstallerError.installFailed(error.localizedDescription))
        }

        let extractDir = tempDir.appendingPathComponent("extracted")
        do {
            try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)
            try extract(zipURL: zipURL, to: extractDir)
        } catch {
            return .failure(UpdateInstallerError.extractionFailed(error.localizedDescription))
        }

        let newAppURL = extractDir.appendingPathComponent("Porto.app")
        guard fm.fileExists(atPath: newAppURL.appendingPathComponent("Contents/Info.plist").path) else {
            return .failure(UpdateInstallerError.extractionFailed("Porto.app was not found in the archive"))
        }

        scheduleSwapAndRelaunch(
            pid: ProcessInfo.processInfo.processIdentifier,
            oldAppURL: oldAppURL,
            newAppURL: newAppURL,
            tempDir: tempDir
        )
        return .success(())
    }

    private static func extract(zipURL: URL, to directory: URL) throws {
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zipURL.path, directory.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else {
            throw UpdateInstallerError.extractionFailed("ditto exited with status \(ditto.terminationStatus)")
        }
    }

    /// Waits for this process to exit, then moves the new bundle into place,
    /// relaunches the app, and cleans up.
    private static func scheduleSwapAndRelaunch(
        pid: Int32,
        oldAppURL: URL,
        newAppURL: URL,
        tempDir: URL
    ) {
        let backupURL = oldAppURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(oldAppURL.lastPathComponent).old-\(UUID().uuidString)")

        let script = """
        #!/bin/sh
        while kill -0 "$1" 2>/dev/null; do sleep 0.1; done
        mv "$2" "$3" || { open "$2"; exit 1; }
        mv "$4" "$2" || { mv "$3" "$2"; open "$2"; exit 1; }
        open "$2" || exit 1
        rm -rf "$3" "$5"
        """

        let scriptURL = tempDir.appendingPathComponent("relaunch.sh")
        try? script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "nohup /bin/sh \"$0\" \"$@\" >/dev/null 2>&1 &",
            scriptURL.path,
            String(pid),
            oldAppURL.path,
            backupURL.path,
            newAppURL.path,
            tempDir.path,
        ]
        try? process.run()
    }

    private static func sha256Hex(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { rawBuffer in
            _ = CC_SHA256(rawBuffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}