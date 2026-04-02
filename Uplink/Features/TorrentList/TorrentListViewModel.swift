import AppKit
import Foundation

/// ViewModel for the torrent list. Delegates to `AppState` for data and actions.
@Observable
@MainActor
final class TorrentListViewModel {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Computed

    var torrents: [Torrent] {
        appState.filteredTorrents
    }

    var tableTorrents: [Torrent] {
        appState.tableFilteredTorrents
    }

    var isConnected: Bool {
        appState.isConnected
    }

    var errorMessage: String? {
        appState.errorMessage
    }

    /// The IDs currently selected in the list.
    var selectedIds: Set<Int> {
        appState.selectedTorrentIds
    }

    var hasSelection: Bool {
        !selectedIds.isEmpty
    }

    // MARK: - Connection Actions

    func connect() async {
        await appState.connect()
    }

    func disconnect() {
        appState.disconnect()
    }

    // MARK: - Batch Actions

    func startSelected() async {
        let ids = Array(selectedIds)
        guard !ids.isEmpty else { return }
        await appState.startTorrents(ids: ids)
    }

    func stopSelected() async {
        let ids = Array(selectedIds)
        guard !ids.isEmpty else { return }
        await appState.stopTorrents(ids: ids)
    }

    /// Shows the remove confirmation for the current selection.
    func confirmRemoveSelected() {
        appState.confirmRemoveSelected()
    }

    /// Executes the removal after confirmation.
    func executeRemove() async {
        await appState.executeRemove()
    }

    // MARK: - Single Torrent Actions

    func toggleTorrent(_ torrent: Torrent) async {
        if torrent.status == .stopped {
            await appState.startTorrents(ids: [torrent.id])
        } else {
            await appState.stopTorrents(ids: [torrent.id])
        }
    }

    func dismissError() {
        appState.errorMessage = nil
    }

    // MARK: - Extended Actions

    /// Starts the specified torrents immediately, bypassing the queue.
    func startNow(ids: [Int]) async {
        await appState.startTorrentsNow(ids: ids)
    }

    /// Verifies (rechecks) the data of the specified torrents.
    func verify(ids: [Int]) async {
        await appState.verifyTorrents(ids: ids)
    }

    /// Reannounces (asks trackers for more peers) the specified torrents.
    func reannounce(ids: [Int]) async {
        await appState.reannounceTorrents(ids: ids)
    }

    /// Shows the move torrent dialog for the given IDs.
    func confirmMove(ids: Set<Int>, currentLocation: String) {
        appState.idsToMove = ids
        appState.moveLocation = currentLocation
        appState.showingMoveTorrent = true
    }

    /// Executes the move operation.
    func executeMove() async {
        await appState.executeMove()
    }

    /// Copies the magnet link for a torrent to the clipboard.
    func copyMagnetLink(for torrent: Torrent) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(torrent.magnetLink, forType: .string)
    }

    /// Copies the info hash for a torrent to the clipboard.
    func copyHash(for torrent: Torrent) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(torrent.hashString, forType: .string)
    }

    // MARK: - Priority Actions

    /// Sets bandwidth priority for the given torrent IDs.
    func setPriority(_ priority: BandwidthPriority, ids: [Int]) async {
        await appState.setTorrentSettings(ids: ids, settings: TorrentSettings(bandwidthPriority: priority.rawValue))
    }

    // MARK: - Queue Actions

    func queueMoveTop(ids: [Int]) async {
        await appState.queueMoveTop(ids: ids)
    }

    func queueMoveUp(ids: [Int]) async {
        await appState.queueMoveUp(ids: ids)
    }

    func queueMoveDown(ids: [Int]) async {
        await appState.queueMoveDown(ids: ids)
    }

    func queueMoveBottom(ids: [Int]) async {
        await appState.queueMoveBottom(ids: ids)
    }

    // MARK: - Open in Finder

    /// Opens the torrent's download directory in Finder, if a path mapping exists.
    func openInFinder(torrent: Torrent) {
        guard let localURL = appState.resolveLocalPathWithAccess(torrent.downloadDir) else { return }
        NSWorkspace.shared.open(localURL)
        appState.sessionManager.stopSecurityScopedAccess()
    }

    /// Whether the torrent's download directory can be resolved to a local path.
    func canOpenInFinder(torrent: Torrent) -> Bool {
        appState.resolveLocalPath(torrent.downloadDir) != nil
    }

    // MARK: - Rename

    /// Prepares the rename sheet for a torrent.
    func promptRename(torrent: Torrent) {
        appState.renameTargetId = torrent.id
        appState.newName = torrent.name
        appState.showingRenameSheet = true
    }

    /// Executes the rename operation.
    func executeRename() async {
        await appState.executeRename()
    }
}
