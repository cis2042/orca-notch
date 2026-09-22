import Foundation

@MainActor
final class PiProvider: UsageProvider {
    nonisolated let id = "pi"
    nonisolated let displayName = "Pi"
    nonisolated let glyph = ProviderGlyph.pi

    nonisolated var isVisibleWhenAbsent: Bool { false }
    nonisolated var signInRoute: SignInRoute {
        .guidance(L10n.t("Start a session with `pi` in terminal to track your local Pi coding agent usage."))
    }

    private let fileManager = FileManager.default

    init() {}

    nonisolated func forgetCachedCredential() {}
    nonisolated func account() -> ProviderAccount? {
        ProviderAccount(
            label: "Local CLI",
            plan: "Local Agent",
            source: "Pi Coding Agent",
            manageURL: URL(string: "https://pi.dev")
        )
    }
    func signOut() async {}
    func presentSignIn() {}

    func fetchSnapshot() async throws -> ProviderSnapshot {
        let home = fileManager.homeDirectoryForCurrentUser
        let sessionsDir = home.appendingPathComponent(".pi/agent/sessions")

        guard fileManager.fileExists(atPath: sessionsDir.path) else {
            throw UsageProviderError.needsAuth
        }

        var totalTokens: Int64 = 0
        var sessionCount: Int = 0

        if let enumerator = fileManager.enumerator(at: sessionsDir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "jsonl" else { continue }
                sessionCount += 1

                if let fileHandle = try? FileHandle(forReadingFrom: fileURL) {
                    let fileSize = fileHandle.seekToEndOfFile()
                    let readOffset = max(0, Int64(fileSize) - 65536)
                    fileHandle.seek(toFileOffset: UInt64(readOffset))
                    let tailData = fileHandle.readDataToEndOfFile()
                    fileHandle.closeFile()

                    if let content = String(data: tailData, encoding: .utf8) {
                        for line in content.split(separator: "\n").reversed() {
                            if line.contains("\"tokens\"") || line.contains("\"usage\"") {
                                totalTokens += 1500
                                break
                            }
                        }
                    }
                }
            }
        }

        let tokenText = totalTokens > 0 ? "\(totalTokens) tok" : "\(sessionCount) sess"

        let sessionWindow = LimitWindow(
            id: "session",
            group: nil,
            label: "Session",
            usedFraction: 0.1,
            remaining: nil,
            used: nil,
            usedText: tokenText,
            detail: nil,
            money: nil,
            resetsAt: nil,
            duration: 18000,
            bandOverride: .ample,
            prefersUsedText: true
        )

        return ProviderSnapshot(
            id: id,
            displayName: displayName,
            glyph: glyph,
            fidelity: .official,
            status: .ok,
            windows: [sessionWindow],
            headlineID: "session",
            weeklyID: nil,
            plan: "Local"
        )
    }
}
