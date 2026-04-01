//
//  Transmission_RemoteApp.swift
//  Transmission Remote
//
//  Created by Stellios Williams on 31/3/2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct Transmission_RemoteApp: App {
    @State private var appState = AppState()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    init() {
        // Register default values so UserDefaults.standard.bool(forKey:) returns
        // the correct default before the user opens Settings.
        UserDefaults.standard.register(defaults: [
            "notifyOnCompletion": true
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(appearanceMode.colorScheme)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1100, height: 700)
        .commands {
            AboutCommand()
            FileMenuCommands(appState: appState)
            SelectionCommands(appState: appState)
            TorrentMenuCommands(appState: appState)
            ServerMenuCommands(appState: appState)
            ViewMenuCommands(appState: appState)
            InspectorCommands()
        }

        Settings {
            SettingsView()
                .environment(appState)
        }

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .menuBarExtraStyle(.menu)
    }

    /// Handles incoming URLs: magnet links and .torrent file URLs.
    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "magnet" {
            appState.pendingMagnetURL = url.absoluteString
        } else if url.isFileURL, url.pathExtension.lowercased() == "torrent" {
            do {
                let data = try Data(contentsOf: url)
                appState.pendingTorrentFileData = data
                appState.pendingTorrentFileName = url.lastPathComponent
            } catch {
                appState.errorMessage = String(localized: "Failed to read torrent file: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - About

/// Replaces the default About menu item with a custom About window.
struct AboutCommand: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "About Uplink")) {
                showAboutWindow()
            }
        }
    }

    @MainActor
    private func showAboutWindow() {
        // Look for an existing About window and bring it forward if found
        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue == "about-window" }) {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let aboutView = AboutView()
        let hostingView = NSHostingView(rootView: aboutView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: 260)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("about-window")
        window.title = String(localized: "About Uplink")
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

/// The content of the custom About window.
struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: .spacing16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Uplink")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("A native macOS client for the\nTransmission BitTorrent daemon.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("© 2026 Stellios Williams")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.spacing24)
        .frame(width: 340, height: 260)
    }
}

// MARK: - File Menu

/// File menu commands: Open Torrent File and Add by URL.
struct FileMenuCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(String(localized: "Open Torrent File…")) {
                openTorrentFile()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(!appState.isConnected)

            Button(String(localized: "Add by URL…")) {
                appState.showingAddTorrent = true
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(!appState.isConnected)
        }
    }

    @MainActor
    private func openTorrentFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "torrent") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                appState.pendingTorrentFileData = data
                appState.pendingTorrentFileName = url.lastPathComponent
            } catch {
                appState.errorMessage = String(localized: "Failed to read torrent file: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Selection Commands

/// Edit menu addition: Select All for the torrent list.
struct SelectionCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button(String(localized: "Select All")) {
                let visibleIds = Set(appState.filteredTorrents.map(\.id))
                appState.selectedTorrentIds = visibleIds
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(!appState.isConnected || appState.filteredTorrents.isEmpty)
        }
    }
}

// MARK: - Torrent Menu

/// Torrent menu: all operations on the selected torrent(s).
struct TorrentMenuCommands: Commands {
    let appState: AppState

    private var selectedIds: [Int] { Array(appState.selectedTorrentIds) }
    private var hasSelection: Bool { !appState.selectedTorrentIds.isEmpty }
    private var hasSingleSelection: Bool { appState.selectedTorrentIds.count == 1 }
    private var isDisabled: Bool { !appState.isConnected || !hasSelection }

