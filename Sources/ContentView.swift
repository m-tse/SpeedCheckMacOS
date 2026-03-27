import SwiftUI
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject var speedTest: SpeedTestManager

    private let intervalOptions = [5, 10, 15, 30, 60]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Network Speed")
                        .font(.headline)
                    Spacer()
                    if speedTest.isRunning {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    }
                }
                Text("speed.cloudflare.com")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Speed display
            VStack(spacing: 12) {
                SpeedRow(label: "Download", value: speedTest.downloadSpeed, unit: "Mbps", icon: "↓", color: .green, showInMenuBar: $speedTest.showDownload)
                SpeedRow(label: "Upload", value: speedTest.uploadSpeed, unit: "Mbps", icon: "↑", color: .blue, showInMenuBar: $speedTest.showUpload)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Status
            HStack {
                if !speedTest.phase.isEmpty {
                    Text(speedTest.phase)
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if let lastTest = speedTest.lastTestTime {
                    Text("Last tested: \(timeAgo(lastTest))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            // Test now button
            Button(action: { speedTest.runSpeedTest() }) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text(speedTest.isRunning ? "Testing..." : "Test Now")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(speedTest.isRunning)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Settings
            VStack(spacing: 8) {
                HStack {
                    Text("Test every")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
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
                }

                Toggle("Launch on login", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {}
                    }
                ))
                .font(.caption)
                .foregroundColor(.secondary)
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
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 260)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
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
