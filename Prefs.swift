import Foundation

enum Prefs {
    static let enabled = "Enabled" // closing apps with the close button
    static let scrollEnabled = "ScrollEnabled"
    static let trackpadDirection = "TrackpadDirection"
    static let mouseDirection = "MouseDirection"
    static let trackpadHorizontal = "TrackpadHorizontal"
    static let mouseHorizontal = "MouseHorizontal"
    static let hideIcon = "HideIcon"
    static let quitExceptions = "QuitExceptions" // bundle identifiers
    static let startAtLogin = "StartAtLogin"

    static func register() {
        // like Scroll Reverser: natural for trackpads, classic for mice
        UserDefaults.standard.register(defaults: [
            enabled: true,
            hideIcon: true, // nothing in the menu bar; opening ScrollFlip again shows the settings
            scrollEnabled: true,
            trackpadDirection: ScrollDirection.natural.rawValue,
            mouseDirection: ScrollDirection.classic.rawValue,
            // reversing continuous horizontal scrolling breaks swipe gestures (e.g. back/forward in browsers)
            trackpadHorizontal: false,
            mouseHorizontal: true,
        ])
    }
}

// Messages for the GitHub test only: printed when SCROLLFLIP_DEBUG is set, never saved anywhere.
let debugging = ProcessInfo.processInfo.environment["SCROLLFLIP_DEBUG"] != nil
func debug(_ message: @autoclosure () -> String) {
    if debugging { FileHandle.standardError.write("[ScrollFlip] \(message())\n".data(using: .utf8)!) }
}

extension Notification.Name {
    // posted when the enabled state, the permission or the menu bar setting changes
    static let scrollFlipStateChanged = Notification.Name("ScrollFlipStateChanged")
}
