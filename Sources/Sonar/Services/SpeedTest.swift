import Foundation

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
        if downMbps > 0 || upMbps > 0 {
            SpeedHistory.append(SpeedResult(date: Date(), down: downMbps, up: upMbps, ping: latencyMs, jitter: jitterMs))
        }
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
        let session = URLSession(configuration: .ephemeral)
        let chunkBytes = 10_000_000     // 10 MB per request
        let maxChunks = 12              // up to ~120 MB
        let start = Date()
        var total = 0
        for _ in 0..<maxChunks {
            if Date().timeIntervalSince(start) >= 12 { break }   // ~12s cap
            guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(chunkBytes)") else { break }
            do {
                let (data, _) = try await session.data(from: url)
                total += data.count
                let e = Date().timeIntervalSince(start)
                if e > 0 { liveMbps = Double(total) * 8 / e / 1_000_000 }
            } catch {
                self.error = "Download failed: \(error.localizedDescription)"
                break
            }
        }
        let e = Date().timeIntervalSince(start)
        downMbps = (e > 0 && total > 0) ? Double(total) * 8 / e / 1_000_000 : 0
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
