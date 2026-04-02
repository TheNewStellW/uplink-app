import AppKit
import SwiftUI

/// Top-level settings tab identifiers.
enum SettingsTabId: Hashable {
    case general
    case transfers
    case servers
}

/// The root Settings view. Top-level TabView with icon-labeled tabs
/// following macOS Settings conventions.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSettingsTab: SettingsTabId = .general

    var body: some View {
        TabView(selection: $selectedSettingsTab) {
            Tab("General", systemImage: "gearshape", value: .general) {
                GeneralSettingsTab()
            }

            Tab("Transfers", systemImage: "arrow.up.arrow.down", value: .transfers) {
                TransfersSettingsTab()
            }

            Tab("Servers", systemImage: "server.rack", value: .servers) {
                ServersSettingsTab()
            }
        }
        .frame(width: 680, height: 480)
        .onAppear {
            if appState.pendingSettingsServerId != nil || appState.pendingAddServer {
                selectedSettingsTab = .servers
            }
        }
    }
}

// MARK: - General Settings Tab

/// Client-level preferences: appearance, interface behaviour, notifications.
struct GeneralSettingsTab: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("showSpeedsInStatusBar") private var showSpeedsInStatusBar = true
    @AppStorage("notifyOnCompletion") private var notifyOnCompletion = true

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            } header: {
                Text("Appearance")
            }

            Section {
                Toggle("Show transfer speeds in status bar", isOn: $showSpeedsInStatusBar)
                Toggle("Notify when downloads complete", isOn: $notifyOnCompletion)
            } header: {
                Text("Notifications & Interface")
            }
        }
        .formStyle(.grouped)
    }
}

/// Transfer list preferences: display mode, sort order, refresh intervals.
struct TransfersSettingsTab: View {
    @Environment(AppState.self) private var appState
    @AppStorage("activePollInterval") private var activePollInterval: Double = 3
    @AppStorage("backgroundPollInterval") private var backgroundPollInterval: Double = 10

