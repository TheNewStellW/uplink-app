import SwiftUI

/// A capsule-shaped badge displaying a torrent's status with appropriate colouring.
struct StatusBadge: View {
    let status: TorrentStatus
    let hasError: Bool

    init(status: TorrentStatus, hasError: Bool = false) {
        self.status = status
        self.hasError = hasError
    }

    private var displayColor: Color {
        hasError ? .red : status.color
    }

    private var displayLabel: String {
        hasError ? String(localized: "Error") : status.label
    }

    private var displaySymbol: String {
        hasError ? "exclamationmark.triangle.fill" : status.symbolName
    }

    var body: some View {
        HStack(spacing: .spacing2) {
            Image(systemName: displaySymbol)
                .font(.caption2)
            Text(displayLabel)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(displayColor)
        .padding(.horizontal, .spacing4 + .spacing2)
        .padding(.vertical, .spacing2)
        .background(displayColor.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Status: \(displayLabel)"))
    }
}
