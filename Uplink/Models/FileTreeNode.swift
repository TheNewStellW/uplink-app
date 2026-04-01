import Foundation

/// A node in the file tree hierarchy. Can represent either a folder or a leaf file.
///
/// Built by parsing flat file paths from the Transmission API into a tree structure.
struct FileTreeNode: Identifiable {
    let id: String
    let name: String
    let isFolder: Bool

    /// Index into the original `files`/`fileStats` arrays. `nil` for folders.
    let fileIndex: Int?

    /// Child nodes (empty for leaf files).
    var children: [FileTreeNode]

    // MARK: - Leaf file data (non-nil for files, nil for folders)

    let fileLength: Int64?
    let fileBytesCompleted: Int64?
    let fileWanted: Bool?
    /// -1 = low, 0 = normal, 1 = high
    let filePriority: Int?

    // MARK: - Aggregate Computed Properties

    /// Total size of all files under this node.
    var totalSize: Int64 {
        if let fileLength {
            return fileLength
        }
        return children.reduce(0) { $0 + $1.totalSize }
    }

    /// Total bytes completed across all files under this node.
    var totalBytesCompleted: Int64 {
        if let fileBytesCompleted {
            return fileBytesCompleted
        }
        return children.reduce(0) { $0 + $1.totalBytesCompleted }
    }

    /// Progress from 0.0 to 1.0 for this node.
    var progress: Double {
        let size = totalSize
        guard size > 0 else { return 0 }
        return Double(totalBytesCompleted) / Double(size)
    }

    /// Number of leaf files under this node.
    var fileCount: Int {
        if !isFolder { return 1 }
        return children.reduce(0) { $0 + $1.fileCount }
    }

    // MARK: - Factory

    /// Builds a tree from flat Transmission file paths and stats.
    static func buildTree(
        files: [TorrentFile],
        fileStats: [TorrentFileStats]
    ) -> [FileTreeNode] {
        // Root container to accumulate children
        var rootChildren: [String: FileTreeNode] = [:]
        var rootOrder: [String] = []

        for (index, file) in files.enumerated() {
            let stats = fileStats.indices.contains(index) ? fileStats[index] : nil
            let components = file.name.split(separator: "/").map(String.init)

            insertPath(
                components: components,
                fileIndex: index,
                file: file,
                stats: stats,
                into: &rootChildren,
                order: &rootOrder,
                pathPrefix: ""
            )
        }

        return rootOrder.compactMap { rootChildren[$0] }
            .sorted { lhs, rhs in
                // Folders before files, then alphabetical
                if lhs.isFolder != rhs.isFolder { return lhs.isFolder }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private static func insertPath(
        components: [String],
        fileIndex: Int,
        file: TorrentFile,
        stats: TorrentFileStats?,
        into children: inout [String: FileTreeNode],
        order: inout [String],
        pathPrefix: String
    ) {
        guard let first = components.first else { return }
        let currentPath = pathPrefix.isEmpty ? first : "\(pathPrefix)/\(first)"
        let remaining = Array(components.dropFirst())

        if remaining.isEmpty {
            // Leaf file
            let node = FileTreeNode(
                id: currentPath,
                name: first,
                isFolder: false,
                fileIndex: fileIndex,
                children: [],
                fileLength: file.length,
                fileBytesCompleted: file.bytesCompleted,
                fileWanted: stats?.wanted,
                filePriority: stats?.priority
            )
            if children[first] == nil {
                order.append(first)
            }
            children[first] = node
        } else {
            // Folder — ensure it exists
            if children[first] == nil {
                order.append(first)
                children[first] = FileTreeNode(
                    id: currentPath,
                    name: first,
                    isFolder: true,
                    fileIndex: nil,
                    children: [],
                    fileLength: nil,
                    fileBytesCompleted: nil,
                    fileWanted: nil,
                    filePriority: nil
                )
            }

            // Recursively insert into the folder's children
            var folder = children[first]!
            var folderChildren: [String: FileTreeNode] = Dictionary(
                uniqueKeysWithValues: folder.children.map { ($0.name, $0) }
            )
            var folderOrder = folder.children.map(\.name)

            insertPath(
                components: remaining,
                fileIndex: fileIndex,
                file: file,
                stats: stats,
                into: &folderChildren,
                order: &folderOrder,
                pathPrefix: currentPath
            )

            folder.children = folderOrder.compactMap { folderChildren[$0] }
                .sorted { lhs, rhs in
                    if lhs.isFolder != rhs.isFolder { return lhs.isFolder }
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            children[first] = folder
        }
    }
}

/// Priority levels for torrent files.
enum FilePriority: Int, CaseIterable, Identifiable {
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
