import Foundation

// Thread-safe byte counter used as a URLSession delegate during the download test.
final class ByteMeter: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _bytes = 0
    var capBytes = Int.max
    var task: URLSessionDataTask?
    var onComplete: ((Error?) -> Void)?

    func current() -> Int { lock.lock(); defer { lock.unlock() }; return _bytes }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock(); _bytes += data.count; let b = _bytes; lock.unlock()
        if b >= capBytes { dataTask.cancel() }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?(error)
    }
}

// Internet speed test against Cloudflare's public speed endpoints.
@MainActor
final class SpeedTest: ObservableObject {
    enum Phase { case idle, latency, download, upload, done, failed }

    @Published var phase: Phase = .idle
    @Published var liveMbps: Double = 0
    @Published var downMbps: Double = 0
    @Published var upMbps: Double = 0
    @Published var latencyMs: Double?
    @Published var jitterMs: Double?
    @Published var error: String?

    var isRunning: Bool {
        switch phase { case .latency, .download, .upload: return true; default: return false }
    }
    var phaseText: String {
        switch phase {
        case .latency: return "Measuring latency…"
        case .download: return "Testing download…"
        case .upload: return "Testing upload…"
        case .done: return "Complete"
        case .failed: return "Failed"
        case .idle: return ""
        }
    }

    func start() async {
        error = nil; liveMbps = 0; downMbps = 0; upMbps = 0; latencyMs = nil; jitterMs = nil
        await runLatency()
        await runDownload()
        await runUpload()
        phase = error == nil ? .done : .failed
    }

    private func runLatency() async {
        phase = .latency
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0") else { return }
        let session = URLSession(configuration: .ephemeral)
        var rtts: [Double] = []
        for _ in 0..<8 {
            let t0 = Date()
            do { _ = try await session.data(from: url); rtts.append(Date().timeIntervalSince(t0) * 1000) }
            catch {}
        }
        guard !rtts.isEmpty else { return }
        let avg = rtts.reduce(0, +) / Double(rtts.count)
        latencyMs = avg
        let variance = rtts.map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(rtts.count)
        jitterMs = variance.squareRoot()
    }

    private func runDownload() async {
        phase = .download
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=100000000") else { return }
        let meter = ByteMeter(); meter.capBytes = 100_000_000
        let session = URLSession(configuration: .ephemeral, delegate: meter, delegateQueue: nil)
        let start = Date()

        let poller = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 150_000_000)
                let e = Date().timeIntervalSince(start)
                if e > 0 { liveMbps = Double(meter.current()) * 8 / e / 1_000_000 }
                if e >= 12 { meter.task?.cancel() }
            }
        }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            meter.onComplete = { _ in c.resume() }
            let t = session.dataTask(with: url); meter.task = t; t.resume()
        }
        poller.cancel()
        let e = Date().timeIntervalSince(start)
        downMbps = e > 0 ? Double(meter.current()) * 8 / e / 1_000_000 : 0
        liveMbps = downMbps
        session.invalidateAndCancel()
    }

    private func runUpload() async {
        phase = .upload
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { return }
        let bytes = 20_000_000
        let data = Data(count: bytes)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let start = Date()
        do {
            let session = URLSession(configuration: .ephemeral)
            _ = try await session.upload(for: req, from: data)
            let e = Date().timeIntervalSince(start)
            upMbps = e > 0 ? Double(bytes) * 8 / e / 1_000_000 : 0
        } catch {
            self.error = "Upload failed: \(error.localizedDescription)"
        }
    }
}
