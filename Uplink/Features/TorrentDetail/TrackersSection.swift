import SwiftUI

/// Displays tracker information grouped by tier, with add/remove functionality.
/// Collapsible via DisclosureGroup, collapsed by default.
struct TrackersSection: View {
    let torrent: Torrent
    let appState: AppState

    @State private var isExpanded: Bool = false
    @State private var newTrackerURL: String = ""
    @State private var isAddingTracker: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: .spacing8) {
                if torrent.trackerStats.isEmpty {
                    Text("No trackers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    let grouped = Dictionary(grouping: torrent.trackerStats, by: \.tier)
                    let sortedTiers = grouped.keys.sorted()
                    ForEach(sortedTiers, id: \.self) { tier in
                        if sortedTiers.count > 1 {
                            Text("Tier \(tier)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.tertiary)
                                .padding(.top, .spacing4)
                        }
                        if let trackers = grouped[tier] {
                            ForEach(trackers) { tracker in
                                trackerRow(tracker)
                            }
                        }
                    }
                }

                Divider()

                // Add tracker
                if isAddingTracker {
                    HStack(spacing: .spacing4) {
                        TextField("Tracker URL", text: $newTrackerURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Button("Add") {
                            guard !newTrackerURL.isEmpty else { return }
                            Task {
                                var settings = TorrentSettings()
                                settings.trackerAdd = [newTrackerURL]
                                await appState.setTorrentSettings(ids: [torrent.id], settings: settings)
                                newTrackerURL = ""
                                isAddingTracker = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newTrackerURL.isEmpty)
                        Button("Cancel") {
                            newTrackerURL = ""
                            isAddingTracker = false
                        }
                        .controlSize(.small)
                    }
                } else {
                    Button {
                        isAddingTracker = true
                    } label: {
                        Label("Add Tracker", systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        } label: {
            HStack {
                Text("Trackers")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                if !torrent.trackerStats.isEmpty {
                    Text("(\(torrent.trackerStats.count))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func trackerRow(_ tracker: TrackerStat) -> some View {
        VStack(alignment: .leading, spacing: .spacing2) {
            HStack {
                Text(tracker.sitename.isEmpty ? tracker.host : tracker.sitename)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                // Remove via context menu
                Menu {
                    Button(role: .destructive) {
                        Task {
                            var settings = TorrentSettings()
                            settings.trackerRemove = [tracker.id]
                            await appState.setTorrentSettings(ids: [torrent.id], settings: settings)
                        }
                    } label: {
                        Label("Remove Tracker", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }

            HStack(spacing: .spacing8) {
                Label("\(tracker.seederCount >= 0 ? "\(tracker.seederCount)" : "?")", systemImage: "arrow.up")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label("\(tracker.leecherCount >= 0 ? "\(tracker.leecherCount)" : "?")", systemImage: "arrow.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !tracker.lastAnnounceResult.isEmpty && tracker.lastAnnounceResult != "Success" {
                    Text(tracker.lastAnnounceResult)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, .spacing2)
    }
}
