import AppKit
import Foundation

struct CleanLogEntry: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let status: String
    let bytes: Int64
    let message: String

    init(result: CleanResult) {
        label = result.label
        status = result.status
        bytes = result.bytes
        message = result.message
    }

    var isSuccess: Bool { status == "cleaned" || status == "would-clean" }
    var isFailure: Bool { status == "failed" || status == "partial" }
}

@MainActor
final class ScanStore: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case ready
        case failed(String)
    }

    enum CleanPhase: Equatable {
        case idle
        case running
        case finished
        case failed(String)
    }

    // Scan results
    @Published private(set) var items: [ScanItem] = []
    @Published private(set) var insights: [Insight] = []
    @Published private(set) var disk: DiskInfo?
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastScan: Date?
    @Published private(set) var scanDuration: TimeInterval = 0
    @Published private(set) var didScanOnce = false

    // Cleaning
    @Published private(set) var cleanPhase: CleanPhase = .idle
    @Published private(set) var cleanLog: [CleanLogEntry] = []
    @Published private(set) var lastReclaimed: Int64 = 0
    @Published var showConfirm = false
    @Published var showProgress = false

    // UI state
    @Published var selected: Set<String> = []
    @Published var layout: Layout = .grouped
    @Published var filter: ItemFilter = .all
    @Published var sortOrder: SortOrder = .size
    @Published var search: String = ""
    @Published var inspectedRowID: String?
    @Published var previewOnly: Bool {
        didSet { UserDefaults.standard.set(previewOnly, forKey: "previewOnly") }
    }

    let cli: CLIClient?
    private var scanTask: Task<Void, Never>?
    private var cleanTask: Task<Void, Never>?

    init() {
        previewOnly = UserDefaults.standard.object(forKey: "previewOnly") as? Bool ?? false
        if let url = CLIClient.locate() {
            cli = CLIClient(binaryURL: url)
        } else {
            cli = nil
            phase = .failed("The macos-system-data helper could not be found. Rebuild the app with `make app`.")
        }
    }

    // MARK: - Derived state

    var reclaimableBytes: Int64 {
        items.filter { $0.cleanable && $0.state == .present }.reduce(0) { $0 + $1.bytes }
    }

    var reclaimableItemCount: Int {
        items.filter { $0.cleanable && $0.state == .present && $0.bytes > 0 }.count
    }

    var deniedCount: Int {
        items.filter { $0.state == .denied }.count
    }

    var allRows: [DisplayRow] {
        var rows = items
            .filter { $0.state == .present && $0.bytes > 0 }
            .map(DisplayRow.init(item:))
        rows += items
            .filter { $0.state == .denied }
            .map(DisplayRow.init(item:))
        rows += insights
            .filter { !($0.catalogued ?? false) }
            .map(DisplayRow.init(insight:))
        return rows
    }

    var displayRows: [DisplayRow] {
        var rows = allRows

        switch filter {
        case .all:
            break
        case .cleanable:
            rows = rows.filter { $0.cleanable }
        case .safe:
            rows = rows.filter { $0.cleanable && $0.safety == .safe }
        }

        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            rows = rows.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.path.localizedCaseInsensitiveContains(query)
                    || $0.note.localizedCaseInsensitiveContains(query)
            }
        }

        switch sortOrder {
        case .size:
            rows.sort { $0.bytes > $1.bytes }
        case .name:
            rows.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
        return rows
    }

    func rows(forTier tier: Int) -> [DisplayRow] {
        displayRows.filter { $0.kind == .item && $0.tier == tier }
    }

    var insightRows: [DisplayRow] {
        displayRows.filter { $0.kind == .insight }
    }

    var selectedItems: [ScanItem] {
        items.filter { selected.contains($0.id) && $0.cleanable && $0.state == .present }
    }

    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.bytes }
    }

    var hasReviewSelection: Bool {
        selectedItems.contains { $0.safety == .review }
    }

    var inspectedRow: DisplayRow? {
        guard let inspectedRowID else { return nil }
        return allRows.first { $0.id == inspectedRowID }
    }

    var tierTotals: [Int: (count: Int, bytes: Int64)] {
        var totals: [Int: (count: Int, bytes: Int64)] = [:]
        for row in displayRows where row.kind == .item {
            let current = totals[row.tier] ?? (0, 0)
            totals[row.tier] = (current.count + 1, current.bytes + row.bytes)
        }
        return totals
    }

    // MARK: - Scanning

    func scan() {
        guard let cli else { return }
        scanTask?.cancel()
        items.removeAll()
        insights.removeAll()
        disk = nil
        selected.removeAll()
        inspectedRowID = nil
        phase = .scanning

        let started = Date()
        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await line in cli.stream(["--json"]) {
                    if Task.isCancelled { return }
                    self.apply(line)
                }
                if Task.isCancelled { return }
                self.phase = .ready
                self.lastScan = Date()
                self.scanDuration = Date().timeIntervalSince(started)
                self.didScanOnce = true
                self.pruneSelection()
            } catch {
                if Task.isCancelled { return }
                self.phase = .failed(error.localizedDescription)
                self.didScanOnce = true
            }
        }
    }

    private func apply(_ line: String) {
        switch CLIMessage.decode(line) {
        case .disk(let info):
            disk = info
        case .item(let item):
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
            } else {
                items.append(item)
            }
        case .insight(let insight):
            insights.append(insight)
        default:
            break
        }
    }

    private func pruneSelection() {
        let valid = Set(items.filter { $0.cleanable && $0.state == .present }.map(\.id))
        selected = selected.intersection(valid)
    }

    // MARK: - Selection

    func setSelected(_ id: String, _ isSelected: Bool) {
        if isSelected {
            selected.insert(id)
        } else {
            selected.remove(id)
        }
    }

    func selectAllSafe() {
        selected = Set(items.filter { $0.cleanable && $0.safety == .safe && $0.state == .present }.map(\.id))
    }

    func clearSelection() {
        selected.removeAll()
    }

    func selectRecommended() {
        selected = Set(items.filter { $0.cleanable && $0.state == .present && $0.tier == 1 }.map(\.id))
    }

    // MARK: - Cleaning

    func runClean() {
        guard let cli, !selected.isEmpty else { return }
        let ids = selectedItems.map(\.id)
        guard !ids.isEmpty else { return }

        cleanTask?.cancel()
        cleanLog.removeAll()
        lastReclaimed = 0
        cleanPhase = .running

        var arguments = ["--json", "--clean-ids", ids.sorted().joined(separator: ",")]
        arguments.append(previewOnly ? "-n" : "-y")

        cleanTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await line in cli.stream(arguments) {
                    if Task.isCancelled { return }
                    self.applyClean(line)
                }
                if Task.isCancelled { return }
                self.cleanPhase = .finished
                self.writeAuditLog(ids: ids)
            } catch {
                if Task.isCancelled { return }
                self.cleanPhase = .failed(error.localizedDescription)
            }
        }
    }

    private func applyClean(_ line: String) {
        switch CLIMessage.decode(line) {
        case .clean(let result):
            cleanLog.append(CleanLogEntry(result: result))
        case .done(let done):
            if let reclaimed = done.reclaimedBytes {
                lastReclaimed = reclaimed
            }
        default:
            break
        }
    }

    func finishCleaning() {
        showProgress = false
        cleanPhase = .idle
        cleanLog.removeAll()
        if !previewOnly {
            selected.removeAll()
            scan()
        }
    }

    private func writeAuditLog(ids: [String]) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let record: [String: Any] = [
            "timestamp": stamp,
            "preview": previewOnly,
            "ids": ids,
            "reclaimedBytes": lastReclaimed,
            "results": cleanLog.map { ["label": $0.label, "status": $0.status, "bytes": $0.bytes] }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: record),
              let line = String(data: data, encoding: .utf8) else { return }

        let manager = FileManager.default
        let logs = manager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MacOS Storage Optimiser", isDirectory: true)
        try? manager.createDirectory(at: logs, withIntermediateDirectories: true)
        let file = logs.appendingPathComponent("clean.log")
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(Data((line + "\n").utf8))
            try? handle.close()
        } else {
            try? (line + "\n").write(to: file, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - External actions

    func revealInFinder(_ path: String) {
        guard !path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func copyPath(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
