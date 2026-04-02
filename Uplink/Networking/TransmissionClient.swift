import Foundation

/// Errors that can occur during RPC communication.
enum TransmissionError: LocalizedError, Sendable {
    case notConfigured
    case invalidURL
    case httpError(statusCode: Int)
    case authenticationRequired
    case rpcError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "No server configured. Open Settings to add a connection."
        case .invalidURL:
            "The server URL is invalid. Check your connection settings."
        case .httpError(let code):
            "Server returned HTTP \(code)."
        case .authenticationRequired:
            "Authentication failed. Check your username and password in Settings."
        case .rpcError(let message):
            "RPC error: \(message)"
        case .networkError(let message):
            "Network error: \(message)"
        }
    }
}

/// A URLSession delegate that optionally bypasses SSL certificate validation.
///
/// When `allowUntrustedCerts` is `true`, the delegate accepts any server
/// certificate, including self-signed ones. This is useful for connecting
/// to Transmission daemons behind reverse proxies with self-signed certs.
///
/// Implements both session-level and task-level challenge handlers because
/// `URLSession` may deliver the TLS challenge at either level depending on
/// the server configuration and connection reuse.
private final class TrustAllCertsDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    var allowUntrustedCerts: Bool = false

    /// Handles the server trust challenge, returning credentials if untrusted certs are allowed.
    private func handleChallenge(
        _ challenge: URLAuthenticationChallenge
    ) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard allowUntrustedCerts,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: serverTrust))
    }

    // Session-level challenge (covers initial TLS handshake for the session)
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        handleChallenge(challenge)
    }

    // Task-level challenge (covers per-request TLS challenges and connection reuse)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        handleChallenge(challenge)
    }
}

/// The single point of contact with the Transmission RPC API.
///
/// Handles session ID negotiation (409 retry), authentication, and
/// all RPC method calls. All methods are async and throw `TransmissionError`.
@MainActor
final class TransmissionClient {
    private let sessionManager: SessionManager
    private let sslDelegate: TrustAllCertsDelegate
    private var urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var sessionId: String?

    /// Tracks the current trust policy so we can detect changes and recreate the session.
    private var currentAllowUntrustedCerts: Bool = false

    /// Tracks the current proxy configuration so we can detect changes and recreate the session.
    private var currentProxyFingerprint: String = ""

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        let delegate = TrustAllCertsDelegate()
        self.sslDelegate = delegate
        self.urlSession = URLSession(
            configuration: .ephemeral,
            delegate: delegate,
            delegateQueue: nil
        )
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// Clears the cached session ID. Call when switching servers.
    func clearSessionId() {
        sessionId = nil
        currentProxyFingerprint = ""
        // Invalidate the session to flush cached TLS and proxy state for the old server
        urlSession.invalidateAndCancel()
        urlSession = URLSession(
            configuration: .ephemeral,
            delegate: sslDelegate,
            delegateQueue: nil
        )
    }

    // MARK: - Public API

    /// Fetches all torrents with the standard field set.
    func getTorrents() async throws -> [Torrent] {
        let request = RPCRequest(
            method: "torrent-get",
            arguments: .torrentGet(fields: TorrentFields.standard)
        )
        let response: RPCResponse<TorrentGetResponse> = try await send(request)
        guard response.isSuccess, let args = response.arguments else {
            throw TransmissionError.rpcError(response.result)
        }
        return args.torrents
    }

    /// Adds a torrent by URL or magnet link.
    func addTorrent(url: String, downloadDir: String? = nil) async throws -> TorrentAddedInfo? {
        let request = RPCRequest(
            method: "torrent-add",
            arguments: .torrentAddURL(filename: url, downloadDir: downloadDir)
        )
        let response: RPCResponse<TorrentAddResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
        return response.arguments?.info
    }

    /// Adds a torrent from file data (base64 encoded).
    func addTorrent(fileData: Data, downloadDir: String? = nil) async throws -> TorrentAddedInfo? {
        let base64 = fileData.base64EncodedString()
        let request = RPCRequest(
            method: "torrent-add",
            arguments: .torrentAddFile(metainfo: base64, downloadDir: downloadDir)
        )
        let response: RPCResponse<TorrentAddResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
        return response.arguments?.info
    }

