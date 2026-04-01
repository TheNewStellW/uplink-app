import SwiftUI

/// Sheet for viewing and editing Transmission daemon session settings.
struct ServerSettingsView: View {
    @Bindable var viewModel: ServerSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView("Loading settings…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                settingsForm
            }

            Divider()
            bottomBar
        }
        .frame(width: 560, height: 600)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Form

    private var settingsForm: some View {
        Form {
            serverInfoSection
            speedLimitsSection
            altSpeedSection
            downloadingSection
            seedingSection
            queueSection
            peersSection
            networkSection
            blocklistSection
            scriptsSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Server Info

    private var serverInfoSection: some View {
        Section("Server Info") {
            LabeledContent("Version", value: viewModel.version)
            LabeledContent("RPC Version", value: "\(viewModel.rpcVersion)")
            LabeledContent("Config Directory", value: viewModel.configDir)
        }
    }

    // MARK: - Speed Limits

    private var speedLimitsSection: some View {
        Section("Speed Limits") {
            Toggle("Limit Download Speed", isOn: $viewModel.speedLimitDownEnabled)
            if viewModel.speedLimitDownEnabled {
                HStack {
                    Text("Download Limit")
                    Spacer()
                    TextField("", value: $viewModel.speedLimitDown, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("kB/s")
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Limit Upload Speed", isOn: $viewModel.speedLimitUpEnabled)
            if viewModel.speedLimitUpEnabled {
                HStack {
                    Text("Upload Limit")
                    Spacer()
                    TextField("", value: $viewModel.speedLimitUp, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("kB/s")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Alternative Speed

    private var altSpeedSection: some View {
        Section("Alternative Speed Limits (Turtle Mode)") {
            Toggle("Enable Alternative Speeds", isOn: $viewModel.altSpeedEnabled)

            HStack {
                Text("Download")
                Spacer()
                TextField("", value: $viewModel.altSpeedDown, format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                Text("kB/s")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Upload")
                Spacer()
                TextField("", value: $viewModel.altSpeedUp, format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                Text("kB/s")
                    .foregroundStyle(.secondary)
            }

            Toggle("Scheduled", isOn: $viewModel.altSpeedTimeEnabled)
            if viewModel.altSpeedTimeEnabled {
                HStack {
                    Text("Start")
                    Spacer()
                    TextField("", value: $viewModel.altSpeedTimeBegin, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("min after midnight")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                HStack {
                    Text("End")
                    Spacer()
                    TextField("", value: $viewModel.altSpeedTimeEnd, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("min after midnight")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                HStack {
                    Text("Days")
                    Spacer()
                    TextField("", value: $viewModel.altSpeedTimeDay, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .help("Bitmask: 127 = every day")
                }
            }
        }
    }

    // MARK: - Downloading

    private var downloadingSection: some View {
        Section("Downloading") {
            HStack {
                Text("Download Directory")
                Spacer()
                TextField("", text: $viewModel.downloadDir)
                    .frame(width: 250)
                    .multilineTextAlignment(.trailing)
            }

            Toggle("Use Incomplete Directory", isOn: $viewModel.incompleteDirEnabled)
            if viewModel.incompleteDirEnabled {
                HStack {
                    Text("Incomplete Directory")
                    Spacer()
                    TextField("", text: $viewModel.incompleteDir)
                        .frame(width: 250)
                        .multilineTextAlignment(.trailing)
                }
            }

            Toggle("Start Added Torrents", isOn: $viewModel.startAddedTorrents)
            Toggle("Rename Partial Files (.part)", isOn: $viewModel.renamePartialFiles)
            Toggle("Trash Original .torrent Files", isOn: $viewModel.trashOriginalTorrentFiles)
        }
    }

    // MARK: - Seeding

    private var seedingSection: some View {
        Section("Seeding") {
            Toggle("Stop Seeding at Ratio", isOn: $viewModel.seedRatioLimited)
            if viewModel.seedRatioLimited {
                HStack {
                    Text("Seed Ratio Limit")
                    Spacer()
                    TextField("", value: $viewModel.seedRatioLimit, format: .number.precision(.fractionLength(2)))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            }

            Toggle("Stop Seeding if Idle", isOn: $viewModel.idleSeedingLimitEnabled)
            if viewModel.idleSeedingLimitEnabled {
                HStack {
                    Text("Idle Limit")
                    Spacer()
                    TextField("", value: $viewModel.idleSeedingLimit, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("min")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Queue

    private var queueSection: some View {
        Section("Queue") {
            Toggle("Download Queue", isOn: $viewModel.downloadQueueEnabled)
            if viewModel.downloadQueueEnabled {
                HStack {
                    Text("Max Downloading")
                    Spacer()
                    TextField("", value: $viewModel.downloadQueueSize, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            }

            Toggle("Seed Queue", isOn: $viewModel.seedQueueEnabled)
            if viewModel.seedQueueEnabled {
                HStack {
                    Text("Max Seeding")
                    Spacer()
                    TextField("", value: $viewModel.seedQueueSize, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            }

            Toggle("Consider Stalled After Idle", isOn: $viewModel.queueStalledEnabled)
            if viewModel.queueStalledEnabled {
                HStack {
                    Text("Stalled Threshold")
                    Spacer()
                    TextField("", value: $viewModel.queueStalledMinutes, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("min")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Peers

    private var peersSection: some View {
        Section("Peers") {
            HStack {
                Text("Global Peer Limit")
                Spacer()
                TextField("", value: $viewModel.peerLimitGlobal, format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Per-Torrent Peer Limit")
                Spacer()
                TextField("", value: $viewModel.peerLimitPerTorrent, format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }

            Toggle("DHT", isOn: $viewModel.dhtEnabled)
            Toggle("PEX", isOn: $viewModel.pexEnabled)
            Toggle("LPD", isOn: $viewModel.lpdEnabled)

            Picker("Encryption", selection: $viewModel.encryption) {
                Text("Required").tag("required")
                Text("Preferred").tag("preferred")
                Text("Tolerated").tag("tolerated")
            }
        }
    }

    // MARK: - Network

    private var networkSection: some View {
        Section("Network") {
            HStack {
                Text("Peer Port")
                Spacer()
                TextField("", value: $viewModel.peerPort, format: .number.grouping(.never))
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            Toggle("Randomize Port on Start", isOn: $viewModel.peerPortRandomOnStart)
            Toggle("Port Forwarding (UPnP / NAT-PMP)", isOn: $viewModel.portForwardingEnabled)
            Toggle("uTP", isOn: $viewModel.utpEnabled)
        }
    }

    // MARK: - Blocklist

    private var blocklistSection: some View {
        Section("Blocklist") {
            Toggle("Enable Blocklist", isOn: $viewModel.blocklistEnabled)
            if viewModel.blocklistEnabled {
                HStack {
                    Text("URL")
                    Spacer()
                    TextField("", text: $viewModel.blocklistUrl)
                        .frame(width: 300)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Entries", value: "\(viewModel.blocklistSize)")
            }
        }
    }

    // MARK: - Scripts

    private var scriptsSection: some View {
        Section("Scripts") {
            Toggle("Run Script on Torrent Added", isOn: $viewModel.scriptTorrentAddedEnabled)
            if viewModel.scriptTorrentAddedEnabled {
                TextField("Script Path", text: $viewModel.scriptTorrentAddedFilename)
            }

            Toggle("Run Script on Torrent Done", isOn: $viewModel.scriptTorrentDoneEnabled)
            if viewModel.scriptTorrentDoneEnabled {
                TextField("Script Path", text: $viewModel.scriptTorrentDoneFilename)
            }

            Toggle("Run Script on Done Seeding", isOn: $viewModel.scriptTorrentDoneSeedingEnabled)
            if viewModel.scriptTorrentDoneSeedingEnabled {
                TextField("Script Path", text: $viewModel.scriptTorrentDoneSeedingFilename)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button {
                Task {
                    await viewModel.save()
                    dismiss()
                }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Save")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.isSaving)
        }
        .padding(.spacing12)
    }
}
