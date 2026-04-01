import Foundation

/// Status codes returned by the Transmission RPC API.
enum TorrentStatus: Int, Codable, Sendable, Comparable {
    case stopped = 0
    case checkWait = 1
    case check = 2
    case downloadWait = 3
    case download = 4
    case seedWait = 5
    case seed = 6

    static func < (lhs: TorrentStatus, rhs: TorrentStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Human-readable label for display.
    var label: String {
        switch self {
        case .stopped: String(localized: "Paused")
        case .checkWait: String(localized: "Waiting to Check")
        case .check: String(localized: "Checking")
        case .downloadWait: String(localized: "Waiting to Download")
        case .download: String(localized: "Downloading")
        case .seedWait: String(localized: "Waiting to Seed")
        case .seed: String(localized: "Seeding")
        }
    }

    /// The SF Symbol name associated with this status.
    var symbolName: String {
        switch self {
        case .stopped: "pause.circle.fill"
        case .checkWait, .check: "arrow.triangle.2.circlepath.circle.fill"
        case .downloadWait, .download: "arrow.down.circle.fill"
        case .seedWait, .seed: "arrow.up.circle.fill"
        }
    }
}

/// Bandwidth priority levels for a torrent.
enum BandwidthPriority: Int, Codable, Sendable, CaseIterable, Identifiable {
    case low = -1
    case normal = 0
    case high = 1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low: String(localized: "Low")
        case .normal: String(localized: "Normal")
        case .high: String(localized: "High")
        }
    }
}

/// Mode controlling how seed ratio / idle limits are applied per-torrent.
enum SeedLimitMode: Int, Codable, Sendable, CaseIterable, Identifiable {
    case useGlobal = 0
    case custom = 1
    case unlimited = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .useGlobal: String(localized: "Use Global")
        case .custom: String(localized: "Custom")
        case .unlimited: String(localized: "Unlimited")
        }
    }
}

/// Sort criteria for the torrent list.
enum TorrentSortOrder: String, CaseIterable, Identifiable, Sendable {
    case name = "Name"
    case status = "Status"
    case percentDone = "Progress"
    case rateDownload = "Download Speed"
    case rateUpload = "Upload Speed"
    case totalSize = "Size"
    case uploadRatio = "Ratio"
    case addedDate = "Date Added"
    case queuePosition = "Queue Position"
    case eta = "ETA"

    var id: String { rawValue }

    /// Localized display label.
    var label: String {
        switch self {
        case .name: String(localized: "Name")
        case .status: String(localized: "Status")
        case .percentDone: String(localized: "Progress")
        case .rateDownload: String(localized: "Download Speed")
        case .rateUpload: String(localized: "Upload Speed")
        case .totalSize: String(localized: "Size")
        case .uploadRatio: String(localized: "Ratio")
        case .addedDate: String(localized: "Date Added")
        case .queuePosition: String(localized: "Queue Position")
        case .eta: String(localized: "ETA")
        }
    }

    /// The SF Symbol for this sort option.
    var symbolName: String {
        switch self {
        case .name: "textformat.abc"
        case .status: "circle.grid.2x1.fill"
        case .percentDone: "percent"
        case .rateDownload: "arrow.down"
        case .rateUpload: "arrow.up"
        case .totalSize: "externaldrive"
        case .uploadRatio: "arrow.up.arrow.down"
        case .addedDate: "calendar"
        case .queuePosition: "list.number"
        case .eta: "clock"
        }
    }
}

/// Display modes for the torrent list rows.
enum ListDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case compact = "Compact"
    case detailed = "Detailed"
    case table = "Table"

    var id: String { rawValue }

    /// Localized display label.
    var label: String {
        switch self {
        case .compact: String(localized: "Compact")
        case .detailed: String(localized: "Detailed")
        case .table: String(localized: "Table")
        }
    }

    var symbolName: String {
        switch self {
        case .compact: "list.bullet"
        case .detailed: "list.bullet.below.rectangle"
        case .table: "tablecells"
        }
    }
}

/// Sidebar filter categories for the torrent list.
enum TorrentFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case downloading = "Downloading"
    case seeding = "Seeding"
    case paused = "Paused"
    case error = "Error"

    var id: String { rawValue }

    /// Localized display label.
    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .downloading: String(localized: "Downloading")
        case .seeding: String(localized: "Seeding")
        case .paused: String(localized: "Paused")
        case .error: String(localized: "Error")
        }
    }

    /// The SF Symbol name for this filter.
    var symbolName: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .downloading: "arrow.down.circle.fill"
        case .seeding: "arrow.up.circle.fill"
        case .paused: "pause.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    /// Returns whether a torrent matches this filter.
    func matches(_ torrent: Torrent) -> Bool {
        switch self {
        case .all:
            return true
        case .downloading:
            return torrent.status == .download || torrent.status == .downloadWait
        case .seeding:
            return torrent.status == .seed || torrent.status == .seedWait
        case .paused:
            return torrent.status == .stopped
        case .error:
            return torrent.hasError
        }
    }
}

