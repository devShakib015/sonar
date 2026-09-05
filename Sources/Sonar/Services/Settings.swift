import Foundation
import ServiceManagement
import AppKit

enum SettingsStore {
    static var menuBarOnly: Bool {
        get { UserDefaults.standard.bool(forKey: "sonar.menuBarOnly") }
        set { UserDefaults.standard.set(newValue, forKey: "sonar.menuBarOnly") }
    }
    static var notifyJoinLeave: Bool {
        get { UserDefaults.standard.bool(forKey: "sonar.notifyJoinLeave") }
        set { UserDefaults.standard.set(newValue, forKey: "sonar.notifyJoinLeave") }
    }
    static var onboarded: Bool {
        get { UserDefaults.standard.bool(forKey: "sonar.onboarded") }
        set { UserDefaults.standard.set(newValue, forKey: "sonar.onboarded") }
    }
}

enum LoginItem {
    static var enabled: Bool { SMAppService.mainApp.status == .enabled }
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        do {
            if on { if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() } }
            else { if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } }
            return true
        } catch { return false }
    }
}

enum ActivationPolicy {
    static func apply(menuBarOnly: Bool) {
        NSApp.setActivationPolicy(menuBarOnly ? .accessory : .regular)
        if !menuBarOnly { NSApp.activate(ignoringOtherApps: true) }
    }
}
