import Foundation

extension Int64 {
    /// Formats a byte count into a human-readable string (e.g. "1.5 GB").
    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension Int {
    /// Formats a bytes-per-second value into a human-readable speed string (e.g. "1.2 MB/s").
    var formattedSpeed: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file) + "/s"
    }
}
