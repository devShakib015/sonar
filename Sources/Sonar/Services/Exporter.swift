import Foundation
import AppKit

enum Exporter {
    private static func iso(_ d: Date) -> String { ISO8601DateFormatter().string(from: d) }
    private static func csvEscape(_ s: String) -> String {
        var v = s
        // Defuse spreadsheet formula injection from network-controlled fields.
        if let f = v.first, "=+-@\t\r".contains(f) { v = "'" + v }
        if v.contains(",") || v.contains("\"") || v.contains("\n") || v.contains("\r") {
            return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return v
    }

    static func csv(_ devices: [Device]) -> String {
        var s = "Name,IP,MAC,Vendor,Type,Online,Trusted,First Seen,Open Ports\n"
        for d in devices {
            let ports = d.openPorts.map { String($0.port) }.joined(separator: " ")
            let row = [d.displayName, d.ip, d.mac, d.vendor ?? "", d.deviceType.label,
                       d.isOnline ? "yes" : "no", d.trusted ? "yes" : "no", iso(d.firstSeen), ports]
            s += row.map(csvEscape).joined(separator: ",") + "\n"
        }
        return s
    }

    static func json(_ devices: [Device]) -> String {
        let arr: [[String: Any]] = devices.map { d in
            ["name": d.displayName, "ip": d.ip, "mac": d.mac, "vendor": d.vendor ?? "",
             "type": d.deviceType.label, "online": d.isOnline, "trusted": d.trusted,
             "firstSeen": iso(d.firstSeen),
             "openPorts": d.openPorts.map { ["port": $0.port, "service": $0.service] }]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted, .sortedKeys]) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    static func report(_ devices: [Device]) -> String {
        var s = "SONAR NETWORK REPORT\nGenerated \(iso(Date()))\nDevices: \(devices.count)  ·  Online: \(devices.filter { $0.isOnline }.count)\n"
        s += String(repeating: "=", count: 60) + "\n\n"
        for d in devices {
            s += "\(d.isOnline ? "●" : "○") \(d.displayName)\n"
            s += "    IP \(d.ip)   MAC \(d.mac.isEmpty ? "—" : d.mac)\n"
            s += "    \(d.deviceType.label)   \(d.vendor ?? "")\n"
            if !d.openPorts.isEmpty { s += "    Ports: \(d.openPorts.map { "\($0.port)" }.joined(separator: ", "))\n" }
            s += "\n"
        }
        return s
    }

    @MainActor static func save(_ text: String, name: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? text.data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }

    @MainActor static func savePDF(_ report: String, name: String) {
        let width: CGFloat = 612
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        tv.string = report
        tv.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        tv.textContainerInset = NSSize(width: 24, height: 24)
        if let container = tv.textContainer, let lm = tv.layoutManager {
            lm.ensureLayout(for: container)
            let used = lm.usedRect(for: container).size
            tv.frame = NSRect(x: 0, y: 0, width: width, height: max(792, used.height + 60))
        }
        let pdf = tv.dataWithPDF(inside: tv.bounds)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        if panel.runModal() == .OK, let url = panel.url { try? pdf.write(to: url, options: .atomic) }
    }
}
