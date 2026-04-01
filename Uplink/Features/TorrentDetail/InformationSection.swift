import AppKit
import SwiftUI

/// Displays torrent metadata: hash, magnet link, privacy, creator, comment, creation date, pieces.
struct InformationSection: View {
    let torrent: Torrent

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            Text("Information")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            infoRow("Hash", value: torrent.hashString, selectable: true)

            HStack {
                Text("Magnet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)
                Text(torrent.magnetLink)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(torrent.magnetLink, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy Magnet Link")
            }

            infoRow("Privacy", value: torrent.isPrivate ? String(localized: "Private") : String(localized: "Public"))

            if !torrent.creator.isEmpty {
                infoRow("Creator", value: torrent.creator)
            }

            if !torrent.comment.isEmpty {
                infoRow("Comment", value: torrent.comment, selectable: true)
            }

            if let created = torrent.dateCreatedValue {
                infoRow("Created", value: created.formatted(date: .abbreviated, time: .shortened))
            }

            if torrent.pieceCount > 0 && torrent.pieceSize > 0 {
                infoRow("Pieces", value: "\(torrent.pieceCount) × \(torrent.pieceSize.formattedByteCount)")
            }
        }
    }

    private func infoRow(_ label: LocalizedStringKey, value: String, selectable: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            if selectable {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            } else {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            Spacer()
        }
    }
}
