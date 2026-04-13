import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Run as a menu bar accessory (no Dock icon, no main menu).
app.setActivationPolicy(.accessory)
app.run()
