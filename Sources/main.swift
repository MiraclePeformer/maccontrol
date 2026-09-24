import Cocoa
import SwiftUI

/// MacControl — a menu bar control center hosted in a popover so it stays open
/// while you adjust things and updates live.
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let state = MenuState()
    private var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "slider.horizontal.3",
                                accessibilityDescription: "MacControl")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }

        let hosting = NSHostingController(rootView: PanelView(state: state))
        hosting.sizingOptions = [.preferredContentSize] // popover fits the SwiftUI content
        popover.contentViewController = hosting
        popover.behavior = .transient // closes only when you click outside
        popover.delegate = self
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        state.refreshAll()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Poll live values only while the panel is open.
    func popoverDidShow(_ notification: Notification) {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.state.refreshLive()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
