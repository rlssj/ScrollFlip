// Run by the GitHub build with ScrollFlip already running: clicks TextEdit's red close button and checks
// that TextEdit quits, then clicks it again holding Option and checks that only the window closes.
import AppKit

let textEdit = "com.apple.TextEdit"
let document = NSTemporaryDirectory() + "scrollflip-test.txt"
try! "prueba".write(toFile: document, atomically: true, encoding: .utf8)

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

func openTextEdit() -> NSRunningApplication {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = ["-b", textEdit, document]
    try! task.run()
    task.waitUntilExit()
    for _ in 0..<40 {
        wait(0.5)
        if let app = running(), !windows(of: app).isEmpty { wait(1); return app }
    }
    fail("TextEdit no abrió ninguna ventana")
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

// 1. the red button quits TextEdit
var app = openTextEdit()
guard let button = closeButtonCentre(of: windows(of: app)[0]) else { fail("no encuentro el botón rojo de TextEdit") }
click(button, option: false)
wait(3)
if let still = running() { fail("botón rojo: TextEdit sigue abierto, con \(windows(of: still).count) ventanas") }
print("✅ botón rojo: TextEdit se ha cerrado entero")

// 2. with Option only the window closes
app = openTextEdit()
guard let button2 = closeButtonCentre(of: windows(of: app)[0]) else { fail("no encuentro el botón rojo de TextEdit") }
click(button2, option: true)
wait(3)
guard let still = running() else { fail("⌥ + botón rojo: TextEdit se ha cerrado entero") }
if !windows(of: still).isEmpty { fail("⌥ + botón rojo: la ventana sigue abierta") }
print("✅ ⌥ + botón rojo: solo se ha cerrado la ventana")
still.forceTerminate()
