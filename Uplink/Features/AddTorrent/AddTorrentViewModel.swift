import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// ViewModel for the Add Torrent sheet.
@Observable
@MainActor
final class AddTorrentViewModel {
    let appState: AppState

    enum Tab: String, CaseIterable {
        case url = "URL / Magnet"
        case file = "File"

        /// Localized display label.
        var label: String {
            switch self {
            case .url: String(localized: "URL / Magnet")
            case .file: String(localized: "File")
            }
        }
    }

    var selectedTab: Tab = .url
    var urlText: String = ""
    var selectedFileData: Data?
    var selectedFileName: String?
    var downloadDirOverride: String = ""
    var isAdding: Bool = false
    var errorMessage: String?
    var freeSpaceText: String?

    init(appState: AppState) {
        self.appState = appState
    }

    /// Whether the current input is valid for submission.
    var canAdd: Bool {
        switch selectedTab {
        case .url:
            let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty
                && (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
                    || trimmed.hasPrefix("magnet:"))
        case .file:
            return selectedFileData != nil
        }
    }

    /// The download directory override, or nil if empty.
    private var downloadDir: String? {
        let trimmed = downloadDirOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Adds the torrent and returns the new torrent's ID if successful.
    func addTorrent() async -> Int? {
        isAdding = true
        errorMessage = nil
        defer { isAdding = false }

        switch selectedTab {
        case .url:
            let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
            return await appState.addTorrent(url: trimmed, downloadDir: downloadDir)

        case .file:
            guard let data = selectedFileData else { return nil }
            return await appState.addTorrent(fileData: data, downloadDir: downloadDir)
        }
    }

    /// Checks free space at the effective download directory.
    func checkFreeSpace() async {
        let path = downloadDir ?? appState.sessionSettings?.downloadDir ?? ""
        guard !path.isEmpty else {
            freeSpaceText = nil
            return
        }
        if let response = await appState.getFreeSpace(path: path) {
            freeSpaceText = String(localized: "\(response.sizeBytes.formattedByteCount) free")
        } else {
            freeSpaceText = nil
        }
    }

    /// Loads a .torrent file from a URL (e.g. from a file picker).
    func loadFile(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            selectedFileData = data
            selectedFileName = url.lastPathComponent
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Failed to read file: \(error.localizedDescription)")
        }
    }
}
