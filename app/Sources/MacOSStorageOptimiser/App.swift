import SwiftUI

@main
struct MacOSStorageOptimiserApp: App {
    @StateObject private var store = ScanStore()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(store)
        }
        .defaultSize(width: 1060, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Scan") {
                Button("Rescan") { store.scan() }
                    .keyboardShortcut("r")
                Divider()
                Button("Select Safe Items") { store.selectAllSafe() }
                Button("Select Tier 1") { store.selectRecommended() }
                Button("Clear Selection") { store.clearSelection() }
                Divider()
                Toggle("Preview Only", isOn: $store.previewOnly)
            }
        }
    }
}
