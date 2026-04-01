import SwiftUI

/// Displays download and upload speeds with directional arrow icons.
struct SpeedIndicator: View {
    let downloadSpeed: Int
    let uploadSpeed: Int

    var body: some View {
        HStack(spacing: .spacing8) {
            HStack(spacing: .spacing2) {
                Image(systemName: "arrow.down")
                    .foregroundStyle(.blue)
                    .font(.caption2)
                Text(downloadSpeed.formattedSpeed)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: .spacing2) {
                Image(systemName: "arrow.up")
                    .foregroundStyle(.green)
                    .font(.caption2)
                Text(uploadSpeed.formattedSpeed)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Download \(downloadSpeed.formattedSpeed), Upload \(uploadSpeed.formattedSpeed)"))
    }
}
