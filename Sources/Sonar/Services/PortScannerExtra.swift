import Foundation

extension PortScanner {
    // Scan an arbitrary host across a custom port list (chunked for fd safety).
    static func scanHost(_ ip: String, ports: [Int], connectTimeout: TimeInterval = 0.8) async -> [PortInfo] {
        var found: [PortInfo] = []
        for chunk in ports.chunked(160) {
            let part: [PortInfo] = await withTaskGroup(of: PortInfo?.self) { group in
                for p in chunk {
                    guard let up = UInt16(exactly: p) else { continue }
                    group.addTask {
                        guard await isOpen(ip: ip, port: up, timeout: connectTimeout) else { return nil }
                        return PortInfo(port: p, service: serviceName(p))
                    }
                }
                var acc: [PortInfo] = []
                for await x in group { if let x { acc.append(x) } }
                return acc
            }
            found.append(contentsOf: part)
        }
        return found.sorted { $0.port < $1.port }
    }

    static func serviceName(_ p: Int) -> String { commonServices[p] ?? "open" }

    // Single source of truth: the curated scanner ports, plus extras for the
    // wider ranges the advanced scanner can hit. Built once.
    static let commonServices: [Int: String] = {
        var m = Dictionary(ports.map { ($0.port, $0.service) }, uniquingKeysWith: { a, _ in a })
        for (k, v) in extraServices where m[k] == nil { m[k] = v }
        return m
    }()

    static let extraServices: [Int: String] = [
        21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS", 80: "HTTP", 110: "POP3",
        135: "MS-RPC", 139: "NetBIOS", 143: "IMAP", 443: "HTTPS", 445: "SMB", 515: "LPD",
        548: "AFP", 554: "RTSP", 587: "SMTP", 631: "IPP", 993: "IMAPS", 995: "POP3S",
        1080: "SOCKS", 1433: "MSSQL", 1723: "PPTP", 1883: "MQTT", 3128: "Proxy", 3306: "MySQL",
        3389: "RDP", 5000: "UPnP", 5060: "SIP", 5432: "PostgreSQL", 5555: "ADB", 5900: "VNC",
        6379: "Redis", 8006: "Proxmox", 8080: "HTTP-alt", 8443: "HTTPS-alt", 8883: "MQTTS",
        9000: "PHP-FPM", 9100: "Printer", 9200: "Elasticsearch", 27017: "MongoDB",
        32400: "Plex", 51820: "WireGuard", 62078: "iOS-sync"
    ]
}
