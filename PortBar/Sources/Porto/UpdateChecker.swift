//
// UpdateChecker — checks GitHub Releases for a newer version of Porto.
//
// On every launch the app asks GitHub for the latest published release
// and compares its tag against the version in Info.plist.
//

import Foundation

struct AppUpdate: Equatable {
    /// Version string without the leading "v" (e.g. "1.2.3").
    let version: String
    /// Full release tag as published (e.g. "v1.2.3").
    let tag: String
    /// Release page on GitHub.
    let htmlURL: URL
    /// Direct download URL for the release zip, if the release has one.
    let downloadURL: URL?
    /// SHA-256 of the zip from the GitHub API, without the "sha256:" prefix.
    let sha256: String?
}

enum UpdateCheckResult: Equatable {
    case upToDate
    case updateAvailable(AppUpdate)
    case failed(String)
}

enum UpdateChecker {
    /// GitHub repository that publishes the releases (owner/name).
    static let repository = "croissantsam/porto"

    private static let releasesURL = URL(
        string: "https://api.github.com/repos/\(repository)/releases/latest"
    )!

    enum UpdateError: LocalizedError {
        case notBundled
        case httpStatus(Int)
        case malformedResponse

        var errorDescription: String? {
            switch self {
            case .notBundled:
                return "Porto is not running from an app bundle, so its version is unknown."
            case .httpStatus(let code):
                return "GitHub returned HTTP \(code)."
            case .malformedResponse:
                return "GitHub returned an unexpected response."
            }
        }
    }

    /// Version from Info.plist, or nil when running outside an app bundle (e.g. `swift run`).
    static var currentVersion: String? {
        guard
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            !version.isEmpty
        else { return nil }
        return version
    }

    /// Fetches the latest release. Completion always runs on the main queue.
    /// `versionOverride` is only used by the `--check-updates` debug flag.
    static func check(
        versionOverride: String? = nil,
        completion: @escaping (UpdateCheckResult) -> Void
    ) {
        guard let currentVersion = versionOverride ?? currentVersion else {
            completion(.failed(UpdateError.notBundled.localizedDescription))
            return
        }

        var request = URLRequest(url: releasesURL)
        request.setValue("Porto/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, response, error in
            let result: UpdateCheckResult

            if let error {
                result = .failed(error.localizedDescription)
            } else if let http = response as? HTTPURLResponse,
                      !(200..<300).contains(http.statusCode) {
                result = .failed(UpdateError.httpStatus(http.statusCode).localizedDescription)
            } else if let data,
                      let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) {
                let asset = release.assets.first { $0.name == "Porto-macos.zip" }
                let update = AppUpdate(
                    version: normalizedVersion(release.tagName),
                    tag: release.tagName,
                    htmlURL: release.htmlURL,
                    downloadURL: asset?.browserDownloadURL,
                    sha256: normalizedDigest(asset?.digest)
                )
                result = isNewer(update.version, than: currentVersion)
                    ? .updateAvailable(update)
                    : .upToDate
            } else {
                result = .failed(UpdateError.malformedResponse.localizedDescription)
            }

            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    /// True when `candidate` is a strictly newer version than `current`.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = versionComponents(candidate)
        let b = versionComponents(current)

        for index in 0..<max(a.count, b.count) {
            let lhs = index < a.count ? a[index] : 0
            let rhs = index < b.count ? b[index] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    /// "v1.2.3-beta" → "1.2.3"
    private static func normalizedVersion(_ tag: String) -> String {
        var version = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if version.hasPrefix("v") || version.hasPrefix("V") { version.removeFirst() }
        if let cut = version.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            version = String(version[version.startIndex..<cut])
        }
        return version
    }

    /// "sha256:abc123" → "abc123"; nil for any other digest format.
    private static func normalizedDigest(_ digest: String?) -> String? {
        guard let digest else { return nil }
        let parts = digest.split(separator: ":")
        guard parts.count == 2, parts[0].lowercased() == "sha256" else { return nil }
        let hex = String(parts[1]).lowercased()
        return hex.isEmpty ? nil : hex
    }

    private static func versionComponents(_ version: String) -> [Int] {
        normalizedVersion(version)
            .split(separator: ".")
            .map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case digest
        }
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: URL
        let assets: [GitHubAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case assets
        }
    }
}