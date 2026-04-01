import Foundation

// MARK: - Request Types

/// A generic Transmission RPC request envelope.
struct RPCRequest: Encodable, Sendable {
    let method: String
    let arguments: RPCArguments?
    let tag: Int?

    init(method: String, arguments: RPCArguments? = nil, tag: Int? = nil) {
        self.method = method
        self.arguments = arguments
        self.tag = tag
    }
}

/// Arguments for an RPC request. Uses an enum to support different argument shapes.
enum RPCArguments: Encodable, Sendable {
    case torrentGet(fields: [String])
    case torrentAction(ids: [Int])
    case torrentRemove(ids: [Int], deleteLocalData: Bool)
    case torrentAddURL(filename: String, downloadDir: String?)
    case torrentAddFile(metainfo: String, downloadDir: String?)
    case torrentSetFiles(ids: [Int], filesWanted: [Int]?, filesUnwanted: [Int]?,
                         priorityHigh: [Int]?, priorityNormal: [Int]?, priorityLow: [Int]?)
    case torrentSetLocation(ids: [Int], location: String, move: Bool)
    case torrentSet(ids: [Int], settings: TorrentSettings)
    case queueMoveTop(ids: [Int])
    case queueMoveUp(ids: [Int])
    case queueMoveDown(ids: [Int])
    case queueMoveBottom(ids: [Int])
    case sessionGet
    case sessionSet(settings: SessionSettingsUpdate)
    case sessionStats
    case portTest
    case blocklistUpdate
    case freeSpace(path: String)
    case torrentRenamePath(ids: [Int], path: String, name: String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        switch self {
        case .torrentGet(let fields):
            try container.encode(fields, forKey: .init("fields"))

        case .torrentAction(let ids):
            try container.encode(ids, forKey: .init("ids"))

        case .torrentRemove(let ids, let deleteLocalData):
            try container.encode(ids, forKey: .init("ids"))
            try container.encode(deleteLocalData, forKey: .init("delete-local-data"))

        case .torrentAddURL(let filename, let downloadDir):
            try container.encode(filename, forKey: .init("filename"))
            if let downloadDir {
                try container.encode(downloadDir, forKey: .init("download-dir"))
            }

        case .torrentAddFile(let metainfo, let downloadDir):
            try container.encode(metainfo, forKey: .init("metainfo"))
            if let downloadDir {
                try container.encode(downloadDir, forKey: .init("download-dir"))
            }

        case .torrentSetFiles(let ids, let filesWanted, let filesUnwanted,
                              let priorityHigh, let priorityNormal, let priorityLow):
            try container.encode(ids, forKey: .init("ids"))
            if let filesWanted {
                try container.encode(filesWanted, forKey: .init("files-wanted"))
            }
            if let filesUnwanted {
                try container.encode(filesUnwanted, forKey: .init("files-unwanted"))
            }
            if let priorityHigh {
                try container.encode(priorityHigh, forKey: .init("priority-high"))
            }
            if let priorityNormal {
                try container.encode(priorityNormal, forKey: .init("priority-normal"))
            }
            if let priorityLow {
                try container.encode(priorityLow, forKey: .init("priority-low"))
            }

        case .torrentSetLocation(let ids, let location, let move):
            try container.encode(ids, forKey: .init("ids"))
            try container.encode(location, forKey: .init("location"))
            try container.encode(move, forKey: .init("move"))

        case .torrentSet(let ids, let settings):
            try container.encode(ids, forKey: .init("ids"))
            try settings.encode(into: &container)

        case .queueMoveTop(let ids),
             .queueMoveUp(let ids),
             .queueMoveDown(let ids),
             .queueMoveBottom(let ids):
            try container.encode(ids, forKey: .init("ids"))

        case .sessionGet:
            break

        case .sessionSet(let settings):
            try settings.encode(into: &container)

        case .sessionStats, .portTest, .blocklistUpdate:
            break

        case .freeSpace(let path):
            try container.encode(path, forKey: .init("path"))

        case .torrentRenamePath(let ids, let path, let name):
            try container.encode(ids, forKey: .init("ids"))
            try container.encode(path, forKey: .init("path"))
            try container.encode(name, forKey: .init("name"))
        }
    }
}

// MARK: - Response Types

