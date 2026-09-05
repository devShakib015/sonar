import Foundation
import Security

// Reads per-device DNS query logs from the user's OWN resolver (NextDNS cloud
// API or a self-hosted Pi-hole v6). This is the legitimate, consent-based way to
// see "which device asked for which domain, when" — no interception, no MITM.
struct DNSQuery: Identifiable {
    let id = UUID()
    let time: Date
    let domain: String
    let device: String
    let status: String
    let type: String

    var blocked: Bool {
        let s = status.uppercased()
        return s == "BLOCKED" || s.contains("GRAVITY") || s.contains("DENY")
            || s.contains("BLOCK") || s.contains("REGEX")
    }
}

struct DNSLogConfig: Codable {
    var provider = "NextDNS"          // "NextDNS" | "Pi-hole"
    var nextdnsProfile = ""
    var nextdnsKey = ""
    var piholeHost = ""
    var piholePassword = ""
}

struct DNSError: LocalizedError { let msg: String; var errorDescription: String? { msg } }

enum DNSLogs {
    static let configKey = "sonar.dnslog.config"

    static func loadConfig() -> DNSLogConfig {
        var c = DNSLogConfig()
        if let d = UserDefaults.standard.data(forKey: configKey),
           let dec = try? JSONDecoder().decode(DNSLogConfig.self, from: d) { c = dec }
        c.nextdnsKey = Keychain.get("nextdnsKey")
        c.piholePassword = Keychain.get("piholePassword")
        return c
    }
    static func saveConfig(_ c: DNSLogConfig) {
        Keychain.set(c.nextdnsKey, for: "nextdnsKey")
        Keychain.set(c.piholePassword, for: "piholePassword")
        var redacted = c; redacted.nextdnsKey = ""; redacted.piholePassword = ""
        if let d = try? JSONEncoder().encode(redacted) { UserDefaults.standard.set(d, forKey: configKey) }
    }

    static func fetch(_ c: DNSLogConfig) async throws -> [DNSQuery] {
        switch c.provider {
        case "Pi-hole": return try await fetchPihole(host: c.piholeHost, password: c.piholePassword)
        default:        return try await fetchNextDNS(profile: c.nextdnsProfile, key: c.nextdnsKey)
        }
    }

    // MARK: NextDNS
    private static func fetchNextDNS(profile: String, key: String, limit: Int = 300) async throws -> [DNSQuery] {
        guard !profile.isEmpty, !key.isEmpty else { throw DNSError(msg: "Enter your NextDNS profile ID and API key.") }
        guard let url = URL(string: "https://api.nextdns.io/profiles/\(profile)/logs?limit=\(limit)") else {
            throw DNSError(msg: "Invalid profile ID.")
        }
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "X-Api-Key")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw DNSError(msg: "No response.") }
        guard http.statusCode == 200 else {
            throw DNSError(msg: http.statusCode == 403 ? "Access denied — check your API key." : "NextDNS returned \(http.statusCode).")
        }
        let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let arr = j?["data"] as? [[String: Any]] ?? []
        return arr.map { item in
            let dev = (item["device"] as? [String: Any])?["name"] as? String
            return DNSQuery(time: parseISO(item["timestamp"] as? String ?? ""),
                     domain: item["domain"] as? String ?? "",
                     device: (dev?.isEmpty == false ? dev! : (item["clientIp"] as? String ?? "Unknown device")),
                     status: item["status"] as? String ?? "default",
                     type: item["type"] as? String ?? "")
        }
    }

    // MARK: Pi-hole v6
    private static func fetchPihole(host: String, password: String) async throws -> [DNSQuery] {
        guard !host.isEmpty else { throw DNSError(msg: "Enter your Pi-hole host or IP.") }
        let base = host.hasPrefix("http") ? host : "http://\(host)"

        // Authenticate → session id
        guard let authURL = URL(string: "\(base)/api/auth") else { throw DNSError(msg: "Invalid host.") }
        var authReq = URLRequest(url: authURL)
        authReq.httpMethod = "POST"
        authReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authReq.httpBody = try JSONSerialization.data(withJSONObject: ["password": password])
        let (adata, aresp) = try await URLSession.shared.data(for: authReq)
        guard (aresp as? HTTPURLResponse)?.statusCode == 200 else {
            throw DNSError(msg: "Pi-hole auth failed — check the host and app password (requires Pi-hole v6).")
        }
        let aj = (try? JSONSerialization.jsonObject(with: adata)) as? [String: Any]
        guard let sid = (aj?["session"] as? [String: Any])?["sid"] as? String else {
            throw DNSError(msg: "Pi-hole did not return a session — is the password correct?")
        }

        // Fetch queries
        guard let qURL = URL(string: "\(base)/api/queries?length=300") else { throw DNSError(msg: "Invalid host.") }
        var qReq = URLRequest(url: qURL)
        qReq.setValue(sid, forHTTPHeaderField: "X-FTL-SID")
        let (qdata, _) = try await URLSession.shared.data(for: qReq)
        let qj = (try? JSONSerialization.jsonObject(with: qdata)) as? [String: Any]
        let arr = qj?["queries"] as? [[String: Any]] ?? []
        return arr.map { item in
            let client = item["client"] as? [String: Any]
            let name = client?["name"] as? String
            let t = (item["time"] as? Double) ?? 0
            return DNSQuery(time: Date(timeIntervalSince1970: t),
                            domain: item["domain"] as? String ?? "",
                            device: (name?.isEmpty == false ? name! : (client?["ip"] as? String ?? "Unknown device")),
                            status: item["status"] as? String ?? "",
                            type: item["type"] as? String ?? "")
        }
    }

    private static func parseISO(_ s: String) -> Date {
        let f1 = ISO8601DateFormatter(); f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        return ISO8601DateFormatter().date(from: s) ?? Date()
    }
}

// Secrets (API keys / passwords) live in the Keychain, never in UserDefaults.
enum Keychain {
    private static let service = "com.shakib.sonar"
    static func set(_ value: String, for account: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
    static func get(_ account: String) -> String {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data, let s = String(data: d, encoding: .utf8) else { return "" }
        return s
    }
}
