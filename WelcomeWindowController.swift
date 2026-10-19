import AppKit

final class WelcomeWindowController: NSWindowController {
    init(menuBar: Bool) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 240, height: 150), styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let contentView = window.contentView!

        let welcomeLabel = NSTextField(wrappingLabelWithString: "¡ScrollFlip se está ejecutando!")
        welcomeLabel.frame = NSRect(x: 18, y: 104, width: 204, height: 34)
        welcomeLabel.alignment = .center
        welcomeLabel.isSelectable = false
        contentView.addSubview(welcomeLabel)

        let helpLabel = NSTextField(wrappingLabelWithString: menuBar ? "Para ver los ajustes, haz clic en «ScrollFlip» en la barra de menús"
                                                                      : "Para ver los ajustes, vuelve a abrir ScrollFlip desde el Finder o Spotlight")
        helpLabel.frame = NSRect(x: 18, y: 58, width: 204, height: 36)
        helpLabel.alignment = .center
        helpLabel.isSelectable = false
        helpLabel.font = .messageFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        contentView.addSubview(helpLabel)

        let okButton = NSButton(title: "OK", target: self, action: #selector(closeWelcomeWindow(_:)))
        okButton.frame = NSRect(x: 77, y: 13, width: 86, height: 32)
        okButton.keyEquivalent = "\r"
        contentView.addSubview(okButton)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        NSApp.activate()
        window?.level = .floating
        window?.center()
        super.showWindow(sender)
        // an accessory app isn't always made active straight away, so make sure the window appears
        window?.orderFrontRegardless()
    }

    @objc private func closeWelcomeWindow(_ sender: Any?) {
        close()
    }
}
