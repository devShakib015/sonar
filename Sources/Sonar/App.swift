import SwiftUI
import AppKit

@main
struct SonarMain {
    static func main() {
        if CommandLine.arguments.contains("--diagnose") {
            Diagnostics.run()
            return
        }
        SonarApp.main()
    }
}

struct SonarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var scanner = Scanner()
    @StateObject private var uptime = UptimeMonitor()
    @StateObject private var meter = ThroughputMeter()

    var body: some Scene {
        Window("Sonar", id: "main") {
            ContentView()
                .environmentObject(scanner)
                .environmentObject(uptime)
                .environmentObject(meter)
                .frame(minWidth: 940, minHeight: 620)
        }
        .windowToolbarStyle(.unified)

        MenuBarExtra("Sonar", systemImage: "dot.radiowaves.left.and.right") {
            MenuBarView()
                .environmentObject(scanner)
                .environmentObject(meter)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let menuBarOnly = SettingsStore.menuBarOnly
        NSApp.setActivationPolicy(menuBarOnly ? .accessory : .regular)
        if !menuBarOnly { NSApp.activate(ignoringOtherApps: true) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
