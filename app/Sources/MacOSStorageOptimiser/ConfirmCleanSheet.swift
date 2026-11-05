import SwiftUI

struct ConfirmCleanSheet: View {
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss

    @State private var typedConfirmation = ""

    private var items: [ScanItem] {
        store.selectedItems.sorted { $0.bytes > $1.bytes }
    }

    private var requiresTyping: Bool {
        store.hasReviewSelection
    }

    private var canConfirm: Bool {
        !requiresTyping || typedConfirmation.trimmingCharacters(in: .whitespaces).lowercased() == "delete"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: store.previewOnly ? "eye.circle.fill" : "trash.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(store.previewOnly ? Color.accentColor : .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.previewOnly ? "Preview cleanup" : "Clean \(items.count) item\(items.count == 1 ? "" : "s")?")
                        .font(.title3.weight(.semibold))
                    Text(store.previewOnly
                         ? "Estimating \(Format.bytes(store.selectedBytes)). Nothing will be deleted."
                         : "This frees \(Format.bytes(store.selectedBytes)). The action cannot be undone.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.safety == .review ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(item.safety == .review ? .orange : .green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.label).font(.callout)
                                Text(Format.shortPath(item.paths.first ?? ""))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text(Format.bytes(item.bytes))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                    }
                }
            }
            .frame(maxHeight: 210)
            .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

            if requiresTyping {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Review-tier items selected", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                    Text("These can remove app data (trash, VM disks, containers). Type delete to confirm.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("delete", text: $typedConfirmation)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            Toggle("Preview only (nothing is deleted)", isOn: $store.previewOnly)
                .toggleStyle(.checkbox)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    let preview = store.previewOnly
                    dismiss()
                    store.runClean()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        guard preview == store.previewOnly else { return }
                        store.showProgress = true
                    }
                } label: {
                    Text(store.previewOnly ? "Run Preview" : "Clean \(Format.bytes(store.selectedBytes))")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(store.previewOnly ? .accentColor : .red)
                .disabled(!canConfirm)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
