import SwiftUI

/// The control-center panel shown in the popover. Stays open until the user
/// clicks outside; every control updates live.
struct PanelView: View {
    @ObservedObject var state: MenuState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !state.displays.isEmpty {
                sectionHeader("DISPLAYS")
                ForEach(Array(state.displays.enumerated()), id: \.element.id) { index, item in
                    sliderRow(
                        icon: "sun.max.fill",
                        title: item.display.name,
                        value: Binding(
                            get: { item.brightness },
                            set: { state.setBrightness($0, at: index) }
                        )
                    )
                }
                Divider()
            }

            sectionHeader("AUDIO")
            sliderRow(
                icon: state.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                title: "Volume",
                value: Binding(get: { state.volume }, set: { state.setVolume($0) })
            )
            HStack {
                Button(action: { state.toggleMute() }) {
                    Label(state.muted ? "Unmute" : "Mute",
                          systemImage: state.muted ? "speaker.slash" : "speaker")
                }
                Spacer()
                Menu {
                    ForEach(state.devices, id: \.id) { device in
                        Button(action: { state.selectDevice(device.id) }) {
                            if device.id == state.currentDeviceID {
                                Label(device.name, systemImage: "checkmark")
                            } else {
                                Text(device.name)
                            }
                        }
                    }
                } label: {
                    Label(currentDeviceName, systemImage: "hifispeaker")
                }
                .frame(maxWidth: 150)
            }

            Divider()

            sectionHeader("SYSTEM")
            HStack {
                Text("Default Browser").foregroundColor(.secondary)
                Spacer()
                Menu {
                    ForEach(state.browsers) { browser in
                        Button(action: { state.setDefaultBrowser(browser) }) {
                            if browser.id == state.currentBrowserPath {
                                Label(browser.name, systemImage: "checkmark")
                            } else {
                                Text(browser.name)
                            }
                        }
                    }
                } label: {
                    Label(state.currentBrowserName, systemImage: "safari")
                }
                .frame(maxWidth: 150)
            }

            Divider()

            sectionHeader("MOUSE JIGGLER")
            Toggle(isOn: Binding(get: { state.jigglerRunning }, set: { _ in state.toggleJiggler() })) {
                Text("Keep Mac awake (jiggle)")
            }
            .toggleStyle(.switch)

            HStack {
                Text("Interval").foregroundColor(.secondary)
                Spacer()
                Menu(MenuState.formatSeconds(state.jigglerInterval)) {
                    Button("15 seconds") { state.setInterval(15) }
                    Button("30 seconds") { state.setInterval(30) }
                    Button("1 minute") { state.setInterval(60) }
                    Button("5 minutes") { state.setInterval(300) }
                    Divider()
                    Button("Custom…") { state.promptCustomInterval() }
                }
                .frame(maxWidth: 110)
            }

            if state.jigglerNeedsPermission {
                Button(action: { state.showAccessibilityHelp() }) {
                    Label("Grant Accessibility Permission", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }

            Divider()

            Toggle(isOn: Binding(get: { state.launchAtLogin }, set: { _ in state.toggleLaunchAtLogin() })) {
                Text("Launch at Login")
            }
            .toggleStyle(.switch)

            HStack {
                Button("About") { state.showAbout() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private var currentDeviceName: String {
        state.devices.first { $0.id == state.currentDeviceID }?.name ?? "Output"
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .kerning(0.5)
    }

    @ViewBuilder
    private func sliderRow(icon: String, title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Slider(value: value, in: 0...1)
            }
        }
    }
}
