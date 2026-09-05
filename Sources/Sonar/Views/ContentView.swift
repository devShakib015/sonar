import SwiftUI

enum Panel: Hashable {
    case overview, radar, diagnostics, wifi, control, monitor, trends, dnsLogs, exposure, uptime, services, settings
    case device(String)
}

struct ContentView: View {
    @EnvironmentObject var scanner: Scanner
    @EnvironmentObject var meter: ThroughputMeter
    @State private var selection: Panel? = .overview
    @State private var showHistory = false
    @State private var search = ""
    @State private var showOnboarding = false
    @State private var booting = true

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
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 0) {
                        GlitchWordmark(size: 21)
                        Spacer()
                    }
                    Text(scanner.localIP.isEmpty ? "\u{25CF} no link" : "\u{25CF} \(scanner.onlineCount) hosts up \u{00B7} \(scanner.localIP)")
                        .font(Term.mono(9)).foregroundStyle(Term.dim).lineLimit(1)
                }
                .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)
                HStack(spacing: 6) {
                    Text(">").font(Term.mono(12, .bold)).foregroundStyle(Term.green)
                    TextField("search", text: $search).textFieldStyle(.plain)
                        .font(Term.mono(12)).foregroundStyle(Term.green)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(Term.dim)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                Divider().overlay(Term.border)
                List(selection: $selection) {
                    Section(header: Text("// TOOLS").font(Term.mono(9, .bold)).foregroundStyle(Term.dim)) {
                        Label("Overview", systemImage: "square.grid.2x2").tag(Panel.overview)
                        Label("Radar", systemImage: "scope").tag(Panel.radar)
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
                        Section(header: Text("// NEW / UNRECOGNIZED").font(Term.mono(9, .bold)).foregroundStyle(Term.amber)) {
                            ForEach(newDevices) { DeviceRow(device: $0).tag(Panel.device($0.id)) }
                        }
                    }
                    Section(header: Text("// ONLINE \u{2014} \(onlineDevices.count + newDevices.count)").font(Term.mono(9, .bold)).foregroundStyle(Term.dim)) {
                        ForEach(onlineDevices) { DeviceRow(device: $0).tag(Panel.device($0.id)) }
                    }
                    if !offlineDevices.isEmpty {
                        Section(header: Text("// RECENTLY OFFLINE").font(Term.mono(9, .bold)).foregroundStyle(Term.faint)) {
                            ForEach(offlineDevices) { DeviceRow(device: $0).tag(Panel.device($0.id)) }
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .font(Term.mono(12))
                .animation(.default, value: scanner.devices.count)
                Divider()
                sidebarFooter
            }
            .frame(minWidth: 300)
        } detail: {
            detailView
        }
        .toolbar { toolbarContent }
        .tint(Term.green)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(onStart: { Task { await scanner.scanNow() } })
        }
        .sheet(isPresented: $showHistory) { HistoryView() }
        .onAppear { scanner.attach(meter); meter.start() }
        .overlay {
            if booting { BootView { finishBoot() }.transition(.opacity) }
        }
        .background(HUDBackground())
        .background(WindowStyler())
        .preferredColorScheme(.dark)
        .crt()
    }

    private func finishBoot() {
        withAnimation(.easeOut(duration: 0.45)) { booting = false }
        if SettingsStore.onboarded {
            if scanner.lastScan == nil { Task { await scanner.scanNow() } }
        } else {
            showOnboarding = true
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .radar:       RadarView(selectDevice: { selection = .device($0) })
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
            if scanner.isScanning { ProgressView(value: scanner.progress).controlSize(.small).tint(Term.green) }
            Text(scanner.statusText).font(Term.mono(10)).foregroundStyle(Term.dim)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            if let last = scanner.lastScan {
                Text("updated \(last.formatted(date: .omitted, time: .shortened))")
                    .font(Term.mono(9)).foregroundStyle(Term.faint)
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            HStack(spacing: 12) {
                HStack(spacing: 3) { Image(systemName: "arrow.down"); Text(formatBytesPerSec(meter.downBps)) }
                    .foregroundStyle(Term.cyan)
                HStack(spacing: 3) { Image(systemName: "arrow.up"); Text(formatBytesPerSec(meter.upBps)) }
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
