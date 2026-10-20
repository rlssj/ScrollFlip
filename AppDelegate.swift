import AppKit

// passed when we restart ourselves, so the new copy stays in the background
private let backgroundArgument = "--background"

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

        // Opened by the user, show the settings; not at login nor when restarting ourselves in the background.
        // (macOS doesn't always make a freshly opened accessory app active, so we can't wait for that.)
        if !(launchedInBackground || launchedAtLogin) {
            showSettings(nil)
            askForPermissionIfMissing()
        } else if !permissionsManager.accessibilityEnabled {
            // right after an update macOS can take a moment to recognise the permission, so look again first
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, !AXIsProcessTrusted() else { return }
                self.showSettings(nil)
                self.askForPermissionIfMissing()
            }
        }
    }

    // without permission, also show the system pop-up to grant it
    private func askForPermissionIfMissing() {
        if !AXIsProcessTrusted() {
            permissionsManager.requestAccessibilityPermission()
        }
    }

    private var launchedInBackground: Bool {
        CommandLine.arguments.contains(backgroundArgument)
    }

    private var launchedAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == AEEventID(kAEOpenApplication)
            && event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }

    // opening the app again from Finder or Spotlight shows the settings, which matters as there's no menu bar item
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(nil)
        return false
    }

    /* The settings window leaves memory behind once closed (SwiftUI keeps caches around), so instead of
     carrying on, a fresh copy starts in the background and this one quits: back to the bare minimum. */
    private func relaunchInBackground() {
        quitter.active = false
        reverser.active = false
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        configuration.addsToRecentItems = false
        configuration.arguments = [backgroundArgument]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                if error == nil {
                    NSApp.terminate(nil)
                } else {
                    // couldn't start again: just carry on in the background
                    self?.settingsWindowController = nil
                    NSApp.setActivationPolicy(.accessory)
                    self?.stateChanged()
                }
            }
        }
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
        quitter.exceptions = Set(model.quitExceptions)
        quitter.active = model.quitEnabled && permitted
        // with nothing to change, there's no need to see any scrolling
        let changesScrolling = model.trackpadDirection != .unchanged || model.mouseDirection != .unchanged
        reverser.active = model.scrollEnabled && changesScrolling && permitted
        statusController.visible = model.showInMenuBar
        statusController.enabled = (model.quitEnabled || model.scrollEnabled) && permitted
        debug("permitted \(permitted), quit tap \(quitter.active), scroll tap \(reverser.active)")
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
            settingsWindowController?.onClose = { [weak self] in
                DispatchQueue.main.async { self?.relaunchInBackground() }
            }
        }
        settingsWindowController?.showWindow(self)
    }
}