/// A generic Transmission RPC response envelope.
struct RPCResponse<T: Decodable>: Decodable {
    let result: String
    let arguments: T?
    let tag: Int?

    /// Whether the RPC call was successful.
    var isSuccess: Bool {
        result == "success"
    }
}

/// The `arguments` payload returned by `torrent-get`.
struct TorrentGetResponse: Decodable, Sendable {
    let torrents: [Torrent]
}

/// The `arguments` payload returned by `torrent-add`.
struct TorrentAddResponse: Decodable, Sendable {
    // The API returns either "torrent-added" or "torrent-duplicate"
    let torrentAdded: TorrentAddedInfo?
    let torrentDuplicate: TorrentAddedInfo?

    enum CodingKeys: String, CodingKey {
        case torrentAdded = "torrent-added"
        case torrentDuplicate = "torrent-duplicate"
    }

    /// The info for the added or duplicate torrent.
    var info: TorrentAddedInfo? {
        torrentAdded ?? torrentDuplicate
    }
}

/// Minimal info returned when adding a torrent.
struct TorrentAddedInfo: Decodable, Sendable {
    let id: Int
    let name: String
    let hashString: String
}

// MARK: - Helpers

/// A dynamic coding key for encoding arbitrary string keys.
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// The standard set of fields requested in `torrent-get` calls.
enum TorrentFields {
    static let standard: [String] = [
        "id", "name", "status", "percentDone", "rateDownload", "rateUpload",
        "totalSize", "downloadedEver", "uploadedEver", "uploadRatio",
        "eta", "error", "errorString", "files", "fileStats",
        "downloadDir", "addedDate", "peers", "trackers",
        "hashString", "magnetLink",
        "bandwidthPriority", "downloadLimit", "downloadLimited",
        "uploadLimit", "uploadLimited", "honorsSessionLimits",
        "seedRatioLimit", "seedRatioMode", "seedIdleLimit", "seedIdleMode",
        "peerLimit", "queuePosition", "labels", "sequentialDownload",
        "trackerStats", "peersConnected", "peersGettingFromUs", "peersSendingToUs",
        "creator", "comment", "dateCreated", "isPrivate", "pieceSize", "pieceCount"
    ]
}

// MARK: - Per-Torrent Settings

/// Encodable update payload for `torrent-set`. Only non-nil fields are sent.
struct TorrentSettings: Sendable {
    var bandwidthPriority: Int?
    var downloadLimit: Int?
    var downloadLimited: Bool?
    var uploadLimit: Int?
    var uploadLimited: Bool?
    var honorsSessionLimits: Bool?
    var seedRatioLimit: Double?
    var seedRatioMode: Int?
    var seedIdleLimit: Int?
    var seedIdleMode: Int?
    var peerLimit: Int?
    var queuePosition: Int?
    var labels: [String]?
    var sequentialDownload: Bool?
    var trackerAdd: [String]?
    var trackerRemove: [Int]?

    /// Encodes non-nil fields into an existing keyed container.
    func encode(into container: inout KeyedEncodingContainer<DynamicCodingKey>) throws {
        if let v = bandwidthPriority { try container.encode(v, forKey: .init("bandwidthPriority")) }
        if let v = downloadLimit { try container.encode(v, forKey: .init("downloadLimit")) }
        if let v = downloadLimited { try container.encode(v, forKey: .init("downloadLimited")) }
        if let v = uploadLimit { try container.encode(v, forKey: .init("uploadLimit")) }
        if let v = uploadLimited { try container.encode(v, forKey: .init("uploadLimited")) }
        if let v = honorsSessionLimits { try container.encode(v, forKey: .init("honorsSessionLimits")) }
        if let v = seedRatioLimit { try container.encode(v, forKey: .init("seedRatioLimit")) }
        if let v = seedRatioMode { try container.encode(v, forKey: .init("seedRatioMode")) }
        if let v = seedIdleLimit { try container.encode(v, forKey: .init("seedIdleLimit")) }
        if let v = seedIdleMode { try container.encode(v, forKey: .init("seedIdleMode")) }
        if let v = peerLimit { try container.encode(v, forKey: .init("peer-limit")) }
        if let v = queuePosition { try container.encode(v, forKey: .init("queuePosition")) }
        if let v = labels { try container.encode(v, forKey: .init("labels")) }
        if let v = sequentialDownload { try container.encode(v, forKey: .init("sequentialDownload")) }
        if let v = trackerAdd { try container.encode(v, forKey: .init("trackerAdd")) }
        if let v = trackerRemove { try container.encode(v, forKey: .init("trackerRemove")) }
    }
}

