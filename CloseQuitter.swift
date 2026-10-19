import AppKit
import ApplicationServices

// The pid of the app whose close button is at this point (global, top-left origin), or nil.
private func closeButtonOwner(at point: CGPoint) -> pid_t? {
    var element: AXUIElement?
    guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element) == .success,
          let element else { return nil }
    var subrole: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
          let subrole = subrole as? String, subrole == kAXCloseButtonSubrole as String else { return nil }
    var pid: pid_t = 0
    return AXUIElementGetPid(element, &pid) == .success ? pid : nil
}

/* A listen-only event tap on left clicks. When a click on a window's red close button completes,
 the app owning that window is asked to quit, as if the user had chosen Quit from its menu.
 Holding Option while clicking keeps the normal behaviour (only the window closes). */
final class CloseQuitter {
    fileprivate var tap: EventTap!
    private var pressedPid: pid_t?

    init() {
        tap = EventTap(events: [.leftMouseDown, .leftMouseUp], options: .listenOnly, callback: clickCallback, userInfo: self)
    }

    // the tap is only installed while active
    var active: Bool {
        get { tap.installed }
        set { tap.installed = newValue }
    }

    fileprivate func mouseDown(at point: CGPoint) {
        pressedPid = closeButtonOwner(at: point)
    }

    fileprivate func mouseUp(at point: CGPoint) {
        // the close button only acts if the mouse is released over it
        guard let pid = pressedPid else { return }
        pressedPid = nil
        guard closeButtonOwner(at: point) == pid,
              let app = NSRunningApplication(processIdentifier: pid),
              app != NSRunningApplication.current, // our own windows just close
              app.bundleIdentifier != "com.apple.finder" // Finder relaunches itself
        else { return }
        app.terminate() // a normal quit, so the app can still ask to save changes
    }
}

// Accessibility queries are slow, so they run on the main queue, never in the tap callback.
// The main queue is serial, so each mouse up is handled after its mouse down.
private let clickCallback: CGEventTapCallBack = { _, type, event, userInfo in
    let quitter = Unmanaged<CloseQuitter>.fromOpaque(userInfo!).takeUnretainedValue()
    let point = event.location
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        quitter.tap.reenable()
    case .leftMouseDown where !event.flags.contains(.maskAlternate):
        DispatchQueue.main.async { quitter.mouseDown(at: point) }
    case .leftMouseUp:
        DispatchQueue.main.async { quitter.mouseUp(at: point) }
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}
