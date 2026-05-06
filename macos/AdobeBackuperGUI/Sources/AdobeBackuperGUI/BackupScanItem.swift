import Foundation

struct BackupScanItem: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let source: String
    let destination: String
    let files: Int
    let bytes: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct BackupScanSummary {
    let items: [BackupScanItem]

    var totalFiles: Int {
        items.reduce(0) { $0 + $1.files }
    }

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.bytes }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}
