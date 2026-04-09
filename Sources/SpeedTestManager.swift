import Foundation
import Combine

// Download 50MB from Cloudflare, upload 10MB — fast, no server discovery
private let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=50000000")!
private let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
private let uploadSize = 10_000_000

class SpeedTestDelegate: NSObject, URLSessionDataDelegate {
    var bytesReceived: Int64 = 0
    var startTime: CFAbsoluteTime = 0
    var onProgress: ((Double) -> Void)?
    var onComplete: (() -> Void)?
    private var data = Data()

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if startTime == 0 { startTime = CFAbsoluteTimeGetCurrent() }
        bytesReceived += Int64(data.count)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        if elapsed > 0.1 {
            let mbps = (Double(bytesReceived) * 8.0) / (elapsed * 1_000_000)
            onProgress?(mbps)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?()
    }
}

class UploadDelegate: NSObject, URLSessionTaskDelegate {
    var startTime: CFAbsoluteTime = 0
    var totalBytes: Int64 = 0
    var onProgress: ((Double) -> Void)?
    var onComplete: (() -> Void)?

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        if startTime == 0 { startTime = CFAbsoluteTimeGetCurrent() }
        totalBytes = totalBytesSent
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        if elapsed > 0.1 {
            let mbps = (Double(totalBytesSent) * 8.0) / (elapsed * 1_000_000)
            onProgress?(mbps)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?()
    }
}

class SpeedTestManager: ObservableObject {
    @Published var downloadSpeed: String = "—"
    @Published var uploadSpeed: String = "—"
    @Published var isRunning: Bool = false
    @Published var lastTestTime: Date? = nil
    @Published var phase: String = ""
    @Published var menuBarTitle: String = "— ⇅"

    @Published var showDownload: Bool {
        didSet {
            UserDefaults.standard.set(showDownload, forKey: "networkspeed_showDownload")
            updateMenuBarTitle()
        }
    }
    @Published var showUpload: Bool {
        didSet {
            UserDefaults.standard.set(showUpload, forKey: "networkspeed_showUpload")
            updateMenuBarTitle()
        }
    }

    @Published var intervalMinutes: Int {
        didSet { UserDefaults.standard.set(intervalMinutes, forKey: "networkspeed_interval") }
    }

    private var timer: AnyCancellable?
    private var currentSession: URLSession?

    init() {
        let saved = UserDefaults.standard.integer(forKey: "networkspeed_interval")
        self.intervalMinutes = saved > 0 ? saved : 10

        let defaults = UserDefaults.standard
        if defaults.object(forKey: "networkspeed_showDownload") == nil {
            self.showDownload = true
        } else {
            self.showDownload = defaults.bool(forKey: "networkspeed_showDownload")
        }
        if defaults.object(forKey: "networkspeed_showUpload") == nil {
            self.showUpload = false
        } else {
            self.showUpload = defaults.bool(forKey: "networkspeed_showUpload")
        }
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
        phase = "Testing download..."
        menuBarTitle = ".. ⇅"
        downloadSpeed = "—"
        uploadSpeed = "—"

        let finish = { [weak self] in
            guard let self = self else { return }
            self.isRunning = false
            self.lastTestTime = Date()
            self.phase = ""
            self.updateMenuBarTitle()
        }

        let doUpload = { [weak self] in
            guard let self = self else { return }
            if self.showUpload {
                self.phase = "Testing upload..."
                self.runUploadTest { [weak self] ulSpeed in
                    self?.uploadSpeed = String(format: "%.0f", ulSpeed)
                    finish()
                }
            } else {
                finish()
            }
        }

        if showDownload {
            phase = "Testing download..."
            runDownloadTest { [weak self] dlSpeed in
                self?.downloadSpeed = String(format: "%.0f", dlSpeed)
                doUpload()
            }
        } else {
            doUpload()
        }
    }

    private func runDownloadTest(completion: @escaping (Double) -> Void) {
        let delegate = SpeedTestDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        currentSession = session

        let semaphore = DispatchSemaphore(value: 0)
        var finalSpeed: Double = 0

        delegate.onProgress = { [weak self] mbps in
            DispatchQueue.main.async {
                self?.downloadSpeed = String(format: "%.0f", mbps)
                if self?.showDownload == true {
                    self?.menuBarTitle = "\(String(format: "%.0f", mbps))↓"
                }
            }
            finalSpeed = mbps
        }

        delegate.onComplete = {
            let elapsed = CFAbsoluteTimeGetCurrent() - delegate.startTime
            if elapsed > 0 {
                finalSpeed = (Double(delegate.bytesReceived) * 8.0) / (elapsed * 1_000_000)
            }
            semaphore.signal()
        }

        session.dataTask(with: downloadURL).resume()

        DispatchQueue.global(qos: .utility).async {
            semaphore.wait()
            session.invalidateAndCancel()
            DispatchQueue.main.async {
                completion(finalSpeed)
            }
        }
    }

    private func runUploadTest(completion: @escaping (Double) -> Void) {
        let delegate = UploadDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        currentSession = session

        let semaphore = DispatchSemaphore(value: 0)
        var finalSpeed: Double = 0

        delegate.onProgress = { [weak self] mbps in
            DispatchQueue.main.async {
                self?.uploadSpeed = String(format: "%.0f", mbps)
                if self?.showUpload == true {
                    var parts: [String] = []
                    if self?.showDownload == true { parts.append("\(self?.downloadSpeed ?? "—")↓") }
                    parts.append("\(String(format: "%.0f", mbps))↑")
                    self?.menuBarTitle = parts.joined(separator: " ")
                }
            }
            finalSpeed = mbps
        }

        delegate.onComplete = {
            let elapsed = CFAbsoluteTimeGetCurrent() - delegate.startTime
            if elapsed > 0 && delegate.totalBytes > 0 {
                finalSpeed = (Double(delegate.totalBytes) * 8.0) / (elapsed * 1_000_000)
            }
            semaphore.signal()
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let uploadData = Data(count: uploadSize)

        session.uploadTask(with: request, from: uploadData).resume()

        DispatchQueue.global(qos: .utility).async {
            semaphore.wait()
            session.invalidateAndCancel()
            DispatchQueue.main.async {
                completion(finalSpeed)
            }
        }
    }

    func updateMenuBarTitle() {
        if downloadSpeed == "—" && uploadSpeed == "—" {
            menuBarTitle = "— ⇅"
            return
        }
        if downloadSpeed == "Error" {
            menuBarTitle = "Error ⇅"
            return
        }
        var parts: [String] = []
        if showDownload { parts.append("\(downloadSpeed)↓") }
        if showUpload { parts.append("\(uploadSpeed)↑") }
        menuBarTitle = parts.isEmpty ? "⇅" : parts.joined(separator: " ")
    }

    func cancel() {
        currentSession?.invalidateAndCancel()
    }
}
