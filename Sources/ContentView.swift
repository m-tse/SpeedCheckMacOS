import SwiftUI
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject var speedTest: SpeedTestManager
    @State private var launchOnLogin = SMAppService.mainApp.status == .enabled
    @State private var now = Date()

    private let intervalOptions = [5, 10, 15, 30, 60]
    private let minuteTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 2) {
                Text("SpeedCheck")
                    .font(.headline)
                Text("speed.cloudflare.com")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Test now / Stop button
            Button(action: {
                if speedTest.isRunning {
                    speedTest.stopTest()
                } else {
                    speedTest.runSpeedTest()
                }
            }) {
                HStack {
                    Image(systemName: speedTest.isRunning ? "stop.fill" : "bolt.fill")
                    Text(speedTest.isRunning ? "Stop" : "Test Now")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ProminentHoverButtonStyle(
                tint: speedTest.isRunning ? Color.red.opacity(0.7) : .accentColor
            ))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Status
            Group {
                if !speedTest.phase.isEmpty {
                    Text(speedTest.phase)
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if let lastTest = speedTest.lastTestTime {
                    Text("Last tested: \(timeAgo(lastTest, now: now))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 4)

            // Speed display
            VStack(spacing: 12) {
                SpeedRow(label: "Download", value: speedTest.downloadSpeed, unit: "Mbps", icon: "↓", color: .green, showInMenuBar: $speedTest.showDownload)
                SpeedRow(label: "Upload", value: speedTest.uploadSpeed, unit: "Mbps", icon: "↑", color: .blue, showInMenuBar: $speedTest.showUpload)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Settings
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("Test every")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: Binding(
                        get: { speedTest.intervalMinutes },
                        set: { speedTest.updateInterval($0) }
                    )) {
                        ForEach(intervalOptions, id: \.self) { mins in
                            Text(mins < 60 ? "\(mins) min" : "1 hour").tag(mins)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .hoverHighlight()
                }

                Toggle("Launch on login", isOn: $launchOnLogin)
                    .onChange(of: launchOnLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchOnLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                .font(.caption)
                .foregroundColor(.secondary)
                .hoverHighlight()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HoverHighlightButtonStyle())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(width: 260)
        .onReceive(minuteTimer) { _ in now = Date() }
    }

    private func timeAgo(_ date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }
}

struct HoverHighlightModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .brightness(isHovering ? -0.15 : 0)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func hoverHighlight() -> some View {
        modifier(HoverHighlightModifier())
    }
}

struct ProminentHoverButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration, tint: tint)
    }

    private struct HoverBody: View {
        let configuration: Configuration
        let tint: Color
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tint.opacity(configuration.isPressed ? 0.7 : (isHovering ? 1.0 : 0.85)))
                )
                .onHover { isHovering = $0 }
        }
    }
}

struct HoverHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration)
    }

    private struct HoverBody: View {
        let configuration: Configuration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.18 : (isHovering ? 0.1 : 0)))
                )
                .onHover { isHovering = $0 }
        }
    }
}

struct SpeedRow: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    @Binding var showInMenuBar: Bool

    var body: some View {
        HStack {
            Toggle("", isOn: $showInMenuBar)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .hoverHighlight()
            Text(icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
