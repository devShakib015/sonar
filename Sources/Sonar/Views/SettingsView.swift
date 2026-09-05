import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var scanner: Scanner
    @State private var launchAtLogin = LoginItem.enabled
    @State private var menuBarOnly = SettingsStore.menuBarOnly

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings").font(.largeTitle.weight(.bold))

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: "Startup & appearance", icon: "power")
                        Toggle("Launch Sonar at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, v in
                                SettingsStore.launchAtLogin = v
                                _ = LoginItem.set(v)
                            }
                        Toggle("Menu-bar only (hide Dock icon)", isOn: $menuBarOnly)
                            .onChange(of: menuBarOnly) { _, v in
                                SettingsStore.menuBarOnly = v
                                ActivationPolicy.apply(menuBarOnly: v)
                            }
                        Text("Menu-bar-only turns Sonar into a background monitor — it keeps scanning and alerting from the menu bar with no Dock icon. Reopen the window from the menu-bar icon.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: "Alerts", icon: "bell.badge")
                        Toggle("Notify on any device joining or leaving", isOn: Binding(
                            get: { scanner.notifyJoinLeave },
                            set: { scanner.notifyJoinLeave = $0 }))
                        Text("New/unknown devices always alert. Per-device alerts can be set on each device's detail page.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(text: "About", icon: "info.circle")
                        InfoRow(label: "Version", value: "1.2.0")
                        InfoRow(label: "Interface", value: scanner.interfaceName)
                        Link("github.com/devShakib015/sonar", destination: URL(string: "https://github.com/devShakib015/sonar")!)
                            .font(.callout)
                        Text("Free & open source (MIT). Fully local — no tracking.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Settings")
    }
}
