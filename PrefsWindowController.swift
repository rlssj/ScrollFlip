import AppKit

private let panelScrolling = NSToolbarItem.Identifier("scrolling")
private let panelQuit = NSToolbarItem.Identifier("quit")
private let panelApp = NSToolbarItem.Identifier("app")

// MARK: Control helpers

private func checkbox(_ title: String, target: AnyObject, action: Selector) -> NSButton {
    let button = NSButton(checkboxWithTitle: title, target: target, action: action)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
}

private func label(_ field: NSTextField, _ font: NSFont, _ color: NSColor) -> NSTextField {
    field.translatesAutoresizingMaskIntoConstraints = false
    field.font = font
    field.textColor = color
    return field
}

private var smallFont: NSFont { .systemFont(ofSize: NSFont.smallSystemFontSize) }

private func box(_ title: String, content: NSView) -> NSBox {
    let box = NSBox()
    box.translatesAutoresizingMaskIntoConstraints = false
    box.title = title
    box.contentViewMargins = .zero
    content.translatesAutoresizingMaskIntoConstraints = false
    box.contentView!.addSubview(content)
    NSLayoutConstraint.activate([
        content.topAnchor.constraint(equalTo: box.contentView!.topAnchor, constant: 14),
        content.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor, constant: 14),
        box.contentView!.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: 14),
        box.contentView!.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: 14),
    ])
    return box
}

private func stack(_ orientation: NSUserInterfaceLayoutOrientation, _ alignment: NSLayoutConstraint.Attribute, _ spacing: CGFloat, _ views: [NSView]) -> NSStackView {
    let stack = NSStackView(views: views)
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = orientation
    stack.distribution = .fill
    stack.alignment = alignment
    stack.spacing = spacing
    stack.detachesHiddenViews = true
    return stack
}

// a pane's content with the standard 20pt margins
private func pane(_ content: NSView) -> NSView {
    let view = NSView()
    view.addSubview(content)
    let bottom = view.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: 20)
    bottom.priority = .defaultHigh
    NSLayoutConstraint.activate([
        content.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
        content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        view.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: 20),
        bottom,
    ])
    return view
}

final class PrefsWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSTabViewDelegate {
    var onClose: (() -> Void)?
    private unowned let appDelegate: AppDelegate
    private let tabView = NSTabView()
    private var panels: [NSToolbarItem.Identifier: (title: String, image: NSImage?, view: NSView)] = [:]
    private let toolbarDefinition = [panelScrolling, panelQuit, panelApp]
    private var width: CGFloat = 400 // minimum width to avoid toolbar collapse

    private var scrollCheckbox: NSButton!
    private var directionsBox: NSView!
    private var trackpadPopUp: NSPopUpButton!
    private var mousePopUp: NSPopUpButton!
    private var trackpadHorizontalCheckbox: NSButton!
    private var mouseHorizontalCheckbox: NSButton!
    private var enableCheckbox: NSButton!
    private var howItWorksBox: NSView!
    private var permissionsBoxes: [NSView] = [] // one per pane, shown only while the permission is missing
    private var startAtLoginCheckbox: NSButton!
    private var showInMenuBarCheckbox: NSButton!

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.title = appDelegate.appName
        window.toolbarStyle = .preference
        super.init(window: window)
        window.delegate = self

