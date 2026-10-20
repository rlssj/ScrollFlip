import AppKit
import ApplicationServices

private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

private func frame(of element: AXUIElement) -> CGRect? {
    guard let position = attribute(element, kAXPositionAttribute), let size = attribute(element, kAXSizeAttribute) else { return nil }
    var origin = CGPoint.zero, extent = CGSize.zero
    AXValueGetValue(position as! AXValue, .cgPoint, &origin)
    AXValueGetValue(size as! AXValue, .cgSize, &extent)
    return CGRect(origin: origin, size: extent)
}

// The topmost normal window at this point: its owner's pid and its bounds (global, top-left origin).
private func window(at point: CGPoint) -> (pid: pid_t, bounds: CGRect)? {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    for info in list {
        guard let bounds = (info[kCGWindowBounds as String] as! CFDictionary?).flatMap({ CGRect(dictionaryRepresentation: $0) }),
              bounds.contains(point) else { continue }
        // front to back, the first normal, visible window here is the one clicked; overlays above it
        // (invisible or system ones, on other layers) don't take clicks on its buttons
        guard info[kCGWindowLayer as String] as? Int == 0, (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
              let pid = info[kCGWindowOwnerPID as String] as? pid_t else {
            debug("skipping window of \(info[kCGWindowOwnerName as String] ?? "-") on layer \(info[kCGWindowLayer as String] ?? "-") at \(bounds)")
            continue
        }
        return (pid, bounds)
    }
    debug("no window at \(point)")
    return nil
}

/* The close button at this point (global, top-left origin): its app's pid and its frame, or nil.
 Asking Accessibility what is at a point doesn't reliably answer with the button (it can even answer with the
 menu bar), so we find the window from the window list and ask its app where its close button is. */
private func closeButton(at point: CGPoint) -> (pid: pid_t, frame: CGRect)? {
    // close buttons sit in a window's top left corner; skip every other click before asking the app anything
    guard let (pid, bounds) = window(at: point) else { return nil }
    guard point.x - bounds.minX < 160, point.y - bounds.minY < 90 else {
        debug("at \(point): not in the top left corner of the window at \(bounds)")
        return nil
    }
    let windows = attribute(AXUIElementCreateApplication(pid), kAXWindowsAttribute) as? [AXUIElement] ?? []
    for window in windows {
        guard let button = attribute(window, kAXCloseButtonAttribute), let buttonFrame = frame(of: button as! AXUIElement) else { continue }
        // a little slack around the button
        let area = buttonFrame.insetBy(dx: -2, dy: -2)
        if area.contains(point) {
            return (pid, area)
        }
    }
    debug("at \(point): window of pid \(pid) at \(bounds), no close button there")
    return nil
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
