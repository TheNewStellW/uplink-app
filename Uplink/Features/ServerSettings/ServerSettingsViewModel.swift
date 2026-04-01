import Foundation

/// ViewModel for the daemon session settings sheet.
@Observable
@MainActor
final class ServerSettingsViewModel {
    let appState: AppState

    var isLoading = false
    var isSaving = false

    // MARK: - Speed Limits

    var speedLimitDownEnabled = false
    var speedLimitDown = 0
    var speedLimitUpEnabled = false
    var speedLimitUp = 0
    var altSpeedEnabled = false
    var altSpeedDown = 0
    var altSpeedUp = 0
    var altSpeedTimeEnabled = false
    var altSpeedTimeBegin = 0
    var altSpeedTimeEnd = 0
    var altSpeedTimeDay = 0

    // MARK: - Downloading

    var downloadDir = ""
    var incompleteDirEnabled = false
    var incompleteDir = ""
    var startAddedTorrents = true
    var renamePartialFiles = true
    var trashOriginalTorrentFiles = false

    // MARK: - Seeding

    var seedRatioLimited = false
    var seedRatioLimit = 0.0
    var idleSeedingLimitEnabled = false
    var idleSeedingLimit = 0

    // MARK: - Queue

    var downloadQueueEnabled = false
    var downloadQueueSize = 0
    var seedQueueEnabled = false
    var seedQueueSize = 0
    var queueStalledEnabled = false
    var queueStalledMinutes = 0

    // MARK: - Peers

    var peerLimitGlobal = 0
    var peerLimitPerTorrent = 0
    var dhtEnabled = false
    var pexEnabled = false
    var lpdEnabled = false
    var encryption = "preferred"

    // MARK: - Network

    var peerPort = 0
    var peerPortRandomOnStart = false
    var portForwardingEnabled = false
    var utpEnabled = false

    // MARK: - Blocklist

    var blocklistEnabled = false
    var blocklistUrl = ""
    var blocklistSize = 0

    // MARK: - Scripts

    var scriptTorrentAddedEnabled = false
    var scriptTorrentAddedFilename = ""
    var scriptTorrentDoneEnabled = false
    var scriptTorrentDoneFilename = ""
    var scriptTorrentDoneSeedingEnabled = false
    var scriptTorrentDoneSeedingFilename = ""

    // MARK: - Read-Only Info

    var version = ""
    var rpcVersion = 0
    var configDir = ""

