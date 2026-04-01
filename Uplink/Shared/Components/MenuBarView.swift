import AppKit
import SwiftUI

/// The dropdown menu shown when clicking the menu bar extra icon.
struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Status header
        Button(statusText) {}
            .disabled(true)

        if appState.isConnected, appState.totalDownloadSpeed > 0 || appState.totalUploadSpeed > 0 {
            Button("↓ \(appState.totalDownloadSpeed.formattedSpeed)  ↑ \(appState.totalUploadSpeed.formattedSpeed)") {}
                .disabled(true)
        }

        Divider()

        // Torrent actions
        Button("Resume All") {
            Task { await appState.startAllTorrents() }
        }
        .disabled(!appState.isConnected || appState.torrents.isEmpty)

        Button("Pause All") {
            Task { await appState.stopAllTorrents() }
        }
        .disabled(!appState.isConnected || appState.torrents.isEmpty)

        Divider()

        Button("Add Torrent…") {
            appState.showingAddTorrent = true
            NSApp.activate(ignoringOtherApps: true)
        }
        .disabled(!appState.isConnected)

        Divider()

        // Server list
        let servers = appState.sessionManager.servers
        let activeId = appState.sessionManager.activeServerId

        ForEach(servers) { server in
            Button {
                Task { await appState.switchServer(to: server.id) }
            } label: {
                if server.id == activeId {
                    Text("✓ \(server.name)")
                } else {
                    Text("   \(server.name)")
                }
            }
        }

        Divider()

        Button("Open Window") {
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit") {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Computed

    private var statusText: String {
        if appState.isConnected, let name = appState.activeServerName {
            return String(localized: "Connected — \(name)")
        } else if appState.isReconnecting, let name = appState.activeServerName {
            return String(localized: "Reconnecting — \(name)")
        } else {
            return String(localized: "Disconnected")
        }
    }
}
