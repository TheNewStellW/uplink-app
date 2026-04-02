import AppKit
import SwiftUI

/// The detail panel shown when a torrent is selected.
struct TorrentDetailView: View {
    let torrent: Torrent
    let appState: AppState

    @State private var freeSpaceText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacing16) {
                headerSection
                Divider()
                statsSection
                Divider()
                InformationSection(torrent: torrent)
                Divider()
                TrackersSection(torrent: torrent, appState: appState)
                Divider()
                PeersSection(torrent: torrent)
                Divider()
                TorrentSettingsSection(torrent: torrent, appState: appState)
                Divider()
                FileTreeView(torrent: torrent, appState: appState)
            }
            .padding(.spacing16)
        }
        .frame(minWidth: 320)
        .navigationTitle(torrent.name)
        .task(id: torrent.downloadDir) {
            if let response = await appState.getFreeSpace(path: torrent.downloadDir) {
                freeSpaceText = String(localized: "\(response.sizeBytes.formattedByteCount) free")
            } else {
                freeSpaceText = nil
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            Text(torrent.name)
                .font(.headline)
                .textSelection(.enabled)

            HStack(spacing: .spacing8) {
                StatusBadge(status: torrent.status, hasError: torrent.hasError)

                if torrent.hasError && !torrent.errorString.isEmpty {
                    Text(torrent.errorString)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            ProgressView(value: torrent.percentDone)
                .progressViewStyle(.linear)
                .tint(torrent.hasError ? .red : torrent.status.color)

            Text("\(Int(torrent.percentDone * 100))% complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            Text("Details")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            statRow("Size", value: torrent.totalSize.formattedByteCount)
            statRow("Downloaded", value: torrent.downloadedEver.formattedByteCount)
            statRow("Uploaded", value: torrent.uploadedEver.formattedByteCount)
            statRow("Ratio", value: String(format: "%.2f", torrent.uploadRatio))
            locationRow
            statRow("Added", value: torrent.addedDateValue.formatted(date: .abbreviated, time: .shortened))

            if torrent.isActive {
                Divider()
                SpeedIndicator(
                    downloadSpeed: torrent.rateDownload,
                    uploadSpeed: torrent.rateUpload
                )
                if let eta = torrent.formattedETA {
                    statRow("ETA", value: eta)
                }
            }
        }
    }

    // MARK: - Location

    private var locationRow: some View {
        HStack {
            Text("Location")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            VStack(alignment: .leading, spacing: .spacing2) {
                Text(torrent.downloadDir)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let freeSpace = freeSpaceText {
                    Text(freeSpace)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if appState.resolveLocalPath(torrent.downloadDir) != nil {
                Button {
                    guard let localURL = appState.resolveLocalPathWithAccess(torrent.downloadDir) else { return }
                    NSWorkspace.shared.open(localURL)
                    appState.sessionManager.stopSecurityScopedAccess()
                } label: {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Open in Finder")
            }
        }
    }

    private func statRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }

}
