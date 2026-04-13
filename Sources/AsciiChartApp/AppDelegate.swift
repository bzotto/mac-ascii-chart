import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // Tiny "ASCII" text label as the menu bar icon.
            // Compressed slightly so it fits comfortably in the menu bar height.
            let title = NSMutableAttributedString(string: "ASCII")
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            title.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: 9, weight: .heavy),
                    // Tighten letter spacing so the word reads as one chunk.
                    .kern: -0.4,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraph,
                ],
                range: NSRange(location: 0, length: title.length)
            )
            button.attributedTitle = title
            button.image = nil
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            // Receive both left- and right-click as actions so we can route
            // them differently (left = toggle popover, right = context menu).
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Popover hosting the chart view
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = AsciiChartViewController()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp
                && event?.modifierFlags.contains(.control) == true)

        if isRightClick {
            // Make sure the popover isn't covering the menu we're about to show.
            if popover.isShown { closePopover() }
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            // Activate our app before showing the popover. As an accessory
            // app we aren't automatically frontmost, which means other apps
            // keep receiving mouse-moved / tracking events while the user
            // hovers over our popover. Activating fixes that so the popover
            // properly "swallows" mouse interaction.
            NSApp.activate(ignoringOtherApps: true)

            popover.show(relativeTo: button.bounds,
                         of: button,
                         preferredEdge: .minY)
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
                // Raise above regular app windows and make sure we get
                // mouse-moved events routed to us.
                window.level = .popUpMenu
                window.acceptsMouseMovedEvents = true
            }
            startMonitoringClicksOutside()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? ProcessInfo.processInfo.processName
        let quit = NSMenuItem(title: "Quit \(appName)",
                              action: #selector(quitApp),
                              keyEquivalent: "q")
        quit.keyEquivalentModifierMask = [.command]
        quit.target = self
        menu.addItem(quit)

        // Standard trick: temporarily attach the menu and trigger a click so
        // it pops up at the status item, then detach so left-click still
        // calls our action selector.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func closePopover() {
        popover.performClose(nil)
        stopMonitoringClicksOutside()
    }

    private func startMonitoringClicksOutside() {
        stopMonitoringClicksOutside()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func stopMonitoringClicksOutside() {
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
    }
}
