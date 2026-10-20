// Run by the GitHub build with ScrollFlip already running. With TextEdit it checks that the red close button
// only closes a window while others are open, quits the app on its last window, and that with Option it closes
// just that one window (not all of them, as macOS would) and never quits the app.
import AppKit

let textEdit = "com.apple.TextEdit"
let document = NSTemporaryDirectory() + "scrollflip-test.txt"
let secondDocument = NSTemporaryDirectory() + "scrollflip-test-2.txt"
try! "prueba".write(toFile: document, atomically: true, encoding: .utf8)
try! "otra".write(toFile: secondDocument, atomically: true, encoding: .utf8)

func wait(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

func running() -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: textEdit).first { !$0.isTerminated }
}

func windows(of app: NSRunningApplication) -> [AXUIElement] {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXWindowsAttribute as CFString, &value)
    return value as? [AXUIElement] ?? []
}

func closeButtonCentre(of window: AXUIElement) -> CGPoint? {
    var button: CFTypeRef?, position: CFTypeRef?, size: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &button) == .success else { return nil }
    let element = button as! AXUIElement
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
    var origin = CGPoint.zero, extent = CGSize.zero
    AXValueGetValue(position as! AXValue, .cgPoint, &origin)
    AXValueGetValue(size as! AXValue, .cgSize, &extent)
    return CGPoint(x: origin.x + extent.width / 2, y: origin.y + extent.height / 2)
}

func openTextEdit(_ documents: [String] = [document], windows expected: Int? = nil) -> NSRunningApplication {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = ["-b", textEdit] + documents
    try! task.run()
    task.waitUntilExit()
    for _ in 0..<40 {
        wait(0.5)
        if let app = running(), windows(of: app).count >= (expected ?? documents.count) { wait(1); return app }
    }
    fail("TextEdit no abrió las ventanas")
}

func click(_ point: CGPoint, option: Bool) {
    let flags: CGEventFlags = option ? .maskAlternate : []
    if option { key(down: true) }
    for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)!
        event.flags = flags
        event.post(tap: .cghidEventTap)
        wait(0.15)
    }
    if option { key(down: false) }
}

// the Option key itself, so the keyboard state shows it held
func key(down: Bool) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: 58, keyDown: down)!
    event.type = .flagsChanged
    event.flags = down ? .maskAlternate : []
    event.post(tap: .cghidEventTap)
    wait(0.2)
}

func fail(_ message: String) -> Never {
    print("❌ \(message)")
    running()?.forceTerminate()
    exit(1)
}

print("Accesibilidad para la prueba: \(AXIsProcessTrusted())")

// 1. with two windows, the red button only closes one
var app = openTextEdit([document, secondDocument])
guard let first = closeButtonCentre(of: windows(of: app)[0]) else { fail("no encuentro el botón rojo de TextEdit") }
click(first, option: false)
wait(3)
guard let afterFirst = running() else { fail("dos ventanas: TextEdit se ha cerrado entero") }
if windows(of: afterFirst).count != 1 { fail("dos ventanas: quedan \(windows(of: afterFirst).count) ventanas") }
print("✅ dos ventanas: el botón rojo solo ha cerrado una")

// 2. with two windows, Option + the red button closes just one, not both
app = openTextEdit([secondDocument], windows: 2)
guard let optionButton = closeButtonCentre(of: windows(of: app)[0]) else { fail("no encuentro el botón rojo de TextEdit") }
click(optionButton, option: true)
wait(3)
guard let afterOption = running() else { fail("⌥ con dos ventanas: TextEdit se ha cerrado entero") }
if windows(of: afterOption).count != 1 { fail("⌥ con dos ventanas: quedan \(windows(of: afterOption).count) ventanas") }
print("✅ ⌥ con dos ventanas: solo se ha cerrado una")

// 3. on the last window, the red button quits TextEdit
app = afterOption
guard let button = closeButtonCentre(of: windows(of: app)[0]) else { fail("no encuentro el botón rojo de TextEdit") }
click(button, option: false)
wait(3)
if let still = running() { fail("botón rojo: TextEdit sigue abierto, con \(windows(of: still).count) ventanas") }
print("✅ botón rojo: TextEdit se ha cerrado entero")

// 4. with Option, the last window closes but TextEdit keeps running
app = openTextEdit()
guard let button2 = closeButtonCentre(of: windows(of: app)[0]) else { fail("no encuentro el botón rojo de TextEdit") }
click(button2, option: true)
wait(3)
guard let still = running() else { fail("⌥ + botón rojo: TextEdit se ha cerrado entero") }
if !windows(of: still).isEmpty { fail("⌥ + botón rojo: la ventana sigue abierta") }
print("✅ ⌥ + botón rojo: solo se ha cerrado la ventana")
still.forceTerminate()
