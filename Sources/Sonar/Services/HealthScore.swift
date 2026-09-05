import Foundation

struct HealthFactor: Identifiable {
    let id = UUID()
    let label: String
    let delta: Int
    let good: Bool
}

struct HealthReport {
    let score: Int
    let grade: String
    let factors: [HealthFactor]
}

// A single 0–100 network-health/security score derived from data already on hand.
enum HealthScore {
    static func evaluate(devices: [Device], uptimePercent: Double) -> HealthReport {
        var score = 100
        var factors: [HealthFactor] = []

        var warn = 0, caution = 0
        for d in devices where d.isOnline {
            let f = Fingerprint.findings(ports: d.openPorts)
            warn += f.filter { $0.severity == 2 }.count
            caution += f.filter { $0.severity == 1 }.count
        }
        if warn > 0 {
            let p = min(40, warn * 10); score -= p
            factors.append(.init(label: "\(warn) high-risk exposed service\(warn == 1 ? "" : "s")", delta: -p, good: false))
        }
        if caution > 0 {
            let p = min(20, caution * 4); score -= p
            factors.append(.init(label: "\(caution) service\(caution == 1 ? "" : "s") worth reviewing", delta: -p, good: false))
        }
        let untrusted = devices.filter { $0.isOnline && !$0.isThisDevice && !$0.trusted }.count
        if untrusted > 0 {
            let p = min(20, untrusted * 3); score -= p
            factors.append(.init(label: "\(untrusted) untrusted device\(untrusted == 1 ? "" : "s") online", delta: -p, good: false))
        }
        let newd = devices.filter { $0.isNew && $0.isOnline }.count
        if newd > 0 {
            let p = min(15, newd * 5); score -= p
            factors.append(.init(label: "\(newd) new / unrecognized device\(newd == 1 ? "" : "s")", delta: -p, good: false))
        }
        if uptimePercent < 99 {
            score -= 6
            factors.append(.init(label: String(format: "Uptime %.1f%% (below 99%%)", uptimePercent), delta: -6, good: false))
        }
        if warn == 0 && caution == 0 {
            factors.append(.init(label: "No insecure services exposed", delta: 0, good: true))
        }
        if untrusted == 0 && devices.contains(where: { $0.isOnline && !$0.isThisDevice }) {
            factors.append(.init(label: "All devices recognized & trusted", delta: 0, good: true))
        }

        score = max(0, min(100, score))
        let grade = score >= 90 ? "A" : score >= 80 ? "B" : score >= 70 ? "C" : score >= 50 ? "D" : "F"
        return HealthReport(score: score, grade: grade, factors: factors)
    }
}
