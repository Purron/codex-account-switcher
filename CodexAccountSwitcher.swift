import AppKit
import Foundation

struct CommandResult {
    let status: Int32
    let output: String
}

struct AuthFile: Decodable {
    struct Tokens: Decodable {
        let accessToken: String?
        let accountId: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountId = "account_id"
        }
    }

    let tokens: Tokens?
}

struct LimitWindowResponse: Decodable {
    let usedPercent: Double?
    let limitWindowSeconds: Double?
    let resetAt: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAt = "reset_at"
    }
}

struct RateLimitResponse: Decodable {
    let primaryWindow: LimitWindowResponse?
    let secondaryWindow: LimitWindowResponse?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

struct UsageResponse: Decodable {
    let rateLimit: RateLimitResponse?

    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
    }
}

struct UsageWindowSnapshot: Codable {
    let usedPercent: Double
    let remainingPercent: Double
    let resetAt: Double?
    let windowSeconds: Double?
}

struct UsageSnapshot: Codable {
    let fetchedAt: Date
    let fiveHour: UsageWindowSnapshot?
    let weekly: UsageWindowSnapshot?
    let error: String?
}

final class UsageFetcher {
    private let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    func fetch(authURL: URL, completion: @escaping (UsageSnapshot) -> Void) {
        guard let auth = readAuth(authURL), let accessToken = auth.tokens?.accessToken else {
            completion(UsageSnapshot(fetchedAt: Date(), fiveHour: nil, weekly: nil, error: "No Codex auth token"))
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("codex_desktop", forHTTPHeaderField: "originator")
        request.setValue("Codex Desktop/0.0 (Macintosh; Intel Mac OS X; arm64)", forHTTPHeaderField: "User-Agent")
        request.setValue(Locale.current.identifier, forHTTPHeaderField: "OAI-Language")

        if let accountId = auth.tokens?.accountId ?? accountIdFromJWT(accessToken) {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(UsageSnapshot(fetchedAt: Date(), fiveHour: nil, weekly: nil, error: error.localizedDescription))
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(UsageSnapshot(fetchedAt: Date(), fiveHour: nil, weekly: nil, error: "Invalid usage response"))
                return
            }

            guard http.statusCode == 200, let data else {
                completion(UsageSnapshot(fetchedAt: Date(), fiveHour: nil, weekly: nil, error: "HTTP \(http.statusCode)"))
                return
            }

            do {
                let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
                let windows = [usage.rateLimit?.primaryWindow, usage.rateLimit?.secondaryWindow].compactMap { $0 }
                let fiveHour = self.snapshot(from: windows, targetSeconds: 5 * 60 * 60)
                let weekly = self.snapshot(from: windows, targetSeconds: 7 * 24 * 60 * 60)
                completion(UsageSnapshot(fetchedAt: Date(), fiveHour: fiveHour, weekly: weekly, error: nil))
            } catch {
                completion(UsageSnapshot(fetchedAt: Date(), fiveHour: nil, weekly: nil, error: "Could not parse usage"))
            }
        }.resume()
    }

