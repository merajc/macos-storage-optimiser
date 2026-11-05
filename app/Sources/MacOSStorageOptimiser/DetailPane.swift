import SwiftUI

struct DetailPane: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        Group {
            if let row = store.inspectedRow {
                ScrollView {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(row.title)
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 6) {
                                    SafetyBadge(text: row.isInsight ? "INFO" : row.safety.rawValue.uppercased(),
                                                color: badgeColor(row))
                                    if row.state == .denied {
                                        SafetyBadge(text: "NO ACCESS", color: .red)
                                    }
                                }
                            }
                            Spacer()
                            Button {
                                store.inspectedRowID = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        Text(Format.bytes(row.bytes))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()

                        if !row.note.isEmpty {
                            Text(row.note)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if row.state == .denied {
                            Text("This folder is protected by macOS. Grant Full Disk Access to the app to measure and clean it.")
                                .font(.callout)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Open Full Disk Access Settings") {
                                store.openFullDiskAccessSettings()
                            }
                            .controlSize(.small)
                        }

                        Divider()

                        detailRow("Tier", tierLabel(row.tier))
                        detailRow("Safety", row.isInsight ? "Read-only" : row.safety.rawValue.capitalized)
                        detailRow("State", stateLabel(row.state))

                        Divider()

                        Text("PATHS")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.7)
                            .foregroundStyle(.secondary)

                        ForEach(paths(for: row), id: \.self) { path in
                            Text(Format.shortPath(path))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 8) {
                            Button("Reveal") { store.revealInFinder(row.path) }
                            Button("Copy path") { store.copyPath(row.path) }
                        }
                        .controlSize(.small)
                        .disabled(row.path.isEmpty)

                        Spacer(minLength: 4)
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.secondary.opacity(0.03))
    }

    private func paths(for row: DisplayRow) -> [String] {
        if let item = store.items.first(where: { $0.id == row.id }), !item.paths.isEmpty {
            return item.paths
        }
        return [row.path]
    }

    private func badgeColor(_ row: DisplayRow) -> Color {
        if row.isInsight { return .secondary }
        switch row.safety {
        case .safe: return .green
        case .review: return .orange
        case .info: return .secondary
        }
    }

    private func tierLabel(_ tier: Int) -> String {
        switch tier {
        case 1: return "Tier 1 · Safe"
        case 2: return "Tier 2 · Developer caches"
        case 3: return "Tier 3 · Review"
        default: return "Insight"
        }
    }

    private func stateLabel(_ state: ItemState) -> String {
        switch state {
        case .present: return "Present"
        case .missing: return "Not found"
        case .denied: return "Permission denied"
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
        }
    }
}
