import Foundation
import CoreGraphics

/* The thread the taps run on. Not the main thread: that one asks other apps about their windows, which can
 take a while, and a tap that doesn't answer in time holds up every click or scroll and is then switched off
 by the system. This thread only runs the callbacks, which return straight away. */
private let tapRunLoop: CFRunLoop = {
    var runLoop: CFRunLoop?
    let ready = DispatchSemaphore(value: 0)
    let thread = Thread {
        runLoop = CFRunLoopGetCurrent()
        // a run loop with nothing in it returns at once, so give it a source that never fires
        var context = CFRunLoopSourceContext()
        CFRunLoopAddSource(runLoop, CFRunLoopSourceCreate(nil, 0, &context), .commonModes)
        ready.signal()
        CFRunLoopRun()
    }
    thread.name = "ScrollFlip event taps"
    thread.qualityOfService = .userInteractive
    thread.start()
    ready.wait()
    return runLoop!
}()

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
        CFRunLoopAddSource(tapRunLoop, source, .commonModes)
        CFRunLoopWakeUp(tapRunLoop)
        self.port = port
    }

    private func remove() {
        guard let port else { return }
        CFRunLoopRemoveSource(tapRunLoop, source, .commonModes)
        CFMachPortInvalidate(port)
        self.port = nil
        source = nil
    }

    // the system disables a tap that is slow or when the user revokes permission
    func reenable() {
        debug("tap was switched off, switching it back on")
        if let port, !CGEvent.tapIsEnabled(tap: port) {
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }
}
