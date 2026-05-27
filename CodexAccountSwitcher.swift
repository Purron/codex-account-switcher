import AppKit
import Foundation

struct CommandResult {
    let status: Int32
    let output: String
}

struct UsageSnapshot {
    let remainingPercent: Int?
    let resetsAt: String?
    let capturedAt: String?
}

struct AccountUsageSummary {
    let fiveHour: UsageSnapshot
    let weekly: UsageSnapshot
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var usageTimer: Timer?
    private let scriptPath: String

    override init() {
        if let bundled = Bundle.main.path(forResource: "codex-account-switcher", ofType: "sh") {
            scriptPath = bundled
        } else {
            scriptPath = FileManager.default.currentDirectoryPath + "/codex-account-switcher.sh"
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItemIcon()
        refreshUsageDisplay()
        usageTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshUsageDisplay()
        }
        rebuildMenu()
    }

    @objc private func rebuildMenu() {
        let menu = NSMenu()
        let active = run(["active"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let profiles = run(["list", "--plain"]).output
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty }

        if profiles.isEmpty {
            let item = NSMenuItem(title: "No profiles yet", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for profile in profiles {
                let summary = usageSummary(forProfile: profile)
                let item = NSMenuItem(title: profileMenuTitle(profile: profile, summary: summary), action: nil, keyEquivalent: "")
                item.state = profile == active ? .on : .off
                item.submenu = profileSubmenu(profile: profile, summary: summary, isActive: profile == active)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(makeItem(title: usageMenuTitle(), action: #selector(refreshUsageNow)))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Capture Current Account...", action: #selector(captureCurrent)))
        menu.addItem(makeItem(title: "Refresh", action: #selector(rebuildMenu), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Open Profiles Folder", action: #selector(openProfilesFolder)))
        menu.addItem(makeItem(title: "Open Codex", action: #selector(openCodex), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Quit Switcher", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func makeItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func profileSubmenu(profile: String, summary: AccountUsageSummary?, isActive: Bool) -> NSMenu {
        let submenu = NSMenu()

        let switchTitle = isActive ? "Current Account" : "Switch to \(profile)"
        let switchItem = NSMenuItem(title: switchTitle, action: #selector(switchProfile(_:)), keyEquivalent: "")
        switchItem.target = self
        switchItem.representedObject = profile
        switchItem.isEnabled = !isActive
        submenu.addItem(switchItem)

        submenu.addItem(.separator())
        addUsageWindowItems(to: submenu, label: "5h", snapshot: summary?.fiveHour)
        submenu.addItem(.separator())
        addUsageWindowItems(to: submenu, label: "1w", snapshot: summary?.weekly)

        return submenu
    }

    private func addUsageWindowItems(to menu: NSMenu, label: String, snapshot: UsageSnapshot?) {
        let remaining = snapshot?.remainingPercent.map { "\($0)%" } ?? "--"
        let reset = formatTimestamp(snapshot?.resetsAt) ?? "--"
        let updated = formatTimestamp(snapshot?.capturedAt) ?? "--"

        let remainingItem = NSMenuItem(title: "\(label) Remaining: \(remaining)", action: nil, keyEquivalent: "")
        remainingItem.isEnabled = false
        menu.addItem(remainingItem)

        let resetItem = NSMenuItem(title: "\(label) Refresh: \(reset)", action: nil, keyEquivalent: "")
        resetItem.isEnabled = false
        menu.addItem(resetItem)

        let updatedItem = NSMenuItem(title: "\(label) Updated: \(updated)", action: nil, keyEquivalent: "")
        updatedItem.isEnabled = false
        menu.addItem(updatedItem)
    }

    private func profileMenuTitle(profile: String, summary: AccountUsageSummary?) -> String {
        let fiveHour = summary?.fiveHour.remainingPercent.map { "\($0)%" } ?? "--"
        let weekly = summary?.weekly.remainingPercent.map { "\($0)%" } ?? "--"
        return "\(profile)    5h \(fiveHour)    1w \(weekly)"
    }

    private func configureStatusItemIcon() {
        guard let button = statusItem.button else { return }
        if let url = Bundle.main.url(forResource: "StatusIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeft
            button.title = " --"
        } else {
            button.title = "Codex"
        }
    }

    @objc private func refreshUsageNow() {
        refreshUsageDisplay()
        rebuildMenu()
    }

    @objc private func switchProfile(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? String else { return }

        let alert = NSAlert()
        alert.messageText = "Switch to \(profile)?"
        alert.informativeText = "Codex will quit, the saved account state will be restored, and Codex will reopen."
        alert.addButton(withTitle: "Switch")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.run(["switch", profile])
            DispatchQueue.main.async {
                if result.status != 0 {
                    self.showError(result.output)
                }
                self.refreshUsageDisplay()
                self.rebuildMenu()
            }
        }
    }

    @objc private func captureCurrent() {
        let alert = NSAlert()
        alert.messageText = "Capture Current Codex Account"
        alert.informativeText = "Codex will quit first so its login state is fully written. Use a short profile name, such as personal or work."
        alert.addButton(withTitle: "Capture")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "profile-name"
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let profile = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profile.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.run(["capture", profile])
            DispatchQueue.main.async {
                if result.status != 0 {
                    self.showError(result.output)
                }
                self.refreshUsageDisplay()
                self.rebuildMenu()
            }
        }
    }

    @objc private func openProfilesFolder() {
        _ = run(["open-folder"])
    }

    @objc private func openCodex() {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/Codex.app"), configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func run(_ arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandResult(status: 1, output: error.localizedDescription)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return CommandResult(status: process.terminationStatus, output: output)
    }

    private func refreshUsageDisplay() {
        let usage = readFiveHourRemainingPercent()
        guard let button = statusItem.button else { return }
        if let usage {
            button.title = " \(usage)%"
            button.toolTip = "5h tokens remaining: \(usage)%"
        } else {
            button.title = " --"
            button.toolTip = "5h tokens remaining unavailable"
        }
    }

    private func usageMenuTitle() -> String {
        if let usage = readFiveHourRemainingPercent() {
            return "5h Tokens Remaining: \(usage)%"
        }
        return "5h Tokens Remaining: --"
    }

    private func readFiveHourRemainingPercent() -> Int? {
        guard let accountID = currentCodexAccountID() else { return nil }
        return usageSummary(forAccountID: accountID)?.fiveHour.remainingPercent
    }

    private func usageSummary(forProfile profile: String) -> AccountUsageSummary? {
        guard let accountID = profileCodexAccountID(profile) else { return nil }
        return usageSummary(forAccountID: accountID)
    }

    private func usageSummary(forAccountID accountID: String) -> AccountUsageSummary? {
        let historyURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.steipete.codexbar/history/codex.json")
        guard let data = try? Data(contentsOf: historyURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accounts = root["accounts"] as? [String: Any] else {
            return nil
        }

        let accountKey = "codex:v1:provider-account:\(accountID)"
        guard let windows = accounts[accountKey] as? [[String: Any]] else { return nil }

        return AccountUsageSummary(
            fiveHour: usageSnapshot(from: windows, windowMinutes: 300, fallbackName: "session"),
            weekly: usageSnapshot(from: windows, windowMinutes: 10080, fallbackName: "weekly")
        )
    }

    private func usageSnapshot(from windows: [[String: Any]], windowMinutes: Int, fallbackName: String) -> UsageSnapshot {
        let window = windows.first { window in
            if let minutes = window["windowMinutes"] as? Int, minutes == windowMinutes {
                return true
            }
            return (window["name"] as? String) == fallbackName
        }

        guard let entries = window?["entries"] as? [[String: Any]], !entries.isEmpty else {
            return UsageSnapshot(remainingPercent: nil, resetsAt: nil, capturedAt: nil)
        }

        let latest = entries.max { lhs, rhs in
            (lhs["capturedAt"] as? String ?? "") < (rhs["capturedAt"] as? String ?? "")
        }
        let used = latest?["usedPercent"] as? Int
        let remaining = used.map { max(0, min(100, 100 - $0)) }
        return UsageSnapshot(
            remainingPercent: remaining,
            resetsAt: latest?["resetsAt"] as? String,
            capturedAt: latest?["capturedAt"] as? String
        )
    }

    private func currentCodexAccountID() -> String? {
        let authURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
        return codexAccountID(from: authURL)
    }

    private func profileCodexAccountID(_ profile: String) -> String? {
        let authURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexAccountSwitcher/profiles")
            .appendingPathComponent(profile)
            .appendingPathComponent("auth/auth.json")
        return codexAccountID(from: authURL)
    }

    private func codexAccountID(from authURL: URL) -> String? {
        guard let data = try? Data(contentsOf: authURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any] else {
            return nil
        }
        return tokens["account_id"] as? String
    }

    private func formatTimestamp(_ value: String?) -> String? {
        guard let value else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: value) ?? {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            return fallback.date(from: value)
        }()
        guard let date else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Codex Account Switcher"
        alert.informativeText = message.isEmpty ? "The command failed." : message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
