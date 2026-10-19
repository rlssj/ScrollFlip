import CoreGraphics

/* An event tap that only exists while it's needed: a tap that isn't installed costs nothing,
 while an installed one is woken for every matching event. */
final class EventTap {
    private let mask: CGEventMask
    private let options: CGEventTapOptions
    private let callback: CGEventTapCallBack
    private let userInfo: UnsafeMutableRawPointer
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    init(events: [CGEventType], options: CGEventTapOptions, callback: @escaping CGEventTapCallBack, userInfo: AnyObject) {
        mask = events.reduce(0) { $0 | CGEventMask(1 << $1.rawValue) }
        self.options = options
        self.callback = callback
        self.userInfo = Unmanaged.passUnretained(userInfo).toOpaque()
    }

    // Installing needs Accessibility permission, so it can fail; a later call tries again.
    var installed: Bool {
        get { port != nil }
        set { newValue ? install() : remove() }
    }

    private func install() {
        guard port == nil,
              let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: options,
                                           eventsOfInterest: mask, callback: callback, userInfo: userInfo) else { return }
        source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.port = port
    }

    private func remove() {
        guard let port else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        CFMachPortInvalidate(port)
        self.port = nil
        source = nil
    }

    // the system disables a tap that is slow or when the user revokes permission
    func reenable() {
        if let port, !CGEvent.tapIsEnabled(tap: port) {
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }
}
