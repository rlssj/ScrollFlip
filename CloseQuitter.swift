import AppKit
import ApplicationServices

// The close button at this point (global, top-left origin): its app's pid and its frame, or nil.
private func closeButton(at point: CGPoint) -> (pid: pid_t, frame: CGRect)? {
    var element: AXUIElement?
    guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element) == .success,
          let element else { return nil }
    var subrole: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
          let subrole = subrole as? String, subrole == kAXCloseButtonSubrole as String else { return nil }
    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else { return nil }
    var position: CFTypeRef?, size: CFTypeRef?
    var origin = CGPoint.zero, extent = CGSize.zero
    if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
       AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success {
        AXValueGetValue(position as! AXValue, .cgPoint, &origin)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
    }
    // a little slack, and never smaller than the point clicked
    return (pid, CGRect(origin: origin, size: extent).insetBy(dx: -2, dy: -2).union(CGRect(origin: point, size: .zero)))
}

/* A listen-only event tap on left clicks. When a click on a window's red close button completes,
 the app owning that window is asked to quit, as if the user had chosen Quit from its menu.
 Holding Option while clicking, or clicking in an app listed as an exception, only closes the window. */
final class CloseQuitter {
    fileprivate var tap: EventTap!
    private var pressed: (pid: pid_t, frame: CGRect)?

    // bundle identifiers of apps whose close button only closes the window
    var exceptions: Set<String> = []

    init() {
        tap = EventTap(events: [.leftMouseDown, .leftMouseUp], options: .listenOnly, callback: clickCallback, userInfo: self)
    }

    // the tap is only installed while active
    var active: Bool {
        get { tap.installed }
        set { tap.installed = newValue }
    }

    fileprivate func mouseDown(at point: CGPoint) {
        pressed = closeButton(at: point)
        debug("mouse down at \(point): \(pressed.map { "close button of pid \($0.pid) in \($0.frame)" } ?? "no close button")")
    }

    fileprivate func mouseUp(at point: CGPoint) {
        // The close button only acts if the mouse is released over it. By now the window may already be gone,
        // so we check against where the button was when it was pressed rather than asking again.
        guard let (pid, frame) = pressed else { return }
        pressed = nil
        debug("mouse up at \(point), inside the button: \(frame.contains(point))")
        guard frame.contains(point),
              let app = NSRunningApplication(processIdentifier: pid),
              app != NSRunningApplication.current, // our own windows just close
              app.bundleIdentifier != "com.apple.finder", // Finder relaunches itself
              !exceptions.contains(app.bundleIdentifier ?? "")
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
    case .leftMouseDown where !optionHeld(event):
        DispatchQueue.main.async { quitter.mouseDown(at: point) }
    case .leftMouseUp:
        DispatchQueue.main.async { quitter.mouseUp(at: point) }
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

// Clicks can arrive without their modifier flags (as Scroll Reverser found on macOS 27 for status item clicks),
// so also ask for the keyboard's current state.
private func optionHeld(_ event: CGEvent) -> Bool {
    event.flags.contains(.maskAlternate) || CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
}
