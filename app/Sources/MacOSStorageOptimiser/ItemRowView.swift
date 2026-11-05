import SwiftUI

struct ItemRowView: View {
    @EnvironmentObject private var store: ScanStore
    let row: DisplayRow

    @State private var hovering = false

    private var isSelected: Bool { store.selected.contains(row.id) }
    private var isInspected: Bool { store.inspectedRowID == row.id }

    var body: some View {
        HStack(spacing: 11) {
            if row.cleanable {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { store.setSelected(row.id, $0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            } else {
                Color.clear.frame(width: 14, height: 14)
            }

            TierIcon(row: row)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(row.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    badge
                }
                Text(Format.shortPath(row.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Text(Format.bytes(row.bytes))
                .font(.system(.callout, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(row.cleanable ? .primary : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(background, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { store.inspectedRowID = row.id }
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(Format.bytes(row.bytes))")
    }

    @ViewBuilder
    private var badge: some View {
        if row.state == .denied {
            SafetyBadge(text: "NO ACCESS", color: .red)
        } else if row.isInsight {
            SafetyBadge(text: "INFO", color: .secondary)
        } else if row.safety == .review {
            SafetyBadge(text: "REVIEW", color: .orange)
        } else if row.tier == 1 {
            SafetyBadge(text: "SAFE", color: .green)
        }
    }

    private var background: Color {
        if isInspected { return Color.accentColor.opacity(0.14) }
        if hovering { return Color.secondary.opacity(0.08) }
        return .clear
    }
}
