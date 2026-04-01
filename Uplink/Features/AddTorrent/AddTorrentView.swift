import SwiftUI
import UniformTypeIdentifiers

/// Sheet for adding a new torrent by URL/magnet or .torrent file.
struct AddTorrentView: View {
    @Bindable var viewModel: AddTorrentViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Source", selection: $viewModel.selectedTab) {
                ForEach(AddTorrentViewModel.Tab.allCases, id: \.self) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.spacing16)

            Divider()

            // Tab content
            Group {
                switch viewModel.selectedTab {
                case .url:
                    urlTab
                case .file:
                    fileTab
                }
            }
            .padding(.spacing16)

            // Download directory override
            VStack(alignment: .leading, spacing: .spacing4) {
                Text("Download Directory (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Default server directory", text: $viewModel.downloadDirOverride)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.downloadDirOverride) {
                        Task { await viewModel.checkFreeSpace() }
                    }
                if let freeSpace = viewModel.freeSpaceText {
                    Text(freeSpace)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, .spacing16)
            .task {
                await viewModel.checkFreeSpace()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, .spacing16)
                    .padding(.top, .spacing8)
            }

            Spacer()

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task {
                        if let torrentId = await viewModel.addTorrent() {
                            viewModel.appState.selectedTorrentIds = [torrentId]
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isAdding {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Add")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canAdd || viewModel.isAdding)
            }
            .padding(.spacing16)
        }
        .frame(width: 480, height: 340)
        .background(.background)
    }

    // MARK: - URL Tab

    private var urlTab: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            Text("Enter a URL, HTTPS link, or magnet link:")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("https:// or magnet:", text: $viewModel.urlText)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - File Tab

    private var fileTab: some View {
        VStack(spacing: .spacing12) {
            if let fileName = viewModel.selectedFileName {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.secondary)
                    Text(fileName)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Clear") {
                        viewModel.selectedFileData = nil
                        viewModel.selectedFileName = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            } else {
                dropZone
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: .spacing8) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Drop a .torrent file here")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Choose File…") {
                chooseFile()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                .foregroundStyle(.tertiary)
        )
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
    }

    // MARK: - File Handling

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "torrent") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadFile(from: url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
            else { return }
            Task { @MainActor in
                viewModel.loadFile(from: url)
            }
        }
    }
}
