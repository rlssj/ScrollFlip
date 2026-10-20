import Foundation
import ServiceManagement

/* Opening at login. The choice is also kept in preferences, so that if the app moves (say from a download
 folder to Applications) it can register its new location the next time it starts. */
final class LoginItemController {
    var startAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            UserDefaults.standard.set(newValue, forKey: Prefs.startAtLogin)
            apply(newValue)
        }
    }

    // called at launch: registers again if the user wants it but macOS doesn't have this copy of the app
    func restore() {
        if UserDefaults.standard.bool(forKey: Prefs.startAtLogin) && SMAppService.mainApp.status != .enabled {
            apply(true)
        }
    }

    private func apply(_ state: Bool) {
        do {
            if state { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Error setting startAtLogin to \(state): \(error)")
        }
    }
}
