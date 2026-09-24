import SwiftUI
import CoreAudio
import ServiceManagement
import ApplicationServices

/// Observable state shared with the SwiftUI panel. Holds the controllers and
/// mirrors live system values so the panel updates in real time while open.
final class MenuState: ObservableObject {
    struct DisplayItem: Identifiable {
        let display: DisplayController.Display
        var brightness: Double
        var id: CGDirectDisplayID { display.id }
    }

    let audio = AudioController()
    let display = DisplayController()
    let jiggler = Jiggler()
    let browser = BrowserController()

    @Published var displays: [DisplayItem] = []
    @Published var volume: Double = 0
    @Published var muted: Bool = false
    @Published var devices: [AudioController.Device] = []
    @Published var currentDeviceID: AudioDeviceID = 0
    @Published var jigglerRunning = false
    @Published var jigglerInterval: Double = 30
    @Published var launchAtLogin = false
    @Published var browsers: [BrowserController.Browser] = []
    @Published var currentBrowserPath: String = ""

    /// While the user is dragging a slider we skip polling those values back,
    /// so hardware quantization can't fight the drag.
    private var suppressPollUntil = Date.distantPast

    private enum Keys {
        static let enabled = "jiggleEnabled"
        static let interval = "jiggleInterval"
    }

    init() {
        if let saved = UserDefaults.standard.object(forKey: Keys.interval) as? Double {
            jiggler.interval = saved
        }
        if UserDefaults.standard.bool(forKey: Keys.enabled) {
            jiggler.start()
        }
        jigglerInterval = jiggler.interval
        jigglerRunning = jiggler.isRunning
        refreshAll()
    }

    // MARK: - Refresh

    /// Full refresh when the panel opens: re-enumerate displays and devices.
    func refreshAll() {
        displays = display.displays().map {
            DisplayItem(display: $0, brightness: display.brightness(for: $0))
        }
        devices = audio.outputDevices()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        browsers = browser.browsers()
        currentBrowserPath = browser.currentDefaultPath() ?? ""
        refreshLive()
    }

    /// Cheap refresh on a timer while open: catches keyboard volume/brightness keys.
    func refreshLive() {
        let now = Date()
        currentDeviceID = audio.currentOutputID()
        muted = audio.isMuted()
        jigglerRunning = jiggler.isRunning

        guard now >= suppressPollUntil else { return }
        let v = audio.volume()
        if abs(v - volume) > 0.005 { volume = v }
        for i in displays.indices {
            let b = display.brightness(for: displays[i].display)
            if abs(b - displays[i].brightness) > 0.005 { displays[i].brightness = b }
        }
    }

    private func noteUserDrag() {
        suppressPollUntil = Date().addingTimeInterval(0.7)
    }

    // MARK: - Display

    func setBrightness(_ value: Double, at index: Int) {
        guard displays.indices.contains(index) else { return }
        noteUserDrag()
        displays[index].brightness = value
        display.setBrightness(value, for: displays[index].display)
    }

    // MARK: - Audio

    func setVolume(_ value: Double) {
        noteUserDrag()
        volume = value
        audio.setVolume(value)
        if value > 0 && muted {
            muted = false
            audio.setMuted(false)
        }
    }

    func toggleMute() {
        muted.toggle()
        audio.setMuted(muted)
    }

    func selectDevice(_ id: AudioDeviceID) {
        audio.setDefaultOutput(id)
        currentDeviceID = id
        // Volume/mute are per-device, so re-read.
        volume = audio.volume()
        muted = audio.isMuted()
    }

    // MARK: - Jiggler

    func toggleJiggler() {
        if jiggler.isRunning {
            jiggler.stop()
        } else {
            jiggler.start()
            if !accessibilityTrusted(prompt: true) { showAccessibilityHelp() }
        }
        jigglerRunning = jiggler.isRunning
        UserDefaults.standard.set(jiggler.isRunning, forKey: Keys.enabled)
    }

    func setInterval(_ seconds: Double) {
        jiggler.interval = seconds
        jigglerInterval = seconds
        if jiggler.isRunning { jiggler.start() }
        UserDefaults.standard.set(seconds, forKey: Keys.interval)
    }

    func promptCustomInterval() {
        let alert = NSAlert()
        alert.messageText = "Custom Interval"
        alert.informativeText = "How many seconds between jiggles? (1–3600)"
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = String(Int(jigglerInterval.rounded()))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard let value = Double(text), value >= 1, value <= 3600 else {
            NSSound.beep()
            return
        }
        setInterval(value)
    }

    // MARK: - Default browser

    var currentBrowserName: String {
        browsers.first { $0.id == currentBrowserPath }?.name ?? "Browser"
    }

    func setDefaultBrowser(_ target: BrowserController.Browser) {
        guard target.id != currentBrowserPath else { return }
        browser.setDefault(target) { [weak self] _ in
            // macOS may show a confirmation prompt; re-read whatever it ended up as.
            self?.currentBrowserPath = self?.browser.currentDefaultPath() ?? ""
        }
    }

    // MARK: - Launch at login

    func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Accessibility

    var jigglerNeedsPermission: Bool {
        jigglerRunning && !AXIsProcessTrusted()
    }

    @discardableResult
    func accessibilityTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    func showAccessibilityHelp() {
        accessibilityTrusted(prompt: true)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        let alert = NSAlert()
        alert.messageText = "Grant Accessibility, then relaunch"
        alert.informativeText = """
        The mouse jiggler needs Accessibility permission to move the cursor.

        1. In the window that opened, turn ON MacControl.
           (If an old MacControl is listed, remove it with “–” first, then add this one with “+”.)
        2. Quit MacControl from the panel, then open it again.
        """
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MacControl"
        alert.informativeText = """
        A menu bar control center.

        • Displays — brightness per screen (software dimming for external monitors)
        • Audio — volume, mute, and output device switching
        • System — default browser
        • Mouse Jiggler — keeps your Mac awake

        The jiggler needs Accessibility permission (Privacy & Security → Accessibility).

        Made by metr0
        """
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    static func formatSeconds(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        if s % 60 == 0 && s >= 60 {
            let m = s / 60
            return m == 1 ? "1 min" : "\(m) min"
        }
        return "\(s)s"
    }
}
