import SwiftUI

struct BonjourView: View {
    @StateObject private var browser = BonjourBrowser()

    private var sorted: [BonjourService] {
        browser.services.sorted { ($0.type, $0.name) < ($1.type, $1.name) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bonjour Services").font(.largeTitle.weight(.bold))
                        Text("What each device advertises on the network — AirPlay, printers, HomeKit, SSH, file sharing and more.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(browser.scanning ? "Scanning…" : "Scan services") { browser.start() }
                        .buttonStyle(.borderedProminent).disabled(browser.scanning)
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SectionTitle(text: "Discovered services", icon: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if browser.scanning { ProgressView().controlSize(.small) }
                            Text("\(browser.services.count)").foregroundStyle(.secondary).font(.callout.monospacedDigit())
                        }
                        if browser.services.isEmpty {
                            Text(browser.scanning ? "Listening for advertisements…" : "Press “Scan services” to browse the network.")
                                .font(.callout).foregroundStyle(.secondary)
                        } else {
                            ForEach(sorted) { s in
                                HStack(spacing: 10) {
                                    Text(s.type)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(Capsule().fill(Color.teal.opacity(0.16)))
                                        .foregroundStyle(.teal)
                                        .frame(width: 150, alignment: .leading)
                                    Text(s.name).lineLimit(1)
                                    Spacer()
                                    if let ip = s.ip, let port = s.port {
                                        Text("\(ip):\(port)").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                                    } else if let h = s.host {
                                        Text(h).font(.system(.caption, design: .monospaced)).foregroundStyle(.tertiary)
                                    } else {
                                        Text("resolving…").font(.caption2).foregroundStyle(.tertiary)
                                    }
                                }
                                .font(.callout)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Services")
        .onAppear { if browser.services.isEmpty { browser.start() } }
    }
}
