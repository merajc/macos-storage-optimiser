import Foundation

// MARK: - Wire format (mirrors `macos-system-data --json`)

enum Safety: String, Decodable, Hashable {
    case safe
    case review
    case info
}

enum ItemState: String, Decodable, Hashable {
    case present
    case missing
    case denied
}

struct ScanItem: Decodable, Identifiable, Hashable {
    let id: String
    let tier: Int
    let safety: Safety
    let label: String
    let note: String
    let state: ItemState
    let bytes: Int64
    let count: Int
    let cleanable: Bool
    let paths: [String]
}

struct Insight: Decodable, Identifiable, Hashable {
    let id: String
    let kind: String
    let label: String
    let bytes: Int64
    let path: String
    let count: Int?
    let catalogued: Bool?
    let sparseLimit: String?
}

struct DiskInfo: Decodable, Hashable {
    let totalBytes: Int64
    let usedBytes: Int64
    let freeBytes: Int64
    let usedPercent: Int
}

struct CleanResult: Decodable, Hashable {
    let id: String
    let label: String
    let status: String
    let bytes: Int64
    let message: String
}

struct DoneInfo: Decodable, Hashable {
    let reclaimableBytes: Int64?
    let reclaimableItems: Int?
    let reclaimedBytes: Int64?
    let status: String?
}

enum CLIMessage {
    case meta
    case disk(DiskInfo)
    case item(ScanItem)
    case insight(Insight)
    case clean(CleanResult)
    case done(DoneInfo)

    static func decode(_ line: String) -> CLIMessage? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else {
            return nil
        }
        let decoder = JSONDecoder()
        switch type {
        case "meta":
            return .meta
        case "disk":
            return (try? decoder.decode(DiskInfo.self, from: data)).map(CLIMessage.disk)
        case "item":
            return (try? decoder.decode(ScanItem.self, from: data)).map(CLIMessage.item)
        case "insight":
            return (try? decoder.decode(Insight.self, from: data)).map(CLIMessage.insight)
        case "clean":
            return (try? decoder.decode(CleanResult.self, from: data)).map(CLIMessage.clean)
        case "done":
            return (try? decoder.decode(DoneInfo.self, from: data)).map(CLIMessage.done)
        default:
            return nil
        }
    }
}

// MARK: - Presentation

struct DisplayRow: Identifiable, Hashable {
    enum Kind: Hashable { case item, insight }

    let id: String
    let kind: Kind
    let title: String
    let note: String
    let path: String
    let bytes: Int64
    let tier: Int
    let safety: Safety
    let cleanable: Bool
    let state: ItemState

    var isInsight: Bool { kind == .insight }

    init(item: ScanItem) {
        id = item.id
        kind = .item
        title = item.label
        note = item.note
        path = item.paths.first ?? ""
        bytes = item.bytes
        tier = item.tier
        safety = item.safety
        cleanable = item.cleanable && item.state == .present
        state = item.state
    }

    init(insight: Insight) {
        id = insight.id
        kind = .insight
        title = insight.label
        note = ""
        path = insight.path
        bytes = insight.bytes
        tier = 0
        safety = .info
        cleanable = false
        state = .present
    }
}

enum Layout: String, CaseIterable, Identifiable {
    case grouped
    case largest

    var id: String { rawValue }
    var title: String {
        switch self {
        case .grouped: return "By category"
        case .largest: return "Largest first"
        }
    }
}

enum ItemFilter: String, CaseIterable, Identifiable {
    case all
    case cleanable
    case safe

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All items"
        case .cleanable: return "Cleanable"
        case .safe: return "Safe only"
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case size
    case name

    var id: String { rawValue }
    var title: String {
        switch self {
        case .size: return "Size"
        case .name: return "Name"
        }
    }
}

// MARK: - Formatting

enum Format {
    static func bytes(_ value: Int64) -> String {
        guard value > 0 else { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: value)
    }

    static func shortPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }
}
