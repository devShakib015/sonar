import Foundation
import Network

// Concurrent TCP connect-scan with best-effort banner/version grabbing.
// Connect scans only — no raw packets, no spoofing.
enum PortScanner {
    enum Probe { case none, passive, http }

    struct PortDef { let port: Int; let service: String; let probe: Probe }

    static let queue = DispatchQueue(label: "sonar.portscan", attributes: .concurrent)

    static let ports: [PortDef] = [
        .init(port: 21,    service: "FTP",            probe: .passive),
        .init(port: 22,    service: "SSH",            probe: .passive),
        .init(port: 23,    service: "Telnet",         probe: .passive),
        .init(port: 25,    service: "SMTP",           probe: .passive),
        .init(port: 53,    service: "DNS",            probe: .none),
        .init(port: 80,    service: "HTTP",           probe: .http),
        .init(port: 110,   service: "POP3",           probe: .passive),
        .init(port: 139,   service: "NetBIOS",        probe: .none),
        .init(port: 143,   service: "IMAP",           probe: .passive),
        .init(port: 443,   service: "HTTPS",          probe: .none),
        .init(port: 445,   service: "SMB",            probe: .none),
        .init(port: 515,   service: "LPD (print)",    probe: .none),
        .init(port: 548,   service: "AFP",            probe: .none),
        .init(port: 554,   service: "RTSP (camera)",  probe: .none),
        .init(port: 631,   service: "IPP (print)",    probe: .http),
        .init(port: 993,   service: "IMAPS",          probe: .none),
        .init(port: 1883,  service: "MQTT",           probe: .none),
        .init(port: 3306,  service: "MySQL",          probe: .passive),
        .init(port: 3389,  service: "RDP",            probe: .none),
        .init(port: 5000,  service: "UPnP/AirPlay",   probe: .http),
        .init(port: 5432,  service: "PostgreSQL",     probe: .none),
        .init(port: 5555,  service: "ADB (Android)",  probe: .none),
        .init(port: 5900,  service: "VNC",            probe: .passive),
        .init(port: 6379,  service: "Redis",          probe: .none),
        .init(port: 8008,  service: "Chromecast",     probe: .http),
        .init(port: 8009,  service: "Chromecast",     probe: .none),
        .init(port: 8080,  service: "HTTP-alt",       probe: .http),
        .init(port: 8443,  service: "HTTPS-alt",      probe: .none),
        .init(port: 8888,  service: "HTTP-alt",       probe: .http),
        .init(port: 9100,  service: "Raw print",      probe: .none),
        .init(port: 32400, service: "Plex",           probe: .http),
        .init(port: 62078, service: "iOS sync",       probe: .none)
    ]

    static func scan(ip: String, connectTimeout: TimeInterval = 1.0) async -> [PortInfo] {
        await withTaskGroup(of: PortInfo?.self) { group in
            for def in ports {
                group.addTask { await probeOne(ip: ip, def: def, timeout: connectTimeout) }
            }
            var found: [PortInfo] = []
            for await item in group { if let item { found.append(item) } }
            return found.sorted { $0.port < $1.port }
        }
    }

    private static func probeOne(ip: String, def: PortDef, timeout: TimeInterval) async -> PortInfo? {
        guard await isOpen(ip: ip, port: UInt16(def.port), timeout: timeout) else { return nil }
        var service = def.service
        if def.probe != .none {
            if let banner = await grabBanner(ip: ip, port: UInt16(def.port), probe: def.probe, timeout: 1.0),
               !banner.isEmpty {
                service += " — " + banner
            }
        }
        return PortInfo(port: def.port, service: service)
    }

    private final class Once {
        private let lock = NSLock(); private var done = false
        func fire() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
    }

    static func isOpen(ip: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        return await withCheckedContinuation { cont in
            let conn = NWConnection(host: NWEndpoint.Host(ip), port: nwPort, using: .tcp)
            let once = Once()
            func finish(_ open: Bool) { if once.fire() { conn.cancel(); cont.resume(returning: open) } }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:              finish(true)
                case .failed, .cancelled: finish(false)
                default:                  break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }

    private static func grabBanner(ip: String, port: UInt16, probe: Probe, timeout: TimeInterval) async -> String? {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return nil }
        return await withCheckedContinuation { cont in
            let conn = NWConnection(host: NWEndpoint.Host(ip), port: nwPort, using: .tcp)
            let once = Once()
            func finish(_ banner: String?) { if once.fire() { conn.cancel(); cont.resume(returning: banner) } }

            func readReply(http: Bool) {
                conn.receive(minimumIncompleteLength: 1, maximumLength: 1400) { data, _, _, _ in
                    finish(http ? httpServer(data) : cleanBanner(data))
                }
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if probe == .http {
                        let req = "HEAD / HTTP/1.0\r\nHost: \(ip)\r\nUser-Agent: Sonar\r\nConnection: close\r\n\r\n"
                        conn.send(content: req.data(using: .utf8), completion: .contentProcessed { _ in readReply(http: true) })
                    } else {
                        readReply(http: false)
                    }
                case .failed, .cancelled:
                    finish(nil)
                default: break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }

    private static func cleanBanner(_ data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        let raw = String(decoding: data, as: UTF8.self)
        let line = raw.split(whereSeparator: { $0 == "\r" || $0 == "\n" }).first.map(String.init) ?? raw
        let printable = line.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0.isPunctuation || $0.isSymbol || $0 == " ") }
        let trimmed = printable.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(72))
    }

    private static func httpServer(_ data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        let raw = String(decoding: data, as: UTF8.self)
        for line in raw.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("server:") {
                let v = line.dropFirst(7).trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { return "Server: " + String(v.prefix(64)) }
            }
        }
        return nil
    }
}
