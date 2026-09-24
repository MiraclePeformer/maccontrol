import Cocoa

private typealias DSGetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
private typealias DSSetBrightness = @convention(c) (UInt32, Float) -> Int32

/// Per-display brightness. Built-in panels use the private DisplayServices
/// hardware brightness API; every other display (and any panel where the
/// hardware call fails) falls back to a software dimming overlay, which works
/// on all monitors without DDC/CI.
final class DisplayController {
    struct Display: Equatable {
        let id: CGDirectDisplayID
        let name: String
        let isBuiltin: Bool
    }

    private var getBrightness: DSGetBrightness?
    private var setBrightnessFn: DSSetBrightness?

    /// Dimming overlays and their current brightness (1.0 == no dim).
    private var overlays: [CGDirectDisplayID: NSWindow] = [:]
    private var overlayBrightness: [CGDirectDisplayID: Double] = [:]

    /// Overlay never fully blacks out a screen, so it stays usable.
    private let overlayMinBrightness = 0.15

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        if let handle = dlopen(path, RTLD_NOW) {
            if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightness = unsafeBitCast(sym, to: DSGetBrightness.self)
            }
            if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightnessFn = unsafeBitCast(sym, to: DSSetBrightness.self)
            }
        }
    }

    func displays() -> [Display] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids.map {
            Display(id: $0, name: name(for: $0), isBuiltin: CGDisplayIsBuiltin($0) != 0)
        }
    }

    func brightness(for display: Display) -> Double {
        if display.isBuiltin, let get = getBrightness {
            var value: Float = 0
            if get(display.id, &value) == 0 { return Double(value) }
        }
        return overlayBrightness[display.id] ?? 1.0
    }

    func setBrightness(_ value: Double, for display: Display) {
        let clamped = max(0, min(1, value))
        if display.isBuiltin, let set = setBrightnessFn, set(display.id, Float(clamped)) == 0 {
            overlays[display.id]?.orderOut(nil) // clear any leftover overlay
            return
        }
        applyOverlay(brightness: clamped, to: display)
    }

    // MARK: Software dimming

    private func applyOverlay(brightness: Double, to display: Display) {
        overlayBrightness[display.id] = brightness
        let effective = overlayMinBrightness + (1 - overlayMinBrightness) * brightness
        let alpha = 1 - effective

        let window = overlays[display.id] ?? makeOverlay(for: display)
        overlays[display.id] = window
        window.alphaValue = CGFloat(alpha)
        if alpha <= 0.001 {
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    private func makeOverlay(for display: Display) -> NSWindow {
        let frame = screenFrame(for: display.id)
        let window = NSWindow(contentRect: frame, styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.ignoresMouseEvents = true
        window.backgroundColor = .black
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        return window
    }

    // MARK: Helpers

    private func screenFrame(for id: CGDirectDisplayID) -> NSRect {
        if let screen = nsScreen(for: id) { return screen.frame }
        let b = CGDisplayBounds(id)
        return NSRect(x: b.minX, y: b.minY, width: b.width, height: b.height)
    }

    private func name(for id: CGDirectDisplayID) -> String {
        nsScreen(for: id)?.localizedName ?? "Display \(id)"
    }

    private func nsScreen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == id
        }
    }
}
