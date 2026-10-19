import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appName = "ScrollFlip"
    var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
    }

    private(set) var permissionsManager: PermissionsManager!
    private(set) var loginItemController = LoginItemController()
    private let quitter = CloseQuitter()
    private let reverser = ScrollReverser()
    private var statusController: StatusItemController!
    private var enableItem: NSMenuItem!
    private var scrollItem: NSMenuItem!
    private var welcomeWindowController: WelcomeWindowController?
    private var prefsWindowController: PrefsWindowController?

    // the two switches only take effect while we have Accessibility permission
    var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: Prefs.enabled) }
        set { setSwitch(Prefs.enabled, newValue) }
    }

    var scrollEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Prefs.scrollEnabled) }
        set { setSwitch(Prefs.scrollEnabled, newValue) }
    }

    private func setSwitch(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: .scrollFlipStateChanged, object: nil)
        if value && !permissionsManager.accessibilityEnabled {
            showPermissionsUI()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()
        terminateOthers()
        permissionsManager = PermissionsManager()

        statusController = StatusItemController(menu: makeStatusMenu())

        // Even though the app has no visible main menu, we set a minimal menu for keyboard shortcut support.
        NSApp.mainMenu = makeMainMenu()

        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: .scrollFlipStateChanged, object: nil)
        stateChanged()

        // Show the welcome window the first time
        if !UserDefaults.standard.bool(forKey: Prefs.hasRunBefore) {
            UserDefaults.standard.set(true, forKey: Prefs.hasRunBefore)
            welcomeWindowController = WelcomeWindowController(menuBar: !UserDefaults.standard.bool(forKey: Prefs.hideIcon))
            welcomeWindowController?.showWindow(self)
        }

        // without permission, open the settings and show the system pop-up to grant it
        if !permissionsManager.accessibilityEnabled {
            showPermissionsUI()
            permissionsManager.requestAccessibilityPermission()
        }
    }

    /* Opening the app from Finder or Spotlight shows the settings, which matters as there's no menu bar item.
     An accessory app isn't always sent the reopen event, but it is made active; at login it isn't. */
    func applicationDidBecomeActive(_ notification: Notification) {
        if !NSApp.windows.contains(where: \.isVisible) {
            orderFrontPreferencesPanel(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        orderFrontPreferencesPanel(nil)
        return false
    }

    // There can be only one ScrollFlip
    private func terminateOthers() {
        for other in NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "") where other != .current {
            other.terminate()
        }
    }

    @objc private func stateChanged() {
        let permitted = permissionsManager.accessibilityEnabled
        let defaults = UserDefaults.standard
        reverser.trackpadDirection = ScrollDirection(rawValue: defaults.integer(forKey: Prefs.trackpadDirection)) ?? .unchanged
        reverser.mouseDirection = ScrollDirection(rawValue: defaults.integer(forKey: Prefs.mouseDirection)) ?? .unchanged
        reverser.trackpadHorizontal = defaults.bool(forKey: Prefs.trackpadHorizontal)
        reverser.mouseHorizontal = defaults.bool(forKey: Prefs.mouseHorizontal)
        quitter.active = enabled && permitted
        reverser.active = scrollEnabled && permitted
        statusController.visible = !UserDefaults.standard.bool(forKey: Prefs.hideIcon)
        statusController.enabled = (enabled || scrollEnabled) && permitted
        enableItem.state = enabled ? .on : .off
        scrollItem.state = scrollEnabled ? .on : .off
    }

    // MARK: Menus

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        scrollItem = menu.addItem(withTitle: "Invertir desplazamiento", action: #selector(toggleScrollEnabled(_:)), keyEquivalent: "")
        scrollItem.target = self
        enableItem = menu.addItem(withTitle: "Cerrar apps con el botón rojo", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        enableItem.target = self
        menu.addItem(.separator())
        addSettingsAndQuitItems(to: menu, separated: false)
        return menu
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        func addSubmenu(_ title: String) -> NSMenu {
            let submenu = NSMenu(title: title)
            mainMenu.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = submenu
            return submenu
        }
        // The app menu must be the first item. Its Settings… and Quit items give ⌘, and ⌘Q while one of our windows is focused.
        addSettingsAndQuitItems(to: addSubmenu(appName), separated: true)
        addSubmenu("Archivo").addItem(withTitle: "Cerrar", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        addSubmenu("Ventana").addItem(withTitle: "Minimizar", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        return mainMenu
    }

    // Used by both the status menu and the app menu.
    private func addSettingsAndQuitItems(to menu: NSMenu, separated: Bool) {
        menu.addItem(withTitle: "Ajustes…", action: #selector(orderFrontPreferencesPanel(_:)), keyEquivalent: ",").target = self
        if separated {
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Salir de \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp
    }

    @objc private func toggleEnabled(_ sender: Any?) {
        enabled.toggle()
    }

    @objc private func toggleScrollEnabled(_ sender: Any?) {
        scrollEnabled.toggle()
    }

    // MARK: Showing windows

    private func showPrefs(permissionsPane: Bool) {
        NSApp.activate()
        permissionsManager.refresh(for: 60)
        if prefsWindowController == nil {
            prefsWindowController = PrefsWindowController(appDelegate: self)
            // the settings window is rebuilt each time it opens, so closed it takes no memory
            prefsWindowController?.onClose = { [weak self] in
                DispatchQueue.main.async { self?.prefsWindowController = nil }
            }
        }
        if permissionsPane {
            prefsWindowController?.showPermissionsPane()
        }
        prefsWindowController?.showWindow(self)
    }

    @objc func orderFrontPreferencesPanel(_ sender: Any?) {
        showPrefs(permissionsPane: false)
    }

    private func showPermissionsUI() {
        showPrefs(permissionsPane: true)
    }
}
