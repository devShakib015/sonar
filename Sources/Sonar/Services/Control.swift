import Foundation
import AppKit
import Darwin

// Legitimate "take control of your own network" actions. Every system change
// (DNS, firewall) goes through macOS's own administrator-authorization dialog —
// Sonar never sees or handles the password.
enum Control {

    // MARK: Wake-on-LAN (magic packet)
    @discardableResult
    static func wake(mac: String) -> Bool {
        let bytes = mac.split(whereSeparator: { $0 == ":" || $0 == "-" }).compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return false }
        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }

        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(9).bigEndian
        inet_pton(AF_INET, "255.255.255.255", &addr.sin_addr)

        let sent = packet.withUnsafeBytes { raw -> Int in
            withUnsafePointer(to: &addr) { a in
                a.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, raw.baseAddress, raw.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        return sent == packet.count
    }

    // MARK: DNS
    static func primaryService() -> String {
        guard let iface = NetworkInfo.current()?.interface else { return "Wi-Fi" }
        let out = Shell.run("/usr/sbin/networksetup", ["-listnetworkserviceorder"])
        for line in out.split(separator: "\n") where line.contains("Device: \(iface)") {
            if let r = line.range(of: "Hardware Port: "), let e = line.range(of: ", Device:") {
                return String(line[r.upperBound..<e.lowerBound])
            }
        }
        return "Wi-Fi"
    }

    static func currentDNS() -> String {
        let out = Shell.run("/usr/sbin/networksetup", ["-getdnsservers", primaryService()])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if out.isEmpty || out.lowercased().contains("aren't any") { return "Automatic (DHCP)" }
        return out.replacingOccurrences(of: "\n", with: ", ")
    }

    static func isValidIP(_ s: String) -> Bool {
        var v4 = in_addr(); var v6 = in6_addr()
        return inet_pton(AF_INET, s, &v4) == 1 || inet_pton(AF_INET6, s, &v6) == 1
    }

    @discardableResult
    static func setDNS(_ servers: [String]) -> Bool {
        // Reject anything that isn't a clean IP literal — prevents shell injection as root.
        guard servers.allSatisfy({ isValidIP($0) }) else { return false }
        let arg = servers.isEmpty ? "empty" : servers.joined(separator: " ")
        let svc = primaryService()
        let script = "do shell script \"/usr/sbin/networksetup -setdnsservers \\\"\(svc)\\\" \(arg)\" with administrator privileges"
        return runOsa(script)
    }

    // MARK: Firewall
    static func firewallEnabled() -> Bool? {
        let out = Shell.run("/usr/libexec/ApplicationFirewall/socketfilterfw", ["--getglobalstate"]).lowercased()
        if out.contains("enabled") { return true }
        if out.contains("disabled") { return false }
        return nil
    }

    @discardableResult
    static func setFirewall(_ on: Bool) -> Bool {
        let script = "do shell script \"/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate \(on ? "on" : "off")\" with administrator privileges"
        return runOsa(script)
    }

    // MARK: Launchers
    static func open(_ urlString: String) { if let u = URL(string: urlString) { NSWorkspace.shared.open(u) } }

    static func sshTo(_ host: String) {
        runOsa("tell application \"Terminal\"\nactivate\ndo script \"ssh \(host)\"\nend tell")
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @discardableResult
    static func runOsa(_ script: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        p.standardOutput = Pipe(); p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus == 0 } catch { return false }
    }
}