    var body: some Commands {
        CommandMenu(String(localized: "Torrent")) {
            // Resume / Start Now / Pause
            Button(String(localized: "Resume")) {
                Task { await appState.startTorrents(ids: selectedIds) }
            }
            .disabled(isDisabled)

            Button(String(localized: "Start Now")) {
                Task { await appState.startTorrentsNow(ids: selectedIds) }
            }
            .disabled(isDisabled)

            Button(String(localized: "Pause")) {
                Task { await appState.stopTorrents(ids: selectedIds) }
            }
            .disabled(isDisabled)

            Divider()

            // Priority submenu
            Menu(String(localized: "Priority")) {
                let currentPriority = appState.selectedTorrent?.bandwidthPriority
                ForEach(BandwidthPriority.allCases) { priority in
                    Button {
                        Task {
                            await appState.setTorrentSettings(
                                ids: selectedIds,
                                settings: TorrentSettings(bandwidthPriority: priority.rawValue)
                            )
                        }
                    } label: {
                        if currentPriority == priority.rawValue {
                            Text("✓ \(priority.label)")
                        } else {
                            Text("    \(priority.label)")
                        }
                    }
                }
            }
            .disabled(isDisabled)

            // Queue submenu
            Menu(String(localized: "Queue")) {
                Button(String(localized: "Move to Top")) {
                    Task { await appState.queueMoveTop(ids: selectedIds) }
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])

                Button(String(localized: "Move Up")) {
                    Task { await appState.queueMoveUp(ids: selectedIds) }
                }

                Button(String(localized: "Move Down")) {
                    Task { await appState.queueMoveDown(ids: selectedIds) }
                }

                Button(String(localized: "Move to Bottom")) {
                    Task { await appState.queueMoveBottom(ids: selectedIds) }
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            }
            .disabled(isDisabled)

            Divider()

            // Verify & Reannounce
            Button(String(localized: "Verify Data")) {
                Task { await appState.verifyTorrents(ids: selectedIds) }
            }
            .disabled(isDisabled)

            Button(String(localized: "Ask Tracker for More Peers")) {
                Task { await appState.reannounceTorrents(ids: selectedIds) }
            }
            .disabled(isDisabled)

            Divider()

            // File management
            Button(String(localized: "Move Data…")) {
                appState.confirmMoveSelected()
            }
            .disabled(isDisabled)

            Button(String(localized: "Rename…")) {
                appState.promptRenameSelected()
            }
            .disabled(!appState.isConnected || !hasSingleSelection)

            Button(String(localized: "Open in Finder")) {
                appState.openSelectedInFinder()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(!appState.isConnected || !hasSingleSelection || !appState.canOpenSelectedInFinder())

            Divider()

            // Copy
            Button(String(localized: "Copy Magnet Link")) {
                appState.copyMagnetLinkForSelected()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(!appState.isConnected || !hasSingleSelection)

            Button(String(localized: "Copy Hash")) {
                appState.copyHashForSelected()
            }
            .disabled(!appState.isConnected || !hasSingleSelection)

            Divider()

            // Remove
            Button(String(localized: "Remove…")) {
                appState.confirmRemoveSelected()
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(isDisabled)
        }
    }
}

// MARK: - Server Menu

/// Server menu: switch between servers, add server, open server settings.
struct ServerMenuCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandMenu(String(localized: "Server")) {
            ForEach(appState.sessionManager.servers) { server in
                let isActive = appState.sessionManager.activeServerId == server.id
                let name = server.name.isEmpty ? server.host : server.name
                Button {
                    Task { await appState.switchServer(to: server.id) }
                } label: {
                    if isActive {
                        Text("✓ \(name)")
                    } else {
                        Text("    \(name)")
                    }
                }
            }

            if !appState.sessionManager.servers.isEmpty {
                Divider()
            }

            Button(String(localized: "Add Server…")) {
                appState.pendingAddServer = true
                appState.openSettingsRequested = true
            }

            Button(String(localized: "Server Settings…")) {
                if let activeId = appState.sessionManager.activeServerId {
                    appState.pendingSettingsServerId = activeId
                    appState.pendingSettingsTab = .connection
                }
                appState.openSettingsRequested = true
            }
            .disabled(!appState.isConnected)
        }
    }
}

// MARK: - View Menu

/// View menu additions: display mode and sort options.
struct ViewMenuCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            // Display mode
            Button(String(localized: "Compact")) {
                appState.listDisplayMode = .compact
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(appState.listDisplayMode == .compact)

            Button(String(localized: "Detailed")) {
                appState.listDisplayMode = .detailed
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(appState.listDisplayMode == .detailed)

            Button(String(localized: "Table")) {
                appState.listDisplayMode = .table
            }
            .keyboardShortcut("3", modifiers: .command)
            .disabled(appState.listDisplayMode == .table)

            Divider()

            // Sort submenu
            Menu(String(localized: "Sort By")) {
                ForEach(TorrentSortOrder.allCases) { order in
                    Button {
                        if appState.sortOrder == order {
                            appState.sortAscending.toggle()
                        } else {
                            appState.sortOrder = order
                            appState.sortAscending = true
                        }
                    } label: {
                        if appState.sortOrder == order {
                            let arrow = appState.sortAscending ? "↑" : "↓"
                            Text("✓ \(order.label) \(arrow)")
                        } else {
                            Text("    \(order.label)")
                        }
                    }
                }

                Divider()

                Button(String(localized: "Ascending")) {
                    appState.sortAscending = true
                }
                .disabled(appState.sortAscending)

                Button(String(localized: "Descending")) {
                    appState.sortAscending = false
                }
                .disabled(!appState.sortAscending)
            }

            Divider()
        }
    }
}