    /// The original settings snapshot for diffing.
    private var original: SessionSettings?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        await appState.refreshSessionSettings()
        guard let settings = appState.sessionSettings else { return }
        original = settings
        populate(from: settings)
    }

    private func populate(from s: SessionSettings) {
        speedLimitDownEnabled = s.speedLimitDownEnabled
        speedLimitDown = s.speedLimitDown
        speedLimitUpEnabled = s.speedLimitUpEnabled
        speedLimitUp = s.speedLimitUp
        altSpeedEnabled = s.altSpeedEnabled
        altSpeedDown = s.altSpeedDown
        altSpeedUp = s.altSpeedUp
        altSpeedTimeEnabled = s.altSpeedTimeEnabled
        altSpeedTimeBegin = s.altSpeedTimeBegin
        altSpeedTimeEnd = s.altSpeedTimeEnd
        altSpeedTimeDay = s.altSpeedTimeDay

        downloadDir = s.downloadDir
        incompleteDirEnabled = s.incompleteDirEnabled
        incompleteDir = s.incompleteDir
        startAddedTorrents = s.startAddedTorrents
        renamePartialFiles = s.renamePartialFiles
        trashOriginalTorrentFiles = s.trashOriginalTorrentFiles

        seedRatioLimited = s.seedRatioLimited
        seedRatioLimit = s.seedRatioLimit
        idleSeedingLimitEnabled = s.idleSeedingLimitEnabled
        idleSeedingLimit = s.idleSeedingLimit

        downloadQueueEnabled = s.downloadQueueEnabled
        downloadQueueSize = s.downloadQueueSize
        seedQueueEnabled = s.seedQueueEnabled
        seedQueueSize = s.seedQueueSize
        queueStalledEnabled = s.queueStalledEnabled
        queueStalledMinutes = s.queueStalledMinutes

        peerLimitGlobal = s.peerLimitGlobal
        peerLimitPerTorrent = s.peerLimitPerTorrent
        dhtEnabled = s.dhtEnabled
        pexEnabled = s.pexEnabled
        lpdEnabled = s.lpdEnabled
        encryption = s.encryption

        peerPort = s.peerPort
        peerPortRandomOnStart = s.peerPortRandomOnStart
        portForwardingEnabled = s.portForwardingEnabled
        utpEnabled = s.utpEnabled

        blocklistEnabled = s.blocklistEnabled
        blocklistUrl = s.blocklistUrl
        blocklistSize = s.blocklistSize

        scriptTorrentAddedEnabled = s.scriptTorrentAddedEnabled
        scriptTorrentAddedFilename = s.scriptTorrentAddedFilename
        scriptTorrentDoneEnabled = s.scriptTorrentDoneEnabled
        scriptTorrentDoneFilename = s.scriptTorrentDoneFilename
        scriptTorrentDoneSeedingEnabled = s.scriptTorrentDoneSeedingEnabled
        scriptTorrentDoneSeedingFilename = s.scriptTorrentDoneSeedingFilename

        version = s.version
        rpcVersion = s.rpcVersion
        configDir = s.configDir
    }

    // MARK: - Save

    func save() async {
        isSaving = true
        defer { isSaving = false }

        var update = SessionSettingsUpdate()

        // Only send fields that differ from the original
        guard let o = original else { return }

        if speedLimitDown != o.speedLimitDown { update.speedLimitDown = speedLimitDown }
        if speedLimitDownEnabled != o.speedLimitDownEnabled { update.speedLimitDownEnabled = speedLimitDownEnabled }
        if speedLimitUp != o.speedLimitUp { update.speedLimitUp = speedLimitUp }
        if speedLimitUpEnabled != o.speedLimitUpEnabled { update.speedLimitUpEnabled = speedLimitUpEnabled }
        if altSpeedDown != o.altSpeedDown { update.altSpeedDown = altSpeedDown }
        if altSpeedUp != o.altSpeedUp { update.altSpeedUp = altSpeedUp }
        if altSpeedEnabled != o.altSpeedEnabled { update.altSpeedEnabled = altSpeedEnabled }
        if altSpeedTimeBegin != o.altSpeedTimeBegin { update.altSpeedTimeBegin = altSpeedTimeBegin }
        if altSpeedTimeEnd != o.altSpeedTimeEnd { update.altSpeedTimeEnd = altSpeedTimeEnd }
        if altSpeedTimeEnabled != o.altSpeedTimeEnabled { update.altSpeedTimeEnabled = altSpeedTimeEnabled }
        if altSpeedTimeDay != o.altSpeedTimeDay { update.altSpeedTimeDay = altSpeedTimeDay }

        if downloadDir != o.downloadDir { update.downloadDir = downloadDir }
        if incompleteDir != o.incompleteDir { update.incompleteDir = incompleteDir }
        if incompleteDirEnabled != o.incompleteDirEnabled { update.incompleteDirEnabled = incompleteDirEnabled }
        if startAddedTorrents != o.startAddedTorrents { update.startAddedTorrents = startAddedTorrents }
        if renamePartialFiles != o.renamePartialFiles { update.renamePartialFiles = renamePartialFiles }
        if trashOriginalTorrentFiles != o.trashOriginalTorrentFiles { update.trashOriginalTorrentFiles = trashOriginalTorrentFiles }

        if seedRatioLimit != o.seedRatioLimit { update.seedRatioLimit = seedRatioLimit }
        if seedRatioLimited != o.seedRatioLimited { update.seedRatioLimited = seedRatioLimited }
        if idleSeedingLimit != o.idleSeedingLimit { update.idleSeedingLimit = idleSeedingLimit }
        if idleSeedingLimitEnabled != o.idleSeedingLimitEnabled { update.idleSeedingLimitEnabled = idleSeedingLimitEnabled }

        if downloadQueueEnabled != o.downloadQueueEnabled { update.downloadQueueEnabled = downloadQueueEnabled }
        if downloadQueueSize != o.downloadQueueSize { update.downloadQueueSize = downloadQueueSize }
        if seedQueueEnabled != o.seedQueueEnabled { update.seedQueueEnabled = seedQueueEnabled }
        if seedQueueSize != o.seedQueueSize { update.seedQueueSize = seedQueueSize }
        if queueStalledEnabled != o.queueStalledEnabled { update.queueStalledEnabled = queueStalledEnabled }
        if queueStalledMinutes != o.queueStalledMinutes { update.queueStalledMinutes = queueStalledMinutes }

        if peerLimitGlobal != o.peerLimitGlobal { update.peerLimitGlobal = peerLimitGlobal }
        if peerLimitPerTorrent != o.peerLimitPerTorrent { update.peerLimitPerTorrent = peerLimitPerTorrent }
        if dhtEnabled != o.dhtEnabled { update.dhtEnabled = dhtEnabled }
        if pexEnabled != o.pexEnabled { update.pexEnabled = pexEnabled }
        if lpdEnabled != o.lpdEnabled { update.lpdEnabled = lpdEnabled }
        if encryption != o.encryption { update.encryption = encryption }

        if peerPort != o.peerPort { update.peerPort = peerPort }
        if peerPortRandomOnStart != o.peerPortRandomOnStart { update.peerPortRandomOnStart = peerPortRandomOnStart }
        if portForwardingEnabled != o.portForwardingEnabled { update.portForwardingEnabled = portForwardingEnabled }
        if utpEnabled != o.utpEnabled { update.utpEnabled = utpEnabled }

        if blocklistEnabled != o.blocklistEnabled { update.blocklistEnabled = blocklistEnabled }
        if blocklistUrl != o.blocklistUrl { update.blocklistUrl = blocklistUrl }

        if scriptTorrentAddedEnabled != o.scriptTorrentAddedEnabled { update.scriptTorrentAddedEnabled = scriptTorrentAddedEnabled }
        if scriptTorrentAddedFilename != o.scriptTorrentAddedFilename { update.scriptTorrentAddedFilename = scriptTorrentAddedFilename }
        if scriptTorrentDoneEnabled != o.scriptTorrentDoneEnabled { update.scriptTorrentDoneEnabled = scriptTorrentDoneEnabled }
        if scriptTorrentDoneFilename != o.scriptTorrentDoneFilename { update.scriptTorrentDoneFilename = scriptTorrentDoneFilename }
        if scriptTorrentDoneSeedingEnabled != o.scriptTorrentDoneSeedingEnabled { update.scriptTorrentDoneSeedingEnabled = scriptTorrentDoneSeedingEnabled }
        if scriptTorrentDoneSeedingFilename != o.scriptTorrentDoneSeedingFilename { update.scriptTorrentDoneSeedingFilename = scriptTorrentDoneSeedingFilename }

        await appState.updateSessionSettings(update)
    }
}