    /// Starts the specified torrents.
    func startTorrents(ids: [Int]) async throws {
        let request = RPCRequest(
            method: "torrent-start",
            arguments: .torrentAction(ids: ids)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Stops the specified torrents.
    func stopTorrents(ids: [Int]) async throws {
        let request = RPCRequest(
            method: "torrent-stop",
            arguments: .torrentAction(ids: ids)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Removes the specified torrents. Optionally deletes local data.
    func removeTorrents(ids: [Int], deleteLocalData: Bool = false) async throws {
        let request = RPCRequest(
            method: "torrent-remove",
            arguments: .torrentRemove(ids: ids, deleteLocalData: deleteLocalData)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Starts the specified torrents immediately, bypassing the queue.
    func startTorrentsNow(ids: [Int]) async throws {
        let request = RPCRequest(
            method: "torrent-start-now",
            arguments: .torrentAction(ids: ids)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Verifies (rechecks) the data of the specified torrents.
    func verifyTorrents(ids: [Int]) async throws {
        let request = RPCRequest(
            method: "torrent-verify",
            arguments: .torrentAction(ids: ids)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Reannounces (asks trackers for more peers) the specified torrents.
    func reannounceTorrents(ids: [Int]) async throws {
        let request = RPCRequest(
            method: "torrent-reannounce",
            arguments: .torrentAction(ids: ids)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Moves the specified torrents to a new download location on the server.
    func moveTorrents(ids: [Int], location: String, move: Bool = true) async throws {
        let request = RPCRequest(
            method: "torrent-set-location",
            arguments: .torrentSetLocation(ids: ids, location: location, move: move)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Moves the specified torrents to the top of the queue.
    func queueMoveTop(ids: [Int]) async throws {
        let request = RPCRequest(
            method: "queue-move-top",
            arguments: .queueMoveTop(ids: ids)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Moves the specified torrents up one position in the queue.
    func queueMoveUp(ids: [Int]) async throws {
        let request = RPCRequest(
            method: "queue-move-up",
            arguments: .queueMoveUp(ids: ids)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Moves the specified torrents down one position in the queue.
    func queueMoveDown(ids: [Int]) async throws {
        let request = RPCRequest(
            method: "queue-move-down",
            arguments: .queueMoveDown(ids: ids)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Moves the specified torrents to the bottom of the queue.
    func queueMoveBottom(ids: [Int]) async throws {
        let request = RPCRequest(
            method: "queue-move-bottom",
            arguments: .queueMoveBottom(ids: ids)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Sets file priorities and wanted status for a torrent.
    func setFiles(
        torrentId: Int,
        filesWanted: [Int]? = nil,
        filesUnwanted: [Int]? = nil,
        priorityHigh: [Int]? = nil,
        priorityNormal: [Int]? = nil,
        priorityLow: [Int]? = nil
    ) async throws {
        let request = RPCRequest(
            method: "torrent-set",
            arguments: .torrentSetFiles(
                ids: [torrentId],
                filesWanted: filesWanted,
                filesUnwanted: filesUnwanted,
                priorityHigh: priorityHigh,
                priorityNormal: priorityNormal,
                priorityLow: priorityLow
            )
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Updates per-torrent settings for the specified torrents.
    func setTorrentSettings(ids: [Int], settings: TorrentSettings) async throws {
        let request = RPCRequest(
            method: "torrent-set",
            arguments: .torrentSet(ids: ids, settings: settings)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Fetches the current daemon session settings.
    func getSessionSettings() async throws -> SessionSettings {
        let request = RPCRequest(
            method: "session-get",
            arguments: .sessionGet
        )
        let response: RPCResponse<SessionSettings> = try await send(request)
        guard response.isSuccess, let settings = response.arguments else {
            throw TransmissionError.rpcError(response.result)
        }
        return settings
    }

    /// Updates daemon session settings.
    func setSessionSettings(_ settings: SessionSettingsUpdate) async throws {
        let request = RPCRequest(
            method: "session-set",
            arguments: .sessionSet(settings: settings)
        )
        let response: RPCResponse<EmptyResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Fetches session-level statistics (speeds, counts, cumulative data).
    func getSessionStats() async throws -> SessionStats {
        let request = RPCRequest(
            method: "session-stats",
            arguments: .sessionStats
        )
        let response: RPCResponse<SessionStats> = try await send(request)
        guard response.isSuccess, let stats = response.arguments else {
            throw TransmissionError.rpcError(response.result)
        }
        return stats
    }

    /// Tests whether the configured peer port is reachable from outside.
    func testPort() async throws -> Bool {
        let request = RPCRequest(
            method: "port-test",
            arguments: .portTest
        )
        let response: RPCResponse<PortTestResponse> = try await send(request)
        guard response.isSuccess, let result = response.arguments else {
            throw TransmissionError.rpcError(response.result)
        }
        return result.portIsOpen
    }

    /// Triggers a blocklist update on the server. Returns the new blocklist size.
    func updateBlocklist() async throws -> Int {
        let request = RPCRequest(
            method: "blocklist-update",
            arguments: .blocklistUpdate
        )
        let response: RPCResponse<BlocklistUpdateResponse> = try await send(request)
        guard response.isSuccess, let result = response.arguments else {
            throw TransmissionError.rpcError(response.result)
        }
        return result.blocklistSize
    }

    /// Checks how much free space is available at the given path on the server.
    func getFreeSpace(path: String) async throws -> FreeSpaceResponse {
        let request = RPCRequest(
            method: "free-space",
            arguments: .freeSpace(path: path)
        )
        let response: RPCResponse<FreeSpaceResponse> = try await send(request)
        guard response.isSuccess, let result = response.arguments else {
            throw TransmissionError.rpcError(response.result)
        }
        return result
    }

    /// Renames a file or directory within a torrent.
    func renameTorrent(id: Int, path: String, name: String) async throws {
        let request = RPCRequest(
            method: "torrent-rename-path",
            arguments: .torrentRenamePath(ids: [id], path: path, name: name)
        )
        let response: RPCResponse<TorrentRenameResponse> = try await send(request)
        guard response.isSuccess else {
            throw TransmissionError.rpcError(response.result)
        }
    }

    /// Tests the connection by requesting the torrent list. Throws on failure.
    func testConnection() async throws {
        _ = try await getTorrents()
    }

    // MARK: - Internal Transport

    /// Sends an RPC request with automatic session ID handling (409 retry).
    private func send<T: Decodable>(_ rpcRequest: RPCRequest) async throws -> RPCResponse<T> {
        guard let server = sessionManager.activeServer else {
            throw TransmissionError.notConfigured
        }
        guard server.isConfigured else {
            throw TransmissionError.notConfigured
        }
        guard let url = server.url else {
            throw TransmissionError.invalidURL
        }

        // Detect if SSL trust or proxy config changed; if so, recreate the session.
        let newAllowUntrusted = server.useSSL && server.allowUntrustedCerts
        let newProxyFingerprint = server.proxyFingerprint
        let needsRecreation = (newAllowUntrusted != currentAllowUntrustedCerts)
            || (newProxyFingerprint != currentProxyFingerprint)

        if needsRecreation {
            currentAllowUntrustedCerts = newAllowUntrusted
            currentProxyFingerprint = newProxyFingerprint
            sslDelegate.allowUntrustedCerts = newAllowUntrusted
            urlSession.invalidateAndCancel()
            urlSession = URLSession(
                configuration: makeConfiguration(for: server),
                delegate: sslDelegate,
                delegateQueue: nil
            )
        }

        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if server.authRequired {
            let credentials = "\(server.username):\(server.password)"
            if let data = credentials.data(using: .utf8) {
                httpRequest.setValue(
                    "Basic \(data.base64EncodedString())",
                    forHTTPHeaderField: "Authorization"
                )
            }
        }

        httpRequest.httpBody = try encoder.encode(rpcRequest)

        // First attempt
        if let sessionId {
            httpRequest.setValue(sessionId, forHTTPHeaderField: "X-Transmission-Session-Id")
        }

        let (data, response) = try await performRequest(httpRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransmissionError.networkError("Invalid response from server.")
        }

        // Handle 409 session ID refresh
        if httpResponse.statusCode == 409 {
            if let newSessionId = httpResponse.value(forHTTPHeaderField: "X-Transmission-Session-Id") {
                self.sessionId = newSessionId
                httpRequest.setValue(newSessionId, forHTTPHeaderField: "X-Transmission-Session-Id")
                let (retryData, retryResponse) = try await performRequest(httpRequest)
                guard let retryHTTP = retryResponse as? HTTPURLResponse else {
                    throw TransmissionError.networkError("Invalid response from server.")
                }
                return try handleResponse(data: retryData, httpResponse: retryHTTP)
            }
        }

        return try handleResponse(data: data, httpResponse: httpResponse)
    }

    /// Creates an ephemeral URLSessionConfiguration with proxy settings from the given server.
    private func makeConfiguration(for server: ServerConfig) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral

        switch server.proxyType {
        case .none:
            break

        case .http:
            var dict: [String: Any] = [
                kCFNetworkProxiesHTTPEnable as String: true,
                kCFNetworkProxiesHTTPProxy as String: server.proxyHost,
                kCFNetworkProxiesHTTPPort as String: server.proxyPort,
            ]
            if server.proxyAuthRequired {
                dict[kCFProxyUsernameKey as String] = server.proxyUsername
                dict[kCFProxyPasswordKey as String] = server.proxyPassword
            }
            config.connectionProxyDictionary = dict

        case .https:
            var dict: [String: Any] = [
                kCFNetworkProxiesHTTPSEnable as String: true,
                kCFNetworkProxiesHTTPSProxy as String: server.proxyHost,
                kCFNetworkProxiesHTTPSPort as String: server.proxyPort,
            ]
            if server.proxyAuthRequired {
                dict[kCFProxyUsernameKey as String] = server.proxyUsername
                dict[kCFProxyPasswordKey as String] = server.proxyPassword
            }
            config.connectionProxyDictionary = dict

        case .socks5:
            var dict: [String: Any] = [
                kCFStreamPropertySOCKSProxyHost as String: server.proxyHost,
                kCFStreamPropertySOCKSProxyPort as String: server.proxyPort,
                kCFStreamPropertySOCKSVersion as String: kCFStreamSocketSOCKSVersion5,
            ]
            if server.proxyAuthRequired {
                dict[kCFStreamPropertySOCKSUser as String] = server.proxyUsername
                dict[kCFStreamPropertySOCKSPassword as String] = server.proxyPassword
            }
            config.connectionProxyDictionary = dict
        }

        return config
    }

    private nonisolated func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw TransmissionError.networkError(error.localizedDescription)
        }
    }

    private func handleResponse<T: Decodable>(
        data: Data, httpResponse: HTTPURLResponse
    ) throws -> RPCResponse<T> {
        switch httpResponse.statusCode {
        case 200:
            do {
                return try decoder.decode(RPCResponse<T>.self, from: data)
            } catch let decodingError as DecodingError {
                // Extract a useful description from the decoding error
                let detail: String
                switch decodingError {
                case .keyNotFound(let key, let context):
                    detail = "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
                case .typeMismatch(let type, let context):
                    detail = "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
                case .valueNotFound(let type, let context):
                    detail = "Null value for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
                case .dataCorrupted(let context):
                    detail = "Corrupted data at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
                @unknown default:
                    detail = decodingError.localizedDescription
                }
                throw TransmissionError.rpcError("Failed to decode response: \(detail)")
            } catch {
                let preview = String(data: data.prefix(200), encoding: .utf8) ?? "(binary data)"
                throw TransmissionError.rpcError(
                    "Invalid response from server. Expected JSON but got: \(preview)"
                )
            }
        case 401:
            throw TransmissionError.authenticationRequired
        default:
            // Include a snippet of the body for non-200 responses to aid debugging
            let body = String(data: data.prefix(200), encoding: .utf8) ?? ""
            if body.isEmpty {
                throw TransmissionError.httpError(statusCode: httpResponse.statusCode)
            }
            throw TransmissionError.networkError(
                "HTTP \(httpResponse.statusCode): \(body)"
            )
        }
    }
}

/// Empty response type for RPC calls that return no arguments.
struct EmptyResponse: Decodable, Sendable {}
