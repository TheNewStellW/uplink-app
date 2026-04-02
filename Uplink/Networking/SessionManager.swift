import Foundation
import Security

/// A mapping from a remote Transmission path to a locally accessible path.
///
/// Used to translate paths reported by the daemon (e.g. `/mnt/tank/Downloads`)
/// into paths accessible from the local machine (e.g. `/Volumes/tank/Downloads`).
struct PathMapping: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var remotePath: String
    var localPath: String
    /// Security-scoped bookmark data for sandbox access to the local path.
    var bookmark: Data?

    init(id: UUID = UUID(), remotePath: String = "", localPath: String = "", bookmark: Data? = nil) {
        self.id = id
        self.remotePath = remotePath
        self.localPath = localPath
        self.bookmark = bookmark
    }
}

/// The type of network proxy for RPC connections.
enum ProxyType: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, http, https, socks5

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .http: String(localized: "HTTP")
        case .https: String(localized: "HTTPS")
        case .socks5: String(localized: "SOCKS5")
        }
    }
}

/// Configuration for a single Transmission RPC server endpoint.
struct ServerConfig: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var rpcPath: String
    var useSSL: Bool
    var allowUntrustedCerts: Bool
    var authRequired: Bool
    var username: String
    var pathMappings: [PathMapping]
    var proxyType: ProxyType
    var proxyHost: String
    var proxyPort: Int
    var proxyAuthRequired: Bool
    var proxyUsername: String

    /// Password is NOT stored here — it lives in the Keychain keyed by `id`.
    /// This transient property is used only while editing in the UI.
    var password: String = ""

    /// Proxy password is NOT stored here — it lives in the Keychain keyed by `id`.
    /// This transient property is used only while editing in the UI.
    var proxyPassword: String = ""

    enum CodingKeys: String, CodingKey {
        case id, name, host, port, rpcPath, useSSL, allowUntrustedCerts, authRequired, username, pathMappings
        case proxyType, proxyHost, proxyPort, proxyAuthRequired, proxyUsername
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: Int = 9091,
        rpcPath: String = "/transmission/rpc",
        useSSL: Bool = false,
        allowUntrustedCerts: Bool = false,
        authRequired: Bool = false,
        username: String = "",
        password: String = "",
        pathMappings: [PathMapping] = [],
        proxyType: ProxyType = .none,
        proxyHost: String = "",
        proxyPort: Int = 8080,
        proxyAuthRequired: Bool = false,
        proxyUsername: String = "",
        proxyPassword: String = ""
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.rpcPath = rpcPath
        self.useSSL = useSSL
        self.allowUntrustedCerts = allowUntrustedCerts
        self.authRequired = authRequired
        self.username = username
        self.password = password
        self.pathMappings = pathMappings
        self.proxyType = proxyType
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
        self.proxyAuthRequired = proxyAuthRequired
        self.proxyUsername = proxyUsername
        self.proxyPassword = proxyPassword
    }

    /// Custom decoder for backward compatibility — existing servers lack proxy keys.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        rpcPath = try container.decode(String.self, forKey: .rpcPath)
        useSSL = try container.decode(Bool.self, forKey: .useSSL)
        allowUntrustedCerts = try container.decode(Bool.self, forKey: .allowUntrustedCerts)
        authRequired = try container.decode(Bool.self, forKey: .authRequired)
        username = try container.decode(String.self, forKey: .username)
        pathMappings = try container.decode([PathMapping].self, forKey: .pathMappings)
        proxyType = try container.decodeIfPresent(ProxyType.self, forKey: .proxyType) ?? .none
        proxyHost = try container.decodeIfPresent(String.self, forKey: .proxyHost) ?? ""
        proxyPort = try container.decodeIfPresent(Int.self, forKey: .proxyPort) ?? 8080
        proxyAuthRequired = try container.decodeIfPresent(Bool.self, forKey: .proxyAuthRequired) ?? false
        proxyUsername = try container.decodeIfPresent(String.self, forKey: .proxyUsername) ?? ""
    }

    /// A value summarising the proxy configuration, suitable for change detection.
    var proxyFingerprint: String {
        "\(proxyType.rawValue)|\(proxyHost)|\(proxyPort)|\(proxyAuthRequired)|\(proxyUsername)"
    }

    /// The fully constructed URL for the RPC endpoint.
    var url: URL? {
        var components = URLComponents()
        components.scheme = useSSL ? "https" : "http"
        components.host = host
        components.port = port
        components.path = rpcPath
        return components.url
    }

    /// Whether the config has enough info to attempt a connection.
    var isConfigured: Bool {
        !host.isEmpty
    }
}

