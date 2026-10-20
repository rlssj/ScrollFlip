import AppKit
import Combine

/* The settings as the settings window sees them. Each change is saved to preferences and announced with
 .scrollFlipStateChanged, which the app delegate applies to the event taps. */
final class AppModel: ObservableObject {
    let permissions: PermissionsManager
    let loginItem = LoginItemController()
    private let defaults = UserDefaults.standard

    init(permissions: PermissionsManager) {
        self.permissions = permissions
        NotificationCenter.default.addObserver(forName: .scrollFlipStateChanged, object: nil, queue: .main) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var permitted: Bool { permissions.accessibilityEnabled }

    var scrollEnabled: Bool {
        get { defaults.bool(forKey: Prefs.scrollEnabled) }
        set { save(newValue, Prefs.scrollEnabled) }
    }
    var trackpadDirection: ScrollDirection {
        get { ScrollDirection(rawValue: defaults.integer(forKey: Prefs.trackpadDirection)) ?? .unchanged }
        set { save(newValue.rawValue, Prefs.trackpadDirection) }
    }
    var mouseDirection: ScrollDirection {
        get { ScrollDirection(rawValue: defaults.integer(forKey: Prefs.mouseDirection)) ?? .unchanged }
        set { save(newValue.rawValue, Prefs.mouseDirection) }
    }
    var trackpadHorizontal: Bool {
        get { defaults.bool(forKey: Prefs.trackpadHorizontal) }
        set { save(newValue, Prefs.trackpadHorizontal) }
    }
    var mouseHorizontal: Bool {
        get { defaults.bool(forKey: Prefs.mouseHorizontal) }
        set { save(newValue, Prefs.mouseHorizontal) }
    }
    var quitEnabled: Bool {
        get { defaults.bool(forKey: Prefs.enabled) }
        set { save(newValue, Prefs.enabled) }
    }
    var showInMenuBar: Bool {
        get { !defaults.bool(forKey: Prefs.hideIcon) }
        set { save(!newValue, Prefs.hideIcon) }
    }
    var startAtLogin: Bool {
        get { loginItem.startAtLogin }
        set { loginItem.startAtLogin = newValue; objectWillChange.send() }
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .scrollFlipStateChanged, object: nil)
    }

    func requestPermission() { permissions.requestAccessibilityPermission() }
    func openAccessibilitySettings() { permissions.openAccessibilityPrefs() }
}
