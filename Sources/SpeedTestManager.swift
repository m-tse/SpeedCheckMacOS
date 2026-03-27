import Foundation
import Combine

class SpeedTestManager: ObservableObject {
    @Published var downloadSpeed: String = "—"
    @Published var uploadSpeed: String = "—"
    @Published var isRunning: Bool = false
    @Published var lastTestTime: Date? = nil
    @Published var serverName: String = "—"
    @Published var menuBarTitle: String = "⇅ —"

    @Published var intervalMinutes: Int {
        didSet { UserDefaults.standard.set(intervalMinutes, forKey: "networkspeed_interval") }
    }

    private var timer: AnyCancellable?
    private var process: Process?

    init() {
        let saved = UserDefaults.standard.integer(forKey: "networkspeed_interval")
        self.intervalMinutes = saved > 0 ? saved : 10
        startTimer()
        runSpeedTest()
    }

    func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: Double(intervalMinutes) * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.runSpeedTest()
            }
    }

    func updateInterval(_ minutes: Int) {
        intervalMinutes = minutes
        startTimer()
    }

    func runSpeedTest() {
        guard !isRunning else { return }
        isRunning = true
        menuBarTitle = "⇅ ..."

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let process = Process()
            let pipe = Pipe()

            // Find speedtest-cli in common locations
            let paths = ["/opt/homebrew/bin/speedtest-cli", "/usr/local/bin/speedtest-cli", "/usr/bin/speedtest-cli"]
            guard let cliPath = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
                DispatchQueue.main.async {
                    self.downloadSpeed = "Error"
                    self.uploadSpeed = "speedtest-cli not found"
                    self.menuBarTitle = "⇅ Error"
                    self.isRunning = false
                }
                return
            }

            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = ["--simple"]
            process.standardOutput = pipe
            process.standardError = pipe
            self.process = process

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self.downloadSpeed = "Error"
                    self.uploadSpeed = error.localizedDescription
                    self.menuBarTitle = "⇅ Error"
                    self.isRunning = false
                }
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            self.parseResults(output)
        }
    }

    private func parseResults(_ output: String) {
        // speedtest-cli --simple outputs:
        // Ping: 12.345 ms
        // Download: 123.45 Mbit/s
        // Upload: 45.67 Mbit/s

        var dl = "—"
        var ul = "—"
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Download:") {
                let parts = trimmed.replacingOccurrences(of: "Download: ", with: "")
                    .replacingOccurrences(of: " Mbit/s", with: "")
                if let value = Double(parts) {
                    dl = String(format: "%.1f", value)
                }
            } else if trimmed.hasPrefix("Upload:") {
                let parts = trimmed.replacingOccurrences(of: "Upload: ", with: "")
                    .replacingOccurrences(of: " Mbit/s", with: "")
                if let value = Double(parts) {
                    ul = String(format: "%.1f", value)
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.downloadSpeed = dl
            self.uploadSpeed = ul
            self.lastTestTime = Date()
            self.isRunning = false

            if dl != "—" {
                self.menuBarTitle = "↓\(dl) ↑\(ul)"
            } else {
                self.menuBarTitle = "⇅ Error"
            }
        }
    }

    func cancel() {
        process?.terminate()
    }
}
