import SwiftUI

extension TorrentStatus {
    /// The semantic colour associated with this status.
    var color: Color {
        switch self {
        case .stopped: .secondary
        case .checkWait, .check: .orange
        case .downloadWait, .download: .blue
        case .seedWait, .seed: .green
        }
    }
}
