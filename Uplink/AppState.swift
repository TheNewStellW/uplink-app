import AppKit
import Foundation
import SwiftUI
import UserNotifications

/// Top-level observable application state.
///
/// Owns the `TransmissionClient` and `SessionManager`, manages the connection
/// lifecycle, torrent polling, and tracks the currently selected torrent.
@Observable
@MainActor
final class AppState {
    // MARK: - Dependencies

    let sessionManager: SessionManager
    let client: TransmissionClient

    // MARK: - Connection State

    enum ConnectionStatus: Sendable {
        case disconnected
        case connecting
        case connected
        case error(String)
        case reconnecting
    }

    private(set) var connectionStatus: ConnectionStatus = .disconnected

    /// Whether we are currently connected to the server.
    var isConnected: Bool {
        if case .connected = connectionStatus { return true }
        return false
    }

    /// Whether the app is currently in reconnection mode.
    var isReconnecting: Bool {
        if case .reconnecting = connectionStatus { return true }
        return false
    }

    // MARK: - Torrent State

    private(set) var torrents: [Torrent] = []
    var selectedTorrentIds: Set<Int> = []
    var selectedFilter: TorrentFilter = .all
    var sortOrder: TorrentSortOrder = .queuePosition
    var sortAscending: Bool = true
    var listDisplayMode: ListDisplayMode = .detailed
    var searchText: String = ""
    var selectedLabelFilter: String?

    /// Sort comparators for the Table display mode. Managed by SwiftUI Table.
    var tableSortOrder: [KeyPathComparator<Torrent>] = [KeyPathComparator(\Torrent.name)]

    /// The currently selected torrent for the detail panel (first of selection).
    var selectedTorrent: Torrent? {
        guard let id = selectedTorrentIds.first else { return nil }
        return torrents.first { $0.id == id }
    }

