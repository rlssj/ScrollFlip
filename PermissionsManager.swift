import AppKit
import ApplicationServices

final class PermissionsManager {
    private(set) var accessibilityEnabled = AXIsProcessTrusted()
    private var timer: Timer?

    init() {
        refresh()
    }

    /* The system doesn't tell us when the permission changes, so we poll, but only while it matters:
     until the permission is granted, and for a while after our settings are opened (in case it's taken away). */
    func refresh(for seconds: TimeInterval = 0) {
        timer?.invalidate()
        timer = nil
        if accessibilityEnabled && seconds == 0 { return }
        let started = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            self.checkState()
            if self.accessibilityEnabled && Date().timeIntervalSince(started) >= seconds {
                timer.invalidate()
            }
        }
        timer?.tolerance = 0.5
    }

    private func checkState() {
        let state = AXIsProcessTrusted()
        if state != accessibilityEnabled {
            accessibilityEnabled = state
            NotificationCenter.default.post(name: .scrollFlipStateChanged, object: nil)
        }
    }

    // shows the system pop-up that asks for Accessibility permission
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func openAccessibilityPrefs() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        refresh()
    }
}
