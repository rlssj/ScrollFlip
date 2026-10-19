// ScrollFlip: clicking a window's red close button quits the whole app.
// The interface follows Scroll Reverser <https://pilotmoon.com/scrollreverser/> (Apache License v2.0).

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