        panels[panelScrolling] = ("Desplazamiento", NSImage(named: NSImage.preferencesGeneralName), makeScrollingSettings())
        panels[panelQuit] = ("Cerrar apps", NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil), makeQuitSettings())
        panels[panelApp] = ("App", NSImage(named: NSImage.applicationIconName), makeAppSettings())
        refresh()
        setUpPanels()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .scrollFlipStateChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setUpPanels() {
        tabView.frame = window!.contentView!.frame
        tabView.autoresizingMask = [.width, .height]
        tabView.tabViewType = .noTabsNoBorder
        tabView.delegate = self
        window!.contentView!.addSubview(tabView)

        for identifier in toolbarDefinition {
            let panel = panels[identifier]!
            let item = NSTabViewItem(identifier: identifier)
            item.label = panel.title
            item.view = panel.view
            // set window width to largest view fitting width
            width = max(width, panel.view.fittingSize.width)
            tabView.addTabViewItem(item)
        }

        let toolbar = NSToolbar(identifier: "PrefsToolbar")
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel
        toolbar.delegate = self
        window!.toolbar = toolbar
        for (index, identifier) in toolbarDefinition.enumerated() {
            toolbar.insertItem(withItemIdentifier: identifier, at: index)
        }

        // start on the last used pane
        var starting = toolbarDefinition[0]
        if let saved = UserDefaults.standard.string(forKey: Prefs.lastUsedPanel), toolbarDefinition.contains(.init(saved)) {
            starting = .init(saved)
        }
        setPane(starting)
    }

    override func showWindow(_ sender: Any?) {
        window?.level = .normal
        NSApp.activate()
        if window?.isVisible == true {
            callAttention()
        } else {
            window?.center()
        }
        super.showWindow(sender)
        window?.orderFrontRegardless()
        window?.makeFirstResponder(nil)
    }

    // animate window frame to draw user's attention
    private func callAttention() {
        guard let window else { return }
        let frame = window.frame
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            window.animator().setFrame(frame.offsetBy(dx: 0, dy: 0.04 * frame.height), display: false)
        }, completionHandler: {
            window.animator().setFrame(frame, display: false)
        })
    }

    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        onClose?()
    }

    func showPermissionsPane() {
        if !appDelegate.permissionsManager.accessibilityEnabled, tabView.selectedTabViewItem?.identifier as? NSToolbarItem.Identifier == panelApp {
            setPane(panelScrolling)
        }
    }

    private func setPane(_ identifier: NSToolbarItem.Identifier) {
        tabView.selectTabViewItem(withIdentifier: identifier)
        window?.toolbar?.selectedItemIdentifier = identifier
        UserDefaults.standard.set(identifier.rawValue, forKey: Prefs.lastUsedPanel)
        updateWindow(for: identifier)
    }

    // set the width to our pre-stored width, and the height to fit the pane, keeping the top edge in place
    private func updateWindow(for identifier: NSToolbarItem.Identifier) {
        guard let window, let pane = panels[identifier]?.view else { return }
        var frame = window.frame
        let chromeHeight = frame.height - window.contentView!.frame.height
        let height = pane.fittingSize.height + chromeHeight
        frame.origin.y += frame.height - height
        frame.size = NSSize(width: width, height: height)
        window.setFrame(frame, display: true, animate: false)
    }

    // MARK: State

    @objc private func refresh() {
        let permitted = appDelegate.permissionsManager.accessibilityEnabled
        scrollCheckbox.state = appDelegate.scrollEnabled ? .on : .off
        trackpadPopUp.selectItem(withTag: UserDefaults.standard.integer(forKey: Prefs.trackpadDirection))
        mousePopUp.selectItem(withTag: UserDefaults.standard.integer(forKey: Prefs.mouseDirection))
        trackpadHorizontalCheckbox.state = UserDefaults.standard.bool(forKey: Prefs.trackpadHorizontal) ? .on : .off
        mouseHorizontalCheckbox.state = UserDefaults.standard.bool(forKey: Prefs.mouseHorizontal) ? .on : .off
        for control in [trackpadPopUp!, mousePopUp!, trackpadHorizontalCheckbox!, mouseHorizontalCheckbox!] as [NSControl] {
            control.isEnabled = appDelegate.scrollEnabled
        }
        enableCheckbox.state = appDelegate.enabled ? .on : .off
        for view in [scrollCheckbox!, directionsBox!, enableCheckbox!, howItWorksBox!] {
            view.isHidden = !permitted
        }
        for box in permissionsBoxes {
            box.isHidden = permitted
        }
        startAtLoginCheckbox.state = appDelegate.loginItemController.startAtLogin ? .on : .off
        showInMenuBarCheckbox.state = UserDefaults.standard.bool(forKey: Prefs.hideIcon) ? .off : .on
        if let identifier = tabView.selectedTabViewItem?.identifier as? NSToolbarItem.Identifier, window?.isVisible == true {
            updateWindow(for: identifier)
        }
    }

    @objc private func scrollEnabledClicked(_ sender: NSButton) {
        appDelegate.scrollEnabled = sender.state == .on
    }

    @objc private func directionChosen(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: sender == trackpadPopUp ? Prefs.trackpadDirection : Prefs.mouseDirection)
        NotificationCenter.default.post(name: .scrollFlipStateChanged, object: nil)
    }

    @objc private func horizontalClicked(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: sender == trackpadHorizontalCheckbox ? Prefs.trackpadHorizontal : Prefs.mouseHorizontal)
        NotificationCenter.default.post(name: .scrollFlipStateChanged, object: nil)
    }

    @objc private func enableClicked(_ sender: NSButton) {
        appDelegate.enabled = sender.state == .on
    }

    @objc private func axButtonClicked(_ sender: Any?) {
        appDelegate.permissionsManager.requestAccessibilityPermission()
    }

    @objc private func openAccessibilityPrefsClicked(_ sender: Any?) {
        appDelegate.permissionsManager.openAccessibilityPrefs()
    }

    @objc private func startAtLoginClicked(_ sender: NSButton) {
        appDelegate.loginItemController.startAtLogin = sender.state == .on
        refresh()
    }

    @objc private func showInMenuBarClicked(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .off, forKey: Prefs.hideIcon)
        NotificationCenter.default.post(name: .scrollFlipStateChanged, object: nil)
    }

    // MARK: Permissions

    // shown only while the permission is missing
    private func makePermissionsBox() -> NSView {
        let description = label(NSTextField(wrappingLabelWithString: "\(appDelegate.appName) necesita el permiso de Accesibilidad para cambiar el desplazamiento y detectar cuándo pulsas el botón de cerrar."),
                                smallFont, .secondaryLabelColor)
        description.alignment = .center
        description.preferredMaxLayoutWidth = 360
        let axButton = NSButton(title: "Solicitar permiso de Accesibilidad", target: self, action: #selector(axButtonClicked(_:)))
        let openPrefsButton = NSButton(title: "Abrir ajustes de Accesibilidad", target: self, action: #selector(openAccessibilityPrefsClicked(_:)))
        openPrefsButton.controlSize = .small
        openPrefsButton.font = .messageFont(ofSize: 11)
        let permissionsBox = box("Permisos", content: stack(.vertical, .centerX, 10, [description, axButton, openPrefsButton]))
        permissionsBoxes.append(permissionsBox)
        return permissionsBox
    }

    // MARK: Scrolling pane

    private func makeScrollingSettings() -> NSView {
        scrollCheckbox = checkbox("Invertir desplazamiento", target: self, action: #selector(scrollEnabledClicked(_:)))

        func directionPopUp() -> NSPopUpButton {
            let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
            popUp.translatesAutoresizingMaskIntoConstraints = false
            for direction in ScrollDirection.allCases {
                popUp.addItem(withTitle: direction.title)
                popUp.lastItem?.tag = direction.rawValue
            }
            popUp.target = self
            popUp.action = #selector(directionChosen(_:))
            return popUp
        }
        trackpadPopUp = directionPopUp()
        mousePopUp = directionPopUp()
        trackpadHorizontalCheckbox = checkbox("También horizontal", target: self, action: #selector(horizontalClicked(_:)))
        mouseHorizontalCheckbox = checkbox("También horizontal", target: self, action: #selector(horizontalClicked(_:)))
        let grid = NSGridView(views: [
            [label(NSTextField(labelWithString: "Trackpad:"), .systemFont(ofSize: NSFont.systemFontSize), .labelColor), trackpadPopUp, trackpadHorizontalCheckbox],
            [label(NSTextField(labelWithString: "Ratón:"), .systemFont(ofSize: NSFont.systemFontSize), .labelColor), mousePopUp, mouseHorizontalCheckbox],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowAlignment = .firstBaseline
        grid.columnSpacing = 8
        grid.rowSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        let note = label(NSTextField(wrappingLabelWithString: "Natural: el contenido sigue a los dedos, como en un iPhone. Clásico: la barra de desplazamiento sigue a los dedos. El Magic Mouse cuenta como trackpad. Invertir el horizontal del trackpad puede invertir también los gestos de deslizar, como atrás y adelante en el navegador."),
                         smallFont, .secondaryLabelColor)
        note.alignment = .center
        note.preferredMaxLayoutWidth = 360
        directionsBox = box("Dirección", content: stack(.vertical, .centerX, 12, [grid, note]))

        let permissionsBox = makePermissionsBox()
        let content = stack(.vertical, .centerX, 17, [scrollCheckbox, directionsBox, permissionsBox])
        content.setHuggingPriority(.defaultHigh, for: .vertical)
        NSLayoutConstraint.activate([
            directionsBox.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            directionsBox.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            permissionsBox.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            permissionsBox.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        return pane(content)
    }

    // MARK: Close apps pane

    private func makeQuitSettings() -> NSView {
        enableCheckbox = checkbox("Cerrar apps con el botón rojo", target: self, action: #selector(enableClicked(_:)))

        // what it does
        let lines = [
            "Al pulsar el botón rojo de cerrar de una ventana, se cierra la app entera, como con ⌘Q.",
            "Si la app tiene cambios sin guardar, te preguntará antes de cerrarse.",
            "Mantén pulsada ⌥ Option al hacer clic para cerrar solo la ventana.",
            "El Finder nunca se cierra.",
        ].map { line -> NSView in
            let field = label(NSTextField(wrappingLabelWithString: "•  " + line), smallFont, .secondaryLabelColor)
            field.preferredMaxLayoutWidth = 360
            return field
        }
        howItWorksBox = box("Cómo funciona", content: stack(.vertical, .leading, 6, lines))

        let permissionsBox = makePermissionsBox()
        let content = stack(.vertical, .centerX, 17, [enableCheckbox, howItWorksBox, permissionsBox])
        content.setHuggingPriority(.defaultHigh, for: .vertical)
        NSLayoutConstraint.activate([
            howItWorksBox.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            howItWorksBox.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            permissionsBox.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            permissionsBox.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        return pane(content)
    }

    // MARK: App pane

    private func makeAppSettings() -> NSView {
        startAtLoginCheckbox = checkbox("Abrir al iniciar sesión", target: self, action: #selector(startAtLoginClicked(_:)))
        showInMenuBarCheckbox = checkbox("Mostrar en la barra de menús", target: self, action: #selector(showInMenuBarClicked(_:)))
        let options = stack(.vertical, .leading, 6, [startAtLoginCheckbox, showInMenuBarCheckbox])

        // a separator is horizontal if it starts out wider than it is tall
        let separator = NSBox(frame: NSRect(x: 0, y: 0, width: 100, height: 1))
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator

        // about the app
        let infoFont = NSFont.messageFont(ofSize: 11)
        let info = stack(.vertical, .centerX, 0, [
            label(NSTextField(labelWithString: appDelegate.appName), .boldSystemFont(ofSize: NSFont.smallSystemFontSize), .labelColor),
            label(NSTextField(labelWithString: appDelegate.appVersion), infoFont, .labelColor),
            label(NSTextField(labelWithString: "Interfaz basada en Scroll Reverser, de Nick Moore"), infoFont, .secondaryLabelColor),
        ])

        let content = stack(.vertical, .centerX, 16, [options, separator, info])
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
            content.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
        ])
        return pane(content)
    }

    // MARK: Toolbar delegate

    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        setPane(sender.itemIdentifier)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let panel = panels[identifier] else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        item.image = panel.image
        item.label = panel.title
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [] }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefinition }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefinition }
}