/// A single file within a torrent.
struct TorrentFile: Codable, Sendable {
    /// Relative path within the torrent.
    let name: String
    let length: Int64
    let bytesCompleted: Int64
}

/// Download stats for a single file within a torrent.
struct TorrentFileStats: Codable, Sendable {
    let wanted: Bool
    /// -1 = low, 0 = normal, 1 = high
    let priority: Int
    let bytesCompleted: Int64

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Some Transmission versions return wanted as 0/1 instead of true/false
        wanted = decodeBoolOrInt(from: c, forKey: .wanted) ?? true
        priority = try c.decode(Int.self, forKey: .priority)
        bytesCompleted = try c.decode(Int64.self, forKey: .bytesCompleted)
    }

    private enum CodingKeys: String, CodingKey {
        case wanted, priority, bytesCompleted
    }
}

/// Core domain model representing a torrent from the Transmission RPC API.
struct Torrent: Identifiable, Sendable {
    let id: Int
    let name: String
    let status: TorrentStatus
    /// Progress from 0.0 to 1.0.
    let percentDone: Double
    /// Download speed in bytes per second.
    let rateDownload: Int
    /// Upload speed in bytes per second.
    let rateUpload: Int
    let totalSize: Int64
    let downloadedEver: Int64
    let uploadedEver: Int64
    let uploadRatio: Double
    /// Estimated time remaining in seconds. -1 = unknown, -2 = unlimited.
    let eta: Int
    let error: Int
    let errorString: String
    let downloadDir: String
    /// Unix timestamp when the torrent was added.
    let addedDate: Int
    let files: [TorrentFile]
    let fileStats: [TorrentFileStats]
    /// The info hash of the torrent.
    let hashString: String
    /// The magnet link for this torrent.
    let magnetLink: String
    /// Bandwidth priority: -1 low, 0 normal, 1 high.
    let bandwidthPriority: Int
    /// Maximum download speed in kB/s.
    let downloadLimit: Int
    /// Whether the download speed limit is enforced.
    let downloadLimited: Bool
    /// Maximum upload speed in kB/s.
    let uploadLimit: Int
    /// Whether the upload speed limit is enforced.
    let uploadLimited: Bool
    /// Whether this torrent honors session-wide speed limits.
    let honorsSessionLimits: Bool
    /// Seed ratio threshold for this torrent.
    let seedRatioLimit: Double
    /// Seed ratio mode: 0 = global, 1 = custom, 2 = unlimited.
    let seedRatioMode: Int
    /// Seed idle limit in minutes.
    let seedIdleLimit: Int
    /// Seed idle mode: 0 = global, 1 = custom, 2 = unlimited.
    let seedIdleMode: Int
    /// Maximum number of peer connections for this torrent.
    let peerLimit: Int
    /// Position in the download/seed queue.
    let queuePosition: Int
    /// User-assigned labels.
    let labels: [String]
    /// Whether to download pieces sequentially.
    let sequentialDownload: Bool
    /// Tracker information for this torrent.
    let trackers: [TrackerInfo]
    /// Detailed tracker statistics.
    let trackerStats: [TrackerStat]
    /// Connected peers.
    let peers: [PeerInfo]
    /// Total number of peers connected.
    let peersConnected: Int
    /// Number of peers we are uploading to.
    let peersGettingFromUs: Int
    /// Number of peers we are downloading from.
    let peersSendingToUs: Int
    /// The creator of the torrent file.
    let creator: String
    /// The torrent's comment field.
    let comment: String
    /// Unix timestamp when the torrent was created.
    let dateCreated: Int
    /// Whether this torrent uses a private tracker.
    let isPrivate: Bool
    /// Size of each piece in bytes.
    let pieceSize: Int64
    /// Total number of pieces.
    let pieceCount: Int

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, status, percentDone, rateDownload, rateUpload
        case totalSize, downloadedEver, uploadedEver, uploadRatio
        case eta, error, errorString, downloadDir, addedDate
        case files, fileStats, hashString, magnetLink
        case bandwidthPriority, downloadLimit, downloadLimited
        case uploadLimit, uploadLimited, honorsSessionLimits
        case seedRatioLimit, seedRatioMode, seedIdleLimit, seedIdleMode
        case peerLimit, queuePosition, labels, sequentialDownload
        case trackers, trackerStats, peers
        case peersConnected, peersGettingFromUs, peersSendingToUs
        case creator, comment, dateCreated, isPrivate, pieceSize, pieceCount
    }
}