// MARK: - New RPC Response Types

/// Response from `port-test`.
struct PortTestResponse: Decodable, Sendable {
    let portIsOpen: Bool

    enum CodingKeys: String, CodingKey {
        case portIsOpen = "port-is-open"
    }
}

/// Response from `blocklist-update`.
struct BlocklistUpdateResponse: Decodable, Sendable {
    let blocklistSize: Int

    enum CodingKeys: String, CodingKey {
        case blocklistSize = "blocklist-size"
    }
}

/// Response from `free-space`.
struct FreeSpaceResponse: Decodable, Sendable {
    let path: String
    let sizeBytes: Int64

    enum CodingKeys: String, CodingKey {
        case path
        case sizeBytes = "size-bytes"
    }
}

/// Response from `torrent-rename-path`.
struct TorrentRenameResponse: Decodable, Sendable {
    let path: String
    let name: String
}

// MARK: - Session Settings Update

/// Encodable update payload for `session-set`. Only non-nil fields are sent.
struct SessionSettingsUpdate: Sendable {
    // Speed
    var speedLimitDown: Int?
    var speedLimitDownEnabled: Bool?
    var speedLimitUp: Int?
    var speedLimitUpEnabled: Bool?
    var altSpeedDown: Int?
    var altSpeedUp: Int?
    var altSpeedEnabled: Bool?
    var altSpeedTimeBegin: Int?
    var altSpeedTimeEnd: Int?
    var altSpeedTimeEnabled: Bool?
    var altSpeedTimeDay: Int?
    // Downloading
    var downloadDir: String?
    var incompleteDir: String?
    var incompleteDirEnabled: Bool?
    var startAddedTorrents: Bool?
    var renamePartialFiles: Bool?
    var trashOriginalTorrentFiles: Bool?
    // Seeding
    var seedRatioLimit: Double?
    var seedRatioLimited: Bool?
    var idleSeedingLimit: Int?
    var idleSeedingLimitEnabled: Bool?
    // Queue
    var downloadQueueEnabled: Bool?
    var downloadQueueSize: Int?
    var seedQueueEnabled: Bool?
    var seedQueueSize: Int?
    var queueStalledEnabled: Bool?
    var queueStalledMinutes: Int?
    // Peers
    var peerLimitGlobal: Int?
    var peerLimitPerTorrent: Int?
    var dhtEnabled: Bool?
    var pexEnabled: Bool?
    var lpdEnabled: Bool?
    var encryption: String?
    // Network
    var peerPort: Int?
    var peerPortRandomOnStart: Bool?
    var portForwardingEnabled: Bool?
    var utpEnabled: Bool?
    // Blocklist
    var blocklistEnabled: Bool?
    var blocklistUrl: String?
    // Scripts
    var scriptTorrentAddedEnabled: Bool?
    var scriptTorrentAddedFilename: String?
    var scriptTorrentDoneEnabled: Bool?
    var scriptTorrentDoneFilename: String?
    var scriptTorrentDoneSeedingEnabled: Bool?
    var scriptTorrentDoneSeedingFilename: String?

