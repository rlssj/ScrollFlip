import AppKit

final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private let menu: NSMenu

    init(menu: NSMenu) {
        self.menu = menu
    }

    var visible = false { didSet { display() } }
    var enabled = true { didSet { statusItem?.button?.appearsDisabled = !enabled } }

    private func display() {
        if visible, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(statusButtonClicked(_:))
            item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
            // the app's logo cut out of its background (StatusIcon.png and @2x in Resources), drawn in a
            // single colour like every other menu bar icon: as a template only its shape is used
            let image = NSImage(named: "StatusIcon")
            image?.isTemplate = true
            image?.accessibilityDescription = "ScrollFlip"
            item.button?.image = image
            item.button?.appearsDisabled = !enabled
            statusItem = item
        } else if !visible, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // left or right click opens the menu; we un-set it afterwards so that target/action keeps working
    @objc private func statusButtonClicked(_ sender: Any?) {
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
}
