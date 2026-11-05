import SwiftUI

struct CleanProgressSheet: View {
    @EnvironmentObject private var store: ScanStore

    private var isRunning: Bool { store.cleanPhase == .running }

    private var isFailed: Bool {
        if case .failed = store.cleanPhase { return true }
        return false
    }

    private var title: String {
        switch store.cleanPhase {
        case .failed: return "Cleanup failed"
        case .finished: return store.previewOnly ? "Preview complete" : "Cleanup complete"
        default: return store.previewOnly ? "Previewing cleanup…" : "Cleaning…"
        }
    }

    private var symbol: String {
        switch store.cleanPhase {
        case .failed: return "exclamationmark.triangle.fill"
        case .finished: return "checkmark.circle.fill"
        default: return "trash.circle.fill"
        }
    }

    private var summary: String {
        switch store.cleanPhase {
        case .failed(let message):
            return message
        case .finished:
            if store.previewOnly {
                return "\(Format.bytes(store.lastReclaimed)) could be reclaimed."
            }
            return "\(Format.bytes(store.lastReclaimed)) reclaimed."
        default:
            return "Working through the selected items…"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(isFailed ? Color.red : .accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title3.weight(.semibold))
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(isFailed ? Color.red : .secondary)
                }
                Spacer()
                if isRunning {
                    ProgressView().controlSize(.small)
                }
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.cleanLog) { entry in
                            HStack(spacing: 8) {
                                CleanStatusIcon(entry: entry)
                                    .font(.caption)
                                Text(entry.label).font(.callout)
                                Spacer(minLength: 8)
                                if entry.bytes > 0 {
                                    Text(Format.bytes(entry.bytes))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Text(statusText(entry.status))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 62, alignment: .trailing)
                            }
                            .id(entry.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: store.cleanLog.count) { _, _ in
                    guard let last = store.cleanLog.last else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .frame(maxHeight: 230)

            Spacer(minLength: 0)

            Divider()

            HStack {
                if store.previewOnly {
                    Label("Preview only — no files were deleted", systemImage: "eye")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { store.finishCleaning() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 540, height: 430)
        .interactiveDismissDisabled(isRunning)
    }

    private func statusText(_ status: String) -> String {
        switch status {
        case "cleaned": return "cleaned"
        case "would-clean": return "would clean"
        case "missing": return "not found"
        case "skipped": return "skipped"
        case "partial": return "partial"
        default: return "failed"
        }
    }
}
