import SwiftUI

/// Displays connected peers with their speeds, progress, and client info.
/// Collapsible via DisclosureGroup, collapsed by default.
struct PeersSection: View {
    let torrent: Torrent

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: .spacing8) {
                if torrent.peers.isEmpty {
                    Text("No peers connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    let sortedPeers = torrent.peers.sorted {
                        ($0.rateToClient + $0.rateToPeer) > ($1.rateToClient + $1.rateToPeer)
                    }
                    ForEach(sortedPeers) { peer in
                        peerRow(peer)
                    }
                }
            }
        } label: {
            HStack {
                Text("Peers")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text("(\(torrent.peersConnected) connected)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func peerRow(_ peer: PeerInfo) -> some View {
        VStack(alignment: .leading, spacing: .spacing2) {
            HStack {
                Text(peer.address)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
                if !peer.clientName.isEmpty {
                    Text("— \(peer.clientName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if !peer.flagStr.isEmpty {
                    Text(peer.flagStr)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: .spacing8) {
                ProgressView(value: peer.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)
                    .scaleEffect(y: 0.5, anchor: .center)

                Text("\(Int(peer.progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 30, alignment: .trailing)

                if peer.rateToClient > 0 {
                    HStack(spacing: .spacing2) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                        Text(peer.rateToClient.formattedSpeed)
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.blue)
                }

                if peer.rateToPeer > 0 {
                    HStack(spacing: .spacing2) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                        Text(peer.rateToPeer.formattedSpeed)
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, .spacing2)
    }
}
