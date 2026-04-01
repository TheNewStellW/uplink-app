import SwiftUI

/// A thin status bar displayed at the bottom of the main window.
///
/// Shows connection status, active server name, torrent count, and global speeds.
struct StatusBarView: View {
    @Environment(AppState.self) private var appState
    @State private var showingStats = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: .spacing12) {
                connectionIndicator
                Spacer()
                if appState.isConnected || appState.isReconnecting {
                    if let version = appState.sessionSettings?.version, !version.isEmpty {
                        Text(version)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    altSpeedToggle
                    sessionStatsButton
                    Spacer()
                    SpeedIndicator(
                        downloadSpeed: appState.totalDownloadSpeed,
                        uploadSpeed: appState.totalUploadSpeed
                    )
                }
            }
            .padding(.horizontal, .spacing16)
            .padding(.vertical, .spacing4)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Subviews

    private var connectionIndicator: some View {
        HStack(spacing: .spacing4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if case .error = appState.connectionStatus {
                Button("Retry") {
                    Task { await appState.connect() }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            if case .reconnecting = appState.connectionStatus {
                Button("Try Now") {
                    Task { await appState.reconnectNow() }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
    }

    private var sessionStatsButton: some View {
        let count = appState.torrents.count
        let countText = String(localized: "\(count) torrents")
        return Button {
            showingStats.toggle()
        } label: {
            Text(countText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Session Statistics"))
        .accessibilityValue(countText)
        .popover(isPresented: $showingStats) {
            sessionStatsPopover
        }
    }

    @ViewBuilder
    private var sessionStatsPopover: some View {
        if let stats = appState.sessionStats {
            VStack(alignment: .leading, spacing: .spacing8) {
                Text("Session Statistics")
                    .font(.headline)

                Divider()

                Group {
                    statsRow("Active", value: "\(stats.activeTorrentCount)")
                    statsRow("Paused", value: "\(stats.pausedTorrentCount)")
                    statsRow("Total", value: "\(stats.torrentCount)")
                }

                Divider()

                Text("This Session")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                statsRow("Downloaded", value: stats.currentStats.downloadedBytes.formattedByteCount)
                statsRow("Uploaded", value: stats.currentStats.uploadedBytes.formattedByteCount)
                statsRow("Duration", value: formatDuration(stats.currentStats.secondsActive))

                Divider()

                Text("All Time")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                statsRow("Downloaded", value: stats.cumulativeStats.downloadedBytes.formattedByteCount)
                statsRow("Uploaded", value: stats.cumulativeStats.uploadedBytes.formattedByteCount)
                statsRow("Sessions", value: "\(stats.cumulativeStats.sessionCount)")
                statsRow("Duration", value: formatDuration(stats.cumulativeStats.secondsActive))
            }
            .padding(.spacing12)
            .frame(width: 240)
        } else {
            Text("No statistics available")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.spacing12)
        }
    }

    private func statsRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .monospacedDigit()
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 {
            return String(localized: "\(days)d \(hours)h \(minutes)m")
        } else if hours > 0 {
            return String(localized: "\(hours)h \(minutes)m")
        } else {
            return String(localized: "\(minutes)m")
        }
    }

    private var altSpeedToggle: some View {
        let isAltSpeed = appState.sessionSettings?.altSpeedEnabled ?? false
        return Button {
            Task { await appState.toggleAltSpeed() }
        } label: {
            Image(systemName: "tortoise.fill")
                .font(.caption)
                .foregroundStyle(isAltSpeed ? .blue : .secondary)
        }
        .buttonStyle(.plain)
        .help(isAltSpeed ? "Disable Alternative Speed Limits" : "Enable Alternative Speed Limits")
        .accessibilityLabel(String(localized: "Alternative Speed Limits"))
        .accessibilityValue(isAltSpeed ? String(localized: "Enabled") : String(localized: "Disabled"))
        .accessibilityAddTraits(.isToggle)
    }

    // MARK: - Computed

    private var statusColor: Color {
        switch appState.connectionStatus {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .error:
            return .red
        case .disconnected:
            return .secondary
        }
    }

    private var statusText: String {
        switch appState.connectionStatus {
        case .connected:
            if let name = appState.activeServerName {
                return String(localized: "Connected — \(name)")
            }
            return String(localized: "Connected")
        case .connecting:
            return String(localized: "Connecting…")
        case .reconnecting:
            let name = appState.activeServerName ?? String(localized: "server")
            if appState.reconnectCountdown > 0 {
                return String(localized: "Reconnecting in \(appState.reconnectCountdown)s — \(name)")
            }
            return String(localized: "Reconnecting… — \(name)")
        case .error(let message):
            return String(localized: "Error: \(message)")
        case .disconnected:
            return String(localized: "Disconnected")
        }
    }
}