    /// Encodes non-nil fields into an existing keyed container.
    func encode(into container: inout KeyedEncodingContainer<DynamicCodingKey>) throws {
        if let v = speedLimitDown { try container.encode(v, forKey: .init("speed-limit-down")) }
        if let v = speedLimitDownEnabled { try container.encode(v, forKey: .init("speed-limit-down-enabled")) }
        if let v = speedLimitUp { try container.encode(v, forKey: .init("speed-limit-up")) }
        if let v = speedLimitUpEnabled { try container.encode(v, forKey: .init("speed-limit-up-enabled")) }
        if let v = altSpeedDown { try container.encode(v, forKey: .init("alt-speed-down")) }
        if let v = altSpeedUp { try container.encode(v, forKey: .init("alt-speed-up")) }
        if let v = altSpeedEnabled { try container.encode(v, forKey: .init("alt-speed-enabled")) }
        if let v = altSpeedTimeBegin { try container.encode(v, forKey: .init("alt-speed-time-begin")) }
        if let v = altSpeedTimeEnd { try container.encode(v, forKey: .init("alt-speed-time-end")) }
        if let v = altSpeedTimeEnabled { try container.encode(v, forKey: .init("alt-speed-time-enabled")) }
        if let v = altSpeedTimeDay { try container.encode(v, forKey: .init("alt-speed-time-day")) }
        if let v = downloadDir { try container.encode(v, forKey: .init("download-dir")) }
        if let v = incompleteDir { try container.encode(v, forKey: .init("incomplete-dir")) }
        if let v = incompleteDirEnabled { try container.encode(v, forKey: .init("incomplete-dir-enabled")) }
        if let v = startAddedTorrents { try container.encode(v, forKey: .init("start-added-torrents")) }
        if let v = renamePartialFiles { try container.encode(v, forKey: .init("rename-partial-files")) }
        if let v = trashOriginalTorrentFiles { try container.encode(v, forKey: .init("trash-original-torrent-files")) }
        if let v = seedRatioLimit { try container.encode(v, forKey: .init("seedRatioLimit")) }
        if let v = seedRatioLimited { try container.encode(v, forKey: .init("seedRatioLimited")) }
        if let v = idleSeedingLimit { try container.encode(v, forKey: .init("idle-seeding-limit")) }
        if let v = idleSeedingLimitEnabled { try container.encode(v, forKey: .init("idle-seeding-limit-enabled")) }
        if let v = downloadQueueEnabled { try container.encode(v, forKey: .init("download-queue-enabled")) }
        if let v = downloadQueueSize { try container.encode(v, forKey: .init("download-queue-size")) }
        if let v = seedQueueEnabled { try container.encode(v, forKey: .init("seed-queue-enabled")) }
        if let v = seedQueueSize { try container.encode(v, forKey: .init("seed-queue-size")) }
        if let v = queueStalledEnabled { try container.encode(v, forKey: .init("queue-stalled-enabled")) }
        if let v = queueStalledMinutes { try container.encode(v, forKey: .init("queue-stalled-minutes")) }
        if let v = peerLimitGlobal { try container.encode(v, forKey: .init("peer-limit-global")) }
        if let v = peerLimitPerTorrent { try container.encode(v, forKey: .init("peer-limit-per-torrent")) }
        if let v = dhtEnabled { try container.encode(v, forKey: .init("dht-enabled")) }
        if let v = pexEnabled { try container.encode(v, forKey: .init("pex-enabled")) }
        if let v = lpdEnabled { try container.encode(v, forKey: .init("lpd-enabled")) }
        if let v = encryption { try container.encode(v, forKey: .init("encryption")) }
        if let v = peerPort { try container.encode(v, forKey: .init("peer-port")) }
        if let v = peerPortRandomOnStart { try container.encode(v, forKey: .init("peer-port-random-on-start")) }
        if let v = portForwardingEnabled { try container.encode(v, forKey: .init("port-forwarding-enabled")) }
        if let v = utpEnabled { try container.encode(v, forKey: .init("utp-enabled")) }
        if let v = blocklistEnabled { try container.encode(v, forKey: .init("blocklist-enabled")) }
        if let v = blocklistUrl { try container.encode(v, forKey: .init("blocklist-url")) }
        if let v = scriptTorrentAddedEnabled { try container.encode(v, forKey: .init("script-torrent-added-enabled")) }
        if let v = scriptTorrentAddedFilename { try container.encode(v, forKey: .init("script-torrent-added-filename")) }
        if let v = scriptTorrentDoneEnabled { try container.encode(v, forKey: .init("script-torrent-done-enabled")) }
        if let v = scriptTorrentDoneFilename { try container.encode(v, forKey: .init("script-torrent-done-filename")) }
        if let v = scriptTorrentDoneSeedingEnabled { try container.encode(v, forKey: .init("script-torrent-done-seeding-enabled")) }
        if let v = scriptTorrentDoneSeedingFilename { try container.encode(v, forKey: .init("script-torrent-done-seeding-filename")) }
    }
}
