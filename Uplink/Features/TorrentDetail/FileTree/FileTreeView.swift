import AppKit
import SwiftUI

/// Displays the file hierarchy of a torrent as a disclosure-group tree.
struct FileTreeView: View {
    let torrent: Torrent
    let appState: AppState

    private var tree: [FileTreeNode] {
        FileTreeNode.buildTree(files: torrent.files, fileStats: torrent.fileStats)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            Text("Files")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            if torrent.files.isEmpty {
                Text("No file information available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tree) { node in
                    FileTreeNodeView(
                        node: node,
                        torrentId: torrent.id,
                        downloadDir: torrent.downloadDir,
                        appState: appState
                    )
                }
            }
        }
    }
}

/// A single node in the file tree — either a disclosure group (folder) or a leaf row (file).
struct FileTreeNodeView: View {
    let node: FileTreeNode
    let torrentId: Int
    let downloadDir: String
    let appState: AppState

    @State private var showingRename = false
    @State private var renameText = ""

    /// The full remote path for this node.
    private var remoteFilePath: String {
        downloadDir + "/" + node.id
    }

    /// The resolved local URL for this node, if a path mapping exists.
    private var localURL: URL? {
        appState.resolveLocalPath(remoteFilePath)
    }

    var body: some View {
        Group {
            if node.isFolder {
                DisclosureGroup {
                    ForEach(node.children) { child in
                        FileTreeNodeView(
                            node: child,
                            torrentId: torrentId,
                            downloadDir: downloadDir,
                            appState: appState
                        )
                    }
                } label: {
                    folderLabel
                }
                .contextMenu { finderContextMenu }
            } else {
                fileLabel
                    .contextMenu { finderContextMenu }
            }
        }
        .alert("Rename", isPresented: $showingRename) {
            TextField("New name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                guard !renameText.isEmpty, renameText != node.name else { return }
                Task {
                    await appState.renameTorrent(
                        id: torrentId,
                        path: node.id,
                        name: renameText
                    )
                }
            }
        } message: {
            Text("Enter a new name for \"\(node.name)\":")
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var finderContextMenu: some View {
        if localURL != nil {
            Button {
                if let url = appState.resolveLocalPathWithAccess(remoteFilePath) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    appState.sessionManager.stopSecurityScopedAccess()
                }
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
        }

        Button {
            renameText = node.name
            showingRename = true
        } label: {
            Label("Rename…", systemImage: "pencil")
        }
    }

    // MARK: - Folder Label

    private var folderLabel: some View {
        VStack(alignment: .leading, spacing: .spacing2) {
            HStack(spacing: .spacing4) {
                Image(systemName: "folder.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(node.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(node.fileCount) files")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(node.totalSize.formattedByteCount)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            ProgressView(value: node.progress)
                .progressViewStyle(.linear)
                .scaleEffect(y: 0.5, anchor: .center)
                .tint(.blue)
                .accessibilityLabel(String(localized: "\(node.name) progress"))
                .accessibilityValue(String(localized: "\(Int(node.progress * 100)) percent"))
        }
        .padding(.vertical, .spacing2)
    }

    // MARK: - File Label

    private var fileLabel: some View {
        VStack(alignment: .leading, spacing: .spacing2) {
            HStack(spacing: .spacing4) {
                // Wanted checkbox
                if let wanted = node.fileWanted, let fileIndex = node.fileIndex {
                    Button {
                        Task { await toggleWanted(fileIndex: fileIndex, currentlyWanted: wanted) }
                    } label: {
                        Image(systemName: wanted ? "checkmark.square.fill" : "square")
                            .font(.caption)
                            .foregroundStyle(wanted ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(wanted ? "Exclude from download" : "Include in download")
                    .accessibilityLabel(String(localized: "Include in download"))
                    .accessibilityValue(wanted ? String(localized: "Included") : String(localized: "Excluded"))
                    .accessibilityAddTraits(.isToggle)
                }

                Image(systemName: "doc.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(node.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(node.fileWanted == false ? .tertiary : .primary)
                Spacer()

                // Priority picker
                if let priority = node.filePriority, let fileIndex = node.fileIndex {
                    Picker("Priority", selection: Binding(
                        get: { FilePriority(rawValue: priority) ?? .normal },
                        set: { newPriority in
                            Task { await setPriority(fileIndex: fileIndex, priority: newPriority) }
                        }
                    )) {
                        ForEach(FilePriority.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                    .font(.caption2)
                }

                Text(node.totalSize.formattedByteCount)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let length = node.fileLength, length > 0 {
                let completed = node.fileBytesCompleted ?? 0
                let pct = length > 0 ? Int(Double(completed) / Double(length) * 100) : 0
                ProgressView(value: Double(completed), total: Double(length))
                    .progressViewStyle(.linear)
                    .scaleEffect(y: 0.5, anchor: .center)
                    .tint(node.fileWanted == false ? .secondary : .blue)
                    .accessibilityLabel(String(localized: "\(node.name) progress"))
                    .accessibilityValue(String(localized: "\(pct) percent"))
            }
        }
        .padding(.vertical, .spacing2)
    }

    // MARK: - Actions

    private func toggleWanted(fileIndex: Int, currentlyWanted: Bool) async {
        do {
            if currentlyWanted {
                try await appState.client.setFiles(torrentId: torrentId, filesUnwanted: [fileIndex])
            } else {
                try await appState.client.setFiles(torrentId: torrentId, filesWanted: [fileIndex])
            }
            await appState.refreshTorrents()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func setPriority(fileIndex: Int, priority: FilePriority) async {
        do {
            switch priority {
            case .low:
                try await appState.client.setFiles(torrentId: torrentId, priorityLow: [fileIndex])
            case .normal:
                try await appState.client.setFiles(torrentId: torrentId, priorityNormal: [fileIndex])
            case .high:
                try await appState.client.setFiles(torrentId: torrentId, priorityHigh: [fileIndex])
            }
            await appState.refreshTorrents()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}


