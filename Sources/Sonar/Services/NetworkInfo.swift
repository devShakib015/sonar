import Foundation

// Discovers the active interface, local addressing, gateway and the host
// range to sweep. Also reads interface byte counters for the throughput meter.
struct NetworkInfo {
    var interface: String
    var localIP: String
    var localMAC: String
    var gatewayIP: String
    var netmaskHex: String
    var hosts: [String]        // candidate host IPs to probe (excludes self)

    static func current() -> NetworkInfo? {
        let route = Shell.run("/sbin/route", ["-n", "get", "default"])
        var iface = ""
        var gateway = ""
        for line in route.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("interface:") { iface = t.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespaces) }
            if t.hasPrefix("gateway:")   { gateway = t.replacingOccurrences(of: "gateway:", with: "").trimmingCharacters(in: .whitespaces) }
        }
        if iface.isEmpty { return nil }

        let localIP = Shell.run("/usr/sbin/ipconfig", ["getifaddr", iface]).trimmingCharacters(in: .whitespacesAndNewlines)
        if localIP.isEmpty { return nil }

        let cfg = Shell.run("/sbin/ifconfig", [iface])
        var mac = ""
        var maskHex = "0xffffff00"
        for raw in cfg.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("ether ") {
                mac = line.replacingOccurrences(of: "ether ", with: "").trimmingCharacters(in: .whitespaces).uppercased()
            }
            if line.hasPrefix("inet ") {
                let parts = line.split(separator: " ").map(String.init)
                if let i = parts.firstIndex(of: "netmask"), i + 1 < parts.count {
                    maskHex = parts[i + 1]
                }
            }
        }

        let hosts = Self.hostRange(ip: localIP, maskHex: maskHex, exclude: localIP)
        return NetworkInfo(interface: iface, localIP: localIP, localMAC: mac,
                           gatewayIP: gateway, netmaskHex: maskHex, hosts: hosts)
    }

    // Compute the list of host addresses in the subnet (capped for large masks).
    static func hostRange(ip: String, maskHex: String, exclude: String) -> [String] {
        guard let ipv = ipToUInt32(ip) else { return [] }
        var mask = UInt32(0xffffff00)
        if maskHex.hasPrefix("0x"), let m = UInt32(maskHex.dropFirst(2), radix: 16) { mask = m }

        var network = ipv & mask
        var broadcast = network | ~mask
        var count = broadcast > network ? broadcast - network - 1 : 0

        // Cap very large subnets to a /24 around the local host to keep sweeps fast.
        if count > 1024 {
            mask = 0xffffff00
            network = ipv & mask
            broadcast = network | ~mask
            count = 254
        }
        guard count > 0 else { return [] }

        var result: [String] = []
        result.reserveCapacity(Int(count))
        var addr = network + 1
        while addr < broadcast {
            let s = uint32ToIP(addr)
            if s != exclude { result.append(s) }
            addr += 1
        }
        return result
    }

    static func ipToUInt32(_ ip: String) -> UInt32? {
        let parts = ip.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4, parts.allSatisfy({ $0 < 256 }) else { return nil }
        return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
    }

    static func uint32ToIP(_ v: UInt32) -> String {
        "\((v >> 24) & 0xff).\((v >> 16) & 0xff).\((v >> 8) & 0xff).\(v & 0xff)"
    }

    // Cumulative (inBytes, outBytes) for the interface, from netstat counters.
    static func byteCounters(interface: String) -> (UInt64, UInt64)? {
        let out = Shell.run("/usr/sbin/netstat", ["-ibn"])
        for raw in out.split(separator: "\n") {
            let f = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard f.count >= 10, f[0] == interface, f[3].contains(":") else { continue }
            if let ib = UInt64(f[6]), let ob = UInt64(f[9]) { return (ib, ob) }
        }
        return nil
    }
}
