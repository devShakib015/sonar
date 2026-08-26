import Foundation
import UserNotifications

// Async ICMP ping (non-blocking — uses the process termination handler).
enum Ping {
    static func alive(_ ip: String, waitMs: Int = 800) async -> Bool {
        await withCheckedContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/sbin/ping")
            p.arguments = ["-c", "1", "-W", "\(waitMs)", "-t", "2", ip]
            p.standardOutput = Pipe(); p.standardError = Pipe()
            p.terminationHandler = { proc in cont.resume(returning: proc.terminationStatus == 0) }
            do { try p.run() } catch { cont.resume(returning: false) }
        }
    }

    // Round-trip latency in ms to a host, or nil if unreachable.
    static func latency(_ ip: String) -> Double? {
        let out = Shell.run("/sbin/ping", ["-c", "1", "-W", "1000", "-t", "2", ip])
        guard let range = out.range(of: "time=") else { return nil }
        let tail = out[range.upperBound...]
        let num = tail.prefix { $0.isNumber || $0 == "." }
        return Double(num)
    }
}

// Local ARP neighbour table (populated by the OS + the ping sweep).
enum Arp {
    static func table() -> [String: String] {
        var map: [String: String] = [:]
        let out = Shell.run("/usr/sbin/arp", ["-an"])
        for line in out.split(separator: "\n") {
            // Format: ? (192.168.1.1) at 8c:3b:ad:xx:xx:xx on en0 ifscope [ethernet]
            guard let open = line.firstIndex(of: "("),
                  let close = line.firstIndex(of: ")"),
                  let atRange = line.range(of: ") at ") else { continue }
            let ip = String(line[line.index(after: open)..<close])
            let after = line[atRange.upperBound...]
            let mac = after.split(separator: " ").first.map(String.init) ?? ""
            guard mac.contains(":"), mac != "(incomplete)" else { continue }
            let up = normalizeMAC(mac)
            if up == "FF:FF:FF:FF:FF:FF" { continue }            // broadcast
            if up.hasPrefix("01:00:5E") || up.hasPrefix("33:33") { continue } // multicast
            if let first = Int(ip.split(separator: ".").first ?? ""), first >= 224 { continue }
            map[ip] = up
        }
        return map
    }

    // macOS arp prints MAC octets without zero-padding (e.g. 8:c3:a:...).
    static func normalizeMAC(_ mac: String) -> String {
        mac.split(separator: ":")
            .map { $0.count == 1 ? "0" + $0 : String($0) }
            .joined(separator: ":")
            .uppercased()
    }
}

enum Notifier {
    static func requestAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func newDevice(name: String, ip: String) {
        notify(title: "New device on your network", body: "\(name) — \(ip)")
    }

    static func notify(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var out: [[Element]] = []
        var i = 0
        while i < count { out.append(Array(self[i..<Swift.min(i + size, count)])); i += size }
        return out
    }
}

func formatBytesPerSec(_ bps: Double) -> String {
    let units = ["B/s", "KB/s", "MB/s", "GB/s"]
    var v = bps; var i = 0
    while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
    return String(format: v >= 100 || i == 0 ? "%.0f %@" : "%.1f %@", v, units[i])
}