extension Torrent: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        status = try c.decode(TorrentStatus.self, forKey: .status)
        percentDone = try c.decode(Double.self, forKey: .percentDone)
        rateDownload = try c.decode(Int.self, forKey: .rateDownload)
        rateUpload = try c.decode(Int.self, forKey: .rateUpload)
        totalSize = try c.decode(Int64.self, forKey: .totalSize)
        downloadedEver = try c.decode(Int64.self, forKey: .downloadedEver)
        uploadedEver = try c.decode(Int64.self, forKey: .uploadedEver)
        uploadRatio = try c.decode(Double.self, forKey: .uploadRatio)
        eta = try c.decode(Int.self, forKey: .eta)
        error = try c.decode(Int.self, forKey: .error)
        errorString = try c.decode(String.self, forKey: .errorString)
        downloadDir = try c.decode(String.self, forKey: .downloadDir)
        addedDate = try c.decode(Int.self, forKey: .addedDate)
        files = try c.decode([TorrentFile].self, forKey: .files)
        fileStats = try c.decode([TorrentFileStats].self, forKey: .fileStats)
        hashString = try c.decode(String.self, forKey: .hashString)
        magnetLink = try c.decode(String.self, forKey: .magnetLink)
        // Fields that may not be present on older Transmission versions
        bandwidthPriority = try c.decodeIfPresent(Int.self, forKey: .bandwidthPriority) ?? 0
        downloadLimit = try c.decodeIfPresent(Int.self, forKey: .downloadLimit) ?? 0
        downloadLimited = decodeBoolOrInt(from: c, forKey: .downloadLimited) ?? false
        uploadLimit = try c.decodeIfPresent(Int.self, forKey: .uploadLimit) ?? 0
        uploadLimited = decodeBoolOrInt(from: c, forKey: .uploadLimited) ?? false
        honorsSessionLimits = decodeBoolOrInt(from: c, forKey: .honorsSessionLimits) ?? true
        seedRatioLimit = try c.decodeIfPresent(Double.self, forKey: .seedRatioLimit) ?? 0.0
        seedRatioMode = try c.decodeIfPresent(Int.self, forKey: .seedRatioMode) ?? 0
        seedIdleLimit = try c.decodeIfPresent(Int.self, forKey: .seedIdleLimit) ?? 0
        seedIdleMode = try c.decodeIfPresent(Int.self, forKey: .seedIdleMode) ?? 0
        peerLimit = try c.decodeIfPresent(Int.self, forKey: .peerLimit) ?? 50
        queuePosition = try c.decodeIfPresent(Int.self, forKey: .queuePosition) ?? 0
        labels = try c.decodeIfPresent([String].self, forKey: .labels) ?? []
        sequentialDownload = decodeBoolOrInt(from: c, forKey: .sequentialDownload) ?? false
        trackers = try c.decodeIfPresent([TrackerInfo].self, forKey: .trackers) ?? []
        trackerStats = try c.decodeIfPresent([TrackerStat].self, forKey: .trackerStats) ?? []
        peers = try c.decodeIfPresent([PeerInfo].self, forKey: .peers) ?? []
        peersConnected = try c.decodeIfPresent(Int.self, forKey: .peersConnected) ?? 0
        peersGettingFromUs = try c.decodeIfPresent(Int.self, forKey: .peersGettingFromUs) ?? 0
        peersSendingToUs = try c.decodeIfPresent(Int.self, forKey: .peersSendingToUs) ?? 0
        creator = try c.decodeIfPresent(String.self, forKey: .creator) ?? ""
        comment = try c.decodeIfPresent(String.self, forKey: .comment) ?? ""
        dateCreated = try c.decodeIfPresent(Int.self, forKey: .dateCreated) ?? 0
        isPrivate = decodeBoolOrInt(from: c, forKey: .isPrivate) ?? false
        pieceSize = try c.decodeIfPresent(Int64.self, forKey: .pieceSize) ?? 0
        pieceCount = try c.decodeIfPresent(Int.self, forKey: .pieceCount) ?? 0
    }

    /// Whether this torrent has an active error.
    var hasError: Bool {
        error != 0
    }

    /// Whether this torrent is currently transferring data.
    var isActive: Bool {
        switch status {
        case .download, .seed:
            return true
        default:
            return false
        }
    }

    /// Formatted ETA string for display.
    var formattedETA: String? {
        guard eta >= 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: TimeInterval(eta))
    }

    /// Date when the torrent was added.
    var addedDateValue: Date {
        Date(timeIntervalSince1970: TimeInterval(addedDate))
    }

    /// Date when the torrent file was created, if available.
    var dateCreatedValue: Date? {
        guard dateCreated > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(dateCreated))
    }
}