    var body: some View {
        Form {
            Section {
                Picker("List Style", selection: Binding(
                    get: { appState.listDisplayMode },
                    set: { appState.listDisplayMode = $0 }
                )) {
                    ForEach(ListDisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            } header: {
                Text("Display")
            }

            Section {
                Picker("Sort By", selection: Binding(
                    get: { appState.sortOrder },
                    set: { appState.sortOrder = $0 }
                )) {
                    ForEach(TorrentSortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }

                Picker("Direction", selection: Binding(
                    get: { appState.sortAscending },
                    set: { appState.sortAscending = $0 }
                )) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
            } header: {
                Text("Default Sort Order")
            }

            Section {
                Picker("Update interval", selection: $activePollInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("3 seconds").tag(3.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                }

                Picker("Background interval", selection: $backgroundPollInterval) {
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                    Text("60 seconds").tag(60.0)
                }
            } header: {
                Text("Refresh")
            }
        }
        .formStyle(.grouped)
    }
}

/// Appearance mode preference.
enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    /// Localized display label.
    var label: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - Server Settings Sub-Tab Identifier

/// Sub-tab identifiers within the Servers settings pane.
/// Defined at file scope so that `AppState` can reference it for navigation.
enum ServerSettingsSubTab: String, CaseIterable, Identifiable, Sendable {
    case connection = "Connection"
    case pathMappings = "Path Mappings"
    case speed = "Speed"
    case torrents = "Torrents"
    case queue = "Queue"
    case network = "Network"

    var id: String { rawValue }

    /// Localized display label.
    var label: String {
        switch self {
        case .connection: String(localized: "Connection")
        case .pathMappings: String(localized: "Path Mappings")
        case .speed: String(localized: "Speed")
        case .torrents: String(localized: "Torrents")
        case .queue: String(localized: "Queue")
        case .network: String(localized: "Network")
        }
    }

    var systemImage: String {
        switch self {
        case .connection: "link"
        case .pathMappings: "arrow.triangle.swap"
        case .speed: "gauge.with.dots.needle.67percent"
        case .torrents: "arrow.down.circle"
        case .queue: "list.number"
        case .network: "network"
        }
    }
}

// MARK: - Servers Settings Tab

/// Two-column layout for managing multiple Transmission server connections.
struct ServersSettingsTab: View {
    @Environment(AppState.self) private var appState
    @State private var selectedServerId: UUID?
    @State private var editingServer: ServerConfig?
    @State private var editingPassword: String = ""
    @State private var editingProxyPassword: String = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showingDeleteConfirmation = false
    @State private var selectedTab: ServerSettingsSubTab = .connection

    enum TestResult {
        case success
        case failure(String)
    }

    // MARK: - Session Settings State

    // Speed
    @State private var speedLimitDownEnabled = false
    @State private var speedLimitDown = 0
    @State private var speedLimitUpEnabled = false
    @State private var speedLimitUp = 0
    @State private var altSpeedEnabled = false
    @State private var altSpeedDown = 0
    @State private var altSpeedUp = 0
    @State private var altSpeedTimeEnabled = false
    @State private var altSpeedTimeBegin = 0
    @State private var altSpeedTimeEnd = 0
    @State private var altSpeedTimeDay = 0

    // Torrents
    @State private var downloadDir = ""
    @State private var incompleteDirEnabled = false
    @State private var incompleteDir = ""
    @State private var startAddedTorrents = true
    @State private var renamePartialFiles = true
    @State private var trashOriginalTorrentFiles = false
    @State private var seedRatioLimited = false
    @State private var seedRatioLimit = 0.0
    @State private var idleSeedingLimitEnabled = false
    @State private var idleSeedingLimit = 0

    // Queue
    @State private var downloadQueueEnabled = false
    @State private var downloadQueueSize = 0
    @State private var seedQueueEnabled = false
    @State private var seedQueueSize = 0
    @State private var queueStalledEnabled = false
    @State private var queueStalledMinutes = 0

    // Network
    @State private var peerPort = 0
    @State private var peerPortRandomOnStart = false
    @State private var portForwardingEnabled = false
    @State private var utpEnabled = false
    @State private var peerLimitGlobal = 0
    @State private var peerLimitPerTorrent = 0
    @State private var dhtEnabled = false
    @State private var pexEnabled = false
    @State private var lpdEnabled = false
    @State private var encryption = "preferred"
    @State private var blocklistEnabled = false
    @State private var blocklistUrl = ""
    @State private var blocklistSize = 0

    // Port test
    @State private var isTestingPort = false
    @State private var portTestResult: Bool?

    // Blocklist update
    @State private var isUpdatingBlocklist = false

    // Session load state
    @State private var isLoadingSession = false
    @State private var sessionLoaded = false
    @State private var isSavingSession = false
    @State private var originalSession: SessionSettings?

    var body: some View {
        HStack(spacing: 0) {
            serverList
                .frame(width: 200)

            Divider()

            if editingServer != nil {
                serverConfigPane
            } else {
                VStack(spacing: .spacing12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("No Server Selected")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Select a server or add a new one.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if appState.pendingAddServer {
                appState.pendingAddServer = false
                addNewServer()
                selectedTab = .connection
            } else if let pendingId = appState.pendingSettingsServerId {
                selectServer(id: pendingId)
                selectedTab = appState.pendingSettingsTab ?? .connection
                appState.pendingSettingsServerId = nil
                appState.pendingSettingsTab = nil
            } else if let activeId = appState.sessionManager.activeServerId {
                selectServer(id: activeId)
            } else if let first = appState.sessionManager.servers.first {
                selectServer(id: first.id)
            }
        }
    }

    // MARK: - Server List

    private var serverList: some View {
        VStack(spacing: 0) {
            List(appState.sessionManager.servers, selection: $selectedServerId) { server in
                serverRow(server)
                    .tag(server.id)
            }
            .listStyle(.sidebar)
            .onChange(of: selectedServerId) { _, newId in
                if let id = newId {
                    saveCurrentEdits()
                    selectServer(id: id)
                }
            }

            Divider()

            HStack(spacing: .spacing4) {
                Button {
                    addNewServer()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("Add Server")

                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(selectedServerId == nil)
                .help("Remove Server")

                Spacer()
            }
            .padding(.horizontal, .spacing4)
            .padding(.vertical, .spacing2)
        }
        .confirmationDialog(
            "Remove Server",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Remove", role: .destructive) {
                if let id = selectedServerId {
                    deleteServer(id: id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this server? This cannot be undone.")
        }
    }

    private func serverRow(_ server: ServerConfig) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: server.id == appState.sessionManager.activeServerId
                ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(server.id == appState.sessionManager.activeServerId
                    ? .green : .secondary.opacity(0.5))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(server.name.isEmpty ? "Untitled Server" : server.name)
                    .font(.body)
                    .lineLimit(1)
                if !server.host.isEmpty {
                    Text("\(server.host):\(server.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, .spacing2)
    }

    // MARK: - Server Config Pane

    /// Whether the selected server is the active (connected) server.
    private var isSelectedServerActive: Bool {
        selectedServerId != nil && selectedServerId == appState.sessionManager.activeServerId
    }

    /// Whether session-dependent tabs should show content.
    private var canShowSessionTabs: Bool {
        isSelectedServerActive && appState.isConnected && sessionLoaded
    }

    private var serverConfigPane: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(ServerSettingsSubTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: .spacing2) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 14))
                            Text(tab.label)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacing4)
                        .background(
                            selectedTab == tab
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                }
            }
            .padding(.horizontal, .spacing8)
            .padding(.top, .spacing8)
            .padding(.bottom, .spacing4)

            switch selectedTab {
            case .connection:
                connectionTab
            case .pathMappings:
                pathMappingsTab
            case .speed:
                speedTab
            case .torrents:
                torrentsTab
            case .queue:
                queueTab
            case .network:
                networkTab
            }
        }
        .onChange(of: editingServer) { _, _ in
            saveCurrentEdits()
        }
        .onChange(of: editingPassword) { _, _ in
            saveCurrentEdits()
        }
        .onChange(of: editingProxyPassword) { _, _ in
            saveCurrentEdits()
        }
        .onChange(of: selectedServerId) { _, _ in
            sessionLoaded = false
            originalSession = nil
        }
        .task(id: selectedServerId) {
            if isSelectedServerActive && appState.isConnected {
                await loadSessionSettings()
            }
        }
    }

    // MARK: - Connection Tab

    private var connectionTab: some View {
        Form {
            Section {
                TextField("Name", text: editingServerBinding.name, prompt: Text("My Server"))
                TextField("Host", text: editingServerBinding.host, prompt: Text("192.168.1.12"))
                TextField("Port", value: editingServerBinding.port, format: .number.grouping(.never))
                TextField("RPC Path", text: editingServerBinding.rpcPath, prompt: Text("/transmission/rpc"))
                Toggle("Use SSL", isOn: editingServerBinding.useSSL)
                if editingServer?.useSSL == true {
                    Toggle("Allow Untrusted Certificates", isOn: editingServerBinding.allowUntrustedCerts)
                        .help("Accept self-signed or untrusted SSL certificates from this server.")
                }
            } header: {
                Text("Server")
            }

            Section {
                Toggle("Requires Authentication", isOn: editingServerBinding.authRequired)
                if editingServer?.authRequired == true {
                    TextField("Username", text: editingServerBinding.username)
                    SecureField("Password", text: $editingPassword)
                }
            } header: {
                Text("Authentication")
            }

            Section {
                Picker("Proxy", selection: editingServerBinding.proxyType) {
                    ForEach(ProxyType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }

                if editingServer?.proxyType != ProxyType.none {
                    TextField("Proxy Host", text: editingServerBinding.proxyHost, prompt: Text("proxy.example.com"))
                    TextField("Proxy Port", value: editingServerBinding.proxyPort, format: .number.grouping(.never))
                    Toggle("Proxy Requires Authentication", isOn: editingServerBinding.proxyAuthRequired)
                    if editingServer?.proxyAuthRequired == true {
                        TextField("Proxy Username", text: editingServerBinding.proxyUsername)
                        SecureField("Proxy Password", text: $editingProxyPassword)
                    }
                }
            } header: {
                Text("Proxy")
            }

            Section {
                HStack(spacing: .spacing12) {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack(spacing: .spacing4) {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isTesting ? "Testing…" : "Test Connection")
                        }
                    }
                    .disabled(!(editingServer?.isConfigured ?? false) || isTesting)

                    if let result = testResult {
                        testResultLabel(result)
                    }

                    Spacer()

                    if appState.sessionManager.activeServerId != selectedServerId {
                        Button("Set as Active") {
                            if let id = selectedServerId {
                                setActiveAndConnect(id: id)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        HStack(spacing: .spacing4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Active Server")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func testResultLabel(_ result: TestResult) -> some View {
        switch result {
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .lineLimit(4)
        }
    }

    // MARK: - Path Mappings Tab

    private var pathMappingsTab: some View {
        VStack(spacing: 0) {
            if let mappings = editingServer?.pathMappings, !mappings.isEmpty {
                List {
                    ForEach(mappings) { mapping in
                        pathMappingRow(mapping)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            if let id = editingServer?.pathMappings[index].id {
                                removePathMapping(id: id)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            } else {
                VStack(spacing: .spacing8) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("No Path Mappings")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Map remote server paths to local paths\nfor \"Open in Finder\" support.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            HStack(spacing: .spacing4) {
                Button {
                    addPathMapping()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("Add Path Mapping")

                Button {
                    if let last = editingServer?.pathMappings.last {
                        removePathMapping(id: last.id)
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(editingServer?.pathMappings.isEmpty ?? true)
                .help("Remove Last Path Mapping")

                Spacer()
            }
            .padding(.horizontal, .spacing4)
            .padding(.vertical, .spacing2)
        }
    }

    private func pathMappingRow(_ mapping: PathMapping) -> some View {
        VStack(alignment: .leading, spacing: .spacing4) {
            HStack(spacing: .spacing8) {
                Image(systemName: "server.rack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                TextField(
                    "Remote path",
                    text: pathMappingBinding(for: mapping.id, keyPath: \.remotePath),
                    prompt: Text("/mnt/tank/Downloads")
                )
                .font(.body.monospaced())
                .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: .spacing8) {
                Image(systemName: "laptopcomputer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                TextField(
                    "Local path",
                    text: pathMappingBinding(for: mapping.id, keyPath: \.localPath),
                    prompt: Text("/Volumes/tank/Downloads")
                )
                .font(.body.monospaced())
                .textFieldStyle(.roundedBorder)
                Button {
                    browseForLocalPath(mappingId: mapping.id)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Browse…")
            }
        }
        .padding(.vertical, .spacing4)
    }

    // MARK: - Session Tab Wrapper

    /// Wraps session-dependent tab content with a "not connected" state.
    @ViewBuilder
    private func sessionTabContent(@ViewBuilder content: () -> some View) -> some View {
        if isLoadingSession {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if canShowSessionTabs {
            VStack(spacing: 0) {
                content()

                Divider()

                HStack {
                    Spacer()
                    Button("Save") {
                        Task { await saveSessionSettings() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isSavingSession)
                }
                .padding(.spacing8)
            }
        } else {
            VStack(spacing: .spacing12) {
                Image(systemName: "network.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(.quaternary)
                Text("Not Connected")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Set this server as active to configure\nits daemon settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                if appState.sessionManager.activeServerId != selectedServerId {
                    Button("Set as Active & Connect") {
                        if let id = selectedServerId {
                            setActiveAndConnect(id: id)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, .spacing4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Speed Tab

    private var speedTab: some View {
        sessionTabContent {
            Form {
                Section("Download & Upload Limits") {
                    Toggle("Limit Download Speed", isOn: $speedLimitDownEnabled)
                    if speedLimitDownEnabled {
                        HStack {
                            Text("Download Limit")
                            Spacer()
                            TextField("", value: $speedLimitDown, format: .number)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("kB/s")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle("Limit Upload Speed", isOn: $speedLimitUpEnabled)
                    if speedLimitUpEnabled {
                        HStack {
                            Text("Upload Limit")
                            Spacer()
                            TextField("", value: $speedLimitUp, format: .number)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("kB/s")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Alternative Speed Limits (Turtle Mode)") {
                    Toggle("Enable Alternative Speeds", isOn: $altSpeedEnabled)

                    HStack {
                        Text("Download")
                        Spacer()
                        TextField("", value: $altSpeedDown, format: .number)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        Text("kB/s")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Upload")
                        Spacer()
                        TextField("", value: $altSpeedUp, format: .number)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        Text("kB/s")
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Schedule Alternative Speeds", isOn: $altSpeedTimeEnabled)
                    if altSpeedTimeEnabled {
                        DatePicker(
                            "From",
                            selection: minutesToDateBinding($altSpeedTimeBegin),
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "To",
                            selection: minutesToDateBinding($altSpeedTimeEnd),
                            displayedComponents: .hourAndMinute
                        )

                        VStack(alignment: .leading, spacing: .spacing4) {
                            Text("Days")
                                .font(.body)
                            HStack(spacing: .spacing8) {
                                ForEach(DayOfWeek.allCases) { day in
                                    Toggle(day.shortLabel, isOn: dayBinding(day))
                                        .toggleStyle(.checkbox)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Torrents Tab

    private var torrentsTab: some View {
        sessionTabContent {
            Form {
                Section("Directories") {
                    HStack {
                        Text("Download Directory")
                        Spacer()
                        TextField("", text: $downloadDir)
                            .frame(width: 220)
                            .multilineTextAlignment(.trailing)
                    }

                    Toggle("Use Incomplete Directory", isOn: $incompleteDirEnabled)
                    if incompleteDirEnabled {
                        HStack {
                            Text("Incomplete Directory")
                            Spacer()
                            TextField("", text: $incompleteDir)
                                .frame(width: 220)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Adding Torrents") {
                    Toggle("Start Added Torrents Automatically", isOn: $startAddedTorrents)
                    Toggle("Rename Partial Files (.part)", isOn: $renamePartialFiles)
                    Toggle("Trash Original .torrent Files", isOn: $trashOriginalTorrentFiles)
                }

                Section("Seeding Limits") {
                    Toggle("Stop Seeding at Ratio", isOn: $seedRatioLimited)
                    if seedRatioLimited {
                        HStack {
                            Text("Seed Ratio Limit")
                            Spacer()
                            TextField("", value: $seedRatioLimit, format: .number.precision(.fractionLength(2)))
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Toggle("Stop Seeding if Idle", isOn: $idleSeedingLimitEnabled)
                    if idleSeedingLimitEnabled {
                        HStack {
                            Text("Idle Limit")
                            Spacer()
                            TextField("", value: $idleSeedingLimit, format: .number)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("min")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Queue Tab

    private var queueTab: some View {
        sessionTabContent {
            Form {
                Section("Download Queue") {
                    Toggle("Limit Simultaneous Downloads", isOn: $downloadQueueEnabled)
                    if downloadQueueEnabled {
                        HStack {
                            Text("Maximum Active Downloads")
                            Spacer()
                            TextField("", value: $downloadQueueSize, format: .number)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Seed Queue") {
                    Toggle("Limit Simultaneous Seeding", isOn: $seedQueueEnabled)
                    if seedQueueEnabled {
                        HStack {
                            Text("Maximum Active Seeding")
                            Spacer()
                            TextField("", value: $seedQueueSize, format: .number)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Stalled Transfers") {
                    Toggle("Consider Transfers Stalled When Idle", isOn: $queueStalledEnabled)
                    if queueStalledEnabled {
                        HStack {
                            Text("Stalled After")
                            Spacer()
                            TextField("", value: $queueStalledMinutes, format: .number)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("min")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Network Tab

    private var networkTab: some View {
        sessionTabContent {
            Form {
                Section("Listening Port") {
                    HStack {
                        Text("Peer Port")
                        Spacer()
                        TextField("", value: $peerPort, format: .number.grouping(.never))
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Randomize Port on Start", isOn: $peerPortRandomOnStart)
                    Toggle("Port Forwarding (UPnP / NAT-PMP)", isOn: $portForwardingEnabled)
                    Toggle("Enable uTP", isOn: $utpEnabled)

                    HStack {
                        Button {
                            isTestingPort = true
                            portTestResult = nil
                            Task {
                                portTestResult = await appState.testPort()
                                isTestingPort = false
                            }
                        } label: {
                            if isTestingPort {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Test Port")
                            }
                        }
                        .disabled(isTestingPort)

                        if let result = portTestResult {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result ? .green : .red)
                            Text(result ? "Port is open" : "Port is closed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Peer Limits") {
                    HStack {
                        Text("Global Peer Limit")
                        Spacer()
                        TextField("", value: $peerLimitGlobal, format: .number)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Per-Torrent Peer Limit")
                        Spacer()
                        TextField("", value: $peerLimitPerTorrent, format: .number)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Peer Discovery") {
                    Toggle("DHT (Distributed Hash Table)", isOn: $dhtEnabled)
                    Toggle("PEX (Peer Exchange)", isOn: $pexEnabled)
                    Toggle("LPD (Local Peer Discovery)", isOn: $lpdEnabled)
                    Picker("Encryption", selection: $encryption) {
                        Text("Required").tag("required")
                        Text("Preferred").tag("preferred")
                        Text("Tolerated").tag("tolerated")
                    }
                }

                Section("Blocklist") {
                    Toggle("Enable Blocklist", isOn: $blocklistEnabled)
                    if blocklistEnabled {
                        HStack {
                            Text("URL")
                            Spacer()
                            TextField("", text: $blocklistUrl)
                                .frame(width: 280)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            LabeledContent("Entries", value: "\(blocklistSize)")
                            Spacer()
                            Button {
                                isUpdatingBlocklist = true
                                Task {
                                    if let newSize = await appState.updateBlocklist() {
                                        blocklistSize = newSize
                                    }
                                    isUpdatingBlocklist = false
                                }
                            } label: {
                                if isUpdatingBlocklist {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Update")
                                }
                            }
                            .disabled(isUpdatingBlocklist)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Session Settings Load / Save

    private func loadSessionSettings() async {
        isLoadingSession = true
        defer { isLoadingSession = false }

        await appState.refreshSessionSettings()
        guard let s = appState.sessionSettings else { return }
        originalSession = s

        // Speed
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

        // Torrents
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

        // Queue
        downloadQueueEnabled = s.downloadQueueEnabled
        downloadQueueSize = s.downloadQueueSize
        seedQueueEnabled = s.seedQueueEnabled
        seedQueueSize = s.seedQueueSize
        queueStalledEnabled = s.queueStalledEnabled
        queueStalledMinutes = s.queueStalledMinutes

        // Network
        peerPort = s.peerPort
        peerPortRandomOnStart = s.peerPortRandomOnStart
        portForwardingEnabled = s.portForwardingEnabled
        utpEnabled = s.utpEnabled
        peerLimitGlobal = s.peerLimitGlobal
        peerLimitPerTorrent = s.peerLimitPerTorrent
        dhtEnabled = s.dhtEnabled
        pexEnabled = s.pexEnabled
        lpdEnabled = s.lpdEnabled
        encryption = s.encryption
        blocklistEnabled = s.blocklistEnabled
        blocklistUrl = s.blocklistUrl
        blocklistSize = s.blocklistSize

        sessionLoaded = true
    }

    private func saveSessionSettings() async {
        guard let o = originalSession else { return }
        isSavingSession = true
        defer { isSavingSession = false }

        var update = SessionSettingsUpdate()

        // Speed diffs
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

        // Torrents diffs
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

        // Queue diffs
        if downloadQueueEnabled != o.downloadQueueEnabled { update.downloadQueueEnabled = downloadQueueEnabled }
        if downloadQueueSize != o.downloadQueueSize { update.downloadQueueSize = downloadQueueSize }
        if seedQueueEnabled != o.seedQueueEnabled { update.seedQueueEnabled = seedQueueEnabled }
        if seedQueueSize != o.seedQueueSize { update.seedQueueSize = seedQueueSize }
        if queueStalledEnabled != o.queueStalledEnabled { update.queueStalledEnabled = queueStalledEnabled }
        if queueStalledMinutes != o.queueStalledMinutes { update.queueStalledMinutes = queueStalledMinutes }

        // Network diffs
        if peerPort != o.peerPort { update.peerPort = peerPort }
        if peerPortRandomOnStart != o.peerPortRandomOnStart { update.peerPortRandomOnStart = peerPortRandomOnStart }
        if portForwardingEnabled != o.portForwardingEnabled { update.portForwardingEnabled = portForwardingEnabled }
        if utpEnabled != o.utpEnabled { update.utpEnabled = utpEnabled }
        if peerLimitGlobal != o.peerLimitGlobal { update.peerLimitGlobal = peerLimitGlobal }
        if peerLimitPerTorrent != o.peerLimitPerTorrent { update.peerLimitPerTorrent = peerLimitPerTorrent }
        if dhtEnabled != o.dhtEnabled { update.dhtEnabled = dhtEnabled }
        if pexEnabled != o.pexEnabled { update.pexEnabled = pexEnabled }
        if lpdEnabled != o.lpdEnabled { update.lpdEnabled = lpdEnabled }
        if encryption != o.encryption { update.encryption = encryption }
        if blocklistEnabled != o.blocklistEnabled { update.blocklistEnabled = blocklistEnabled }
        if blocklistUrl != o.blocklistUrl { update.blocklistUrl = blocklistUrl }

        await appState.updateSessionSettings(update)

        // Refresh to pick up any server-side adjustments
        await loadSessionSettings()
    }

    // MARK: - Helpers

    private func pathMappingBinding(for mappingId: UUID, keyPath: WritableKeyPath<PathMapping, String>) -> Binding<String> {
        Binding(
            get: {
                editingServer?.pathMappings.first(where: { $0.id == mappingId })?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                guard let index = editingServer?.pathMappings.firstIndex(where: { $0.id == mappingId }) else { return }
                editingServer?.pathMappings[index][keyPath: keyPath] = newValue
            }
        )
    }

    private func addPathMapping() {
        editingServer?.pathMappings.append(PathMapping())
        saveCurrentEdits()
    }

    private func removePathMapping(id: UUID) {
        editingServer?.pathMappings.removeAll { $0.id == id }
        saveCurrentEdits()
    }

    private func browseForLocalPath(mappingId: UUID) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the local folder that corresponds to the remote path"

        if panel.runModal() == .OK, let url = panel.url {
            guard let index = editingServer?.pathMappings.firstIndex(where: { $0.id == mappingId }) else { return }
            editingServer?.pathMappings[index].localPath = url.path(percentEncoded: false)
            // Save a security-scoped bookmark so the app can access this path later
            if let bookmarkData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                editingServer?.pathMappings[index].bookmark = bookmarkData
            }
            saveCurrentEdits()
            // Also persist the bookmark into SessionManager directly
            appState.sessionManager.saveBookmark(for: mappingId, url: url)
        }
    }

    /// A binding into the editingServer state for form fields.
    private var editingServerBinding: Binding<ServerConfig> {
        Binding(
            get: { editingServer ?? ServerConfig() },
            set: { editingServer = $0 }
        )
    }

    // MARK: - Actions

    private func selectServer(id: UUID) {
        selectedServerId = id
        if var server = appState.sessionManager.servers.first(where: { $0.id == id }) {
            server.password = appState.sessionManager.password(for: id)
            server.proxyPassword = appState.sessionManager.proxyPassword(for: id)
            editingServer = server
            editingPassword = server.password
            editingProxyPassword = server.proxyPassword
        }
        testResult = nil
    }

    private func addNewServer() {
        let newServer = ServerConfig(name: "New Server")
        let created = appState.sessionManager.addServer(newServer)
        selectServer(id: created.id)
    }

    private func deleteServer(id: UUID) {
        appState.sessionManager.deleteServer(id: id)
        if let first = appState.sessionManager.servers.first {
            selectServer(id: first.id)
        } else {
            selectedServerId = nil
            editingServer = nil
        }
    }

    private func saveCurrentEdits() {
        guard var server = editingServer,
            appState.sessionManager.servers.contains(where: { $0.id == server.id })
        else { return }
        server.password = editingPassword
        server.proxyPassword = editingProxyPassword
        appState.sessionManager.updateServer(server)
    }

    private func setActiveAndConnect(id: UUID) {
        saveCurrentEdits()
        Task {
            await appState.switchServer(to: id)
        }
    }

    private func testConnection() async {
        guard var server = editingServer else { return }
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        server.password = editingPassword
        appState.sessionManager.updateServer(server)
        let previousActiveId = appState.sessionManager.activeServerId
        appState.sessionManager.setActiveServer(id: server.id)
        appState.client.clearSessionId()

        do {
            try await appState.client.testConnection()
            testResult = .success
        } catch {
            testResult = .failure(error.localizedDescription)
        }

        if let previousId = previousActiveId, previousId != server.id {
            appState.sessionManager.setActiveServer(id: previousId)
            appState.client.clearSessionId()
        }
    }

    // MARK: - Time Picker Helpers

    /// Creates a Binding<Date> that converts minutes-since-midnight to/from a Date.
    private func minutesToDateBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let hour = minutes.wrappedValue / 60
                let minute = minutes.wrappedValue % 60
                let calendar = Calendar.current
                return calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
            },
            set: { newDate in
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: newDate)
                minutes.wrappedValue = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }

    /// Creates a Binding<Bool> for a specific day in the bitmask.
    private func dayBinding(_ day: DayOfWeek) -> Binding<Bool> {
        Binding<Bool>(
            get: { altSpeedTimeDay & day.rawValue != 0 },
            set: { isOn in
                if isOn {
                    altSpeedTimeDay |= day.rawValue
                } else {
                    altSpeedTimeDay &= ~day.rawValue
                }
            }
        )
    }
}
// MARK: - Day of Week

/// Days of the week as a bitmask matching Transmission's alt-speed-time-day field.
enum DayOfWeek: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 4
    case wednesday = 8
    case thursday = 16
    case friday = 32
    case saturday = 64

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: String(localized: "Sun")
        case .monday: String(localized: "Mon")
        case .tuesday: String(localized: "Tue")
        case .wednesday: String(localized: "Wed")
        case .thursday: String(localized: "Thu")
        case .friday: String(localized: "Fri")
        case .saturday: String(localized: "Sat")
        }
    }
}

