import Foundation
import Darwin

// SSDP / UPnP discovery: sends one M-SEARCH multicast query and collects the
// self-descriptions devices broadcast in reply. Passive-style enumeration —
// devices are designed to answer this; nothing is intercepted or spoofed.
struct SSDPDevice {
    var ip: String
    var server: String?
    var location: String?
    var st: String?
}

enum SSDP {
    static func discover(timeout: TimeInterval = 2.0) -> [String: SSDPDevice] {
        var results: [String: SSDPDevice] = [:]

        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return results }
        defer { close(fd) }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var ttl: Int32 = 2
        setsockopt(fd, Int32(IPPROTO_IP), IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<Int32>.size))
        var tv = timeval(tv_sec: 0, tv_usec: 400_000)   // 0.4s poll slices
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(1900).bigEndian
        inet_pton(AF_INET, "239.255.255.250", &dest.sin_addr)

        let msg = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 1\r\nST: ssdp:all\r\n\r\n"
        let sent = msg.withCString { cstr -> Int in
            withUnsafePointer(to: &dest) { dptr in
                dptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, cstr, strlen(cstr), 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return results }

        let end = Date().addingTimeInterval(timeout)
        var buf = [UInt8](repeating: 0, count: 4096)

        while Date() < end {
            var src = sockaddr_in()
            var srclen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &src) { sptr in
                sptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    recvfrom(fd, &buf, buf.count, 0, sa, &srclen)
                }
            }
            if n <= 0 { continue }

            let ip = ipString(from: src)
            let text = String(decoding: buf[0..<n], as: UTF8.self)
            var dev = results[ip] ?? SSDPDevice(ip: ip, server: nil, location: nil, st: nil)
            for line in text.components(separatedBy: "\r\n") {
                let low = line.lowercased()
                if low.hasPrefix("server:")   { dev.server   = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
                if low.hasPrefix("location:") { dev.location = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces) }
                if low.hasPrefix("st:")       { dev.st       = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
            }
            results[ip] = dev
        }
        return results
    }

    private static func ipString(from addr: sockaddr_in) -> String {
        var a = addr.sin_addr
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &a, &buf, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buf)
    }
}