    /// Sorted unique labels across all torrents.
    var uniqueLabels: [String] {
        let allLabels = torrents.flatMap(\.labels)
        return Array(Set(allLabels)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Torrents filtered by sidebar, search, and label, without sorting applied.
    /// Used as the base for both list and table display modes.
    private var baseFilteredTorrents: [Torrent] {
        var filtered = torrents.filter { selectedFilter.matches($0) }
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let label = selectedLabelFilter {
            filtered = filtered.filter { $0.labels.contains(label) }
        }
        return filtered
    }

    /// Torrents filtered and sorted for the Table display mode.
    var tableFilteredTorrents: [Torrent] {
        baseFilteredTorrents.sorted(using: tableSortOrder)
    }

    /// Torrents filtered by the current sidebar selection, search text, label, and sorted
    /// using the list/compact mode sort settings.
    var filteredTorrents: [Torrent] {
        baseFilteredTorrents.sorted { a, b in
            let result: Bool
            switch sortOrder {
            case .name:
                result = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .status:
                result = a.status.rawValue < b.status.rawValue
            case .percentDone:
                result = a.percentDone < b.percentDone
            case .rateDownload:
                result = a.rateDownload < b.rateDownload
            case .rateUpload:
                result = a.rateUpload < b.rateUpload
            case .totalSize:
                result = a.totalSize < b.totalSize
            case .uploadRatio:
                result = a.uploadRatio < b.uploadRatio
            case .addedDate:
                result = a.addedDate < b.addedDate
            case .queuePosition:
                result = a.queuePosition < b.queuePosition
            case .eta:
                // -1 and -2 are special values; push them to end
                let aEta = a.eta < 0 ? Int.max : a.eta
                let bEta = b.eta < 0 ? Int.max : b.eta
                result = aEta < bEta
            }
            return sortAscending ? result : !result
        }
    }

    /// Total download speed across all torrents.
    var totalDownloadSpeed: Int {
        torrents.reduce(0) { $0 + $1.rateDownload }
    }

    /// Total upload speed across all torrents.
    var totalUploadSpeed: Int {
        torrents.reduce(0) { $0 + $1.rateUpload }
    }

    // MARK: - Session Settings

    /// The cached daemon session settings. Nil if not yet fetched.
    private(set) var sessionSettings: SessionSettings?

    /// The cached session statistics. Nil if not yet fetched.
    private(set) var sessionStats: SessionStats?

    // MARK: - Error State

    /// An error message to display as an inline banner.
    var errorMessage: String?

    /// When true, the current error is an authentication failure and the user
    /// should be prompted to check their server credentials.
    var showAuthenticationError: Bool = false

    /// Whether the Add Torrent sheet should be presented.
    var showingAddTorrent: Bool = false

    /// When set, the Settings window should open the Servers tab and select this server.
    /// Cleared after the Settings view consumes it.
    var pendingSettingsServerId: UUID?

    /// When set, the Settings window should open the Servers tab, and the
    /// specific sub-tab (e.g. `.connection`) for the pending server.
    var pendingSettingsTab: ServerSettingsSubTab?

    /// When true, the Settings window should create a new server entry when it opens.
    var pendingAddServer: Bool = false

    /// When true, a view with access to `@Environment(\.openSettings)` should open Settings.
    /// Set by Commands structs that cannot access the environment directly.
    var openSettingsRequested: Bool = false

    /// Pending magnet URL to add (set by onOpenURL or drag-and-drop).
    var pendingMagnetURL: String?

    /// Pending .torrent file data to add (set by onOpenURL or drag-and-drop).
    var pendingTorrentFileData: Data?

    /// Pending .torrent file name for display.
    var pendingTorrentFileName: String?

    // MARK: - Menu-Triggered UI State

    /// Whether the remove confirmation dialog is showing.
    var showingRemoveConfirmation = false

    /// IDs queued for removal (set before showing confirmation dialog).
    var idsToRemove: Set<Int> = []

    /// Whether to delete local data when removing. Set before confirming.
    var deleteLocalDataOnRemove = false

    /// Whether the move torrent sheet is showing.
    var showingMoveTorrent = false

    /// IDs queued for moving.
    var idsToMove: Set<Int> = []

    /// The new location path for the move operation.
    var moveLocation: String = ""

    /// Whether the rename sheet is showing.
    var showingRenameSheet = false

    /// The torrent being renamed.
    var renameTargetId: Int?

    /// The new name for the rename operation.
    var newName: String = ""

    // MARK: - Notifications

    /// Tracks torrent IDs that were not yet complete on the previous poll,
    /// so we can detect the transition to 100%.
    private var previousCompletionStates: [Int: Double] = [:]

    /// Whether the user has been asked for notification permission this session.
    private var notificationPermissionRequested = false

    // MARK: - Polling

    private var pollingTask: Task<Void, Never>?
    private var pollCycleCount: Int = 0
    private static let activePollInterval: TimeInterval = 3
    private static let backgroundPollInterval: TimeInterval = 10

    // MARK: - Reconnection

    /// Number of consecutive polling failures.
    private var consecutiveFailures: Int = 0

    /// Seconds remaining until the next reconnection attempt.
    private(set) var reconnectCountdown: Int = 0

    /// The task running the reconnection countdown loop.
    private var reconnectTask: Task<Void, Never>?

    /// Number of consecutive failures before entering reconnection mode.
    private static let failureThresholdForReconnect = 3

    /// Maximum backoff delay in seconds.
    private static let maxReconnectDelay: Int = 30

    // MARK: - Initialisation

    init() {
        let sessionManager = SessionManager()
        self.sessionManager = sessionManager
        self.client = TransmissionClient(sessionManager: sessionManager)
    }

    // MARK: - Server

    /// The display name of the currently active server.
    var activeServerName: String? {
        sessionManager.activeServer?.name
    }

    /// Whether there is at least one server configured.
    var hasServers: Bool {
        !sessionManager.servers.isEmpty
    }

    /// Whether the active server has enough info to connect.
    var isActiveServerConfigured: Bool {
        sessionManager.activeServer?.isConfigured ?? false
    }

    /// Resolves a remote path to a local file URL using the active server's path mappings.
    func resolveLocalPath(_ remotePath: String) -> URL? {
        sessionManager.resolveLocalPath(remotePath)
    }

    /// Resolves a remote path with security-scoped bookmark access for sandbox compatibility.
    func resolveLocalPathWithAccess(_ remotePath: String) -> URL? {
        sessionManager.resolveLocalPathWithAccess(remotePath)
    }

    /// Switches to a different server: disconnects, changes active, reconnects.
    func switchServer(to id: UUID) async {
        disconnect()
        sessionManager.setActiveServer(id: id)
        client.clearSessionId()
        if isActiveServerConfigured {
            await connect()
        }
    }

    // MARK: - Connection

    /// Attempts to connect to the configured server and starts polling.
    func connect() async {
        guard let server = sessionManager.activeServer, server.isConfigured else {
            connectionStatus = .error("No server configured.")
            return
        }

        cancelReconnection()
        consecutiveFailures = 0
        showAuthenticationError = false
        connectionStatus = .connecting
        do {
            try await client.testConnection()
            connectionStatus = .connected
            errorMessage = nil
            requestNotificationPermission()
            await refreshSessionSettings()
            await refreshSessionStats()
            startPolling()
        } catch {
            connectionStatus = .error(error.localizedDescription)
        }
    }

    /// Disconnects from the server and stops polling.
    func disconnect() {
        stopPolling()
        cancelReconnection()
        consecutiveFailures = 0
        torrents = []
        selectedTorrentIds = []
        previousCompletionStates = [:]
        connectionStatus = .disconnected
        errorMessage = nil
        showAuthenticationError = false
    }

    // MARK: - Polling

    /// Starts the periodic torrent fetch loop.
    func startPolling() {
        stopPolling()
        pollCycleCount = 0
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshTorrents()
                // Refresh session stats every ~10th cycle (~30s when active)
                self.pollCycleCount += 1
                if self.pollCycleCount % 10 == 0 {
                    await self.refreshSessionStats()
                }
                let interval = NSApplication.shared.isActive
                    ? AppState.activePollInterval
                    : AppState.backgroundPollInterval
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Stops the polling loop.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Reconnection Logic

    /// Transitions from connected to reconnecting mode after repeated failures.
    private func enterReconnectionMode() {
        stopPolling()
        connectionStatus = .reconnecting
        startReconnectLoop()
    }

    /// Starts the reconnection loop with exponential backoff.
    private func startReconnectLoop() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                guard let self else { return }

                // Calculate delay with exponential backoff: 5, 10, 20, 30 (capped)
                let delay = min(5 * Int(pow(2.0, Double(attempt))), Self.maxReconnectDelay)

                // Countdown each second
                self.reconnectCountdown = delay
                for secondsLeft in stride(from: delay, through: 1, by: -1) {
                    guard !Task.isCancelled else { return }
                    self.reconnectCountdown = secondsLeft
                    try? await Task.sleep(for: .seconds(1))
                }
                self.reconnectCountdown = 0

                // Attempt reconnection
                guard !Task.isCancelled else { return }
                do {
                    try await self.client.testConnection()
                    // Success — resume normal operation
                    self.connectionStatus = .connected
                    self.consecutiveFailures = 0
                    self.errorMessage = nil
                    self.startPolling()
                    return
                } catch {
                    attempt += 1
                    // Continue loop to try again with increased backoff
                }
            }
        }
    }

