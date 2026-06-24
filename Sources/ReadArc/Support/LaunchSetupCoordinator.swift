import Foundation

enum LaunchSetupCoordinator {
    private static let didRunSetupKey = "readArc.didRunLaunchSetup.v1"

    @MainActor
    static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: didRunSetupKey) else {
            return
        }

        UserDefaults.standard.set(true, forKey: didRunSetupKey)
        prepareApplicationSupport()
        requestDocumentsAccess()
    }

    private static func prepareApplicationSupport() {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        let directories = [
            applicationSupport.appendingPathComponent("ReadArc", isDirectory: true),
            applicationSupport
                .appendingPathComponent("ReadArc", isDirectory: true)
                .appendingPathComponent("AgentWorkspace", isDirectory: true)
        ]

        for directory in directories {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private static func requestDocumentsAccess() {
        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        Task.detached(priority: .utility) {
            _ = try? FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
        }
    }
}
