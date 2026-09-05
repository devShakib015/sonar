import SwiftUI

enum Panel: Hashable {
    case overview, diagnostics, wifi, control, monitor, trends, dnsLogs, exposure, uptime, services, settings
    case device(String)
}

struct ContentView: View {
    @EnvironmentObject var scanner: Scanner
    @State private var selection: Panel? = .overview
    @State private var showHistory = false
    @State private var search = ""

    private func matchesSearch(_ d: Device) -> Bool {
        guard !search.isEmpty else { return true }
        let q = search.lowercased()
        return d.displayName.lowercased().contains(q) || d.ip.contains(q)
            || (d.vendor ?? "").lowercased().contains(q) || d.mac.lowercased().contains(q)
    }
    private var newDevices: [Device] { scanner.devices.filter { $0.isNew && $0.isOnline && matchesSearch($0) } }
    private var onlineDevices: [Device] { scanner.devices.filter { $0.isOnline && !$0.isNew && matchesSearch($0) } }
    private var offlineDevices: [Device] { scanner.devices.filter { !$0.isOnline && matchesSearch($0) } }

    private func device(_ id: String) -> Device? { scanner.devices.first { $0.id == id } }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                    TextField("Search devices", text: $search).textFieldStyle(.plain)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                Divider()
                List(selection: $selection) {
                    Section("Tools") {
                        Label("Overview", systemImage: "square.grid.2x2").tag(Panel.overview)
                        Label("Diagnostics", systemImage: "stethoscope").tag(Panel.diagnostics)
                        Label("Wi-Fi", systemImage: "wifi").tag(Panel.wifi)
                        Label("Exposure", systemImage: "lock.shield").tag(Panel.exposure)
                        Label("Services", systemImage: "antenna.radiowaves.left.and.right").tag(Panel.services)
                        Label("Control", systemImage: "slider.horizontal.3").tag(Panel.control)
                        Label("Monitor", systemImage: "chart.xyaxis.line").tag(Panel.monitor)
                        Label("Trends", systemImage: "chart.bar.xaxis").tag(Panel.trends)
                        Label("Uptime", systemImage: "bolt.horizontal.circle").tag(Panel.uptime)
                        Label("Settings", systemImage: "gearshape").tag(Panel.settings)
                        Label("DNS Logs", systemImage: "network.badge.shield.half.filled").tag(Panel.dnsLogs)
                    }
                    if !newDevices.isEmpty {
                        Section("New / Unrecognized") {
                            ForEach(newDevices) { DeviceRow(device: $0).tag(Panel.device($0.id)) }
                        }
                    }
                    Section("Online — \(onlineDevices.count + newDevices.count)") {
                        ForEach(onlineDevices) { DeviceRow(device: $0).tag(Panel.device($0.id)) }
                    }
                    if !offlineDevices.isEmpty {
                        Section("Recently offline") {
                            ForEach(offlineDevices) { DeviceRow(device: $0).tag(Panel.device($0.id)) }
                        }
                    }
                }
                .listStyle(.sidebar)
                Divider()
                sidebarFooter
            }
            .frame(minWidth: 300)
        } detail: {
            detailView
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showHistory) { HistoryView() }
        .task { if scanner.lastScan == nil { await scanner.scanNow() } }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .diagnostics: DiagnosticsView()
        case .wifi:        WiFiView()
        case .exposure:    ExposureView()
        case .services:    BonjourView()
        case .settings:    SettingsView()
        case .control:     ControlView()
        case .monitor:     MonitorView()
        case .trends:      TrendsView()
        case .uptime:      ReliabilityView()
        case .dnsLogs:     DNSLogsView()
        case .device(let id):
            if let d = device(id) { DeviceDetailView(device: d) }
            else { OverviewView(openHistory: { showHistory = true }, selectDevice: { selection = .device($0) }) }
        default:
            OverviewView(openHistory: { showHistory = true }, selectDevice: { selection = .device($0) })
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 5) {
            if scanner.isScanning { ProgressView(value: scanner.progress).controlSize(.small) }
            Text(scanner.statusText).font(.caption).foregroundStyle(.secondary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            if let last = scanner.lastScan {
                Text("Updated \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            HStack(spacing: 12) {
                HStack(spacing: 3) { Image(systemName: "arrow.down"); Text(formatBytesPerSec(scanner.downBps)) }
                    .foregroundStyle(.blue)
                HStack(spacing: 3) { Image(systemName: "arrow.up"); Text(formatBytesPerSec(scanner.upBps)) }
                    .foregroundStyle(.green)
            }
            .font(.caption.monospacedDigit()).help("Live throughput on this Mac")

            Button { showHistory = true } label: { Label("Activity", systemImage: "clock.arrow.circlepath") }

            Menu {
                Toggle("Auto-refresh", isOn: Binding(get: { scanner.autoRefresh }, set: { scanner.setAutoRefresh($0) }))
                Divider()
                Picker("Interval", selection: Binding(get: { scanner.interval }, set: { scanner.setInterval($0) })) {
                    Text("Every 30s").tag(TimeInterval(30))
                    Text("Every 1m").tag(TimeInterval(60))
                    Text("Every 5m").tag(TimeInterval(300))
                    Text("Every 15m").tag(TimeInterval(900))
                }
            } label: { Label("Auto", systemImage: scanner.autoRefresh ? "clock.fill" : "clock") }

            Button { Task { await scanner.scanNow() } } label: {
                if scanner.isScanning { Label("Scanning…", systemImage: "rays") }
                else { Label("Scan", systemImage: "dot.radiowaves.left.and.right") }
            }
            .disabled(scanner.isScanning).keyboardShortcut("r", modifiers: .command)
        }
    }
}
