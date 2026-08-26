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

    var body: some Scene {
        Window("Sonar", id: "main") {
            ContentView()
                .environmentObject(scanner)
                .frame(minWidth: 940, minHeight: 620)
        }
        .windowToolbarStyle(.unified)

        MenuBarExtra("Sonar", systemImage: "dot.radiowaves.left.and.right") {
            MenuBarView()
                .environmentObject(scanner)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
