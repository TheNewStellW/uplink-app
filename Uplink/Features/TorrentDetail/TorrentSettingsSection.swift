import SwiftUI

/// Per-torrent settings section displayed inline in the torrent detail panel.
struct TorrentSettingsSection: View {
    let torrent: Torrent
    let appState: AppState

    // MARK: - Local Editing State

    @State private var bandwidthPriority: BandwidthPriority = .normal
    @State private var downloadLimited = false
    @State private var downloadLimit = 0
    @State private var uploadLimited = false
    @State private var uploadLimit = 0
    @State private var honorsSessionLimits = true
    @State private var seedRatioMode: SeedLimitMode = .useGlobal
    @State private var seedRatioLimit = 0.0
    @State private var seedIdleMode: SeedLimitMode = .useGlobal
    @State private var seedIdleLimit = 0
    @State private var peerLimit = 50
    @State private var queuePosition = 0
    @State private var sequentialDownload = false
    @State private var labelsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            Text("Settings")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            priorityRow
            downloadLimitRow
            uploadLimitRow
            honorsSessionRow
            seedRatioRow
            seedIdleRow
            peersRow
            queueRow
            sequentialRow
            labelsRow
        }
        .onAppear { syncFromTorrent() }
        .onChange(of: torrent.id) { _, _ in syncFromTorrent() }
    }

    // MARK: - Rows

    private var priorityRow: some View {
        HStack {
            Text("Priority")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Picker("", selection: $bandwidthPriority) {
                ForEach(BandwidthPriority.allCases) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: bandwidthPriority) { _, newValue in
                apply(TorrentSettings(bandwidthPriority: newValue.rawValue))
            }
        }
    }

    private var downloadLimitRow: some View {
        HStack {
            Text("Download Limit")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Toggle("", isOn: $downloadLimited)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: downloadLimited) { _, newValue in
                    apply(TorrentSettings(downloadLimited: newValue))
                }
            if downloadLimited {
                TextField("", value: $downloadLimit, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit {
                        apply(TorrentSettings(downloadLimit: downloadLimit))
                    }
                Text("kB/s")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private var uploadLimitRow: some View {
        HStack {
            Text("Upload Limit")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Toggle("", isOn: $uploadLimited)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: uploadLimited) { _, newValue in
                    apply(TorrentSettings(uploadLimited: newValue))
                }
            if uploadLimited {
                TextField("", value: $uploadLimit, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit {
                        apply(TorrentSettings(uploadLimit: uploadLimit))
                    }
                Text("kB/s")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private var honorsSessionRow: some View {
        HStack {
            Text("Honor Session Limits")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Toggle("", isOn: $honorsSessionLimits)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: honorsSessionLimits) { _, newValue in
                    apply(TorrentSettings(honorsSessionLimits: newValue))
                }
            Spacer()
        }
    }

    private var seedRatioRow: some View {
        HStack {
            Text("Seed Ratio")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Picker("", selection: $seedRatioMode) {
                ForEach(SeedLimitMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 120)
            .onChange(of: seedRatioMode) { _, newValue in
                apply(TorrentSettings(seedRatioMode: newValue.rawValue))
            }
            if seedRatioMode == .custom {
                TextField("", value: $seedRatioLimit, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onSubmit {
                        apply(TorrentSettings(seedRatioLimit: seedRatioLimit))
                    }
            }
            Spacer()
        }
    }

    private var seedIdleRow: some View {
        HStack {
            Text("Seed Idle Limit")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Picker("", selection: $seedIdleMode) {
                ForEach(SeedLimitMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 120)
            .onChange(of: seedIdleMode) { _, newValue in
                apply(TorrentSettings(seedIdleMode: newValue.rawValue))
            }
            if seedIdleMode == .custom {
                TextField("", value: $seedIdleLimit, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onSubmit {
                        apply(TorrentSettings(seedIdleLimit: seedIdleLimit))
                    }
                Text("min")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private var peersRow: some View {
        HStack {
            Text("Max Peers")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            TextField("", value: $peerLimit, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .onSubmit {
                    apply(TorrentSettings(peerLimit: peerLimit))
                }
            Spacer()
        }
    }

    private var queueRow: some View {
        HStack {
            Text("Queue Position")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Stepper(value: $queuePosition, in: 0...999) {
                Text("\(queuePosition)")
                    .font(.caption)
                    .monospacedDigit()
            }
            .onChange(of: queuePosition) { _, newValue in
                apply(TorrentSettings(queuePosition: newValue))
            }
            Spacer()
        }
    }

    private var sequentialRow: some View {
        HStack {
            Text("Sequential Download")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Toggle("", isOn: $sequentialDownload)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: sequentialDownload) { _, newValue in
                    apply(TorrentSettings(sequentialDownload: newValue))
                }
            Spacer()
        }
    }

    private var labelsRow: some View {
        HStack {
            Text("Labels")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            TextField("Comma-separated", text: $labelsText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let labels = labelsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    apply(TorrentSettings(labels: labels))
                }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func syncFromTorrent() {
        bandwidthPriority = BandwidthPriority(rawValue: torrent.bandwidthPriority) ?? .normal
        downloadLimited = torrent.downloadLimited
        downloadLimit = torrent.downloadLimit
        uploadLimited = torrent.uploadLimited
        uploadLimit = torrent.uploadLimit
        honorsSessionLimits = torrent.honorsSessionLimits
        seedRatioMode = SeedLimitMode(rawValue: torrent.seedRatioMode) ?? .useGlobal
        seedRatioLimit = torrent.seedRatioLimit
        seedIdleMode = SeedLimitMode(rawValue: torrent.seedIdleMode) ?? .useGlobal
        seedIdleLimit = torrent.seedIdleLimit
        peerLimit = torrent.peerLimit
        queuePosition = torrent.queuePosition
        sequentialDownload = torrent.sequentialDownload
        labelsText = torrent.labels.joined(separator: ", ")
    }

    private func apply(_ settings: TorrentSettings) {
        Task {
            await appState.setTorrentSettings(ids: [torrent.id], settings: settings)
        }
    }
}