/// Manages persistence of multiple server configurations.
///
/// Server list is stored as JSON in `UserDefaults`. Passwords are stored
/// in the system Keychain, keyed by each server's UUID.
@Observable
final class SessionManager: Sendable {
    private static let serversKey = "servers"
    private static let activeServerIdKey = "activeServerId"
    private static let keychainService = "com.transmissionremote.rpc"

    // Legacy keys for migration
    private static let legacyHostKey = "connection.host"
    private static let legacyPortKey = "connection.port"
    private static let legacyRpcPathKey = "connection.rpcPath"
    private static let legacyUseSSLKey = "connection.useSSL"
    private static let legacyAuthRequiredKey = "connection.authRequired"
    private static let legacyUsernameKey = "connection.username"

    /// All configured servers.
    private(set) var servers: [ServerConfig] = []

    /// The UUID of the currently active server.
    private(set) var activeServerId: UUID?

    /// Bookmark URLs whose security-scoped access has been started.
    /// Kept alive so the sandbox grant persists until explicitly released.
    private var activeSecurityScopedURLs: [URL] = []

    /// The currently active server configuration, with password loaded from Keychain.
    var activeServer: ServerConfig? {
        guard let id = activeServerId,
            var server = servers.first(where: { $0.id == id })
        else {
            return nil
        }
        server.password = Self.loadPassword(for: server.id)
        server.proxyPassword = Self.loadProxyPassword(for: server.id)
        return server
    }