    /// Cancels any active reconnection attempt.
    private func cancelReconnection() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectCountdown = 0
    }

    /// Cancels the current countdown and attempts reconnection immediately.
    func reconnectNow() async {
        cancelReconnection()
        connectionStatus = .reconnecting
        reconnectCountdown = 0
        do {
            try await client.testConnection()
            connectionStatus = .connected
            consecutiveFailures = 0
            errorMessage = nil
            startPolling()
        } catch {
            // Restart the reconnection loop
            startReconnectLoop()
        }
    }

    /// Fetches the torrent list once. Called by the poll loop and on-demand.
    func refreshTorrents() async {
        do {
            let fetched = try await client.getTorrents()
            checkForCompletedTorrents(fetched)
            torrents = fetched
            errorMessage = nil
            consecutiveFailures = 0

            // Clear selection for torrents that no longer exist
            let fetchedIds = Set(fetched.map(\.id))
            selectedTorrentIds = selectedTorrentIds.intersection(fetchedIds)
        } catch {
            if case .authenticationRequired = error as? TransmissionError {
                errorMessage = error.localizedDescription
                showAuthenticationError = true
                stopPolling()
                connectionStatus = .error(error.localizedDescription)
                return
            }

            consecutiveFailures += 1
            errorMessage = error.localizedDescription

            if consecutiveFailures >= Self.failureThresholdForReconnect {
                enterReconnectionMode()
            }
        }
    }

    // MARK: - Torrent Actions

    /// Starts the specified torrents.
    func startTorrents(ids: [Int]) async {
        do {
            try await client.startTorrents(ids: ids)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stops the specified torrents.
    func stopTorrents(ids: [Int]) async {
        do {
            try await client.stopTorrents(ids: ids)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Resumes all torrents on the active server.
    func startAllTorrents() async {
        let allIds = torrents.map(\.id)
        guard !allIds.isEmpty else { return }
        await startTorrents(ids: allIds)
    }

    /// Pauses all torrents on the active server.
    func stopAllTorrents() async {
        let allIds = torrents.map(\.id)
        guard !allIds.isEmpty else { return }
        await stopTorrents(ids: allIds)
    }

    /// Removes the specified torrents.
    func removeTorrents(ids: [Int], deleteLocalData: Bool = false) async {
        do {
            try await client.removeTorrents(ids: ids, deleteLocalData: deleteLocalData)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Starts the specified torrents immediately, bypassing the queue.
    func startTorrentsNow(ids: [Int]) async {
        do {
            try await client.startTorrentsNow(ids: ids)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Verifies (rechecks) the data of the specified torrents.
    func verifyTorrents(ids: [Int]) async {
        do {
            try await client.verifyTorrents(ids: ids)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reannounces (asks trackers for more peers) the specified torrents.
    func reannounceTorrents(ids: [Int]) async {
        do {
            try await client.reannounceTorrents(ids: ids)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Moves the specified torrents to a new download location on the server.
    func moveTorrents(ids: [Int], location: String, move: Bool = true) async {
        do {
            try await client.moveTorrents(ids: ids, location: location, move: move)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Queue Actions

    /// Moves the specified torrents to the top of the queue.
    func queueMoveTop(ids: [Int]) async {
        do {
            try await client.queueMoveTop(ids: ids)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Moves the specified torrents up one position in the queue.
    func queueMoveUp(ids: [Int]) async {
        do {
            try await client.queueMoveUp(ids: ids)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Moves the specified torrents down one position in the queue.
    func queueMoveDown(ids: [Int]) async {
        do {
            try await client.queueMoveDown(ids: ids)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Moves the specified torrents to the bottom of the queue.
    func queueMoveBottom(ids: [Int]) async {
        do {
            try await client.queueMoveBottom(ids: ids)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Session Settings Actions

    /// Fetches the daemon session settings. Failures are non-critical and won't
    /// surface an error banner (session settings are supplementary to the connection).
    func refreshSessionSettings() async {
        do {
            sessionSettings = try await client.getSessionSettings()
        } catch {
            // Silently ignore — session settings are supplementary
        }
    }

    /// Updates per-torrent settings for the given torrent IDs.
    func setTorrentSettings(ids: [Int], settings: TorrentSettings) async {
        do {
            try await client.setTorrentSettings(ids: ids, settings: settings)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Updates daemon session settings.
    func updateSessionSettings(_ settings: SessionSettingsUpdate) async {
        do {
            try await client.setSessionSettings(settings)
            await refreshSessionSettings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches session-level statistics. Failures are non-critical.
    func refreshSessionStats() async {
        do {
            sessionStats = try await client.getSessionStats()
        } catch {
            // Silently ignore — session stats are supplementary
        }
    }

    /// Tests whether the configured peer port is reachable. Returns nil on failure.
    func testPort() async -> Bool? {
        do {
            return try await client.testPort()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Triggers a blocklist update. Returns the new blocklist size, or nil on failure.
    func updateBlocklist() async -> Int? {
        do {
            return try await client.updateBlocklist()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Checks free space at the given path. Returns nil on failure.
    func getFreeSpace(path: String) async -> FreeSpaceResponse? {
        do {
            return try await client.getFreeSpace(path: path)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Renames a file or directory within a torrent.
    func renameTorrent(id: Int, path: String, name: String) async {
        do {
            try await client.renameTorrent(id: id, path: path, name: name)
            await refreshTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Toggles the alternative speed mode on the daemon.
    func toggleAltSpeed() async {
        guard let current = sessionSettings?.altSpeedEnabled else { return }
        var update = SessionSettingsUpdate()
        update.altSpeedEnabled = !current
        await updateSessionSettings(update)
    }

    // MARK: - Notifications

    /// Requests notification authorization if not already granted.
    func requestNotificationPermission() {
        guard !notificationPermissionRequested else { return }
        notificationPermissionRequested = true
        let center = UNUserNotificationCenter.current()
        Task.detached {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
        }
    }

    /// Checks for newly completed torrents and sends notifications.
    private func checkForCompletedTorrents(_ fetched: [Torrent]) {
        let notifyEnabled = UserDefaults.standard.bool(forKey: "notifyOnCompletion")
        guard notifyEnabled else {
            // Still update the tracking state so we don't fire stale notifications
            // if the user re-enables the setting later
            updateCompletionStates(fetched)
            return
        }

        // On first poll, just record the initial states without notifying
        guard !previousCompletionStates.isEmpty else {
            updateCompletionStates(fetched)
            return
        }

        for torrent in fetched {
            let previousProgress = previousCompletionStates[torrent.id]
            // Torrent just completed: was previously tracked and not done, now at 100%
            if let prev = previousProgress, prev < 1.0, torrent.percentDone >= 1.0 {
                sendCompletionNotification(for: torrent)
            }
        }

        updateCompletionStates(fetched)
    }

    /// Updates the tracked completion states dictionary.
    private func updateCompletionStates(_ fetched: [Torrent]) {
        var newStates: [Int: Double] = [:]
        for torrent in fetched {
            newStates[torrent.id] = torrent.percentDone
        }
        previousCompletionStates = newStates
    }

    /// Sends a local notification for a completed torrent.
    private func sendCompletionNotification(for torrent: Torrent) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Download Complete")
        content.body = torrent.name
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "torrent-complete-\(torrent.id)",
            content: content,
            trigger: nil
        )

        Task.detached {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Menu-Driven Actions

    /// Prepares the remove confirmation for the current selection.
    func confirmRemoveSelected() {
        guard !selectedTorrentIds.isEmpty else { return }
        idsToRemove = selectedTorrentIds
        showingRemoveConfirmation = true
    }

    /// Executes the queued removal.
    func executeRemove() async {
        let ids = Array(idsToRemove)
        guard !ids.isEmpty else { return }
        await removeTorrents(ids: ids, deleteLocalData: deleteLocalDataOnRemove)
        idsToRemove.removeAll()
        deleteLocalDataOnRemove = false
    }

    /// Prepares the move sheet for the current selection.
    func confirmMoveSelected() {
        guard !selectedTorrentIds.isEmpty else { return }
        idsToMove = selectedTorrentIds
        if let first = selectedTorrent {
            moveLocation = first.downloadDir
        }
        showingMoveTorrent = true
    }

    /// Executes the queued move.
    func executeMove() async {
        let ids = Array(idsToMove)
        guard !ids.isEmpty, !moveLocation.isEmpty else { return }
        await moveTorrents(ids: ids, location: moveLocation)
        idsToMove.removeAll()
        moveLocation = ""
    }

    /// Prepares the rename sheet for the selected torrent.
    func promptRenameSelected() {
        guard let torrent = selectedTorrent else { return }
        renameTargetId = torrent.id
        newName = torrent.name
        showingRenameSheet = true
    }

    /// Executes the queued rename.
    func executeRename() async {
        guard let id = renameTargetId else { return }
        guard let torrent = torrents.first(where: { $0.id == id }) else { return }
        guard !newName.isEmpty, newName != torrent.name else { return }
        await renameTorrent(id: id, path: torrent.name, name: newName)
        renameTargetId = nil
        newName = ""
    }

    /// Copies the magnet link of the first selected torrent to the clipboard.
    func copyMagnetLinkForSelected() {
        guard let torrent = selectedTorrent else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(torrent.magnetLink, forType: .string)
    }

    /// Copies the info hash of the first selected torrent to the clipboard.
    func copyHashForSelected() {
        guard let torrent = selectedTorrent else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(torrent.hashString, forType: .string)
    }

    /// Whether the first selected torrent can be opened in Finder.
    func canOpenSelectedInFinder() -> Bool {
        guard let torrent = selectedTorrent else { return false }
        return resolveLocalPath(torrent.downloadDir) != nil
    }

    /// Opens the selected torrent's download directory in Finder.
    func openSelectedInFinder() {
        guard let torrent = selectedTorrent else { return }
        guard let localURL = resolveLocalPathWithAccess(torrent.downloadDir) else { return }
        NSWorkspace.shared.open(localURL)
        sessionManager.stopSecurityScopedAccess()
    }

    // MARK: - Torrent Addition

    /// Adds a torrent by URL or magnet link. Returns the added torrent's ID.
    func addTorrent(url: String, downloadDir: String? = nil) async -> Int? {
        do {
            let info = try await client.addTorrent(url: url, downloadDir: downloadDir)
            await refreshTorrents()
            return info?.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Adds a torrent from file data. Returns the added torrent's ID.
    func addTorrent(fileData: Data, downloadDir: String? = nil) async -> Int? {
        do {
            let info = try await client.addTorrent(fileData: fileData, downloadDir: downloadDir)
            await refreshTorrents()
            return info?.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
