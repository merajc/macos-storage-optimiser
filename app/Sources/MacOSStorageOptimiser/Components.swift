import SwiftUI

struct CapacityBar: View {
    let usedPercent: Double
    let reclaimableBytes: Int64
    let totalBytes: Int64

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let used = min(max(usedPercent, 0), 1)
            let reclaimable = totalBytes > 0
                ? min(Double(reclaimableBytes) / Double(totalBytes), used)
                : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: width)
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: max(0, width * used))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(3, width * reclaimable))
            }
        }
    }
}

struct SafetyBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }
}

struct SectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
    }
}

struct TierIcon: View {
    let row: DisplayRow

    var icon: String {
        if row.state == .denied { return "lock.fill" }
        if row.isInsight { return "info.circle.fill" }
        switch row.tier {
        case 1: return "checkmark.shield.fill"
        case 2: return "hammer.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        if row.state == .denied { return .red }
        if row.isInsight { return .secondary }
        switch row.tier {
        case 1: return .green
        case 2: return .blue
        default: return .orange
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 18)
    }
}

struct CleanStatusIcon: View {
    let entry: CleanLogEntry

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(color)
    }

    private var symbol: String {
        switch entry.status {
        case "cleaned": return "checkmark.circle.fill"
        case "would-clean": return "eye.circle.fill"
        case "missing": return "minus.circle"
        case "skipped": return "forward.circle"
        case "partial": return "exclamationmark.circle.fill"
        default: return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch entry.status {
        case "cleaned": return .green
        case "would-clean": return .accentColor
        case "missing", "skipped": return .secondary
        case "partial": return .orange
        default: return .red
        }
    }
}
