import Foundation

// Persists time-series metrics (online count, throughput, latency) to disk so
// trend charts survive relaunches. Rolling 7-day retention.
final class MetricsStore {
    private(set) var samples: [MetricSample] = []
    private let url: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Sonar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("metrics.json")
        load()
    }

    func record(_ s: MetricSample) {
        samples.append(s)
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        samples.removeAll { $0.t < cutoff }
        if samples.count > 20000 { samples.removeFirst(samples.count - 20000) }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(samples) { try? data.write(to: url) }
    }
    private func load() {
        if let d = try? Data(contentsOf: url),
           let s = try? JSONDecoder().decode([MetricSample].self, from: d) { samples = s }
    }
}
