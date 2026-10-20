import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    init(model: AppModel) {
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        // the window takes the size of its content, so nothing ever needs scrolling
        hosting.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible != true {
            window?.center()
        }
        super.showWindow(sender)
        // an accessory app isn't always made active straight away, so make sure the window appears
        window?.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
