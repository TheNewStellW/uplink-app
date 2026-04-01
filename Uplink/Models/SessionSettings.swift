import Foundation

/// The Transmission daemon's session configuration, fetched via `session-get`.
///
/// Uses `decodeIfPresent` for all fields to handle older Transmission versions
/// that may not return every field.
struct SessionSettings: Sendable, Equatable {
    // MARK: - Speed Limits

    var speedLimitDown: Int
    var speedLimitDownEnabled: Bool
    var speedLimitUp: Int
    var speedLimitUpEnabled: Bool

    // MARK: - Alternative Speed Limits (Turtle Mode)

    var altSpeedDown: Int
    var altSpeedUp: Int
    var altSpeedEnabled: Bool
    var altSpeedTimeBegin: Int
    var altSpeedTimeEnd: Int
    var altSpeedTimeEnabled: Bool
    var altSpeedTimeDay: Int

    // MARK: - Downloading

    var downloadDir: String
    var incompleteDir: String
    var incompleteDirEnabled: Bool
    var startAddedTorrents: Bool
    var renamePartialFiles: Bool
    var trashOriginalTorrentFiles: Bool

    // MARK: - Seeding

    var seedRatioLimit: Double
    var seedRatioLimited: Bool
    var idleSeedingLimit: Int
    var idleSeedingLimitEnabled: Bool

    // MARK: - Queue

    var downloadQueueEnabled: Bool
    var downloadQueueSize: Int
    var seedQueueEnabled: Bool
    var seedQueueSize: Int
    var queueStalledEnabled: Bool
    var queueStalledMinutes: Int

    // MARK: - Peers

    var peerLimitGlobal: Int
    var peerLimitPerTorrent: Int
    var dhtEnabled: Bool
    var pexEnabled: Bool
    var lpdEnabled: Bool
    var encryption: String

    // MARK: - Network

    var peerPort: Int
    var peerPortRandomOnStart: Bool
    var portForwardingEnabled: Bool
    var utpEnabled: Bool

    // MARK: - Blocklist

    var blocklistEnabled: Bool
    var blocklistUrl: String
    var blocklistSize: Int

    // MARK: - Scripts

    var scriptTorrentAddedEnabled: Bool
    var scriptTorrentAddedFilename: String
    var scriptTorrentDoneEnabled: Bool
    var scriptTorrentDoneFilename: String
    var scriptTorrentDoneSeedingEnabled: Bool
    var scriptTorrentDoneSeedingFilename: String

    // MARK: - Read-Only Info

    var version: String
    var rpcVersion: Int
    var configDir: String

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case speedLimitDown = "speed-limit-down"
        case speedLimitDownEnabled = "speed-limit-down-enabled"
        case speedLimitUp = "speed-limit-up"
        case speedLimitUpEnabled = "speed-limit-up-enabled"
        case altSpeedDown = "alt-speed-down"
        case altSpeedUp = "alt-speed-up"
        case altSpeedEnabled = "alt-speed-enabled"
        case altSpeedTimeBegin = "alt-speed-time-begin"
        case altSpeedTimeEnd = "alt-speed-time-end"
        case altSpeedTimeEnabled = "alt-speed-time-enabled"
        case altSpeedTimeDay = "alt-speed-time-day"
        case downloadDir = "download-dir"
        case incompleteDir = "incomplete-dir"
        case incompleteDirEnabled = "incomplete-dir-enabled"
        case startAddedTorrents = "start-added-torrents"
        case renamePartialFiles = "rename-partial-files"
        case trashOriginalTorrentFiles = "trash-original-torrent-files"
        case seedRatioLimit = "seedRatioLimit"
        case seedRatioLimited = "seedRatioLimited"
        case idleSeedingLimit = "idle-seeding-limit"
        case idleSeedingLimitEnabled = "idle-seeding-limit-enabled"
        case downloadQueueEnabled = "download-queue-enabled"
        case downloadQueueSize = "download-queue-size"
        case seedQueueEnabled = "seed-queue-enabled"
        case seedQueueSize = "seed-queue-size"
        case queueStalledEnabled = "queue-stalled-enabled"
        case queueStalledMinutes = "queue-stalled-minutes"
        case peerLimitGlobal = "peer-limit-global"
        case peerLimitPerTorrent = "peer-limit-per-torrent"
        case dhtEnabled = "dht-enabled"
        case pexEnabled = "pex-enabled"
        case lpdEnabled = "lpd-enabled"
        case encryption
        case peerPort = "peer-port"
        case peerPortRandomOnStart = "peer-port-random-on-start"
        case portForwardingEnabled = "port-forwarding-enabled"
        case utpEnabled = "utp-enabled"
        case blocklistEnabled = "blocklist-enabled"
        case blocklistUrl = "blocklist-url"
        case blocklistSize = "blocklist-size"
        case scriptTorrentAddedEnabled = "script-torrent-added-enabled"
        case scriptTorrentAddedFilename = "script-torrent-added-filename"
        case scriptTorrentDoneEnabled = "script-torrent-done-enabled"
        case scriptTorrentDoneFilename = "script-torrent-done-filename"
        case scriptTorrentDoneSeedingEnabled = "script-torrent-done-seeding-enabled"
        case scriptTorrentDoneSeedingFilename = "script-torrent-done-seeding-filename"
        case version
        case rpcVersion = "rpc-version"
        case configDir = "config-dir"
    }
}

