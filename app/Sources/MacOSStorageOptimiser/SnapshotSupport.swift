import AppKit
import SwiftUI

/// Development/CI helper: set MSD_SNAPSHOT_PATH to render the window to a PNG
/// after the first scan completes, then quit. Uses the window's own view
/// hierarchy, so it works without Screen Recording permission.
enum SnapshotSupport {
    static func scheduleIfRequested(store: ScanStore) {
        guard let path = ProcessInfo.processInfo.environment["MSD_SNAPSHOT_PATH"], !path.isEmpty else {
            return
        }
        Task { @MainActor in
            for _ in 0..<120 {
                if store.phase == .ready { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            let environment = ProcessInfo.processInfo.environment
            if environment["MSD_SNAPSHOT_LAYOUT"] == "largest" {
                store.layout = .largest
                store.selectAllSafe()
            }
            if environment["MSD_SNAPSHOT_AUTOCLEAN"] == "dry" {
                store.previewOnly = true
                store.selected = Set(
                    store.items
                        .filter { $0.cleanable && $0.state == .present && $0.bytes > 0 }
                        .sorted { $0.bytes > $1.bytes }
                        .prefix(2)
                        .map(\.id)
                )
                store.runClean()
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                exit(0)
            }
            if environment["MSD_SNAPSHOT_SHEET"] == "confirm" {
                let ids = store.items
                    .filter { $0.cleanable && $0.state == .present }
                    .sorted { $0.bytes > $1.bytes }
                    .prefix(4)
                    .map(\.id)
                store.selected = Set(ids)
                try? await Task.sleep(nanoseconds: 300_000_000)
                store.showConfirm = true
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                capture(to: path, window: NSApp.keyWindow)
                NSApp.terminate(nil)
                return
            }
            try? await Task.sleep(nanoseconds: 800_000_000)
            capture(to: path, window: nil)
            NSApp.terminate(nil)
        }
    }

    @MainActor
    private static func capture(to path: String, window preferred: NSWindow?) {
        let target = preferred ?? NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil })
        guard let window = target,
              let view = window.contentView else {
            FileHandle.standardError.write(Data("No visible window to snapshot\n".utf8))
            return
        }
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            FileHandle.standardError.write(Data("Could not allocate snapshot bitmap\n".utf8))
            return
        }
        view.cacheDisplay(in: bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("Could not encode snapshot\n".utf8))
            return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write(Data("Snapshot written to \(path)\n".utf8))
    }
}
