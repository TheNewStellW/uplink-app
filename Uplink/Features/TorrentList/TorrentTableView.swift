import SwiftUI

/// A column-based table view for torrents with sortable, user-customizable columns.
/// Uses SwiftUI's native `Table` with clickable column headers for sorting.
struct TorrentTableView: View {
    let torrents: [Torrent]
    @Binding var selection: Set<Int>
    @Binding var sortOrder: [KeyPathComparator<Torrent>]
    @Binding var columnCustomization: TableColumnCustomization<Torrent>
    let contextMenu: (Torrent) -> AnyView

    var body: some View {
        Table(
            torrents,
            selection: $selection,
            sortOrder: $sortOrder,
            columnCustomization: $columnCustomization
        ) {
            defaultVisibleColumns
            defaultHiddenColumns
        }
        .contextMenu(forSelectionType: Int.self) { ids in
            if let id = ids.first,
               let torrent = torrents.first(where: { $0.id == id }) {
                contextMenu(torrent)
            }
        } primaryAction: { _ in
            // Double-click — no special action needed
        }
    }

    // MARK: - Default Visible Columns

    @TableColumnBuilder<Torrent, KeyPathComparator<Torrent>>
    private var defaultVisibleColumns: some TableColumnContent<Torrent, KeyPathComparator<Torrent>> {
        TableColumn("Name", value: \Torrent.name) { torrent in
            HStack(spacing: .spacing4) {
                Image(systemName: torrent.status.symbolName)
                    .font(.caption2)
                    .foregroundStyle(torrent.hasError ? .red : torrent.status.color)
                    .frame(width: 12)
                Text(torrent.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .width(min: 150, ideal: 300)
        .customizationID("name")
        .disabledCustomizationBehavior(.visibility)

        TableColumn("Status", value: \Torrent.status) { torrent in
            StatusBadge(status: torrent.status, hasError: torrent.hasError)
        }
        .width(min: 80, ideal: 100)
        .customizationID("status")

        TableColumn("Progress", value: \Torrent.percentDone) { torrent in
            HStack(spacing: .spacing4) {
                ProgressView(value: torrent.percentDone)
                    .progressViewStyle(.linear)
                    .tint(torrent.hasError ? .red : torrent.status.color)
                    .frame(minWidth: 40)
                Text("\(Int(torrent.percentDone * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .width(min: 80, ideal: 120)
        .customizationID("progress")

        TableColumn("↓ Speed", value: \Torrent.rateDownload) { torrent in
            Text(torrent.rateDownload > 0 ? torrent.rateDownload.formattedSpeed : "—")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(torrent.rateDownload > 0 ? .primary : .tertiary)
        }
        .width(min: 60, ideal: 80)
        .customizationID("rateDownload")

        TableColumn("↑ Speed", value: \Torrent.rateUpload) { torrent in
            Text(torrent.rateUpload > 0 ? torrent.rateUpload.formattedSpeed : "—")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(torrent.rateUpload > 0 ? .primary : .tertiary)
        }
        .width(min: 60, ideal: 80)
        .customizationID("rateUpload")

        TableColumn("Size", value: \Torrent.totalSize) { torrent in
            Text(torrent.totalSize.formattedByteCount)
                .font(.caption)
                .monospacedDigit()
        }
        .width(min: 60, ideal: 80)
        .customizationID("totalSize")

        TableColumn("ETA", value: \Torrent.eta) { torrent in
            Text(torrent.formattedETA ?? "—")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(torrent.eta >= 0 ? .primary : .tertiary)
        }
        .width(min: 50, ideal: 70)
        .customizationID("eta")

        TableColumn("Ratio", value: \Torrent.uploadRatio) { torrent in
            Text(torrent.uploadRatio >= 0 ? String(format: "%.2f", torrent.uploadRatio) : "—")
                .font(.caption)
                .monospacedDigit()
        }
        .width(min: 45, ideal: 55)
        .customizationID("ratio")
    }

    // MARK: - Default Hidden Columns

    @TableColumnBuilder<Torrent, KeyPathComparator<Torrent>>
    private var defaultHiddenColumns: some TableColumnContent<Torrent, KeyPathComparator<Torrent>> {
        TableColumn("Downloaded", value: \Torrent.downloadedEver) { torrent in
            Text(torrent.downloadedEver.formattedByteCount)
                .font(.caption)
                .monospacedDigit()
        }
        .width(min: 60, ideal: 80)
        .customizationID("downloaded")
        .defaultVisibility(.hidden)

        TableColumn("Uploaded", value: \Torrent.uploadedEver) { torrent in
            Text(torrent.uploadedEver.formattedByteCount)
                .font(.caption)
                .monospacedDigit()
        }
        .width(min: 60, ideal: 80)
        .customizationID("uploaded")
        .defaultVisibility(.hidden)

        TableColumn("Added", value: \Torrent.addedDate) { torrent in
            Text(torrent.addedDateValue, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption)
        }
        .width(min: 80, ideal: 120)
        .customizationID("addedDate")
        .defaultVisibility(.hidden)

        TableColumn("Location", value: \Torrent.downloadDir) { torrent in
            Text(torrent.downloadDir)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .width(min: 100, ideal: 200)
        .customizationID("downloadDir")
        .defaultVisibility(.hidden)

        TableColumn("Queue", value: \Torrent.queuePosition) { torrent in
            Text("\(torrent.queuePosition)")
                .font(.caption)
                .monospacedDigit()
        }
        .width(min: 40, ideal: 50)
        .customizationID("queuePosition")
        .defaultVisibility(.hidden)

        TableColumn("Priority", value: \Torrent.bandwidthPriority) { torrent in
            let priority = BandwidthPriority(rawValue: torrent.bandwidthPriority) ?? .normal
            Text(priority.label)
                .font(.caption)
        }
        .width(min: 50, ideal: 65)
        .customizationID("priority")
        .defaultVisibility(.hidden)

        TableColumn("Peers", value: \Torrent.peersConnected) { torrent in
            Text("\(torrent.peersSendingToUs)/\(torrent.peersConnected)")
                .font(.caption)
                .monospacedDigit()
        }
        .width(min: 45, ideal: 60)
        .customizationID("peers")
        .defaultVisibility(.hidden)

        TableColumn("Seeds", value: \Torrent.peersGettingFromUs) { torrent in
            Text("\(torrent.peersGettingFromUs)")
                .font(.caption)
                .monospacedDigit()
        }
        .width(min: 40, ideal: 50)
        .customizationID("seeds")
        .defaultVisibility(.hidden)

        TableColumn("Hash", value: \Torrent.hashString) { torrent in
            Text(torrent.hashString)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .width(min: 80, ideal: 120)
        .customizationID("hash")
        .defaultVisibility(.hidden)

        TableColumn("Error", value: \Torrent.errorString) { torrent in
            if torrent.hasError {
                Text(torrent.errorString)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .width(min: 60, ideal: 120)
        .customizationID("error")
        .defaultVisibility(.hidden)
    }
}