    private func readAuth(_ url: URL) -> AuthFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AuthFile.self, from: data)
    }

    private func snapshot(from windows: [LimitWindowResponse], targetSeconds: Double) -> UsageWindowSnapshot? {
        let candidates = windows.compactMap { window -> (LimitWindowResponse, Double)? in
            guard let seconds = window.limitWindowSeconds else { return nil }
            return (window, seconds)
        }
        guard let selected = candidates.min(by: { abs($0.1 - targetSeconds) < abs($1.1 - targetSeconds) }) else {
            return nil
        }

        let tolerance = max(60, targetSeconds * 0.20)
        guard abs(selected.1 - targetSeconds) <= tolerance else { return nil }

        let used = selected.0.usedPercent ?? 0
        let remaining = min(max(100 - used, 0), 100)
        return UsageWindowSnapshot(
            usedPercent: used,
            remainingPercent: remaining,
            resetAt: selected.0.resetAt,
            windowSeconds: selected.1
        )
    }

    private func accountIdFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let auth = json["https://api.openai.com/auth"] as? [String: Any],
              let accountId = auth["chatgpt_account_id"] as? String else {
            return nil
        }
        return accountId
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let scriptPath: String
    private let usageFetcher = UsageFetcher()
    private var usageByProfile: [String: UsageSnapshot] = [:]
    private var usageTimer: Timer?
    private var isRefreshingUsage = false

    private var switcherHome: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexAccountSwitcher")
    }

    private var usageCacheURL: URL {
        switcherHome.appendingPathComponent("usage-cache.json")
    }

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
        loadUsageCache()
        rebuildMenu()
        refreshUsage()
        usageTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshUsage()
        }
    }

    @objc private func rebuildMenu() {
        let menu = NSMenu()
        let active = activeProfile()
        let profiles = profileNames()

        if profiles.isEmpty {
            let item = NSMenuItem(title: "No profiles yet", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for profile in profiles {
                let item = NSMenuItem(title: profileTitle(profile: profile), action: nil, keyEquivalent: "")
                item.state = profile == active ? .on : .off
                item.submenu = profileSubmenu(profile: profile, isActive: profile == active)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Capture Current Account...", action: #selector(captureCurrent)))
        menu.addItem(makeItem(title: isRefreshingUsage ? "Refreshing Usage..." : "Refresh Usage", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Open Profiles Folder", action: #selector(openProfilesFolder)))
        menu.addItem(makeItem(title: "Open Codex", action: #selector(openCodex), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Quit Switcher", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
        updateStatusBarTitle(activeProfile: active)
    }

    private func makeItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func profileSubmenu(profile: String, isActive: Bool) -> NSMenu {
        let submenu = NSMenu()

        addUsageItems(to: submenu, snapshot: usageByProfile[profile])
        submenu.addItem(.separator())

        let switchTitle = isActive ? "Current Account" : "Switch to \(profile)"
        let switchItem = NSMenuItem(title: switchTitle, action: #selector(switchProfile(_:)), keyEquivalent: "")
        switchItem.target = self
        switchItem.representedObject = profile
        switchItem.isEnabled = !isActive
        submenu.addItem(switchItem)

        return submenu
    }

    private func configureStatusItemIcon() {
        guard let button = statusItem.button else { return }
        if let url = Bundle.main.url(forResource: "StatusIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeft
            button.title = ""
            button.toolTip = "Codex Account Switcher"
        } else {
            button.title = "Codex"
        }
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
                self.rebuildMenu()
                self.refreshUsage()
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
                self.rebuildMenu()
                self.refreshUsage()
            }
        }
    }

    @objc private func refreshNow() {
        rebuildMenu()
        refreshUsage()
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

    private func profileNames() -> [String] {
        run(["list", "--plain"]).output
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    private func activeProfile() -> String {
        run(["active"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func profileAuthURL(profile: String) -> URL {
        switcherHome
            .appendingPathComponent("profiles")
            .appendingPathComponent(profile)
            .appendingPathComponent("auth/auth.json")
    }

    private func refreshUsage() {
        guard !isRefreshingUsage else { return }

        let profiles = profileNames()
        guard !profiles.isEmpty else {
            usageByProfile.removeAll()
            saveUsageCache()
            rebuildMenu()
            return
        }

        isRefreshingUsage = true
        rebuildMenu()

        let group = DispatchGroup()
        var updated: [String: UsageSnapshot] = [:]
        let lock = NSLock()

        for profile in profiles {
            group.enter()
            usageFetcher.fetch(authURL: profileAuthURL(profile: profile)) { snapshot in
                lock.lock()
                updated[profile] = snapshot
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.usageByProfile = updated
            self.isRefreshingUsage = false
            self.saveUsageCache()
            self.rebuildMenu()
        }
    }

    private func loadUsageCache() {
        guard let data = try? Data(contentsOf: usageCacheURL),
              let decoded = try? JSONDecoder().decode([String: UsageSnapshot].self, from: data) else {
            return
        }
        usageByProfile = decoded
    }

    private func saveUsageCache() {
        do {
            try FileManager.default.createDirectory(at: switcherHome, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(usageByProfile)
            try data.write(to: usageCacheURL, options: .atomic)
        } catch {
            // The menu can still work without a persisted usage cache.
        }
    }

    private func profileTitle(profile: String) -> String {
        guard let snapshot = usageByProfile[profile], snapshot.error == nil else {
            return "\(profile)  5h --  1w --"
        }
        return "\(profile)  5h \(formatPercent(snapshot.fiveHour?.remainingPercent))  1w \(formatPercent(snapshot.weekly?.remainingPercent))"
    }

    private func addUsageItems(to menu: NSMenu, snapshot: UsageSnapshot?) {
        guard let snapshot else {
            addDisabled("Usage: not loaded", to: menu)
            return
        }

        if let error = snapshot.error {
            addDisabled("Usage: \(error)", to: menu)
            addDisabled("Updated: \(formatDate(snapshot.fetchedAt))", to: menu)
            return
        }

        addDisabled("5h remaining: \(formatPercent(snapshot.fiveHour?.remainingPercent))", to: menu)
        addDisabled("5h resets: \(formatReset(snapshot.fiveHour?.resetAt))", to: menu)
        addDisabled("1w remaining: \(formatPercent(snapshot.weekly?.remainingPercent))", to: menu)
        addDisabled("1w resets: \(formatReset(snapshot.weekly?.resetAt))", to: menu)
        addDisabled("Updated: \(formatDate(snapshot.fetchedAt))", to: menu)
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func updateStatusBarTitle(activeProfile: String) {
        guard let button = statusItem.button else { return }

        if activeProfile.isEmpty {
            button.title = ""
            button.toolTip = "Codex Account Switcher"
            return
        }

        let snapshot = usageByProfile[activeProfile]
        button.title = " \(formatPercent(snapshot?.fiveHour?.remainingPercent))"

        if let snapshot, snapshot.error == nil {
            button.toolTip = "\(activeProfile): 5h \(formatPercent(snapshot.fiveHour?.remainingPercent)), 1w \(formatPercent(snapshot.weekly?.remainingPercent))"
        } else {
            button.toolTip = "\(activeProfile): usage unavailable"
        }
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    private func formatReset(_ epochSeconds: Double?) -> String {
        guard let epochSeconds, epochSeconds.isFinite else { return "--" }
        return formatDate(Date(timeIntervalSince1970: epochSeconds))
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        if calendar.isDateInToday(date) {
            return "Today \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(timeFormatter.string(from: date))"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
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
