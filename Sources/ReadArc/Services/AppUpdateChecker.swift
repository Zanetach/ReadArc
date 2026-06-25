import AppKit
import Foundation

enum AppUpdateChecker {
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/Zanetach/ReadArc/releases/latest")
    private static let releasesPageURL = URL(string: "https://github.com/Zanetach/ReadArc/releases")

    static func latestReleaseVersion() async throws -> String {
        try await fetchLatestRelease().displayVersion
    }

    @MainActor
    static func checkForUpdates(language: AppLanguage) {
        Task {
            do {
                let release = try await fetchLatestRelease()
                await MainActor.run {
                    presentResult(for: release, language: language.resolved)
                }
            } catch let error as UpdateCheckError {
                await MainActor.run {
                    presentError(error, language: language.resolved)
                }
            } catch {
                await MainActor.run {
                    presentError(.network(error.localizedDescription), language: language.resolved)
                }
            }
        }
    }

    private static func fetchLatestRelease() async throws -> GitHubRelease {
        guard let latestReleaseURL else {
            throw UpdateCheckError.network("Invalid update URL.")
        }

        var request = URLRequest(url: latestReleaseURL)
        request.timeoutInterval = 8
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ReadArc", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateCheckError.network("Invalid server response.")
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        case 404:
            throw UpdateCheckError.noRelease
        default:
            throw UpdateCheckError.network("GitHub returned HTTP \(httpResponse.statusCode).")
        }
    }

    @MainActor
    private static func presentResult(for release: GitHubRelease, language: AppLanguage) {
        let currentVersion = Bundle.main.readArcShortVersion
        let currentDisplayVersion = Bundle.main.readArcDisplayVersion
        let latestVersion = release.displayVersion
        let hasUpdate = VersionComparator.isVersion(latestVersion, newerThan: currentVersion)

        let alert = NSAlert()
        alert.alertStyle = .informational

        if hasUpdate {
            alert.messageText = L10n.text("updates.available.title", language: language)
            alert.informativeText = String(
                format: L10n.text("updates.available.message", language: language),
                currentDisplayVersion,
                latestVersion
            )
            alert.addButton(withTitle: L10n.text("updates.openReleases", language: language))
            alert.addButton(withTitle: L10n.text("updates.later", language: language))
        } else {
            alert.messageText = L10n.text("updates.current.title", language: language)
            alert.informativeText = String(
                format: L10n.text("updates.current.message", language: language),
                currentDisplayVersion
            )
            alert.addButton(withTitle: L10n.text("updates.ok", language: language))
        }

        if alert.runModal() == .alertFirstButtonReturn, hasUpdate {
            if let url = release.htmlURL ?? releasesPageURL {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @MainActor
    private static func presentError(_ error: UpdateCheckError, language: AppLanguage) {
        let alert = NSAlert()
        alert.alertStyle = .warning

        switch error {
        case .noRelease:
            alert.messageText = L10n.text("updates.noRelease.title", language: language)
            alert.informativeText = L10n.text("updates.noRelease.message", language: language)
            alert.addButton(withTitle: L10n.text("updates.openReleases", language: language))
            alert.addButton(withTitle: L10n.text("updates.ok", language: language))
            if alert.runModal() == .alertFirstButtonReturn {
                if let releasesPageURL {
                    NSWorkspace.shared.open(releasesPageURL)
                }
            }
        case .network(let message):
            alert.messageText = L10n.text("updates.failed.title", language: language)
            alert.informativeText = message
            alert.addButton(withTitle: L10n.text("updates.ok", language: language))
            alert.runModal()
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: URL?

    var displayVersion: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
    }
}

private enum UpdateCheckError: Error {
    case noRelease
    case network(String)
}

private enum VersionComparator {
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = numericParts(candidate)
        let currentParts = numericParts(current)
        let count = max(candidateParts.count, currentParts.count)

        for index in 0..<count {
            let candidateValue = index < candidateParts.count ? candidateParts[index] : 0
            let currentValue = index < currentParts.count ? currentParts[index] : 0
            if candidateValue != currentValue {
                return candidateValue > currentValue
            }
        }

        return false
    }

    private static func numericParts(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split { !$0.isNumber }
            .compactMap { Int($0) }
    }
}

extension Bundle {
    var readArcShortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    }

    var readArcBuildVersion: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var readArcDisplayVersion: String {
        "\(readArcShortVersion) (\(readArcBuildVersion))"
    }
}
