import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appName = "ScrollFlip"

    private var permissionsManager: PermissionsManager!
    private var model: AppModel!
    private let quitter = CloseQuitter()
    private let reverser = ScrollReverser()
    private var statusController: StatusItemController!
    private var scrollItem: NSMenuItem!
    private var quitItem: NSMenuItem!
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()
        terminateOthers()
        permissionsManager = PermissionsManager()
        model = AppModel(permissions: permissionsManager)

        statusController = StatusItemController(menu: makeStatusMenu())

        // Even though the app has no visible main menu, we set a minimal menu for keyboard shortcut support.
        NSApp.mainMenu = makeMainMenu()

        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: .scrollFlipStateChanged, object: nil)
        stateChanged()

        // without permission, open the settings and show the system pop-up to grant it
        if !permissionsManager.accessibilityEnabled {
            showSettings(nil)
            permissionsManager.requestAccessibilityPermission()
        }
    }

    /* Opening the app from Finder or Spotlight shows the settings, which matters as there's no menu bar item.
     An accessory app isn't always sent the reopen event, but it is made active; at login it isn't. */
    func applicationDidBecomeActive(_ notification: Notification) {
        if !NSApp.windows.contains(where: \.isVisible) {
            showSettings(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(nil)
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
        reverser.trackpadDirection = model.trackpadDirection
        reverser.mouseDirection = model.mouseDirection
        reverser.trackpadHorizontal = model.trackpadHorizontal
        reverser.mouseHorizontal = model.mouseHorizontal
        quitter.active = model.quitEnabled && permitted
        reverser.active = model.scrollEnabled && permitted
        statusController.visible = model.showInMenuBar
        statusController.enabled = (model.quitEnabled || model.scrollEnabled) && permitted
        scrollItem.state = model.scrollEnabled ? .on : .off
        quitItem.state = model.quitEnabled ? .on : .off
    }

    // MARK: Menus

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        scrollItem = menu.addItem(withTitle: "Cambiar el desplazamiento", action: #selector(toggleScroll(_:)), keyEquivalent: "")
        scrollItem.target = self
        quitItem = menu.addItem(withTitle: "Salir con el botón rojo", action: #selector(toggleQuit(_:)), keyEquivalent: "")
        quitItem.target = self
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
        menu.addItem(withTitle: "Ajustes…", action: #selector(showSettings(_:)), keyEquivalent: ",").target = self
        if separated {
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Salir de \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp
    }

    @objc private func toggleScroll(_ sender: Any?) {
        model.scrollEnabled.toggle()
    }

    @objc private func toggleQuit(_ sender: Any?) {
        model.quitEnabled.toggle()
    }

    // MARK: Settings window

    @objc func showSettings(_ sender: Any?) {
        // in the Dock while the settings are open, and back in the background when they close
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        permissionsManager.refresh(for: 60)
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(model: model)
            // the window is rebuilt each time it opens, so closed it takes no memory
            settingsWindowController?.onClose = { [weak self] in
                DispatchQueue.main.async {
                    self?.settingsWindowController = nil
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
        settingsWindowController?.showWindow(self)
    }
}