extension SessionSettings: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        speedLimitDown = try c.decodeIfPresent(Int.self, forKey: .speedLimitDown) ?? 0
        speedLimitDownEnabled = try c.decodeIfPresent(Bool.self, forKey: .speedLimitDownEnabled) ?? false
        speedLimitUp = try c.decodeIfPresent(Int.self, forKey: .speedLimitUp) ?? 0
        speedLimitUpEnabled = try c.decodeIfPresent(Bool.self, forKey: .speedLimitUpEnabled) ?? false
        altSpeedDown = try c.decodeIfPresent(Int.self, forKey: .altSpeedDown) ?? 0
        altSpeedUp = try c.decodeIfPresent(Int.self, forKey: .altSpeedUp) ?? 0
        altSpeedEnabled = try c.decodeIfPresent(Bool.self, forKey: .altSpeedEnabled) ?? false
        altSpeedTimeBegin = try c.decodeIfPresent(Int.self, forKey: .altSpeedTimeBegin) ?? 0
        altSpeedTimeEnd = try c.decodeIfPresent(Int.self, forKey: .altSpeedTimeEnd) ?? 0
        altSpeedTimeEnabled = try c.decodeIfPresent(Bool.self, forKey: .altSpeedTimeEnabled) ?? false
        altSpeedTimeDay = try c.decodeIfPresent(Int.self, forKey: .altSpeedTimeDay) ?? 0
        downloadDir = try c.decodeIfPresent(String.self, forKey: .downloadDir) ?? ""
        incompleteDir = try c.decodeIfPresent(String.self, forKey: .incompleteDir) ?? ""
        incompleteDirEnabled = try c.decodeIfPresent(Bool.self, forKey: .incompleteDirEnabled) ?? false
        startAddedTorrents = try c.decodeIfPresent(Bool.self, forKey: .startAddedTorrents) ?? true
        renamePartialFiles = try c.decodeIfPresent(Bool.self, forKey: .renamePartialFiles) ?? true
        trashOriginalTorrentFiles = try c.decodeIfPresent(Bool.self, forKey: .trashOriginalTorrentFiles) ?? false
        seedRatioLimit = try c.decodeIfPresent(Double.self, forKey: .seedRatioLimit) ?? 0.0
        seedRatioLimited = try c.decodeIfPresent(Bool.self, forKey: .seedRatioLimited) ?? false
        idleSeedingLimit = try c.decodeIfPresent(Int.self, forKey: .idleSeedingLimit) ?? 0
        idleSeedingLimitEnabled = try c.decodeIfPresent(Bool.self, forKey: .idleSeedingLimitEnabled) ?? false
        downloadQueueEnabled = try c.decodeIfPresent(Bool.self, forKey: .downloadQueueEnabled) ?? false
        downloadQueueSize = try c.decodeIfPresent(Int.self, forKey: .downloadQueueSize) ?? 5
        seedQueueEnabled = try c.decodeIfPresent(Bool.self, forKey: .seedQueueEnabled) ?? false
        seedQueueSize = try c.decodeIfPresent(Int.self, forKey: .seedQueueSize) ?? 5
        queueStalledEnabled = try c.decodeIfPresent(Bool.self, forKey: .queueStalledEnabled) ?? false
        queueStalledMinutes = try c.decodeIfPresent(Int.self, forKey: .queueStalledMinutes) ?? 30
        peerLimitGlobal = try c.decodeIfPresent(Int.self, forKey: .peerLimitGlobal) ?? 200
        peerLimitPerTorrent = try c.decodeIfPresent(Int.self, forKey: .peerLimitPerTorrent) ?? 50
        dhtEnabled = try c.decodeIfPresent(Bool.self, forKey: .dhtEnabled) ?? true
        pexEnabled = try c.decodeIfPresent(Bool.self, forKey: .pexEnabled) ?? true
        lpdEnabled = try c.decodeIfPresent(Bool.self, forKey: .lpdEnabled) ?? false
        encryption = try c.decodeIfPresent(String.self, forKey: .encryption) ?? "preferred"
        peerPort = try c.decodeIfPresent(Int.self, forKey: .peerPort) ?? 51413
        peerPortRandomOnStart = try c.decodeIfPresent(Bool.self, forKey: .peerPortRandomOnStart) ?? false
        portForwardingEnabled = try c.decodeIfPresent(Bool.self, forKey: .portForwardingEnabled) ?? false
        utpEnabled = try c.decodeIfPresent(Bool.self, forKey: .utpEnabled) ?? true
        blocklistEnabled = try c.decodeIfPresent(Bool.self, forKey: .blocklistEnabled) ?? false
        blocklistUrl = try c.decodeIfPresent(String.self, forKey: .blocklistUrl) ?? ""
        blocklistSize = try c.decodeIfPresent(Int.self, forKey: .blocklistSize) ?? 0
        scriptTorrentAddedEnabled = try c.decodeIfPresent(Bool.self, forKey: .scriptTorrentAddedEnabled) ?? false
        scriptTorrentAddedFilename = try c.decodeIfPresent(String.self, forKey: .scriptTorrentAddedFilename) ?? ""
        scriptTorrentDoneEnabled = try c.decodeIfPresent(Bool.self, forKey: .scriptTorrentDoneEnabled) ?? false
        scriptTorrentDoneFilename = try c.decodeIfPresent(String.self, forKey: .scriptTorrentDoneFilename) ?? ""
        scriptTorrentDoneSeedingEnabled = try c.decodeIfPresent(Bool.self, forKey: .scriptTorrentDoneSeedingEnabled) ?? false
        scriptTorrentDoneSeedingFilename = try c.decodeIfPresent(String.self, forKey: .scriptTorrentDoneSeedingFilename) ?? ""
        version = try c.decodeIfPresent(String.self, forKey: .version) ?? ""
        rpcVersion = try c.decodeIfPresent(Int.self, forKey: .rpcVersion) ?? 0
        configDir = try c.decodeIfPresent(String.self, forKey: .configDir) ?? ""
    }
}
