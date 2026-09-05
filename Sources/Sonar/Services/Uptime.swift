import Foundation

struct OutageRecord: Codable, Identifiable {
    var id = UUID()
    let start: Date
    var end: Date?
    let scope: String      // "internet" or "local"
    var durationSec: Double?
}

struct SpeedResult: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let down: Double
    let up: Double
    let ping: Double?
    let jitter: Double?
}

enum SpeedHistory {
    private static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sonar", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("speedtests.json")
    }
    static func load() -> [SpeedResult] {
        (try? JSONDecoder().decode([SpeedResult].self, from: Data(contentsOf: url))) ?? []
    }
    static func append(_ r: SpeedResult) {
        var a = load(); a.insert(r, at: 0); if a.count > 200 { a = Array(a.prefix(200)) }
        if let d = try? JSONEncoder().encode(a) { try? d.write(to: url) }
    }
}

// Continuously checks gateway + internet reachability and logs outages.
@MainActor final class UptimeMonitor: ObservableObject {
    @Published var internetUp = true
    @Published var gatewayUp = true
    @Published var monitoring = true
    @Published var lastCheck: Date?
    @Published var outages: [OutageRecord] = []

    private var timer: Timer?
    private var current: OutageRecord?
    private let startedAt = Date()
    private let url: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sonar", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("outages.json")
        if let d = try? Data(contentsOf: url), let o = try? JSONDecoder().decode([OutageRecord].self, from: d) { outages = o }
        start()
    }

    func start() {
        monitoring = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        Task { await check() }
    }
    func stop() { monitoring = false; timer?.invalidate(); timer = nil }
    func toggle() { monitoring ? stop() : start() }

    var currentOutage: OutageRecord? { current }

    func check() async {
        let gw = NetworkInfo.current()?.gatewayIP ?? ""
        let gwOK = gw.isEmpty ? true : await Ping.alive(gw)
        var netOK = await Ping.alive("1.1.1.1")
        if !netOK { netOK = await Ping.alive("8.8.8.8") }
        gatewayUp = gwOK; internetUp = netOK; lastCheck = Date()

        if !netOK {
            if current == nil {
                current = OutageRecord(start: Date(), end: nil, scope: gwOK ? "internet" : "local", durationSec: nil)
            }
        } else if var o = current {
            o.end = Date(); o.durationSec = o.end!.timeIntervalSince(o.start)
            outages.insert(o, at: 0)
            if outages.count > 500 { outages.removeLast(outages.count - 500) }
            current = nil; save()
            Notifier.notify(title: "Connection restored", body: "Was down for \(Self.fmt(o.durationSec ?? 0))")
        }
    }

    func uptimePercent(hours: Double) -> Double {
        let effectiveStart = max(Date().addingTimeInterval(-hours * 3600), startedAt)
        let observed = Date().timeIntervalSince(effectiveStart)
        guard observed > 0 else { return 100 }
        var down = 0.0
        for o in outages {
            let s = max(o.start, effectiveStart), e = o.end ?? Date()
            if e > s { down += e.timeIntervalSince(s) }
        }
        if let c = current { down += Date().timeIntervalSince(max(c.start, effectiveStart)) }
        return max(0, min(100, (1 - down / observed) * 100))
    }

    static func fmt(_ s: Double) -> String {
        if s < 60 { return String(format: "%.0fs", s) }
        if s < 3600 { return "\(Int(s/60))m \(Int(s.truncatingRemainder(dividingBy: 60)))s" }
        return String(format: "%.1fh", s / 3600)
    }

    private func save() { if let d = try? JSONEncoder().encode(outages) { try? d.write(to: url) } }
}
