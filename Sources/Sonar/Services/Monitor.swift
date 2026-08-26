import Foundation

// Per-process bandwidth via two nettop snapshots (cumulative counters, diffed).
enum Monitor {
    struct ProcUsage: Identifiable {
        let id = UUID()
        let name: String
        let inBps: Double
        let outBps: Double
    }

    private static func snapshot() -> [String: (UInt64, UInt64)] {
        let out = Shell.run("/usr/bin/nettop",
                            ["-P", "-x", "-J", "bytes_in,bytes_out", "-L", "1", "-n"], timeout: 6)
        var map: [String: (UInt64, UInt64)] = [:]
        for line in out.split(separator: "\n").dropFirst() {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 4, !f[1].isEmpty else { continue }
            map[f[1]] = (UInt64(f[2]) ?? 0, UInt64(f[3]) ?? 0)
        }
        return map
    }

    static func topTalkers() -> [ProcUsage] {
        let a = snapshot()
        Thread.sleep(forTimeInterval: 1.0)
        let b = snapshot()
        var res: [ProcUsage] = []
        for (proc, v2) in b {
            guard let v1 = a[proc] else { continue }
            let din = v2.0 >= v1.0 ? Double(v2.0 - v1.0) : 0
            let dout = v2.1 >= v1.1 ? Double(v2.1 - v1.1) : 0
            guard din + dout > 0 else { continue }
            let display = proc.split(separator: ".").dropLast().joined(separator: ".")
            res.append(ProcUsage(name: display.isEmpty ? proc : display, inBps: din, outBps: dout))
        }
        return Array(res.sorted { ($0.inBps + $0.outBps) > ($1.inBps + $1.outBps) }.prefix(15))
    }
}
