import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        VStack(spacing: 0) {
            capacityHeader
            Divider()
            if store.deniedCount > 0 {
                deniedBanner
            }
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    filterBar
                    Divider()
                    content
                }
                if store.inspectedRow != nil {
                    Divider()
                    DetailPane()
                        .frame(width: 300)
                        .transition(.move(edge: .trailing))
                }
            }
            Divider()
            bottomBar
        }
        .frame(minWidth: 900, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $store.showConfirm) {
            ConfirmCleanSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showProgress) {
            CleanProgressSheet()
                .environmentObject(store)
        }
        .task {
            if !store.didScanOnce && store.phase == .idle {
                store.scan()
            }
            SnapshotSupport.scheduleIfRequested(store: store)
        }
    }

    // MARK: - Header

    private var capacityHeader: some View {
        HStack(alignment: .center, spacing: 26) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Reclaimable")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Format.bytes(store.reclaimableBytes))
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(store.reclaimableItemCount == 1 ? "1 item" : "\(store.reclaimableItemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 56)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Text(Format.bytes(store.disk?.usedBytes ?? 0)).fontWeight(.medium)
                    Text("of \(Format.bytes(store.disk?.totalBytes ?? 0)) used")
                        .foregroundStyle(.secondary)
                    Text("· \(Format.bytes(store.disk?.freeBytes ?? 0)) free")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)

                CapacityBar(
                    usedPercent: Double(store.disk?.usedPercent ?? 0) / 100.0,
                    reclaimableBytes: store.reclaimableBytes,
                    totalBytes: store.disk?.totalBytes ?? 1
                )
                .frame(height: 9)

                if let lastScan = store.lastScan {
                    Text("Scanned \(lastScan.formatted(date: .omitted, time: .shortened)) · \(String(format: "%.1fs", store.scanDuration))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Reading disk capacity…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: 380)

            Spacer()

            if store.phase == .scanning {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text("Scanning…").font(.callout).foregroundStyle(.secondary)
                }
            }

            Button {
                store.scan()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(store.phase == .scanning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }

    private var deniedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(store.deniedCount) folder\(store.deniedCount == 1 ? "" : "s") need Full Disk Access")
                    .font(.callout.weight(.medium))
                Text("These sizes read as unknown instead of clean. Grant access to measure and clean them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") { store.openFullDiskAccessSettings() }
                .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("Layout", selection: $store.layout) {
                ForEach(Layout.allCases) { layout in
                    Text(layout.title).tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 196)

            Picker("Filter", selection: $store.filter) {
                ForEach(ItemFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .labelsHidden()
            .frame(width: 126)

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search", text: $store.search)
                    .textFieldStyle(.plain)
                    .frame(width: 140)
                if !store.search.isEmpty {
                    Button {
                        store.search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))

            Picker("Sort", selection: $store.sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text("Sort: \(order.title)").tag(order)
                }
            }
            .labelsHidden()
            .frame(width: 108)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if case .failed(let message) = store.phase, store.allRows.isEmpty {
            failureView(message)
        } else if store.allRows.isEmpty {
            if store.phase == .scanning {
                scanningView
            } else {
                emptyView
            }
        } else {
            listView
        }
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if store.layout == .grouped {
                    ForEach([1, 2, 3], id: \.self) { tier in
                        let rows = store.rows(forTier: tier)
                        if !rows.isEmpty {
                            sectionView(
                                title: tierTitle(tier),
                                detail: detailText(rows),
                                rows: rows
                            )
                        } else if tier == 1 {
                            allClearSection
                        }
                    }
                    if !store.insightRows.isEmpty {
                        sectionView(
                            title: "Insights · read-only",
                            detail: detailText(store.insightRows),
                            rows: store.insightRows
                        )
                    }
                } else {
                    sectionView(
                        title: "Largest first",
                        detail: detailText(store.displayRows),
                        rows: store.displayRows
                    )
                }
            }
            .padding(16)
        }
    }

    private var allClearSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: tierTitle(1), detail: "0 items · 0 B")
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
                Text("No stranded updater clones or App Store staging files.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
    }

    private func sectionView(title: String, detail: String, rows: [DisplayRow]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: title, detail: detail)
            VStack(spacing: 1) {
                ForEach(rows) { row in
                    ItemRowView(row: row)
                }
            }
        }
    }

    private func detailText(_ rows: [DisplayRow]) -> String {
        let bytes = rows.reduce(Int64(0)) { $0 + $1.bytes }
        let count = rows.count
        return "\(count) item\(count == 1 ? "" : "s") · \(Format.bytes(bytes))"
    }

    private func tierTitle(_ tier: Int) -> String {
        switch tier {
        case 1: return "Tier 1 · safe to clean"
        case 2: return "Tier 2 · developer caches"
        default: return "Tier 3 · review first"
        }
    }

    // MARK: - States

    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Auditing System Data…")
                .font(.headline)
            Text("Measuring caches and temp folders. Items appear as they are measured.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "internaldrive")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Nothing to reclaim")
                .font(.title3.weight(.semibold))
            Text("No major System Data culprits were found on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Run Audit") { store.scan() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38))
                .foregroundStyle(.orange)
            Text("Audit failed")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Button("Try Again") { store.scan() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Select safe items") { store.selectAllSafe() }
                .buttonStyle(.link)
                .disabled(store.phase == .scanning)

            if !store.selected.isEmpty {
                Button("Clear") { store.clearSelection() }
                    .buttonStyle(.link)
            }

            Spacer()

            if store.selected.isEmpty {
                Text("Select items to clean — nothing is deleted until you confirm.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(store.selectedItems.count) selected · \(Format.bytes(store.selectedBytes))")
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
            }

            Toggle("Preview only", isOn: $store.previewOnly)
                .toggleStyle(.checkbox)
                .help("Run the cleanup in dry-run mode; no files are modified.")

            Button {
                store.showConfirm = true
            } label: {
                Text(store.previewOnly
                     ? "Preview \(Format.bytes(store.selectedBytes))"
                     : "Clean \(Format.bytes(store.selectedBytes))")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(store.previewOnly ? .accentColor : .red)
            .disabled(store.selected.isEmpty || store.phase == .scanning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.bar)
    }
}
