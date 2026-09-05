import Foundation
import SwiftUI

// Live up/down throughput, sampled OFF the main actor so the UI never blocks.
// Isolated from Scanner so its 1 Hz updates don't re-render the whole window.
@MainActor
final class ThroughputMeter: ObservableObject {
    @Published var upBps: Double = 0
    @Published var downBps: Double = 0
    @Published var history: [ThroughputSample] = []

    private var timer: Timer?
    private var iface: String?
    private var last: (UInt64, UInt64)?
    private var lastTime: Date?

    func start() {
        timer?.invalidate()
        last = nil; lastTime = nil
        Task { @MainActor in
            self.iface = await Task.detached { NetworkInfo.current()?.interface }.value
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in await self?.tick() }
            }
        }
    }

    private func tick() async {
        guard let iface else {
            self.iface = await Task.detached { NetworkInfo.current()?.interface }.value
            return
        }
        guard let cur = await Task.detached(operation: { NetworkInfo.byteCounters(interface: iface) }).value else { return }
        let now = Date()
        if let prev = last, let lt = lastTime {
            let dt = now.timeIntervalSince(lt)
            if dt > 0 {
                downBps = cur.0 >= prev.0 ? Double(cur.0 - prev.0) / dt : 0
                upBps   = cur.1 >= prev.1 ? Double(cur.1 - prev.1) / dt : 0
                history.append(ThroughputSample(time: now, down: downBps, up: upBps))
                if history.count > 120 { history.removeFirst(history.count - 120) }
            }
        }
        last = cur; lastTime = now
    }
}
