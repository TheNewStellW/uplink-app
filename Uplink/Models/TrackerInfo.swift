import Foundation

/// Decodes a value that may be a JSON boolean or an integer (0/1).
/// Some Transmission versions encode booleans as integers.
func decodeBoolOrInt<K: CodingKey>(
    from container: KeyedDecodingContainer<K>,
    forKey key: K
) -> Bool? {
    if let value = try? container.decode(Bool.self, forKey: key) {
        return value
    }
    if let intValue = try? container.decode(Int.self, forKey: key) {
        return intValue != 0
    }
    return nil
}

/// Basic tracker information as returned by the `trackers` field in `torrent-get`.
struct TrackerInfo: Codable, Sendable, Identifiable {
    let id: Int
    let announce: String
    let scrape: String
    let sitename: String
    let tier: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        announce = try c.decodeIfPresent(String.self, forKey: .announce) ?? ""
        scrape = try c.decodeIfPresent(String.self, forKey: .scrape) ?? ""
        sitename = try c.decodeIfPresent(String.self, forKey: .sitename) ?? ""
        tier = try c.decodeIfPresent(Int.self, forKey: .tier) ?? 0
    }
}

/// Detailed tracker statistics as returned by the `trackerStats` field in `torrent-get`.
struct TrackerStat: Codable, Sendable, Identifiable {
    let id: Int
    let host: String
    let sitename: String
    let tier: Int
    let announceState: Int
    let downloadCount: Int
    let hasAnnounced: Bool
    let hasScraped: Bool
    let lastAnnouncePeerCount: Int
    let lastAnnounceResult: String
    let lastScrapeResult: String
    let leecherCount: Int
    let seederCount: Int
    let nextAnnounceTime: Int
    let nextScrapeTime: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? ""
        sitename = try c.decodeIfPresent(String.self, forKey: .sitename) ?? ""
        tier = try c.decodeIfPresent(Int.self, forKey: .tier) ?? 0
        announceState = try c.decodeIfPresent(Int.self, forKey: .announceState) ?? 0
        downloadCount = try c.decodeIfPresent(Int.self, forKey: .downloadCount) ?? -1
        hasAnnounced = decodeBoolOrInt(from: c, forKey: .hasAnnounced) ?? false
        hasScraped = decodeBoolOrInt(from: c, forKey: .hasScraped) ?? false
        lastAnnouncePeerCount = try c.decodeIfPresent(Int.self, forKey: .lastAnnouncePeerCount) ?? 0
        lastAnnounceResult = try c.decodeIfPresent(String.self, forKey: .lastAnnounceResult) ?? ""
        lastScrapeResult = try c.decodeIfPresent(String.self, forKey: .lastScrapeResult) ?? ""
        leecherCount = try c.decodeIfPresent(Int.self, forKey: .leecherCount) ?? -1
        seederCount = try c.decodeIfPresent(Int.self, forKey: .seederCount) ?? -1
        nextAnnounceTime = try c.decodeIfPresent(Int.self, forKey: .nextAnnounceTime) ?? 0
        nextScrapeTime = try c.decodeIfPresent(Int.self, forKey: .nextScrapeTime) ?? 0
    }
}

/// Information about a connected peer as returned by the `peers` field in `torrent-get`.
struct PeerInfo: Codable, Sendable, Identifiable {
    let address: String
    let clientName: String
    let flagStr: String
    let isDownloadingFrom: Bool
    let isUploadingTo: Bool
    let port: Int
    let progress: Double
    let rateToClient: Int
    let rateToPeer: Int

    /// Unique identifier combining address and port.
    var id: String { "\(address):\(port)" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        clientName = try c.decodeIfPresent(String.self, forKey: .clientName) ?? ""
        flagStr = try c.decodeIfPresent(String.self, forKey: .flagStr) ?? ""
        isDownloadingFrom = decodeBoolOrInt(from: c, forKey: .isDownloadingFrom) ?? false
        isUploadingTo = decodeBoolOrInt(from: c, forKey: .isUploadingTo) ?? false
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? 0
        progress = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0.0
        rateToClient = try c.decodeIfPresent(Int.self, forKey: .rateToClient) ?? 0
        rateToPeer = try c.decodeIfPresent(Int.self, forKey: .rateToPeer) ?? 0
    }
}

/// Session-level statistics as returned by the `session-stats` RPC method.
struct SessionStats: Decodable, Sendable {
    let activeTorrentCount: Int
    let downloadSpeed: Int
    let uploadSpeed: Int
    let pausedTorrentCount: Int
    let torrentCount: Int
    let cumulativeStats: SessionStatGroup
    let currentStats: SessionStatGroup

    enum CodingKeys: String, CodingKey {
        case activeTorrentCount
        case downloadSpeed
        case uploadSpeed
        case pausedTorrentCount
        case torrentCount
        case cumulativeStats = "cumulative-stats"
        case currentStats = "current-stats"
    }
}

/// A group of session statistics (cumulative or current session).
struct SessionStatGroup: Decodable, Sendable {
    let downloadedBytes: Int64
    let filesAdded: Int
    let secondsActive: Int
    let sessionCount: Int
    let uploadedBytes: Int64
}
