import Foundation

// Diagnostic network utilities: DNS, WHOIS, traceroute, IP geolocation, public IP.
enum NetTools {
    static func dnsLookup(_ name: String, type: String) -> String {
        let dig = "/usr/bin/dig"
        if FileManager.default.isExecutableFile(atPath: dig) {
            let out = Shell.run(dig, ["+short", type, name], timeout: 8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return out.isEmpty ? "(no records)" : out
        }
        let out = Shell.run("/usr/bin/host", ["-t", type, name], timeout: 8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? "(no records)" : out
    }

    static func whois(_ domain: String) -> String {
        let out = Shell.run("/usr/bin/whois", [domain], timeout: 15)
        return out.isEmpty ? "(no WHOIS data)" : String(out.prefix(8000))
    }

    struct TraceHop: Identifiable {
        let id = UUID()
        let hop: Int
        let ip: String
        let ms: Double?
        var geo: String?
    }

    static func traceroute(_ host: String) -> [TraceHop] {
        let out = Shell.run("/usr/sbin/traceroute",
                            ["-n", "-w", "1", "-q", "1", "-m", "20", host], timeout: 45)
        var hops: [TraceHop] = []
        for line in out.split(separator: "\n") {
            let f = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard let hop = Int(f.first ?? "") else { continue }
            var ip = "*"; var ms: Double?
            for (i, tok) in f.enumerated() {
                let parts = tok.split(separator: ".")
                if parts.count == 4, Int(parts[0]) != nil {
                    ip = tok
                    if i + 1 < f.count { ms = Double(f[i + 1]) }
                    break
                }
            }
            hops.append(TraceHop(hop: hop, ip: ip, ms: ms, geo: nil))
        }
        return hops
    }

    struct PublicIP { var ip, city, region, country, org: String }

    static func publicIP() async -> PublicIP? {
        guard let url = URL(string: "https://ipwho.is/") else { return nil }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 5
            let (data, _) = try await URLSession.shared.data(for: req)
            let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let conn = j["connection"] as? [String: Any]
            return PublicIP(ip: j["ip"] as? String ?? "—",
                            city: j["city"] as? String ?? "",
                            region: j["region"] as? String ?? "",
                            country: j["country"] as? String ?? "",
                            org: conn?["isp"] as? String ?? conn?["org"] as? String ?? "")
        } catch { return nil }
    }

    static func geolocate(_ ip: String) async -> String? {
        let o = ip.split(separator: ".").compactMap { Int($0) }
        if ip == "*" || o.count != 4
            || o[0] == 10 || o[0] == 127
            || (o[0] == 172 && (16...31).contains(o[1]))
            || (o[0] == 192 && o[1] == 168)
            || (o[0] == 169 && o[1] == 254)
            || (o[0] == 100 && (64...127).contains(o[1])) { return nil }
        guard let url = URL(string: "https://ipwho.is/\(ip)") else { return nil }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 5
            let (data, _) = try await URLSession.shared.data(for: req)
            let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            guard (j["success"] as? Bool) == true else { return nil }
            let city = j["city"] as? String ?? ""
            let country = j["country"] as? String ?? ""
            let isp = (j["connection"] as? [String: Any])?["isp"] as? String ?? ""
            let loc = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
            return [loc, isp].filter { !$0.isEmpty }.joined(separator: " · ")
        } catch { return nil }
    }
}
