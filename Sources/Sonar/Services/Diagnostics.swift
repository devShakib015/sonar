import Foundation

// Headless self-test: exercises the scanning engine (interface discovery, ARP,
// SSDP, latency, one port scan) and prints a summary. Run: Sonar --diagnose
enum Diagnostics {
    static func run() {
        print("── Sonar diagnostics ──")
        guard let net = NetworkInfo.current() else {
            print("No active network connection found."); return
        }
        print("Interface : \(net.interface)")
        print("This Mac  : \(net.localIP)  (\(net.localMAC))")
        print("Gateway   : \(net.gatewayIP)")
        print("In range  : \(net.hosts.count) host addresses")
        if let lat = Ping.latency(net.gatewayIP) {
            print("Gateway RTT: \(String(format: "%.1f", lat)) ms")
        }

        let arp = Arp.table()
        print("\nARP neighbours: \(arp.count)")
        for (ip, mac) in arp.sorted(by: { $0.key < $1.key }).prefix(10) {
            print("  \(ip.padding(toLength: 16, withPad: " ", startingAt: 0)) \(mac)  [\(OUIDatabase.vendor(for: mac) ?? "unknown")]")
        }

        let ssdp = SSDP.discover(timeout: 2.0)
        print("\nSSDP/UPnP responders: \(ssdp.count)")
        for (ip, dev) in ssdp.sorted(by: { $0.key < $1.key }).prefix(6) {
            print("  \(ip)  \(dev.server ?? dev.st ?? "")")
        }

        let sem = DispatchSemaphore(value: 0)
        Task {
            let ports = await PortScanner.scan(ip: net.gatewayIP)
            let list = ports.map { String($0.port) }.joined(separator: ", ")
            print("\nGateway open ports: \(list.isEmpty ? "none" : list)")
            for p in ports { print("  \(p.port)  \(p.service)") }
            sem.signal()
        }
        sem.wait()

        if let w = WiFi.current() {
            print("\nWi-Fi: ch \(w.channel) \(w.band) \(w.width)  RSSI \(w.rssi)dBm  \(w.security)  SSID=\(w.ssid ?? "nil")")
        }
        let talkers = Monitor.topTalkers()
        print("\nTop talkers: \(talkers.count)")
        for t in talkers.prefix(5) {
            print("  \(t.name)  down \(Int(t.inBps))B/s  up \(Int(t.outBps))B/s")
        }

        print("\n✓ Engine OK")
    }
}
