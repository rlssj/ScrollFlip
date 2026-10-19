import Foundation
import ServiceManagement

final class LoginItemController {
    var startAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Error setting startAtLogin to \(newValue): \(error)")
            }
        }
    }
}
