// ScrollFlip: reverses scrolling, and clicking a window's red close button quits the whole app.
// Based on Scroll Reverser <https://pilotmoon.com/scrollreverser/> (Apache License v2.0).

import AppKit

let app = NSApplication.shared
if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
    // used by the GitHub build to save pictures of the settings window
    Snapshot.save(to: CommandLine.arguments[index + 1])
    exit(0)
}
let delegate = AppDelegate()
app.delegate = delegate
app.run()
