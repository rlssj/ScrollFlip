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

extension Notification.Name {
    // posted when the enabled state, the permission or the menu bar setting changes
    static let scrollFlipStateChanged = Notification.Name("ScrollFlipStateChanged")
}
