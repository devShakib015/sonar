import Foundation
import Darwin

struct BonjourService: Identifiable {
    let id: String
    let name: String
    let type: String       // friendly
    let rawType: String
    var host: String?
    var port: Int?
    var ip: String?
}

// Browses common Bonjour/mDNS service types to show what each device advertises.
final class BonjourBrowser: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var services: [BonjourService] = []
    @Published var scanning = false
    private var browsers: [NetServiceBrowser] = []
    private var pending: [NetService] = []

    static let types: [(String, String)] = [
        ("_airplay._tcp.", "AirPlay"), ("_raop._tcp.", "AirPlay Audio"),
        ("_googlecast._tcp.", "Cast / Chromecast"), ("_spotify-connect._tcp.", "Spotify Connect"),
        ("_ipp._tcp.", "Printer (IPP)"), ("_ipps._tcp.", "Printer (IPPS)"),
        ("_pdl-datastream._tcp.", "Printer (raw)"), ("_printer._tcp.", "Printer (LPR)"),
        ("_ssh._tcp.", "SSH"), ("_sftp-ssh._tcp.", "SFTP"),
        ("_smb._tcp.", "File Sharing (SMB)"), ("_afpovertcp._tcp.", "File Sharing (AFP)"),
        ("_rfb._tcp.", "Screen Sharing (VNC)"), ("_hap._tcp.", "HomeKit"),
        ("_http._tcp.", "Web Service"), ("_daap._tcp.", "Media Library"),
        ("_companion-link._tcp.", "Apple Continuity"), ("_amzn-wplay._tcp.", "Fire TV"),
        ("_nvstream._tcp.", "NVIDIA GameStream")
    ]

    func start() {
        stopAll()
        services = []; scanning = true
        for (raw, _) in Self.types {
            let b = NetServiceBrowser(); b.delegate = self
            b.searchForServices(ofType: raw, inDomain: "local.")
            browsers.append(b)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.finish() }
    }
    func finish() { browsers.forEach { $0.stop() }; scanning = false }
    func stopAll() { browsers.forEach { $0.stop() }; browsers = []; pending = [] }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        pending.append(service)
        service.resolve(withTimeout: 4)
        let bs = BonjourService(id: service.name + service.type, name: service.name,
                                type: Self.friendly(service.type), rawType: service.type)
        if !services.contains(where: { $0.id == bs.id }) { services.append(bs) }
    }
    func netServiceDidResolveAddress(_ sender: NetService) {
        let ip = Self.firstIP(sender)
        if let i = services.firstIndex(where: { $0.id == sender.name + sender.type }) {
            services[i].host = sender.hostName
            services[i].port = sender.port
            services[i].ip = ip
        }
        pending.removeAll { $0 == sender }
    }
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        pending.removeAll { $0 == sender }
    }

    static func friendly(_ raw: String) -> String {
        types.first { $0.0 == raw }?.1 ?? raw
    }
    static func firstIP(_ s: NetService) -> String? {
        guard let addrs = s.addresses else { return nil }
        for data in addrs {
            let ip: String? = data.withUnsafeBytes { raw in
                guard let sa = raw.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return nil }
                if sa.pointee.sa_family == UInt8(AF_INET) {
                    var a = raw.baseAddress!.assumingMemoryBound(to: sockaddr_in.self).pointee
                    var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &a.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
                    return String(cString: buf)
                }
                return nil
            }
            if let ip { return ip }
        }
        return nil
    }
}

// Grabs a device's web-UI <title> for better identification.
enum HTTPTitle {
    static func fetch(ip: String, port: Int, timeout: TimeInterval = 2.5) async -> String? {
        guard let url = URL(string: "http://\(ip):\(port)/") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = timeout
        req.setValue("Sonar", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        let html = String(decoding: data.prefix(30000), as: UTF8.self)
        guard let t = IGD.firstMatch(in: html, pattern: "<title[^>]*>(.*?)</title>", group: 1) else { return nil }
        let clean = t.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\n", with: " ")
        return clean.isEmpty ? nil : String(clean.prefix(80))
    }
}