    init() {
        let defaults = UserDefaults.standard

        // Try loading new multi-server format
        if let data = defaults.data(forKey: Self.serversKey),
            let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data)
        {
            self.servers = decoded
            if let idString = defaults.string(forKey: Self.activeServerIdKey),
                let id = UUID(uuidString: idString)
            {
                self.activeServerId = id
            } else if let first = decoded.first {
                self.activeServerId = first.id
            }
        } else {
            // Attempt legacy migration from single-server config
            migrateLegacyConfig()
        }
    }

    // MARK: - CRUD

    /// Adds a new server and persists it. Returns the created server.
    @discardableResult
    func addServer(_ server: ServerConfig) -> ServerConfig {
        var newServer = server
        // Ensure unique ID
        if servers.contains(where: { $0.id == newServer.id }) {
            newServer = ServerConfig(
                name: server.name,
                host: server.host,
                port: server.port,
                rpcPath: server.rpcPath,
                useSSL: server.useSSL,
                allowUntrustedCerts: server.allowUntrustedCerts,
                authRequired: server.authRequired,
                username: server.username,
                password: server.password,
                proxyType: server.proxyType,
                proxyHost: server.proxyHost,
                proxyPort: server.proxyPort,
                proxyAuthRequired: server.proxyAuthRequired,
                proxyUsername: server.proxyUsername,
                proxyPassword: server.proxyPassword
            )
        }

        if newServer.authRequired {
            Self.savePassword(newServer.password, for: newServer.id)
        }
        if newServer.proxyAuthRequired {
            Self.saveProxyPassword(newServer.proxyPassword, for: newServer.id)
        }

        servers.append(newServer)

        // Auto-activate if this is the first server
        if servers.count == 1 {
            activeServerId = newServer.id
        }

        persistServers()
        return newServer
    }

    /// Updates an existing server in place.
    func updateServer(_ server: ServerConfig) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }

        if server.authRequired {
            Self.savePassword(server.password, for: server.id)
        } else {
            Self.deletePassword(for: server.id)
        }

        if server.proxyAuthRequired {
            Self.saveProxyPassword(server.proxyPassword, for: server.id)
        } else {
            Self.deleteProxyPassword(for: server.id)
        }

        servers[index] = server
        persistServers()
    }

    /// Deletes a server by ID.
    func deleteServer(id: UUID) {
        Self.deletePassword(for: id)
        Self.deleteProxyPassword(for: id)
        servers.removeAll { $0.id == id }

        if activeServerId == id {
            activeServerId = servers.first?.id
        }

        persistServers()
    }

    /// Sets the active server by ID.
    func setActiveServer(id: UUID) {
        guard servers.contains(where: { $0.id == id }) else { return }
        activeServerId = id
        let defaults = UserDefaults.standard
        defaults.set(id.uuidString, forKey: Self.activeServerIdKey)
    }

    /// Loads the password for a server from the Keychain.
    func password(for serverId: UUID) -> String {
        Self.loadPassword(for: serverId)
    }

    /// Loads the proxy password for a server from the Keychain.
    func proxyPassword(for serverId: UUID) -> String {
        Self.loadProxyPassword(for: serverId)
    }

    // MARK: - Path Mapping

    /// Resolves a remote path to a local file URL using the active server's path mappings.
    ///
    /// Finds the first mapping whose `remotePath` is a prefix of the given path,
    /// replaces the prefix with `localPath`, and returns the result as a file URL.
    /// Trailing slashes are normalised so mappings work regardless of how the user entered them.
    /// Returns `nil` if no mapping matches.
    func resolveLocalPath(_ remotePath: String) -> URL? {
        guard let server = activeServer else { return nil }
        let normalizedInput = remotePath.hasSuffix("/") ? String(remotePath.dropLast()) : remotePath

        for mapping in server.pathMappings {
            let remote = mapping.remotePath.hasSuffix("/")
                ? String(mapping.remotePath.dropLast()) : mapping.remotePath
            let local = mapping.localPath.hasSuffix("/")
                ? String(mapping.localPath.dropLast()) : mapping.localPath
            guard !remote.isEmpty, !local.isEmpty else { continue }

            if normalizedInput == remote || normalizedInput.hasPrefix(remote + "/") {
                let suffix = String(normalizedInput.dropFirst(remote.count))
                let resolved = local + suffix
                return URL(fileURLWithPath: resolved)
            }
        }
        return nil
    }

    /// Starts security-scoped access for the mapping that matches the given remote path.
    ///
    /// Returns the resolved local URL with security access started, or `nil` if no mapping
    /// matches or the bookmark is unavailable. The bookmark URL is stored in
    /// `activeSecurityScopedURLs` so its scope stays alive; call `stopSecurityScopedAccess()`
    /// to release all held scopes.
    func resolveLocalPathWithAccess(_ remotePath: String) -> URL? {
        guard let server = activeServer else { return nil }
        let normalizedInput = remotePath.hasSuffix("/") ? String(remotePath.dropLast()) : remotePath

        for mapping in server.pathMappings {
            let remote = mapping.remotePath.hasSuffix("/")
                ? String(mapping.remotePath.dropLast()) : mapping.remotePath
            let local = mapping.localPath.hasSuffix("/")
                ? String(mapping.localPath.dropLast()) : mapping.localPath
            guard !remote.isEmpty, !local.isEmpty else { continue }

            if normalizedInput == remote || normalizedInput.hasPrefix(remote + "/") {
                let suffix = String(normalizedInput.dropFirst(remote.count))

                // Try to resolve via security-scoped bookmark first
                if let bookmarkData = mapping.bookmark {
                    var isStale = false
                    if let bookmarkURL = try? URL(
                        resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    ) {
                        if isStale {
                            refreshBookmark(for: mapping.id, url: bookmarkURL)
                        }
                        if bookmarkURL.startAccessingSecurityScopedResource() {
                            activeSecurityScopedURLs.append(bookmarkURL)
                        }
                        // Build the resolved path as a plain file URL under the
                        // now-accessible bookmark directory so the sandbox permits it.
                        let resolvedPath = bookmarkURL.path + suffix
                        return URL(fileURLWithPath: resolvedPath)
                    }
                }

                // Fall back to plain path (works outside sandbox or for already-permitted paths)
                let resolved = local + suffix
                return URL(fileURLWithPath: resolved)
            }
        }
        return nil
    }

    /// Stops security-scoped access for all bookmark URLs that were activated
    /// by previous `resolveLocalPathWithAccess` calls.
    func stopSecurityScopedAccess() {
        for url in activeSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeSecurityScopedURLs.removeAll()
    }

    /// Creates a security-scoped bookmark for the given URL and stores it in the mapping.
    func saveBookmark(for mappingId: UUID, url: URL) {
        guard let serverIndex = servers.firstIndex(where: { $0.pathMappings.contains(where: { $0.id == mappingId }) }),
              let mappingIndex = servers[serverIndex].pathMappings.firstIndex(where: { $0.id == mappingId })
        else { return }

        if let bookmarkData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            servers[serverIndex].pathMappings[mappingIndex].bookmark = bookmarkData
            persistServers()
        }
    }

    /// Refreshes a stale bookmark.
    private func refreshBookmark(for mappingId: UUID, url: URL) {
        saveBookmark(for: mappingId, url: url)
    }

    // MARK: - Persistence

    private func persistServers() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(servers) {
            defaults.set(data, forKey: Self.serversKey)
        }
        if let id = activeServerId {
            defaults.set(id.uuidString, forKey: Self.activeServerIdKey)
        } else {
            defaults.removeObject(forKey: Self.activeServerIdKey)
        }
    }

    // MARK: - Legacy Migration

    private func migrateLegacyConfig() {
        let defaults = UserDefaults.standard
        guard let host = defaults.string(forKey: Self.legacyHostKey), !host.isEmpty else {
            return
        }

        let storedPort = defaults.integer(forKey: Self.legacyPortKey)
        let username = defaults.string(forKey: Self.legacyUsernameKey) ?? ""
        let password = Self.loadLegacyPassword(for: username)

        let server = ServerConfig(
            name: host,
            host: host,
            port: storedPort != 0 ? storedPort : 9091,
            rpcPath: defaults.string(forKey: Self.legacyRpcPathKey) ?? "/transmission/rpc",
            useSSL: defaults.bool(forKey: Self.legacyUseSSLKey),
            authRequired: defaults.bool(forKey: Self.legacyAuthRequiredKey),
            username: username,
            password: password
        )

        // Add without going through the public method to avoid double-persist
        if server.authRequired {
            Self.savePassword(password, for: server.id)
        }
        servers.append(server)
        activeServerId = server.id
        persistServers()

        // Clean up legacy keys
        defaults.removeObject(forKey: Self.legacyHostKey)
        defaults.removeObject(forKey: Self.legacyPortKey)
        defaults.removeObject(forKey: Self.legacyRpcPathKey)
        defaults.removeObject(forKey: Self.legacyUseSSLKey)
        defaults.removeObject(forKey: Self.legacyAuthRequiredKey)
        defaults.removeObject(forKey: Self.legacyUsernameKey)
    }

    // MARK: - Keychain Helpers

    private static func savePassword(_ password: String, for serverId: UUID) {
        guard let data = password.data(using: .utf8) else { return }
        let account = serverId.uuidString

        // Delete any existing item first
        deletePassword(for: serverId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadPassword(for serverId: UUID) -> String {
        let account = serverId.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
            let password = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return password
    }

    private static func deletePassword(for serverId: UUID) {
        let account = serverId.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Proxy Keychain Helpers

    private static func saveProxyPassword(_ password: String, for serverId: UUID) {
        guard let data = password.data(using: .utf8) else { return }
        let account = serverId.uuidString + ".proxy"

        deleteProxyPassword(for: serverId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadProxyPassword(for serverId: UUID) -> String {
        let account = serverId.uuidString + ".proxy"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
            let password = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return password
    }

    private static func deleteProxyPassword(for serverId: UUID) {
        let account = serverId.uuidString + ".proxy"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Loads a password using the legacy account-name-based lookup (for migration).
    private static func loadLegacyPassword(for account: String) -> String {
        guard !account.isEmpty else { return "" }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
            let password = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return password
    }
}
