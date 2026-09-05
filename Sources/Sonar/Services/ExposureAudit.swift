import Foundation
import Darwin

struct PortMapping: Identifiable {
    let id = UUID()
    let externalPort: Int
    let proto: String
    let internalClient: String
    let internalPort: Int
    let description: String
    let enabled: Bool
}

struct ExposureResult {
    var upnpAvailable = false
    var externalIP: String?
    var mappings: [PortMapping] = []
    var note: String?
}

// Reads the router's UPnP Internet Gateway Device to list ports forwarded to the
// internet (what's actually exposed). Reads your own router's config — no attack.
enum IGD {
    static func audit() async -> ExposureResult {
        var result = ExposureResult()
        guard let location = discoverLocation() else {
            result.note = "No UPnP Internet Gateway Device found. Your router may have UPnP disabled — a safe default (nothing can auto-open ports)."
            return result
        }
        guard let (controlURL, serviceType) = await serviceInfo(location: location) else {
            result.upnpAvailable = true
            result.note = "Found a UPnP gateway but couldn't read its WAN connection service."
            return result
        }
        result.upnpAvailable = true
        result.externalIP = await soapExternalIP(controlURL: controlURL, serviceType: serviceType)
        var idx = 0
        while idx < 100 {
            guard let m = await soapMapping(controlURL: controlURL, serviceType: serviceType, index: idx) else { break }
            result.mappings.append(m)
            idx += 1
        }
        if result.mappings.isEmpty {
            result.note = "UPnP is enabled but there are no active port forwards — nothing is being auto-exposed to the internet."
        }
        return result
    }

    static func discoverLocation(timeout: TimeInterval = 2.0) -> String? {
        let fd = socket(AF_INET, SOCK_DGRAM, 0); guard fd >= 0 else { return nil }; defer { close(fd) }
        var tv = timeval(tv_sec: 0, tv_usec: 400_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var dest = sockaddr_in(); dest.sin_family = sa_family_t(AF_INET); dest.sin_port = in_port_t(1900).bigEndian
        inet_pton(AF_INET, "239.255.255.250", &dest.sin_addr)
        let msg = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\n\r\n"
        _ = msg.withCString { c in withUnsafePointer(to: &dest) { d in d.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
            sendto(fd, c, strlen(c), 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size)) } } }
        let end = Date().addingTimeInterval(timeout)
        var buf = [UInt8](repeating: 0, count: 4096)
        while Date() < end {
            let n = recv(fd, &buf, buf.count, 0)
            if n <= 0 { continue }
            let text = String(decoding: buf[0..<n], as: UTF8.self)
            for line in text.components(separatedBy: "\r\n") where line.lowercased().hasPrefix("location:") {
                return String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    static func serviceInfo(location: String) async -> (String, String)? {
        guard let url = URL(string: location) else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 6
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        let xml = String(decoding: data, as: UTF8.self)
        let base = urlBase(location: url, xml: xml)
        for block in matches(in: xml, pattern: "<service>(.*?)</service>", group: 1, dotAll: true) {
            guard let st = firstMatch(in: block, pattern: "<serviceType>([^<]*)</serviceType>", group: 1) else { continue }
            if st.contains("WANIPConnection") || st.contains("WANPPPConnection") {
                guard var ctl = firstMatch(in: block, pattern: "<controlURL>([^<]*)</controlURL>", group: 1) else { continue }
                if !ctl.hasPrefix("http") {
                    if !ctl.hasPrefix("/") { ctl = "/" + ctl }
                    ctl = base + ctl
                }
                return (ctl, st)
            }
        }
        return nil
    }

    static func urlBase(location: URL, xml: String) -> String {
        if let b = firstMatch(in: xml, pattern: "<URLBase>([^<]*)</URLBase>", group: 1), b.hasPrefix("http") {
            return b.hasSuffix("/") ? String(b.dropLast()) : b
        }
        var s = "\(location.scheme ?? "http")://\(location.host ?? "")"
        if let port = location.port { s += ":\(port)" }
        return s
    }

    static func soapExternalIP(controlURL: String, serviceType: String) async -> String? {
        let body = soapBody(action: "GetExternalIPAddress", serviceType: serviceType, args: "")
        guard let resp = await soapCall(controlURL: controlURL, serviceType: serviceType, action: "GetExternalIPAddress", body: body) else { return nil }
        return firstMatch(in: resp, pattern: "<NewExternalIPAddress>([^<]*)</NewExternalIPAddress>", group: 1)
    }

    static func soapMapping(controlURL: String, serviceType: String, index: Int) async -> PortMapping? {
        let body = soapBody(action: "GetGenericPortMappingEntry", serviceType: serviceType,
                            args: "<NewPortMappingIndex>\(index)</NewPortMappingIndex>")
        guard let resp = await soapCall(controlURL: controlURL, serviceType: serviceType, action: "GetGenericPortMappingEntry", body: body) else { return nil }
        if resp.contains("<errorCode>") || resp.contains(":Fault") { return nil }  // end of list
        let ext = Int(firstMatch(in: resp, pattern: "<NewExternalPort>([^<]*)</NewExternalPort>", group: 1) ?? "") ?? 0
        let proto = firstMatch(in: resp, pattern: "<NewProtocol>([^<]*)</NewProtocol>", group: 1) ?? "?"
        let client = firstMatch(in: resp, pattern: "<NewInternalClient>([^<]*)</NewInternalClient>", group: 1) ?? ""
        let inPort = Int(firstMatch(in: resp, pattern: "<NewInternalPort>([^<]*)</NewInternalPort>", group: 1) ?? "") ?? 0
        let desc = firstMatch(in: resp, pattern: "<NewPortMappingDescription>([^<]*)</NewPortMappingDescription>", group: 1) ?? ""
        let enabled = (firstMatch(in: resp, pattern: "<NewEnabled>([^<]*)</NewEnabled>", group: 1) ?? "1") == "1"
        if client.isEmpty && ext == 0 { return nil }
        return PortMapping(externalPort: ext, proto: proto, internalClient: client, internalPort: inPort, description: desc, enabled: enabled)
    }

    static func soapBody(action: String, serviceType: String, args: String) -> String {
        "<?xml version=\"1.0\"?><s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:\(action) xmlns:u=\"\(serviceType)\">\(args)</u:\(action)></s:Body></s:Envelope>"
    }

    static func soapCall(controlURL: String, serviceType: String, action: String, body: String) async -> String? {
        guard let url = URL(string: controlURL) else { return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        req.setValue("\"\(serviceType)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        req.httpBody = body.data(using: .utf8); req.timeoutInterval = 6
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func firstMatch(in s: String, pattern: String, group: Int) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return nil }
        guard let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let gr = Range(m.range(at: group), in: s) else { return nil }
        return String(s[gr])
    }
    static func matches(in s: String, pattern: String, group: Int, dotAll: Bool) -> [String] {
        var opts: NSRegularExpression.Options = [.caseInsensitive]
        if dotAll { opts.insert(.dotMatchesLineSeparators) }
        guard let re = try? NSRegularExpression(pattern: pattern, options: opts) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s))
            .compactMap { Range($0.range(at: group), in: s).map { String(s[$0]) } }
    }
}
