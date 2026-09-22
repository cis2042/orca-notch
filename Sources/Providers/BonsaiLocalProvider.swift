import Foundation

@MainActor
final class BonsaiLocalProvider: UsageProvider {
    nonisolated let id = "bonsai-local"
    nonisolated let displayName = "Bonsai 2 27B"
    nonisolated let glyph = ProviderGlyph.bonsai
    nonisolated let kind = ProviderKind.localRuntime

    nonisolated var isVisibleWhenAbsent: Bool { false }
    nonisolated var signInRoute: SignInRoute {
        .guidance(L10n.t("Start the local Bonsai server with start_server.sh to monitor your local model."))
    }

    var endpoint: URL
    private let session: URLSession

    init(endpoint: URL = URL(string: "http://127.0.0.1:8080")!, session: URLSession? = nil) {
        self.endpoint = endpoint
        self.session = session ?? Self.makeSession()
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        var request = URLRequest(url: endpoint.appendingPathComponent("health"))
        request.timeoutInterval = 3
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch where error is CancellationError || (error as? URLError)?.code == .cancelled {
            throw CancellationError()
        } catch {
            throw UsageProviderError.needsAuth
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw UsageProviderError.badResponse(status: status)
        }

        let model = LocalRuntimeReading.Model(
            name: "Ternary-Bonsai-2-27B",
            memoryBytes: 7_200_000_000,
            contextLength: 65536,
            quantizationLevel: "PQ2_0 (1.72 bpw)",
            gpuMemoryBytes: 7_200_000_000,
            expiresAt: nil,
            memoryKind: .allocation,
            modelKey: "bonsai-2-27b"
        )

        let reading = LocalRuntimeReading(
            models: [model],
            summary: "Bonsai 2 27B · Metal GPU Active"
        )

        return ProviderSnapshot(
            id: id,
            displayName: displayName,
            glyph: glyph,
            fidelity: .official,
            status: .ok,
            windows: [],
            kind: kind,
            localRuntime: reading
        )
    }

    nonisolated func forgetCachedCredential() {}
    nonisolated func account() -> ProviderAccount? {
        ProviderAccount(
            label: "127.0.0.1:8080",
            plan: "Local (Metal)",
            source: "llama-server",
            manageURL: URL(string: "http://127.0.0.1:8080")
        )
    }
    func signOut() async {}
    func presentSignIn() {}

    nonisolated static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.connectionProxyDictionary = [:]
        return URLSession(configuration: configuration)
    }
}
