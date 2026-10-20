import AppKit
import SwiftUI

/* Renders the settings window to PNG files, light and dark, with and without the permission,
 so the design can be checked from the GitHub build without running the app. */
enum Snapshot {
    static func save(to directory: String) {
        NSApplication.shared.setActivationPolicy(.prohibited)
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        Prefs.register()
        // a sample exception, to see the list
        UserDefaults.standard.set(["com.apple.TextEdit"], forKey: Prefs.quitExceptions)
        let model = AppModel(permissions: PermissionsManager())
        for (name, appearance) in [("claro", NSAppearance.Name.aqua), ("oscuro", .darkAqua)] {
            let view = NSHostingView(rootView: SettingsView(model: model))
            view.frame = NSRect(x: 0, y: 0, width: 480, height: 730)
            let window = NSWindow(contentRect: view.frame, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearance)
            window.titlebarAppearsTransparent = true
            window.contentView = view
            window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(1))
            view.layoutSubtreeIfNeeded()
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            let path = "\(directory)/ajustes-\(name).png"
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            print("saved \(path)")
            window.close()
        }
    }
}
