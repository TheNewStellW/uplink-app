//
//  ContentView.swift
//  Transmission Remote
//
//  Created by Stellios Williams on 31/3/2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// The root view of the app. Two-pane NavigationSplitView with an inspector
/// for the torrent detail panel (collapsible via toolbar or ⌃⌘I).
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings
    @State private var listViewModel: TorrentListViewModel?
    @State private var showInspector = true
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 220)
            } detail: {
                if let viewModel = listViewModel {
                    TorrentListView(viewModel: viewModel)
                }
            }
            .navigationSplitViewStyle(.prominentDetail)
            .inspector(isPresented: $showInspector) {
                Group {
                    if let torrent = appState.selectedTorrent {
                        TorrentDetailView(torrent: torrent, appState: appState)
                    } else {
                        EmptyStateView(
                            symbolName: "sidebar.squares.right",
                            title: "No Torrent Selected",
                            subtitle: "Select a torrent from the list to see its details."
                        )
                    }
                }
                .inspectorColumnWidth(min: 320, ideal: 420, max: 600)
            }

            StatusBarView()
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            // Far left: Add torrent
            ToolbarItem(placement: .navigation) {
                Button {
                    appState.showingAddTorrent = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                }
                .help("Add Torrent (⌘N)")
                .disabled(!appState.isConnected)
            }

            // After add: torrent batch actions
            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    guard let vm = listViewModel else { return }
                    Task { await vm.startSelected() }
                } label: {
                    Image(systemName: "play.fill")
                        .fontWeight(.medium)
                }
                .help("Resume Selected")
                .disabled(listViewModel?.hasSelection != true)

                Button {
                    guard let vm = listViewModel else { return }
                    Task { await vm.stopSelected() }
                } label: {
                    Image(systemName: "pause.fill")
                        .fontWeight(.medium)
                }
                .help("Pause Selected")
                .disabled(listViewModel?.hasSelection != true)

                Button {
                    listViewModel?.confirmRemoveSelected()
                } label: {
                    Image(systemName: "trash")
                        .fontWeight(.medium)
                }
                .help("Remove Selected (⌫)")
                .disabled(listViewModel?.hasSelection != true)
            }

            // Far right: inspector toggle
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Image(systemName: "sidebar.trailing")
                        .fontWeight(.medium)
                }
                .help(showInspector ? "Hide Detail Panel" : "Show Detail Panel")
            }
        }
        .sheet(isPresented: $appState.showingAddTorrent) {
            let vm = AddTorrentViewModel(appState: appState)
            AddTorrentView(viewModel: vm)
                .onAppear {
                    // Pre-fill from pending magnet or file
                    if let magnetURL = appState.pendingMagnetURL {
                        vm.selectedTab = .url
                        vm.urlText = magnetURL
                        appState.pendingMagnetURL = nil
                    } else if let fileData = appState.pendingTorrentFileData {
                        vm.selectedTab = .file
                        vm.selectedFileData = fileData
                        vm.selectedFileName = appState.pendingTorrentFileName
                        appState.pendingTorrentFileData = nil
                        appState.pendingTorrentFileName = nil
                    }
                }
        }
        .onChange(of: appState.selectedFilter) {
            appState.selectedLabelFilter = nil
        }
        .onChange(of: appState.pendingMagnetURL) { _, newValue in
            if newValue != nil { appState.showingAddTorrent = true }
        }
        .onChange(of: appState.pendingTorrentFileData) { _, newValue in
            if newValue != nil { appState.showingAddTorrent = true }
        }
        .onChange(of: appState.openSettingsRequested) { _, requested in
            if requested {
                appState.openSettingsRequested = false
                openSettings()
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            handleDroppedURLs(urls)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.blue, lineWidth: 2)
                    .background(.blue.opacity(0.05))
                    .allowsHitTesting(false)
            }
        }
        .task {
            // Create the view model once, referencing the environment's AppState
            if listViewModel == nil {
                listViewModel = TorrentListViewModel(appState: appState)
            }
            // Auto-connect on launch if active server is configured
            if appState.isActiveServerConfigured {
                await appState.connect()
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        @Bindable var appState = appState
        return List(selection: $appState.selectedFilter) {
            Section {
                ForEach(appState.sessionManager.servers) { server in
                    serverRow(server)
                }

                Button {
                    appState.pendingAddServer = true
                    openSettings()
                } label: {
                    Label("Add Server…", systemImage: "plus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } header: {
                Text("Servers")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
            }

            Section {
                ForEach(TorrentFilter.allCases) { filter in
                    Label {
                        HStack {
                            Text(filter.label)
                            Spacer()
                            Text("\(count(for: filter))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                    } icon: {
                        Image(systemName: filter.symbolName)
                    }
                    .tag(filter)
                }
            } header: {
                Text("Filters")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
            }

            if !appState.uniqueLabels.isEmpty {
                Section {
                    Button {
                        appState.selectedLabelFilter = nil
                    } label: {
                        Label {
                            HStack {
                                Text("All Labels")
                                Spacer()
                                if appState.selectedLabelFilter == nil {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        } icon: {
                            Image(systemName: "tag")
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(appState.uniqueLabels, id: \.self) { label in
                        Button {
                            appState.selectedLabelFilter = label
                        } label: {
                            Label {
                                HStack {
                                    Text(label)
                                    Spacer()
                                    Text("\(labelCount(for: label))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .monospacedDigit()
                                    if appState.selectedLabelFilter == label {
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            } icon: {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Labels")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func serverRow(_ server: ServerConfig) -> some View {
        let iconInfo = serverIconInfo(server)
        return Button {
            Task {
                await appState.switchServer(to: server.id)
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: .spacing2) {
                    Text(server.name.isEmpty ? server.host : server.name)
                        .font(.body)
                        .lineLimit(1)
                    Text(verbatim: "\(server.host):\(server.port)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            } icon: {
                Image(systemName: iconInfo.symbol)
                    .foregroundStyle(iconInfo.color)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Settings…") {
                appState.pendingSettingsServerId = server.id
                appState.pendingSettingsTab = .connection
                openSettings()
            }
        }
    }

    private func serverIconInfo(_ server: ServerConfig) -> (symbol: String, color: Color) {
        let isActive = appState.sessionManager.activeServerId == server.id
        guard isActive else {
            return ("externaldrive.fill", .secondary)
        }
        switch appState.connectionStatus {
        case .connected:
            return ("externaldrive.fill.badge.checkmark", .green)
        case .connecting:
            return ("externaldrive.fill", .orange)
        case .reconnecting:
            return ("externaldrive.fill.badge.exclamationmark", .orange)
        case .error:
            return ("externaldrive.fill.badge.xmark", .red)
        case .disconnected:
            return ("externaldrive.fill", .secondary)
        }
    }

    private func count(for filter: TorrentFilter) -> Int {
        appState.torrents.filter { filter.matches($0) }.count
    }

    private func labelCount(for label: String) -> Int {
        appState.torrents.filter { $0.labels.contains(label) }.count
    }

    // MARK: - Drag and Drop

    private func handleDroppedURLs(_ urls: [URL]) {
        guard appState.isConnected else { return }
        for url in urls {
            if url.absoluteString.hasPrefix("magnet:") {
                appState.pendingMagnetURL = url.absoluteString
                return
            } else if url.isFileURL, url.pathExtension.lowercased() == "torrent" {
                do {
                    let data = try Data(contentsOf: url)
                    appState.pendingTorrentFileData = data
                    appState.pendingTorrentFileName = url.lastPathComponent
                } catch {
                    appState.errorMessage = String(localized: "Failed to read file: \(error.localizedDescription)")
                }
                return
            }
        }
    }
}
