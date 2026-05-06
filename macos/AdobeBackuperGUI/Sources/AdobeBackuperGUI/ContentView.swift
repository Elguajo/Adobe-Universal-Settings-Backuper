import SwiftUI
import AppKit

struct ContentView: View {
    let engine: BackupEngine

    @State private var summary = BackupScanSummary(items: [])
    @State private var selectedItems = Set<BackupScanItem.ID>()
    @State private var isScanning = false
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var status = "Run a scan to see what will be backed up."
    @State private var log = ""

    private var selectedScanItems: [BackupScanItem] {
        summary.items.filter { selectedItems.contains($0.id) }
    }

    private var selectedSummary: BackupScanSummary {
        BackupScanSummary(items: selectedScanItems)
    }

    private var isBusy: Bool {
        isScanning || isBackingUp || isRestoring
    }

    var body: some View {
        VStack(spacing: 0) {
            actionRow

            Divider()

            NavigationSplitView {
                List(summary.items, selection: $selectedItems) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.category)
                            .lineLimit(1)
                        Text("\(item.formattedSize) - \(item.files) files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(item.id)
                }
                .listStyle(.sidebar)
                .navigationTitle("Adobe Backuper")
                .navigationSplitViewColumnWidth(min: 150, ideal: 240, max: 420)
            } detail: {
                detailView
                    .navigationTitle("Backup Preview")
            }
        }
        .task {
            await scan()
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                Task { await scan() }
            } label: {
                Label("Scan", systemImage: "magnifyingglass")
            }
            .disabled(isBusy)

            Button {
                selectAll()
            } label: {
                Label("Select All", systemImage: "checklist.checked")
            }
            .disabled(summary.items.isEmpty || isBusy)

            Button {
                selectedItems.removeAll()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .disabled(selectedItems.isEmpty || isBusy)

            Spacer()

            Text("\(selectedItems.count) selected")
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                Task { await backup() }
            } label: {
                Label("Backup", systemImage: "externaldrive.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedItems.isEmpty || isBusy)

            Button {
                chooseRestoreFolder()
            } label: {
                Label("Restore", systemImage: "arrow.clockwise.circle")
            }
            .disabled(isBusy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var detailView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                SummaryMetric(title: "Selected", value: "\(selectedSummary.items.count)")
                SummaryMetric(title: "Files", value: "\(selectedSummary.totalFiles)")
                SummaryMetric(title: "Size", value: selectedSummary.formattedSize)
            }

            if let item = selectedScanItems.first {
                DetailRow(title: "Category", value: item.category)
                DetailRow(title: "From", value: item.source)
                DetailRow(title: "To", value: item.destination)
                DetailRow(title: "Size", value: "\(item.formattedSize), \(item.files) files")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No backup locations selected")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            Text(status)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(log.isEmpty ? "Engine output will appear here." : log)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(24)
    }

    private func selectAll() {
        selectedItems = Set(summary.items.map(\.id))
    }

    private func scan() async {
        isScanning = true
        status = "Scanning Adobe settings, plugins, and ScriptUI panels..."
        log = ""

        do {
            summary = try await engine.scan()
            selectAll()
            status = summary.items.isEmpty ? "Nothing found to backup." : "Scan complete. Choose one, several, or all locations."
        } catch {
            status = error.localizedDescription
        }

        isScanning = false
    }

    private func backup() async {
        isBackingUp = true
        status = "Backing up \(selectedItems.count) selected locations..."

        do {
            log = try await engine.backup(items: selectedScanItems)
            status = "Backup complete."
            summary = try await engine.scan()
            selectAll()
        } catch {
            status = error.localizedDescription
        }

        isBackingUp = false
    }

    private func chooseRestoreFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Adobe backup to restore"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let folder = panel.url {
            Task { await restore(from: folder) }
        }
    }

    private func restore(from folder: URL) async {
        isRestoring = true
        status = "Restoring from \(folder.path)..."

        do {
            log = try await engine.restore(from: folder)
            status = "Restore complete."
        } catch {
            status = error.localizedDescription
        }

        isRestoring = false
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
