import AppKit
import SwiftUI

/// The main torrent list shown in the content column of the NavigationSplitView.
struct TorrentListView: View {
    @Bindable var viewModel: TorrentListViewModel
    @SceneStorage("tableColumnCustomization") private var columnCustomization: TableColumnCustomization<Torrent>

    var body: some View {
        @Bindable var appState = viewModel.appState

        Group {
            if viewModel.isConnected && viewModel.torrents.isEmpty {
                EmptyStateView(
                    symbolName: "arrow.down.circle",
                    title: "No Torrents",
                    subtitle: "Add a torrent using the toolbar button or ⌘N."
                )
            } else if viewModel.isConnected {
                torrentList
            }
        }
        .frame(minWidth: 400)
        .searchable(
            text: Binding(
                get: { viewModel.appState.searchText },
                set: { viewModel.appState.searchText = $0 }
            ),
            prompt: "Filter torrents"
        )
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $appState.showingMoveTorrent) {
            MoveTorrentSheet(appState: viewModel.appState)
        }
        .sheet(isPresented: $appState.showingRenameSheet) {
            RenameTorrentSheet(appState: viewModel.appState)
        }
        .confirmationDialog(
            removeConfirmationTitle,
            isPresented: $appState.showingRemoveConfirmation
        ) {
            Button(removeConfirmationTitle, role: .destructive) {
                Task { await viewModel.executeRemove() }
            }
            Button(removeAndDeleteTitle, role: .destructive) {
                viewModel.appState.deleteLocalDataOnRemove = true
                Task { await viewModel.executeRemove() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(removeConfirmationMessage)
        }
        // Keyboard shortcuts
        .keyboardShortcut(.delete, modifiers: [])
        .onKeyPress(.space) {
            Task { await toggleSelected() }
            return .handled
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var torrentList: some View {
        @Bindable var appState = viewModel.appState
        if appState.listDisplayMode == .table {
            TorrentTableView(
                torrents: viewModel.tableTorrents,
                selection: $appState.selectedTorrentIds,
                sortOrder: $appState.tableSortOrder,
                columnCustomization: $columnCustomization
            ) { torrent in
                AnyView(torrentContextMenu(for: torrent))
            }
            .overlay(alignment: .top) {
                if let error = viewModel.errorMessage {
                    errorBanner(message: error)
                }
            }
        } else {
            List(viewModel.torrents, selection: $appState.selectedTorrentIds) { torrent in
                Group {
                    if appState.listDisplayMode == .compact {
                        CompactTorrentRowView(torrent: torrent) {
                            Task { await viewModel.toggleTorrent(torrent) }
                        }
                    } else {
                        TorrentRowView(torrent: torrent) {
                            Task { await viewModel.toggleTorrent(torrent) }
                        }
                    }
                }
                .tag(torrent.id)
                .contextMenu {
                    torrentContextMenu(for: torrent)
                }
            }
            .listStyle(.inset)
            .id("torrentList-\(appState.sortOrder.rawValue)-\(appState.sortAscending)")
            .overlay(alignment: .top) {
                if let error = viewModel.errorMessage {
                    errorBanner(message: error)
                }
            }
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(4)
            Spacer()
            if viewModel.appState.showAuthenticationError {
                SettingsLink {
                    Text("Open Settings")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            Button {
                viewModel.dismissError()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.spacing8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, .spacing8)
        .padding(.top, .spacing4)
        .transition(.opacity.combined(with: .scale(0.97)))
        .animation(.spring(duration: 0.25), value: viewModel.errorMessage)
    }

    @ViewBuilder
    private func torrentContextMenu(for torrent: Torrent) -> some View {
        // Start / Stop
        if torrent.status == .stopped {
            Button {
                Task { await viewModel.appState.startTorrents(ids: [torrent.id]) }
            } label: {
                Label("Resume", systemImage: "play.fill")
            }
            Button {
                Task { await viewModel.startNow(ids: [torrent.id]) }
            } label: {
                Label("Start Now", systemImage: "forward.fill")
            }
        } else {
            Button {
                Task { await viewModel.appState.stopTorrents(ids: [torrent.id]) }
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
        }

        Divider()

        // Priority submenu
        Menu {
            ForEach(BandwidthPriority.allCases) { priority in
                Button {
                    Task { await viewModel.setPriority(priority, ids: [torrent.id]) }
                } label: {
                    HStack {
                        Text(priority.label)
                        if torrent.bandwidthPriority == priority.rawValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Priority", systemImage: "gauge.with.dots.needle.33percent")
        }

        // Queue position submenu
        Menu {
            Button {
                Task { await viewModel.queueMoveTop(ids: [torrent.id]) }
            } label: {
                Label("Move to Top", systemImage: "arrow.up.to.line")
            }
            Button {
                Task { await viewModel.queueMoveUp(ids: [torrent.id]) }
            } label: {
                Label("Move Up", systemImage: "arrow.up")
            }
            Button {
                Task { await viewModel.queueMoveDown(ids: [torrent.id]) }
            } label: {
                Label("Move Down", systemImage: "arrow.down")
            }
            Button {
                Task { await viewModel.queueMoveBottom(ids: [torrent.id]) }
            } label: {
                Label("Move to Bottom", systemImage: "arrow.down.to.line")
            }
        } label: {
            Label("Queue", systemImage: "list.number")
        }

        Divider()

        // Verify & Reannounce
        Button {
            Task { await viewModel.verify(ids: [torrent.id]) }
        } label: {
            Label("Verify Data", systemImage: "arrow.triangle.2.circlepath")
        }

        Button {
            Task { await viewModel.reannounce(ids: [torrent.id]) }
        } label: {
            Label("Ask Tracker for More Peers", systemImage: "antenna.radiowaves.left.and.right")
        }

        Divider()

        // File management
        Button {
            viewModel.confirmMove(ids: [torrent.id], currentLocation: torrent.downloadDir)
        } label: {
            Label("Move Data…", systemImage: "folder.badge.questionmark")
        }

        if viewModel.canOpenInFinder(torrent: torrent) {
            Button {
                viewModel.openInFinder(torrent: torrent)
            } label: {
                Label("Open in Finder", systemImage: "folder")
            }
        }

        Divider()

        // Rename
        Button {
            viewModel.promptRename(torrent: torrent)
        } label: {
            Label("Rename…", systemImage: "pencil")
        }

        // Copy info
        Button {
            viewModel.copyMagnetLink(for: torrent)
        } label: {
            Label("Copy Magnet Link", systemImage: "link")
        }

        Button {
            viewModel.copyHash(for: torrent)
        } label: {
            Label("Copy Hash", systemImage: "number")
        }

        Divider()

        // Remove
        Button(role: .destructive) {
            viewModel.appState.idsToRemove = [torrent.id]
            viewModel.appState.showingRemoveConfirmation = true
        } label: {
            Label("Remove…", systemImage: "trash")
        }
    }

    // MARK: - Remove Confirmation Helpers

    private var removeCount: Int {
        viewModel.appState.idsToRemove.count
    }

    private var removeConfirmationTitle: String {
        if removeCount == 1 {
            return String(localized: "Remove Torrent")
        } else {
            return String(localized: "Remove \(removeCount) Torrents")
        }
    }

    private var removeAndDeleteTitle: String {
        if removeCount == 1 {
            return String(localized: "Remove and Delete Data")
        } else {
            return String(localized: "Remove \(removeCount) and Delete Data")
        }
    }

    private var removeConfirmationMessage: String {
        if removeCount == 1 {
            if let name = viewModel.appState.torrents.first(where: { viewModel.appState.idsToRemove.contains($0.id) })?.name {
                return String(localized: "Are you sure you want to remove \"\(name)\"?")
            }
            return String(localized: "Are you sure you want to remove the selected torrent?")
        } else {
            return String(localized: "Are you sure you want to remove \(removeCount) torrents?")
        }
    }

    // MARK: - Keyboard Shortcut Helpers

    /// Toggles pause/resume for the entire selection.
    private func toggleSelected() async {
        let selectedIds = viewModel.selectedIds
        guard !selectedIds.isEmpty else { return }
        let selectedTorrents = viewModel.torrents.filter { selectedIds.contains($0.id) }
        let allPaused = selectedTorrents.allSatisfy { $0.status == .stopped }
        if allPaused {
            await viewModel.startSelected()
        } else {
            await viewModel.stopSelected()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .secondaryAction) {
            // Display mode picker
            Picker("Display", selection: Binding(
                get: { viewModel.appState.listDisplayMode },
                set: { viewModel.appState.listDisplayMode = $0 }
            )) {
                ForEach(ListDisplayMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbolName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .help("List Display Mode")

            // Sort menu
            Menu {
                ForEach(TorrentSortOrder.allCases) { order in
                    Button {
                        if viewModel.appState.sortOrder == order {
                            viewModel.appState.sortAscending.toggle()
                        } else {
                            viewModel.appState.sortOrder = order
                            viewModel.appState.sortAscending = true
                        }
                    } label: {
                        HStack {
                            Label(order.label, systemImage: order.symbolName)
                            if viewModel.appState.sortOrder == order {
                                Image(systemName: viewModel.appState.sortAscending
                                    ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .fontWeight(.medium)
            }
            .help("Sort Torrents")
        }

    }
}

// MARK: - Torrent Row

/// A single row in the torrent list.
struct TorrentRowView: View {
    let torrent: Torrent
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing4) {
            HStack {
                Text(torrent.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                StatusBadge(status: torrent.status, hasError: torrent.hasError)
            }

            ProgressView(value: torrent.percentDone)
                .progressViewStyle(.linear)
                .tint(torrent.hasError ? .red : torrent.status.color)
                .scaleEffect(y: 0.5, anchor: .center)
                .accessibilityLabel(String(localized: "Progress"))
                .accessibilityValue(String(localized: "\(Int(torrent.percentDone * 100)) percent"))

            HStack {
                Text(torrent.totalSize.formattedByteCount)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let eta = torrent.formattedETA {
                    Text("• \(eta) remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                SpeedIndicator(
                    downloadSpeed: torrent.rateDownload,
                    uploadSpeed: torrent.rateUpload
                )

                if isHovered {
                    Button {
                        onToggle()
                    } label: {
                        Image(
                            systemName: torrent.status == .stopped
                                ? "play.fill" : "pause.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    .accessibilityLabel(torrent.status == .stopped ? String(localized: "Resume") : String(localized: "Pause"))
                }
            }
        }
        .padding(.vertical, .spacing8)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(duration: 0.25)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Compact Torrent Row

/// A compact single-line row for the torrent list.
struct CompactTorrentRowView: View {
    let torrent: Torrent
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: .spacing8) {
            Image(systemName: torrent.status.symbolName)
                .font(.caption)
                .foregroundStyle(torrent.hasError ? .red : torrent.status.color)
                .frame(width: 16)

            Text(torrent.name)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            ProgressView(value: torrent.percentDone)
                .progressViewStyle(.linear)
                .tint(torrent.hasError ? .red : torrent.status.color)
                .frame(width: 80)
                .scaleEffect(y: 0.5, anchor: .center)
                .accessibilityLabel(String(localized: "Progress"))
                .accessibilityValue(String(localized: "\(Int(torrent.percentDone * 100)) percent"))

            Text("\(Int(torrent.percentDone * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
                .accessibilityHidden(true)

            if torrent.rateDownload > 0 || torrent.rateUpload > 0 {
                SpeedIndicator(
                    downloadSpeed: torrent.rateDownload,
                    uploadSpeed: torrent.rateUpload
                )
            }

            if isHovered {
                Button {
                    onToggle()
                } label: {
                    Image(
                        systemName: torrent.status == .stopped
                            ? "play.fill" : "pause.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .accessibilityLabel(torrent.status == .stopped ? String(localized: "Resume") : String(localized: "Pause"))
            }
        }
        .padding(.vertical, .spacing4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(duration: 0.25)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Move Torrent Sheet

/// A sheet that lets the user specify a new remote path for moving torrent data.
struct MoveTorrentSheet: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing16) {
            Text("Move Torrent Data")
                .font(.headline)

            Text("Enter the new location on the remote server:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Remote path", text: $appState.moveLocation)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    appState.idsToMove.removeAll()
                    appState.moveLocation = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Move") {
                    Task {
                        await appState.executeMove()
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appState.moveLocation.isEmpty)
            }
        }
        .padding(.spacing24)
        .frame(minWidth: 400)
    }
}
// MARK: - Rename Torrent Sheet

/// A sheet that lets the user rename a torrent.
struct RenameTorrentSheet: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing16) {
            Text("Rename Torrent")
                .font(.headline)

            Text("Enter a new name:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Name", text: $appState.newName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    appState.renameTargetId = nil
                    appState.newName = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    Task {
                        await appState.executeRename()
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appState.newName.isEmpty)
            }
        }
        .padding(.spacing24)
        .frame(minWidth: 400)
    }
}

