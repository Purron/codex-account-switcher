import AppKit
import Darwin
import Foundation
import QuartzCore

struct CommandResult {
    let status: Int32
    let output: String
}

private extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

struct AuthFile: Decodable {
    struct Tokens: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let idToken: String?
        let accountId: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case idToken = "id_token"
            case accountId = "account_id"
        }
    }

    let tokens: Tokens?
}

struct OAuthTokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let idToken: String?
    let accountId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case accountId = "account_id"
    }
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

private enum AccountService: String, CaseIterable {
    case codex
    case claude

    var tabTitle: String { rawValue }
    var accountType: String { rawValue }

    var displayTitle: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude"
        }
    }

    var appName: String {
        displayTitle
    }

    var defaultAppPath: String {
        "/Applications/\(appName).app"
    }

    var headerTitle: String {
        AppDesign.appName
    }

    var supportsUsage: Bool {
        self == .codex
    }

    var supportsProfiles: Bool {
        self == .codex
    }

    var profilePathComponents: [String] {
        switch self {
        case .codex:
            return ["profiles"]
        case .claude:
            return ["services", "claude", "profiles"]
        }
    }

    var profileAuthFileName: String {
        switch self {
        case .codex:
            return "auth.json"
        case .claude:
            return "claude.json"
        }
    }
}

private enum ServiceAvailability: Equatable {
    case installed
    case historyOnly
    case unavailable

    var isSelectable: Bool {
        self != .unavailable
    }

    var contentAlpha: CGFloat {
        switch self {
        case .installed, .historyOnly:
            return 1
        case .unavailable:
            return 0.32
        }
    }
}

private enum ServiceSelectionMode: Equatable {
    case auto
    case service(AccountService)

    var service: AccountService? {
        if case let .service(service) = self { return service }
        return nil
    }
}

private enum ProjectConversationLamp: CaseIterable, Equatable {
    case red
    case yellow
    case green
}

private enum AppDesign {
    static let appName = "Agent Status Indicator"
    static let blue = NSColor(calibratedRed: 28 / 255, green: 97 / 255, blue: 1, alpha: 1)
    static var hoverBackground: NSColor {
        isSystemDarkMode
            ? NSColor.white.withAlphaComponent(0.08)
            : NSColor.black.withAlphaComponent(0.05)
    }
    static var nativeMenuFont: NSFont { NSFont.menuFont(ofSize: 0) }

    // Dynamic color tokens. Keep alpha semantics aligned with the Figma light
    // design, but resolve to readable values in dark mode.
    static var isSystemDarkMode: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    static var panelBackground: NSColor {
        isSystemDarkMode
            ? NSColor(calibratedRed: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 0.92)
            : NSColor.white.withAlphaComponent(0.85)
    }
    static var moduleBackground: NSColor {
        isSystemDarkMode
            ? NSColor.white.withAlphaComponent(0.10)
            : NSColor.black.withAlphaComponent(0.05)
    }
    static var raisedHoverBackground: NSColor {
        isSystemDarkMode
            ? NSColor.white.withAlphaComponent(0.16)
            : NSColor.black.withAlphaComponent(0.10)
    }
    static var textPrimary: NSColor {
        isSystemDarkMode
            ? NSColor.white.withAlphaComponent(0.88)
            : NSColor.black.withAlphaComponent(0.85)
    }
    static var textSecondary: NSColor {
        isSystemDarkMode
            ? NSColor.white.withAlphaComponent(0.62)
            : NSColor.black.withAlphaComponent(0.65)
    }
    static var textTertiary: NSColor {
        isSystemDarkMode
            ? NSColor.white.withAlphaComponent(0.44)
            : NSColor.black.withAlphaComponent(0.45)
    }
    static var separator: NSColor {
        isSystemDarkMode
            ? NSColor.white.withAlphaComponent(0.14)
            : NSColor.black.withAlphaComponent(0.10)
    }
    static var menuItemText: NSColor {
        isSystemDarkMode
            ? NSColor.white.withAlphaComponent(0.88)
            : NSColor.black.withAlphaComponent(0.85)
    }
    static var linkBlue: NSColor {
        NSColor.linkColor
    }

    static func pingFang(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        .systemFont(ofSize: size, weight: weight)
    }

}

private func svgFillAttribute(_ color: NSColor) -> String {
    let resolved = color.usingColorSpace(.sRGB) ?? color
    let red = Int((resolved.redComponent * 255).rounded())
    let green = Int((resolved.greenComponent * 255).rounded())
    let blue = Int((resolved.blueComponent * 255).rounded())
    let alpha = max(0, min(1, resolved.alphaComponent))
    return #"fill="rgb(\#(red),\#(green),\#(blue))" fill-opacity="\#(String(format: "%.3f", alpha))""#
}

private func svgReplacingFills(_ svg: String, with color: NSColor) -> String {
    let fill = svgFillAttribute(color)
    return svg
        .replacingOccurrences(of: #"fill="white""#, with: fill)
        .replacingOccurrences(of: #"fill="black" fill-opacity="0.65""#, with: fill)
        .replacingOccurrences(of: #"fill="black" fill-opacity="0.45""#, with: fill)
        .replacingOccurrences(of: #"fill="black""#, with: fill)
}

private func aspectFitRect(for image: NSImage, in rect: NSRect) -> NSRect {
    let imageSize = image.size
    guard imageSize.width > 0, imageSize.height > 0, rect.width > 0, rect.height > 0 else {
        return rect
    }
    let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
    let width = imageSize.width * scale
    let height = imageSize.height * scale
    return NSRect(
        x: rect.midX - width / 2,
        y: rect.midY - height / 2,
        width: width,
        height: height
    )
}

private func drawTemplateImage(_ image: NSImage, in rect: NSRect, color: NSColor, fraction: CGFloat = 1) {
    let tintedImage = NSImage(size: image.size)
    tintedImage.lockFocus()
    let imageRect = NSRect(origin: .zero, size: image.size)
    NSColor.clear.setFill()
    imageRect.fill()
    image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
    color.setFill()
    imageRect.fill(using: .sourceIn)
    tintedImage.unlockFocus()
    tintedImage.isTemplate = false

    tintedImage.draw(
        in: aspectFitRect(for: tintedImage, in: rect),
        from: .zero,
        operation: .sourceOver,
        fraction: fraction,
        respectFlipped: true,
        hints: nil
    )
}

private func drawSystemSymbol(_ name: String, in rect: NSRect, pointSize: CGFloat, color: NSColor) {
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: pointSize, weight: .medium)) else { return }
    drawTemplateImage(image, in: rect, color: color)
}

private enum ProjectConversationState: Equatable {
    case idle
    case completed
    case active
    case needsReview
    case permission
    case blocked
    case stale
    case paused

    var title: String {
        switch self {
        case .idle:
            return "空闲"
        case .completed:
            return "已完成"
        case .active:
            return "工作中"
        case .needsReview:
            return "需要查看"
        case .permission:
            return "等待授权"
        case .blocked:
            return "阻塞"
        case .stale:
            return "状态过期"
        case .paused:
            return "已暂停"
        }
    }

    var detailTitle: String {
        switch self {
        case .idle:
            return "Project conversation idle"
        case .completed:
            return "Project conversation completed"
        case .active:
            return "Project conversation active"
        case .needsReview:
            return "Project conversation needs review"
        case .permission:
            return "Project conversation waiting for permission"
        case .blocked:
            return "Project conversation blocked"
        case .stale:
            return "Project conversation status stale"
        case .paused:
            return "Project conversation monitor paused"
        }
    }

    var shortTitle: String { title }

    var panelTitle: String {
        switch self {
        case .idle:
            return "空闲，待命中"
        case .completed:
            return "已完成，待命中"
        case .active:
            return "工作中"
        case .needsReview:
            return "需要查看"
        case .permission:
            return "等待授权"
        case .blocked:
            return "阻塞"
        case .stale:
            return "状态过期"
        case .paused:
            return "监控暂停"
        }
    }

    // Single source of truth for state ranking. Higher wins when several
    // sessions are active. Urgency order: act-now (paused/blocked/permission)
    // > soft attention (needsReview) > untrusted (stale) > working > idle.
    var priority: Int {
        switch self {
        case .paused:
            return 100
        case .blocked:
            return 90
        case .permission:
            return 80
        case .needsReview:
            return 70
        case .stale:
            return 60
        case .active:
            return 50
        case .completed:
            return 40
        case .idle:
            return 0
        }
    }
}

private struct ProjectConversationItem: Equatable {
    let service: AccountService
    let title: String
    let subtitle: String
}

private struct ProjectConversationMetadata: Equatable {
    let item: ProjectConversationItem
    let startedAt: Date?
}

private struct ProjectConversationSession: Equatable {
    let sessionID: String
    let service: AccountService
    let title: String
    let subtitle: String
    let state: ProjectConversationState
    let detail: String
    let source: String
    let updatedAt: Date?
    let startedAt: Date?
}

private final class ProfileMenuItemPayload {
    let service: AccountService
    let profile: String

    init(service: AccountService, profile: String) {
        self.service = service
        self.profile = profile
    }
}

private final class SessionMenuItemPayload {
    let session: ProjectConversationSession

    init(session: ProjectConversationSession) {
        self.session = session
    }
}

private struct ProjectConversationSnapshot: Equatable {
    let state: ProjectConversationState
    let detail: String
    let source: String
    let updatedAt: Date?
    let activeSessionCount: Int
    let sessions: [ProjectConversationSession]

    static let idle = ProjectConversationSnapshot(
        state: .idle,
        detail: "No recent unfinished agent work.",
        source: "Local agent sessions",
        updatedAt: nil,
        activeSessionCount: 0,
        sessions: []
    )
}

private enum AgentActivitySignal {
    case idle
    case active
    case attention
    case permission
    case blocked
    case done
    case stale
    case paused

    var projectState: ProjectConversationState {
        switch self {
        case .active:
            return .active
        case .attention:
            return .needsReview
        case .permission:
            return .permission
        case .blocked:
            return .blocked
        case .idle:
            return .idle
        case .done:
            return .completed
        case .stale:
            return .stale
        case .paused:
            return .paused
        }
    }

    var priority: Int {
        projectState.priority
    }

    static func normalized(_ rawValue: String) -> AgentActivitySignal? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch normalized {
        case "idle", "session_start", "session_end", "turn_end":
            return .idle
        case "thinking", "working", "tool_done", "subagent_start", "subagent_stop",
             "tooluse", "tool_use", "pre_tool_use", "post_tool_use":
            return .active
        case "attention", "notification":
            return .attention
        case "permission", "permission_request", "permissionrequest":
            return .permission
        case "blocked", "failure", "failed", "error", "exception", "max_tokens", "maxtokens":
            return .blocked
        case "done":
            return .done
        case "stale":
            return .stale
        case "off", "pause", "paused":
            return .paused
        default:
            return nil
        }
    }
}

private enum ExpiredActivityPolicy {
    case markStale
    case hide
}

private struct ProjectConversationCandidate {
    let signal: AgentActivitySignal
    let updatedAt: Date?
    let startedAt: Date?
    let event: String?
    let sessionID: String
    let project: ProjectConversationItem?
}

private func newerDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
    switch (lhs, rhs) {
    case let (lhs?, rhs?):
        return max(lhs, rhs)
    case let (lhs?, nil):
        return lhs
    case let (nil, rhs?):
        return rhs
    case (nil, nil):
        return nil
    }
}

private final class ProjectConversationMonitor {
    private struct SessionFile {
        let url: URL
        let modifiedAt: Date
        let size: UInt64
    }

    private struct ClaudeRuntimeSession {
        let url: URL
        let modifiedAt: Date
        let pid: Int32?
        let sessionID: String
        let cwd: String?
        let startedAt: Date?
    }

    private let fileManager: FileManager
    private let sessionTTL: TimeInterval = 30 * 60
    private let recentConversationTTL: TimeInterval = 60 * 60
    private let blockingTTL: TimeInterval = 2 * 60 * 60
    private let attentionTTL: TimeInterval = 12 * 60 * 60
    private let maxTailBytes: UInt64 = 512 * 1024
    private let recentFileLimit = 12

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func snapshot(now: Date = Date()) -> ProjectConversationSnapshot {
        let snapshots = [
            agentSignalStateSnapshot(now: now),
            localSessionSnapshot(now: now)
        ].compactMap { $0 }

        return mergedSnapshot(from: snapshots) ?? .idle
    }

    private func mergedSnapshot(from snapshots: [ProjectConversationSnapshot]) -> ProjectConversationSnapshot? {
        guard !snapshots.isEmpty else { return nil }
        guard snapshots.count > 1 else { return snapshots.first }

        let sessions = mergedSessions(from: snapshots)
        let updatedAt = snapshots.compactMap(\.updatedAt).max()
        let source = snapshots.map(\.source).joined(separator: " + ")

        if let selected = sessions.first {
            return ProjectConversationSnapshot(
                state: selected.state,
                detail: selected.detail,
                source: source,
                updatedAt: updatedAt,
                activeSessionCount: sessions.count,
                sessions: sessions
            )
        }

        return snapshots
            .sorted {
                if statePriority($0.state) != statePriority($1.state) {
                    return statePriority($0.state) > statePriority($1.state)
                }
                return ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
            }
            .first
    }

    private func mergedSessions(from snapshots: [ProjectConversationSnapshot]) -> [ProjectConversationSession] {
        var seen = Set<String>()
        var sessions: [ProjectConversationSession] = []

        let sorted = snapshots
            .flatMap(\.sessions)
            .sorted { sessionStartDate($0) > sessionStartDate($1) }

        for session in sorted {
            let key = sessionKey(service: session.service, sessionID: session.sessionID)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            sessions.append(session)
        }

        return sessions
    }

    private func agentSignalStateSnapshot(now: Date) -> ProjectConversationSnapshot? {
        let url = agentSignalStateFileURL()
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ProjectConversationSnapshot(
                state: .stale,
                detail: "Agent Signal state exists but could not be read.",
                source: "Agent Signal state",
                updatedAt: fileModificationDate(url),
                activeSessionCount: 0,
                sessions: []
            )
        }

        let sessions = object["sessions"] as? [String: Any] ?? [:]
        var candidates: [ProjectConversationCandidate] = []

        for (sessionID, value) in sessions {
            guard let record = value as? [String: Any],
                  let rawSignal = record["signal"] as? String,
                  let signal = AgentActivitySignal.normalized(rawSignal) else {
                continue
            }
            let startedAt = stringDate(record["started_at"] as? String) ?? stringDate(record["created_at"] as? String) ?? stringDate(record["updated_at"] as? String)
            let service = agentSignalService(from: record, sessionID: sessionID)
            let metadata = conversationMetadata(
                service: service,
                sessionID: sessionID,
                cwd: record["cwd"] as? String,
                title: conversationTitle(from: record),
                startedAt: startedAt
            )

            candidates.append(
                ProjectConversationCandidate(
                    signal: signal,
                    updatedAt: stringDate(record["updated_at"] as? String),
                    startedAt: metadata.startedAt,
                    event: record["last_event"] as? String,
                    sessionID: sessionID,
                    project: metadata.item
                )
            )
        }

        if candidates.isEmpty,
           let rawAggregate = object["aggregate"] as? String,
           let signal = AgentActivitySignal.normalized(rawAggregate) {
            candidates.append(
                ProjectConversationCandidate(
                    signal: signal,
                    updatedAt: stringDate(object["updated_at"] as? String),
                    startedAt: stringDate(object["started_at"] as? String) ?? stringDate(object["updated_at"] as? String),
                    event: "aggregate",
                    sessionID: "aggregate",
                    project: nil
                )
            )
        }

        if candidates.isEmpty {
            return ProjectConversationSnapshot(
                state: .idle,
                detail: "Agent Signal state has no active sessions.",
                source: "Agent Signal state",
                updatedAt: stringDate(object["updated_at"] as? String) ?? fileModificationDate(url),
                activeSessionCount: 0,
                sessions: []
            )
        }

        return aggregateSnapshot(
            candidates: candidates,
            now: now,
            source: "Agent Signal state",
            staleDetail: "Agent Signal state is stale; confirm before switching accounts.",
            expiredActivityPolicy: .markStale
        )
    }

    private func localSessionSnapshot(now: Date) -> ProjectConversationSnapshot? {
        let codexFiles = recentSessionFiles()
        let claudeRuntimeSessions = recentClaudeRuntimeSessions()
        guard !codexFiles.isEmpty || !claudeRuntimeSessions.isEmpty else {
            return ProjectConversationSnapshot(
                state: .idle,
                detail: "No Codex session files or Claude runtime sessions were found.",
                source: "Local agent sessions",
                updatedAt: nil,
                activeSessionCount: 0,
                sessions: []
            )
        }

        var candidates: [ProjectConversationCandidate] = []
        for file in codexFiles {
            guard let candidate = lastCandidate(in: file) else { continue }
            candidates.append(candidate)
        }
        for runtimeSession in claudeRuntimeSessions {
            guard let candidate = claudeRuntimeCandidate(from: runtimeSession) else { continue }
            candidates.append(candidate)
        }

        guard !candidates.isEmpty else {
            return ProjectConversationSnapshot(
                state: .idle,
                detail: "Recent Codex and Claude sessions look complete.",
                source: "Local agent sessions",
                updatedAt: codexFiles.map(\.modifiedAt).max()
                    ?? claudeRuntimeSessions.map(\.modifiedAt).max(),
                activeSessionCount: 0,
                sessions: []
            )
        }

        return aggregateSnapshot(
            candidates: candidates,
            now: now,
            source: "Local agent sessions",
            staleDetail: "Recent agent session activity is stale; confirm before switching accounts.",
            expiredActivityPolicy: .hide
        )
    }

    private func aggregateSnapshot(
        candidates: [ProjectConversationCandidate],
        now: Date,
        source: String,
        staleDetail: String,
        expiredActivityPolicy: ExpiredActivityPolicy
    ) -> ProjectConversationSnapshot {
        let normalized = candidates.compactMap { candidate -> ProjectConversationCandidate? in
            guard let updatedAt = candidate.updatedAt else { return candidate }
            let age = now.timeIntervalSince(updatedAt)

            switch candidate.signal.projectState {
            case .active where age > sessionTTL:
                guard expiredActivityPolicy == .markStale else { return nil }
                return ProjectConversationCandidate(
                    signal: .stale,
                    updatedAt: updatedAt,
                    startedAt: candidate.startedAt,
                    event: candidate.event,
                    sessionID: candidate.sessionID,
                    project: candidate.project
                )
            case .permission where age > blockingTTL,
                 .blocked where age > blockingTTL:
                guard expiredActivityPolicy == .markStale else { return nil }
                return ProjectConversationCandidate(
                    signal: .stale,
                    updatedAt: updatedAt,
                    startedAt: candidate.startedAt,
                    event: candidate.event,
                    sessionID: candidate.sessionID,
                    project: candidate.project
                )
            case .needsReview where age > attentionTTL:
                guard expiredActivityPolicy == .markStale else { return nil }
                return ProjectConversationCandidate(
                    signal: .stale,
                    updatedAt: updatedAt,
                    startedAt: candidate.startedAt,
                    event: candidate.event,
                    sessionID: candidate.sessionID,
                    project: candidate.project
                )
            default:
                return candidate
            }
        }

        if normalized.isEmpty {
            return ProjectConversationSnapshot(
                state: .idle,
                detail: "Recent agent sessions are complete or inactive.",
                source: source,
                updatedAt: candidates.compactMap(\.updatedAt).max(),
                activeSessionCount: 0,
                sessions: []
            )
        }

        let sessions = sessionItems(from: normalized, now: now, source: source, staleDetail: staleDetail)
        let latestStartedCandidate = normalized.max { lhs, rhs in
            candidateStartDate(lhs) < candidateStartDate(rhs)
        }
        let selectedSession = sessions.sorted { lhs, rhs in
            if lhs.state.priority != rhs.state.priority {
                return lhs.state.priority > rhs.state.priority
            }
            return sessionActivityDate(lhs) > sessionActivityDate(rhs)
        }.first
        let selectedState = selectedSession?.state ?? latestStartedCandidate?.signal.projectState ?? .idle
        let activeCount = sessions.count
        let updatedAt = normalized.compactMap(\.updatedAt).max()
        let detail = selectedSession?.detail
            ?? latestStartedCandidate.map {
                sessionDetail(
                    state: $0.signal.projectState,
                    event: $0.event,
                    activeCount: activeCount,
                    staleDetail: staleDetail
                )
            }
            ?? "No recent unfinished agent work."

        return ProjectConversationSnapshot(
            state: selectedState,
            detail: detail,
            source: source,
            updatedAt: updatedAt,
            activeSessionCount: activeCount,
            sessions: sessions
        )
    }

    private func agentSignalStateFileURL() -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let path = environment["AGENT_SIGNAL_LIGHT_STATE_FILE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        if let dir = environment["AGENT_SIGNAL_LIGHT_STATE_DIR"], !dir.isEmpty {
            return URL(fileURLWithPath: dir, isDirectory: true).appendingPathComponent("status.json")
        }
        return URL(fileURLWithPath: "/tmp/agent-signal/status.json")
    }

    private func recentSessionFiles() -> [SessionFile] {
        let root = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [SessionFile] = []
        for case let url as URL in enumerator {
            guard url.lastPathComponent.hasPrefix("rollout-"),
                  url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: [
                      .isRegularFileKey,
                      .contentModificationDateKey,
                      .fileSizeKey
                  ]),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  let size = values.fileSize else {
                continue
            }

            files.append(SessionFile(url: url, modifiedAt: modifiedAt, size: UInt64(size)))
        }

        return Array(files.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(recentFileLimit))
    }

    private func recentClaudeSessionFiles() -> [SessionFile] {
        recentClaudeSessionFiles(excluding: [])
    }

    private func recentClaudeSessionFiles(excluding excludedSessionIDs: Set<String>) -> [SessionFile] {
        let root = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
        guard let projectDirectories = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [SessionFile] = []
        for directory in projectDirectories {
            guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true,
                  let candidates = try? fileManager.contentsOfDirectory(
                      at: directory,
                      includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
                      options: [.skipsHiddenFiles]
                  ) else {
                continue
            }

            for url in candidates {
                guard url.pathExtension == "jsonl",
                      !excludedSessionIDs.contains(url.deletingPathExtension().lastPathComponent),
                      let values = try? url.resourceValues(forKeys: [
                          .isRegularFileKey,
                          .contentModificationDateKey,
                          .fileSizeKey
                      ]),
                      values.isRegularFile == true,
                      let modifiedAt = values.contentModificationDate,
                      let size = values.fileSize else {
                    continue
                }

                files.append(SessionFile(url: url, modifiedAt: modifiedAt, size: UInt64(size)))
            }
        }

        return Array(files.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(recentFileLimit))
    }

    private func recentClaudeRuntimeSessions() -> [ClaudeRuntimeSession] {
        let root = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/sessions", isDirectory: true)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var sessions: [ClaudeRuntimeSession] = []
        for url in urls where url.pathExtension == "json" {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawSessionID = object["sessionId"] as? String else {
                continue
            }

            let sessionID = rawSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sessionID.isEmpty else { continue }

            let pid = claudePID(from: object["pid"])
            if let pid, !processIsRunning(pid) {
                continue
            }
            if pid == nil, Date().timeIntervalSince(modifiedAt) > sessionTTL {
                continue
            }

            sessions.append(
                ClaudeRuntimeSession(
                    url: url,
                    modifiedAt: modifiedAt,
                    pid: pid,
                    sessionID: sessionID,
                    cwd: object["cwd"] as? String,
                    startedAt: claudeStartedAt(from: object["startedAt"]) ?? stringDate(object["procStart"] as? String)
                )
            )
        }

        return Array(sessions.sorted { sessionStartDate($0) > sessionStartDate($1) }.prefix(recentFileLimit))
    }

    private func processIsRunning(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }

    private func claudeRuntimeCandidate(from runtimeSession: ClaudeRuntimeSession) -> ProjectConversationCandidate? {
        let transcript = claudeTranscriptFile(for: runtimeSession)
        let metadata = transcript.flatMap {
            claudeConversationMetadata(from: $0, sessionID: runtimeSession.sessionID)
        } ?? claudeConversationMetadata(
            sessionID: runtimeSession.sessionID,
            cwd: runtimeSession.cwd,
            title: nil,
            startedAt: runtimeSession.startedAt ?? runtimeSession.modifiedAt
        )

        guard let transcript,
              let lines = tailLines(from: transcript),
              let latest = lines.reversed().compactMap({
                  claudeCandidate(
                      from: $0,
                      defaultSessionID: runtimeSession.sessionID,
                      project: metadata.item,
                      runningSession: true
                  )
              }).first else {
            return ProjectConversationCandidate(
                signal: .active,
                updatedAt: transcript?.modifiedAt ?? runtimeSession.modifiedAt,
                startedAt: metadata.startedAt ?? runtimeSession.startedAt ?? runtimeSession.modifiedAt,
                event: "Claude session",
                sessionID: "claude:\(runtimeSession.sessionID)",
                project: metadata.item
            )
        }

        return ProjectConversationCandidate(
            signal: latest.signal,
            updatedAt: latest.updatedAt ?? transcript.modifiedAt,
            startedAt: metadata.startedAt ?? latest.startedAt ?? runtimeSession.startedAt ?? transcript.modifiedAt,
            event: latest.event,
            sessionID: "claude:\(latest.sessionID)",
            project: latest.project
        )
    }

    private func claudeTranscriptFile(for runtimeSession: ClaudeRuntimeSession) -> SessionFile? {
        let directURL = runtimeSession.cwd.flatMap {
            claudeTranscriptURL(sessionID: runtimeSession.sessionID, cwd: $0)
        }
        if let directURL, let file = sessionFile(at: directURL) {
            return file
        }

        return claudeTranscriptURL(sessionID: runtimeSession.sessionID).flatMap(sessionFile(at:))
    }

    private func claudeTranscriptURL(sessionID: String, cwd: String) -> URL {
        let directoryName = cwd.replacingOccurrences(of: "/", with: "-")
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent("\(sessionID).jsonl")
    }

    private func claudeTranscriptURL(sessionID: String) -> URL? {
        let root = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
        guard let projectDirectories = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for directory in projectDirectories {
            guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true else {
                continue
            }

            let url = directory.appendingPathComponent("\(sessionID).jsonl")
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    private func sessionFile(at url: URL) -> SessionFile? {
        guard let values = try? url.resourceValues(forKeys: [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]),
              values.isRegularFile == true,
              let modifiedAt = values.contentModificationDate,
              let size = values.fileSize else {
            return nil
        }

        return SessionFile(url: url, modifiedAt: modifiedAt, size: UInt64(size))
    }

    private func claudePID(from value: Any?) -> Int32? {
        if let number = value as? NSNumber {
            return number.int32Value
        }
        if let string = value as? String,
           let int = Int32(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return int
        }
        return nil
    }

    private func claudeStartedAt(from value: Any?) -> Date? {
        if let number = value as? NSNumber {
            let rawValue = number.doubleValue
            let seconds = rawValue > 10_000_000_000 ? rawValue / 1_000 : rawValue
            return Date(timeIntervalSince1970: seconds)
        }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let rawValue = Double(trimmed) {
                let seconds = rawValue > 10_000_000_000 ? rawValue / 1_000 : rawValue
                return Date(timeIntervalSince1970: seconds)
            }
            return stringDate(trimmed)
        }
        return nil
    }

    private func statePriority(_ state: ProjectConversationState) -> Int {
        state.priority
    }

    private func sessionStartDate(_ session: ProjectConversationSession) -> Date {
        session.startedAt ?? session.updatedAt ?? .distantPast
    }

    private func sessionActivityDate(_ session: ProjectConversationSession) -> Date {
        session.updatedAt ?? session.startedAt ?? .distantPast
    }

    private func sessionStartDate(_ session: ClaudeRuntimeSession) -> Date {
        session.startedAt ?? session.modifiedAt
    }

    private func lastCandidate(in file: SessionFile) -> ProjectConversationCandidate? {
        guard let lines = tailLines(from: file), !lines.isEmpty else { return nil }
        let sessionID = rolloutSessionID(from: file.url) ?? file.url.deletingPathExtension().lastPathComponent
        guard let metadata = conversationMetadata(from: file, sessionID: sessionID) else { return nil }
        guard let latest = lines.reversed().compactMap({ line in
            candidate(from: line, defaultSessionID: sessionID, project: metadata.item)
        }).first else { return nil }
        let updatedAt = newerDate(latest.updatedAt, file.modifiedAt)
        let signal: AgentActivitySignal
        if latest.signal.projectState == .completed,
           let latestUpdatedAt = latest.updatedAt,
           file.modifiedAt.timeIntervalSince(latestUpdatedAt) > 5 {
            signal = .active
        } else {
            signal = latest.signal
        }

        return ProjectConversationCandidate(
            signal: signal,
            updatedAt: updatedAt,
            startedAt: metadata.startedAt ?? latest.startedAt ?? updatedAt ?? file.modifiedAt,
            event: latest.event,
            sessionID: latest.sessionID,
            project: latest.project
        )
    }

    private func lastClaudeCandidate(in file: SessionFile) -> ProjectConversationCandidate? {
        guard let lines = tailLines(from: file), !lines.isEmpty else { return nil }
        let fallbackSessionID = file.url.deletingPathExtension().lastPathComponent
        guard let metadata = claudeConversationMetadata(from: file, sessionID: fallbackSessionID) else { return nil }
        guard let latest = lines.reversed().compactMap({ line in
            claudeCandidate(from: line, defaultSessionID: fallbackSessionID, project: metadata.item)
        }).first else { return nil }
        let updatedAt = latest.updatedAt ?? file.modifiedAt

        return ProjectConversationCandidate(
            signal: latest.signal,
            updatedAt: updatedAt,
            startedAt: metadata.startedAt ?? latest.startedAt ?? updatedAt,
            event: latest.event,
            sessionID: "claude:\(latest.sessionID)",
            project: latest.project
        )
    }

    private func tailLines(from file: SessionFile) -> [String]? {
        guard let handle = try? FileHandle(forReadingFrom: file.url) else { return nil }
        defer { try? handle.close() }

        do {
            let offset = file.size > maxTailBytes ? file.size - maxTailBytes : 0
            try handle.seek(toOffset: offset)
            guard let data = try handle.readToEnd(), !data.isEmpty else { return [] }

            var lineData = data.split(separator: 0x0A, omittingEmptySubsequences: true).map { Data($0) }
            if offset > 0, !lineData.isEmpty {
                lineData.removeFirst()
            }

            return lineData.compactMap { String(data: $0, encoding: .utf8) }
        } catch {
            return nil
        }
    }

    private func conversationMetadata(from file: SessionFile, sessionID: String) -> ProjectConversationMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: file.url) else {
            return conversationMetadata(sessionID: sessionID, cwd: nil, title: nil, startedAt: file.modifiedAt)
        }
        defer { try? handle.close() }

        var cwd: String?
        var title: String?
        var startedAt: Date?
        var threadSource: String?

        do {
            let data = try handle.read(upToCount: Int(maxTailBytes)) ?? Data()
            let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
            for lineData in lines {
                guard let line = String(data: Data(lineData), encoding: .utf8),
                      let data = line.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let payload = object["payload"] as? [String: Any] else {
                    continue
                }

                if (object["type"] as? String) == "session_meta" {
                    cwd = payload["cwd"] as? String
                    title = title ?? conversationTitle(from: payload)
                    startedAt = stringDate(payload["timestamp"] as? String) ?? stringDate(payload["started_at"] as? String)
                    threadSource = payload["thread_source"] as? String
                    if threadSource == "subagent" {
                        return nil
                    }
                    continue
                }

                title = title ?? userConversationTitle(from: payload)
                if title != nil, cwd != nil {
                    break
                }
            }
        } catch {
            return conversationMetadata(sessionID: sessionID, cwd: nil, title: nil, startedAt: file.modifiedAt)
        }

        if threadSource == "subagent" {
            return nil
        }
        return conversationMetadata(sessionID: sessionID, cwd: cwd, title: title, startedAt: startedAt ?? file.modifiedAt)
    }

    private func claudeConversationMetadata(from file: SessionFile, sessionID: String) -> ProjectConversationMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: file.url) else {
            return claudeConversationMetadata(sessionID: sessionID, cwd: nil, title: nil, startedAt: file.modifiedAt)
        }
        defer { try? handle.close() }

        var cwd: String?
        var title: String?
        var startedAt: Date?
        var sawSidechain = false

        do {
            let data = try handle.read(upToCount: Int(maxTailBytes)) ?? Data()
            let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
            for lineData in lines {
                guard let line = String(data: Data(lineData), encoding: .utf8),
                      let data = line.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }

                if (object["isSidechain"] as? Bool) == true {
                    sawSidechain = true
                    continue
                }

                cwd = cwd ?? object["cwd"] as? String
                startedAt = startedAt ?? stringDate(object["timestamp"] as? String)
                title = title ?? claudeUserConversationTitle(from: object)
                if title != nil, cwd != nil, startedAt != nil {
                    break
                }
            }
        } catch {
            return claudeConversationMetadata(sessionID: sessionID, cwd: nil, title: nil, startedAt: file.modifiedAt)
        }

        if sawSidechain, cwd == nil, title == nil {
            return nil
        }
        return claudeConversationMetadata(sessionID: sessionID, cwd: cwd, title: title, startedAt: startedAt ?? file.modifiedAt)
    }

    private func conversationMetadata(
        service: AccountService,
        sessionID: String,
        cwd: String?,
        title: String?,
        startedAt: Date?
    ) -> ProjectConversationMetadata {
        switch service {
        case .codex:
            return conversationMetadata(sessionID: sessionID, cwd: cwd, title: title, startedAt: startedAt)
        case .claude:
            return claudeConversationMetadata(sessionID: cleanAgentSessionID(sessionID), cwd: cwd, title: title, startedAt: startedAt)
        }
    }

    private func agentSignalService(from record: [String: Any], sessionID: String) -> AccountService {
        if let service = accountService(from: sessionID) {
            return service
        }

        for key in ["service", "provider", "agent", "app", "client"] {
            if let service = accountService(from: record[key]) {
                return service
            }
        }

        if let metadata = record["metadata"] as? [String: Any] {
            for key in ["service", "provider", "agent", "app", "client"] {
                if let service = accountService(from: metadata[key]) {
                    return service
                }
            }
        }

        return .codex
    }

    private func accountService(from value: Any?) -> AccountService? {
        guard let rawValue = value as? String else { return nil }
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        if normalized.contains("claude") {
            return .claude
        }
        if normalized.contains("codex") {
            return .codex
        }
        return nil
    }

    private func cleanAgentSessionID(_ sessionID: String) -> String {
        sessionID
            .replacingOccurrences(of: "claude:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func claudeConversationMetadata(sessionID: String, cwd: String?, title: String?, startedAt: Date?) -> ProjectConversationMetadata {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = (trimmedTitle?.isEmpty == false) ? trimmedTitle! : "Claude 对话"
        let trimmedCWD = cwd?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedCWD, !trimmedCWD.isEmpty {
            let url = URL(fileURLWithPath: trimmedCWD)
            let project = url.lastPathComponent.isEmpty ? compactPath(trimmedCWD) : url.lastPathComponent
            return ProjectConversationMetadata(
                item: ProjectConversationItem(service: .claude, title: displayTitle, subtitle: "Claude · \(project)"),
                startedAt: startedAt
            )
        }

        let shortID = String(sessionID.prefix(18))
        return ProjectConversationMetadata(
            item: ProjectConversationItem(service: .claude, title: displayTitle, subtitle: "Claude · \(shortID)"),
            startedAt: startedAt
        )
    }

    private func conversationMetadata(sessionID: String, cwd: String?, title: String?, startedAt: Date?) -> ProjectConversationMetadata {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = (trimmedTitle?.isEmpty == false) ? trimmedTitle! : "Codex 对话"
        let trimmedCWD = cwd?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedCWD, !trimmedCWD.isEmpty {
            let url = URL(fileURLWithPath: trimmedCWD)
            let project = url.lastPathComponent.isEmpty ? compactPath(trimmedCWD) : url.lastPathComponent
            return ProjectConversationMetadata(
                item: ProjectConversationItem(service: .codex, title: displayTitle, subtitle: "Codex · \(project)"),
                startedAt: startedAt
            )
        }

        let shortID = String(sessionID.prefix(18))
        return ProjectConversationMetadata(
            item: ProjectConversationItem(service: .codex, title: displayTitle, subtitle: "Codex · \(shortID)"),
            startedAt: startedAt
        )
    }

    private func conversationTitle(from payload: [String: Any]) -> String? {
        for key in ["title", "thread_title", "conversation_title", "name"] {
            if let value = payload[key] as? String,
               let title = normalizedConversationTitle(value) {
                return title
            }
        }
        return nil
    }

    private func userConversationTitle(from payload: [String: Any]) -> String? {
        guard let payloadType = payload["type"] as? String else { return nil }

        if payloadType == "user_message" {
            if let message = payload["message"] as? String {
                return normalizedConversationTitle(message)
            }
            if let elements = payload["message"] as? [[String: Any]] {
                return normalizedConversationTitle(text(from: elements))
            }
        }

        if payloadType == "message",
           (payload["role"] as? String) == "user" {
            if let content = payload["content"] as? String {
                return normalizedConversationTitle(content)
            }
            if let elements = payload["content"] as? [[String: Any]] {
                return normalizedConversationTitle(text(from: elements))
            }
        }

        return nil
    }

    private func claudeUserConversationTitle(from object: [String: Any]) -> String? {
        guard (object["type"] as? String) == "user",
              let message = object["message"] as? [String: Any] else {
            return nil
        }

        if let content = message["content"] as? String {
            return normalizedConversationTitle(content)
        }
        if let elements = message["content"] as? [[String: Any]] {
            return normalizedConversationTitle(text(from: elements))
        }
        return nil
    }

    private func text(from elements: [[String: Any]]) -> String {
        elements.compactMap { element in
            element["text"] as? String
        }.joined(separator: "\n")
    }

    private func normalizedConversationTitle(_ value: String) -> String? {
        let withoutEnvironment = value.replacingOccurrences(
            of: "(?s)<environment_context>.*?</environment_context>",
            with: " ",
            options: .regularExpression
        )
        var cleaned = withoutEnvironment
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }
        if cleaned.hasPrefix("The following is the Codex agent history") {
            return nil
        }

        if cleaned.hasPrefix("Automation:") {
            cleaned = String(cleaned.dropFirst("Automation:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = cleaned.range(of: "Automation ID:") {
                cleaned = String(cleaned[..<range.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard !cleaned.isEmpty else { return nil }
        if cleaned.count > 32 {
            return String(cleaned.prefix(32)) + "..."
        }
        return cleaned
    }

    private func compactPath(_ path: String) -> String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~/" + String(path.dropFirst(home.count + 1))
        }
        return path
    }

    private func candidate(
        from line: String,
        defaultSessionID: String,
        project: ProjectConversationItem?
    ) -> ProjectConversationCandidate? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let timestamp = stringDate(object["timestamp"] as? String)
        let topLevelType = object["type"] as? String
        let payload = object["payload"] as? [String: Any] ?? [:]
        let sessionID = sessionID(in: payload) ?? defaultSessionID

        switch topLevelType {
        case "compacted":
            return ProjectConversationCandidate(
                signal: .active,
                updatedAt: timestamp,
                startedAt: nil,
                event: "context compacted",
                sessionID: sessionID,
                project: project
            )
        case "event_msg":
            return eventMessageCandidate(payload, timestamp: timestamp, sessionID: sessionID, project: project)
        case "response_item":
            return responseItemCandidate(payload, timestamp: timestamp, sessionID: sessionID, project: project)
        default:
            return nil
        }
    }

    private func claudeCandidate(
        from line: String,
        defaultSessionID: String,
        project: ProjectConversationItem?,
        runningSession: Bool = false
    ) -> ProjectConversationCandidate? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if (object["isSidechain"] as? Bool) == true {
            return nil
        }

        let timestamp = stringDate(object["timestamp"] as? String)
        let type = object["type"] as? String
        let sessionID = (object["sessionId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSessionID = (sessionID?.isEmpty == false) ? sessionID! : defaultSessionID
        if claudeObjectIsError(object) {
            return ProjectConversationCandidate(
                signal: .blocked,
                updatedAt: timestamp,
                startedAt: nil,
                event: "Claude error",
                sessionID: resolvedSessionID,
                project: project
            )
        }

        switch type {
        case "queue-operation":
            return nil
        case "last-prompt":
            return nil
        case "attachment":
            return ProjectConversationCandidate(
                signal: .active,
                updatedAt: timestamp,
                startedAt: nil,
                event: "Claude attachment",
                sessionID: resolvedSessionID,
                project: project
            )
        case "user":
            let event = claudeUserHasToolResult(object) ? "Claude tool result" : "Claude user prompt"
            return ProjectConversationCandidate(
                signal: .active,
                updatedAt: timestamp,
                startedAt: nil,
                event: event,
                sessionID: resolvedSessionID,
                project: project
            )
        case "assistant":
            let contentTypes = claudeMessageContentTypes(object)
            let toolNames = claudeToolUseNames(object)
            let stopReason = claudeStopReason(object)
            let signal: AgentActivitySignal
            let hasPendingToolUse = runningSession && (stopReason == "tool_use" || !toolNames.isEmpty)
            if hasPendingToolUse {
                signal = .permission
            } else if let toolName = toolNames.first {
                signal = claudeToolSignal(toolName)
            } else if contentTypes.contains("thinking") || stopReason == "tool_use" {
                signal = .active
            } else {
                signal = .done
            }
            let event: String
            if let toolName = toolNames.first {
                event = toolName
            } else if contentTypes.contains("thinking") {
                event = "Claude thinking"
            } else {
                event = "Claude response"
            }
            return ProjectConversationCandidate(
                signal: signal,
                updatedAt: timestamp,
                startedAt: nil,
                event: event,
                sessionID: resolvedSessionID,
                project: project
            )
        default:
            return nil
        }
    }

    private func claudeToolSignal(_ toolName: String) -> AgentActivitySignal {
        let normalized = toolName.lowercased()
        if normalized.contains("permission") || normalized.contains("approval") {
            return .permission
        }
        if normalized.contains("askuser") || normalized.contains("question") || normalized.contains("input") {
            return .attention
        }
        return .active
    }

    private func claudeStopReason(_ object: [String: Any]) -> String? {
        guard let message = object["message"] as? [String: Any],
              let value = message["stop_reason"] as? String else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func claudeObjectIsError(_ object: [String: Any]) -> Bool {
        if (object["isApiErrorMessage"] as? Bool) == true || object["error"] != nil {
            return true
        }
        return claudeMessageText(object).localizedCaseInsensitiveContains("API Error")
    }

    private func claudeMessageText(_ object: [String: Any]) -> String {
        guard let message = object["message"] as? [String: Any] else { return "" }
        if let content = message["content"] as? String {
            return content
        }
        if let elements = message["content"] as? [[String: Any]] {
            return text(from: elements)
        }
        return ""
    }

    private func claudeMessageContentTypes(_ object: [String: Any]) -> [String] {
        guard let message = object["message"] as? [String: Any],
              let elements = message["content"] as? [[String: Any]] else {
            return []
        }
        return elements.compactMap { $0["type"] as? String }
    }

    private func claudeToolUseNames(_ object: [String: Any]) -> [String] {
        guard let message = object["message"] as? [String: Any],
              let elements = message["content"] as? [[String: Any]] else {
            return []
        }
        return elements.compactMap { element in
            guard (element["type"] as? String) == "tool_use" else { return nil }
            return element["name"] as? String
        }
    }

    private func claudeUserHasToolResult(_ object: [String: Any]) -> Bool {
        guard let message = object["message"] as? [String: Any],
              let elements = message["content"] as? [[String: Any]] else {
            return false
        }
        return elements.contains { ($0["type"] as? String) == "tool_result" }
    }

    private func eventMessageCandidate(
        _ payload: [String: Any],
        timestamp: Date?,
        sessionID: String,
        project: ProjectConversationItem?
    ) -> ProjectConversationCandidate? {
        switch payload["type"] as? String {
        case "task_started", "user_message":
            return ProjectConversationCandidate(signal: .active, updatedAt: timestamp, startedAt: nil, event: "task started", sessionID: sessionID, project: project)
        case "task_complete", "turn_aborted":
            return ProjectConversationCandidate(signal: .done, updatedAt: timestamp, startedAt: nil, event: "task complete", sessionID: sessionID, project: project)
        case "agent_message":
            if (payload["phase"] as? String) == "final_answer" {
                return ProjectConversationCandidate(signal: .done, updatedAt: timestamp, startedAt: nil, event: "final answer", sessionID: sessionID, project: project)
            }
            return ProjectConversationCandidate(signal: .active, updatedAt: timestamp, startedAt: nil, event: "agent message", sessionID: sessionID, project: project)
        default:
            return nil
        }
    }

    private func responseItemCandidate(
        _ payload: [String: Any],
        timestamp: Date?,
        sessionID: String,
        project: ProjectConversationItem?
    ) -> ProjectConversationCandidate? {
        switch payload["type"] as? String {
        case "reasoning":
            return ProjectConversationCandidate(signal: .active, updatedAt: timestamp, startedAt: nil, event: "reasoning", sessionID: sessionID, project: project)
        case "function_call", "custom_tool_call":
            let toolName = toolName(in: payload)
            let normalizedToolName = toolName.lowercased()
            let signal: AgentActivitySignal
            if normalizedToolName.contains("permission") || normalizedToolName.contains("approval") {
                signal = .permission
            } else if normalizedToolName == "request_user_input" {
                signal = .attention
            } else {
                signal = .active
            }
            return ProjectConversationCandidate(signal: signal, updatedAt: timestamp, startedAt: nil, event: toolName, sessionID: sessionID, project: project)
        case "function_call_output":
            return ProjectConversationCandidate(signal: .active, updatedAt: timestamp, startedAt: nil, event: "tool output", sessionID: sessionID, project: project)
        case "message":
            if (payload["role"] as? String) == "user" {
                return nil
            }
            if (payload["phase"] as? String) == "final_answer" {
                return ProjectConversationCandidate(signal: .done, updatedAt: timestamp, startedAt: nil, event: "final answer", sessionID: sessionID, project: project)
            }
            return ProjectConversationCandidate(signal: .active, updatedAt: timestamp, startedAt: nil, event: "message", sessionID: sessionID, project: project)
        default:
            return nil
        }
    }

    private func toolName(in payload: [String: Any]) -> String {
        guard let name = payload["name"] as? String else { return "tool call" }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "tool call" : trimmed
    }

    private func sessionID(in payload: [String: Any]) -> String? {
        for key in ["threadId", "thread_id", "conversationId", "conversation_id"] {
            if let value = payload[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private func rolloutSessionID(from url: URL) -> String? {
        let parts = url.deletingPathExtension().lastPathComponent.split(separator: "-")
        guard parts.count >= 5 else { return nil }
        let candidate = parts.suffix(5).joined(separator: "-").lowercased()
        return candidate.count == 36 ? candidate : nil
    }

    private func fileModificationDate(_ url: URL) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }

    private func sessionItems(
        from candidates: [ProjectConversationCandidate],
        now: Date,
        source: String,
        staleDetail: String
    ) -> [ProjectConversationSession] {
        var result: [ProjectConversationSession] = []
        var seen = Set<String>()

        for candidate in candidates.sorted(by: { candidateStartDate($0) > candidateStartDate($1) }) {
            let state = candidate.signal.projectState
            guard shouldDisplaySession(state) || shouldDisplayRecentCompletedSession(candidate, now: now) else { continue }
            guard let project = candidate.project else { continue }
            let key = sessionKey(service: project.service, sessionID: candidate.sessionID)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(
                ProjectConversationSession(
                    sessionID: candidate.sessionID,
                    service: project.service,
                    title: project.title,
                    subtitle: project.subtitle,
                    state: state,
                    detail: sessionDetail(
                        state: state,
                        event: candidate.event,
                        activeCount: 1,
                        staleDetail: staleDetail
                    ),
                    source: source,
                    updatedAt: candidate.updatedAt,
                    startedAt: candidate.startedAt
                )
            )
        }

        return result
    }

    private func sessionKey(service: AccountService, sessionID: String) -> String {
        "\(service.rawValue):\(sessionID)"
    }

    private func shouldDisplaySession(_ state: ProjectConversationState) -> Bool {
        switch state {
        case .active, .needsReview, .permission, .blocked, .stale, .paused:
            return true
        case .idle, .completed:
            return false
        }
    }

    private func shouldDisplayRecentCompletedSession(_ candidate: ProjectConversationCandidate, now: Date) -> Bool {
        guard candidate.signal.projectState == .completed,
              let updatedAt = candidate.updatedAt else {
            return false
        }
        return now.timeIntervalSince(updatedAt) <= recentConversationTTL
    }

    private func candidateStartDate(_ candidate: ProjectConversationCandidate) -> Date {
        candidate.startedAt ?? candidate.updatedAt ?? .distantPast
    }

    private func sessionDetail(
        state: ProjectConversationState,
        event: String?,
        activeCount: Int,
        staleDetail: String
    ) -> String {
        switch state {
        case .idle:
            return "No recent unfinished agent work."
        case .completed:
            return "The latest agent conversation appears complete."
        case .active:
            return activeCount > 1
                ? "\(activeCount) agent sessions may still be running."
                : "An agent conversation may still be running."
        case .needsReview:
            return event.map { "The agent is waiting on \($0)." }
                ?? "The agent may be waiting for you to review something."
        case .permission:
            return event.map { "The agent is waiting for authorization: \($0)." }
                ?? "The agent is waiting for authorization."
        case .blocked:
            return event.map { "The agent is blocked around \($0)." }
                ?? "The agent may be blocked by a failure or exception."
        case .stale:
            return staleDetail
        case .paused:
            return "Project conversation monitoring is paused."
        }
    }
}

private func stringDate(_ value: String?) -> Date? {
    guard let value else { return nil }

    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractionalFormatter.date(from: value) {
        return date
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}

private enum TrafficLightStatusIcon {
    static func image(for state: ProjectConversationState, tick: Int) -> NSImage {
        let size = NSSize(width: 44, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        drawPillBackground(in: NSRect(origin: .zero, size: size))
        drawLights(for: state, tick: tick, in: NSRect(x: 0, y: 0, width: 44, height: 16), gap: 4)

        image.isTemplate = false
        return image
    }

    static let menuBarSize = NSSize(width: 92, height: 24)

    // Menu-bar item: a dark rounded pill showing the selected service glyph
    // on the left and the three status lamps on the right.
    static func menuBarImage(service: AccountService, state: ProjectConversationState, tick: Int) -> NSImage {
        let size = menuBarSize
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Single full-rounded capsule: service icon + divider + traffic lights.
        let pill = NSRect(origin: .zero, size: size)
        NSColor.black.setFill()
        NSBezierPath(roundedRect: pill, xRadius: size.height / 2, yRadius: size.height / 2).fill()

        let iconRect = NSRect(x: 8, y: 6, width: 12, height: 12)
        drawServiceGlyph(service: service, in: iconRect)

        NSColor.white.withAlphaComponent(0.15).setStroke()
        let divider = NSBezierPath()
        divider.lineWidth = 1
        divider.move(to: NSPoint(x: 28.5, y: 6))
        divider.line(to: NSPoint(x: 28.5, y: 18))
        divider.stroke()

        drawMenuBarStateLights(for: state, tick: tick, in: NSRect(x: 36, y: 0, width: 48, height: 24))

        image.isTemplate = false
        return image
    }

    private static func drawMenuBarStateLights(for state: ProjectConversationState, tick: Int, in rect: NSRect) {
        let lamps: [(ProjectConversationLamp, NSColor, CGFloat)] = [
            (.red, NSColor(calibratedRed: 240 / 255, green: 51 / 255, blue: 46 / 255, alpha: 1), 6),
            (.yellow, NSColor(calibratedRed: 1, green: 188 / 255, blue: 32 / 255, alpha: 1), 24),
            (.green, NSColor(calibratedRed: 7 / 255, green: 171 / 255, blue: 75 / 255, alpha: 1), 42)
        ]

        for (lamp, color, centerX) in lamps {
            let intensity = lightIntensity(lamp, state: state, tick: tick)
            let alpha = intensity > 0 ? max(0.32, intensity) : 0.18
            color.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.minX + centerX - 6, y: rect.midY - 6, width: 12, height: 12)).fill()
        }
    }

    private static func drawServiceGlyph(service: AccountService, in rect: NSRect) {
        let resourceName = service == .codex ? "CodexTabIcon" : "ClaudeTabIcon"
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "svg"),
           let svg = try? String(contentsOf: url, encoding: .utf8) {
            let white = svg.replacingOccurrences(of: #"fill="black" fill-opacity="0.65""#, with: #"fill="white""#)
            if let data = white.data(using: .utf8), let image = NSImage(data: data) {
                image.draw(in: rect)
                return
            }
        }
        // Fallback dot glyph.
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.midX - 3, y: rect.midY - 3, width: 6, height: 6)).fill()
    }

    static func staticPillImage() -> NSImage {
        let size = NSSize(width: 44, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        drawPillBackground(in: NSRect(origin: .zero, size: size))
        drawLights(for: .paused, tick: 0, in: NSRect(x: 0, y: 0, width: 44, height: 16), gap: 4, forceAllOn: true)

        image.isTemplate = false
        return image
    }

    private static func drawPillBackground(in rect: NSRect) {
        NSColor.black.setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
    }

    static func drawLights(
        for state: ProjectConversationState,
        tick: Int,
        in rect: NSRect,
        gap: CGFloat = 4,
        forceAllOn: Bool = false,
        maxDiameter: CGFloat = 10
    ) {
        let diameter = min(maxDiameter, rect.height)
        let totalWidth = diameter * 3 + gap * 2
        let startX = rect.midX - totalWidth / 2
        let y = rect.midY - diameter / 2

        let lamps: [(ProjectConversationLamp, NSColor)] = [
            (.red, NSColor(calibratedRed: 240 / 255, green: 51 / 255, blue: 46 / 255, alpha: 1)),
            (.yellow, NSColor(calibratedRed: 1, green: 188 / 255, blue: 32 / 255, alpha: 1)),
            (.green, NSColor(calibratedRed: 7 / 255, green: 171 / 255, blue: 75 / 255, alpha: 1))
        ]

        for (index, entry) in lamps.enumerated() {
            let x = startX + CGFloat(index) * (diameter + gap)
            let lampRect = NSRect(x: x, y: y, width: diameter, height: diameter)
            let intensity = forceAllOn ? 1 : lightIntensity(entry.0, state: state, tick: tick)
            let path = NSBezierPath(ovalIn: lampRect)

            if intensity > 0 {
                NSGraphicsContext.saveGraphicsState()
                let shadow = NSShadow()
                shadow.shadowColor = entry.1.withAlphaComponent(0.35 * intensity)
                shadow.shadowBlurRadius = 2.5
                shadow.set()
                entry.1.withAlphaComponent(max(0.32, intensity)).setFill()
                path.fill()
                NSGraphicsContext.restoreGraphicsState()

                NSColor.white.withAlphaComponent(0.18 + 0.18 * intensity).setStroke()
                path.lineWidth = 0.7
                path.stroke()
            } else {
                entry.1.withAlphaComponent(0.18).setFill()
                path.fill()
                NSColor.black.withAlphaComponent(0.08).setStroke()
                path.lineWidth = 0.7
                path.stroke()
            }
        }
    }

    static func drawServiceTabLights(
        for state: ProjectConversationState,
        tick: Int,
        in rect: NSRect
    ) {
        let diameter: CGFloat = 8
        let gap: CGFloat = 4
        let totalWidth = diameter * 3 + gap * 2
        let startX = rect.midX - totalWidth / 2
        let y = rect.midY - diameter / 2
        let lamps: [(ProjectConversationLamp, NSColor)] = [
            (.red, NSColor(calibratedRed: 240 / 255, green: 51 / 255, blue: 46 / 255, alpha: 1)),
            (.yellow, NSColor(calibratedRed: 1, green: 188 / 255, blue: 32 / 255, alpha: 1)),
            (.green, NSColor(calibratedRed: 7 / 255, green: 171 / 255, blue: 75 / 255, alpha: 1))
        ]

        for (index, entry) in lamps.enumerated() {
            let intensity = lightIntensity(entry.0, state: state, tick: tick)
            let alpha = intensity > 0 ? max(0.45, intensity) : 0.28
            entry.1.withAlphaComponent(alpha).setFill()
            NSBezierPath(
                ovalIn: NSRect(
                    x: startX + CGFloat(index) * (diameter + gap),
                    y: y,
                    width: diameter,
                    height: diameter
                )
            ).fill()
        }
    }

    private static func lightIntensity(
        _ lamp: ProjectConversationLamp,
        state: ProjectConversationState,
        tick: Int
    ) -> CGFloat {
        // Agreed traffic-light mapping:
        //   idle                 = no lit lamp
        //   completed            = green steady while still in the recent window
        //   active               = green breathing
        //   needs review/notice  = yellow breathing
        //   permission           = yellow blinking
        //   blocked/failure      = red breathing
        //   stale/untrusted      = red steady
        //   paused               = red + green steady
        switch state {
        case .idle:
            return 0
        case .completed:
            return lamp == .green ? 1 : 0
        case .active:
            return lamp == .green ? breathingIntensity(tick: tick) : 0
        case .needsReview:
            return lamp == .yellow ? breathingIntensity(tick: tick) : 0
        case .permission:
            return lamp == .yellow ? blinkingIntensity(tick: tick) : 0
        case .blocked:
            return lamp == .red ? breathingIntensity(tick: tick) : 0
        case .stale:
            return lamp == .red ? 1 : 0
        case .paused:
            return (lamp == .red || lamp == .green) ? 1 : 0
        }
    }

    private static func breathingIntensity(tick: Int) -> CGFloat {
        let phase = Double(tick) * 0.18
        let normalized = (sin(phase - .pi / 2) + 1) / 2
        return CGFloat(0.32 + normalized * 0.68)
    }

    private static func blinkingIntensity(tick: Int) -> CGFloat {
        ((tick / 10) % 2 == 0) ? 1 : 0
    }

    // Brief "just finished" green pulse.
    private static func pulseIntensity(tick: Int) -> CGFloat {
        let values: [CGFloat] = [1.0, 0.7, 0, 0]
        return values[(tick / 8) % values.count]
    }

    // Strong attention pulse for states that block the agent (permission).
    private static func alertPulseIntensity(tick: Int) -> CGFloat {
        let values: [CGFloat] = [0.45, 0.72, 1.0, 0.72, 0, 0, 0, 0]
        return values[(tick / 6) % values.count]
    }

    // Low-key caution pulse for an untrusted/stale status.
    private static func dimPulseIntensity(tick: Int) -> CGFloat {
        let values: [CGFloat] = [0.35, 0.5, 0.65, 0.5, 0, 0, 0, 0]
        return values[(tick / 8) % values.count]
    }
}

private struct UsageBarRow {
    let title: String
    let usedPercent: Double?
    let resetText: String
}

private struct ProfileTabItem {
    let service: AccountService
    let accountType: String
    let profile: String
    let subtitle: String
    let isActive: Bool
}

private enum MenuDesign {
    static let width: CGFloat = 320
    static let horizontalPadding: CGFloat = 12
    static let contentWidth: CGFloat = 296
    static let separatorX: CGFloat = 12
    static let separatorWidth: CGFloat = 296
    static let nativeTextX: CGFloat = 16
    static let panelCornerRadius: CGFloat = 13
    static let moduleCornerRadius: CGFloat = 8
    static let usageCornerRadius: CGFloat = 6
    static let innerCornerRadius: CGFloat = 4
}

private final class ServiceTabsMenuView: NSView {
    private static let height: CGFloat = 48
    private static let segmentHeight: CGFloat = 48
    private static let gap: CGFloat = 0

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: Self.height)
    }

    init(
        selectionMode: ServiceSelectionMode,
        animationOriginMode: ServiceSelectionMode? = nil,
        serviceStates: [AccountService: ProjectConversationState],
        serviceAvailability: [AccountService: ServiceAvailability],
        tickProvider: @escaping () -> Int,
        target: AnyObject?,
        action: Selector
    ) {
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: Self.height)))

        let modes: [ServiceSelectionMode] = [.auto] + AccountService.allCases.map { .service($0) }
        let tabCount = CGFloat(modes.count)
        let tabWidth = MenuDesign.separatorWidth / tabCount
        let highlightView = ServiceTabHighlightView(frame: tabRect(for: animationOriginMode ?? selectionMode, modes: modes, tabWidth: tabWidth))
        addSubview(highlightView)
        let selectedRect = tabRect(for: selectionMode, modes: modes, tabWidth: tabWidth)
        if highlightView.frame != selectedRect {
            DispatchQueue.main.async { [weak highlightView] in
                guard let highlightView else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    highlightView.animator().frame = selectedRect
                }
            }
        }
        for (index, mode) in modes.enumerated() {
            let button = ServiceTabButton(
                mode: mode,
                isSelected: mode == selectionMode,
                serviceState: mode.service.flatMap { serviceStates[$0] },
                availability: mode.service.flatMap { serviceAvailability[$0] } ?? .installed,
                tickProvider: tickProvider,
                frame: NSRect(
                    x: MenuDesign.separatorX + CGFloat(index) * (tabWidth + Self.gap),
                    y: 0,
                    width: tabWidth,
                    height: Self.segmentHeight
                ),
                target: target,
                action: action
            )
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        AppDesign.moduleBackground.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: MenuDesign.separatorX, y: 0, width: MenuDesign.separatorWidth, height: Self.segmentHeight),
            xRadius: MenuDesign.moduleCornerRadius,
            yRadius: MenuDesign.moduleCornerRadius
        ).fill()
    }

    private func tabRect(for mode: ServiceSelectionMode, modes: [ServiceSelectionMode], tabWidth: CGFloat) -> NSRect {
        let index = modes.firstIndex(of: mode) ?? 0
        return NSRect(
            x: MenuDesign.separatorX + CGFloat(index) * (tabWidth + Self.gap),
            y: 0,
            width: tabWidth,
            height: Self.segmentHeight
        )
    }
}

private final class ServiceTabHighlightView: NSView {
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = MenuDesign.moduleCornerRadius
        layer?.masksToBounds = true
        layer?.backgroundColor = AppDesign.blue.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class ServiceTabButton: NSControl {
    override var isFlipped: Bool { true }

    let mode: ServiceSelectionMode
    private let isSelectedService: Bool
    private let serviceState: ProjectConversationState?
    private let availability: ServiceAvailability
    private let tickProvider: () -> Int
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    init(
        mode: ServiceSelectionMode,
        isSelected: Bool,
        serviceState: ProjectConversationState?,
        availability: ServiceAvailability,
        tickProvider: @escaping () -> Int,
        frame: NSRect,
        target: AnyObject?,
        action: Selector?
    ) {
        self.mode = mode
        self.isSelectedService = isSelected
        self.serviceState = serviceState
        self.availability = availability
        self.tickProvider = tickProvider
        super.init(frame: frame)
        self.target = target
        self.action = action
        isEnabled = availability.isSelectable
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        guard availability.isSelectable, !isSelectedService else { return }
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        guard availability.isSelectable, !isSelectedService else { return }
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard availability.isSelectable else { return }
        isPressed = true
        needsDisplay = true
        isPressed = false
        needsDisplay = true

        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        if !isSelectedService, isHovered || isPressed {
            AppDesign.hoverBackground.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: MenuDesign.moduleCornerRadius, yRadius: MenuDesign.moduleCornerRadius).fill()
        }

        switch mode {
        case .auto:
            let textColor = isSelectedService
                ? NSColor.white
                : AppDesign.textPrimary.withAlphaComponent(availability.contentAlpha)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: textColor
            ]
            let text = "AUTO" as NSString
            let size = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: floor((bounds.width - size.width) / 2), y: floor((bounds.height - size.height) / 2)), withAttributes: attributes)
        case .service:
            let iconSize: CGFloat = 16
            let iconRect = NSRect(
                x: floor((bounds.width - iconSize) / 2),
                y: 9,
                width: iconSize,
                height: iconSize
            )
            drawServiceIcon(in: iconRect)
            if let serviceState, availability.isSelectable {
                let indicatorRect = NSRect(
                    x: floor((bounds.width - 32) / 2),
                    y: 31,
                    width: 32,
                    height: 8
                )
                TrafficLightStatusIcon.drawServiceTabLights(
                    for: serviceState,
                    tick: tickProvider(),
                    in: indicatorRect
                )
            }
        }
    }

    private func drawServiceIcon(in rect: NSRect) {
        guard let service = mode.service else { return }
        let resourceName = service == .codex ? "CodexTabIcon" : "ClaudeTabIcon"
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "svg"),
           let svg = try? String(contentsOf: url, encoding: .utf8),
           let data = adaptedSVG(svg).data(using: .utf8),
           let image = NSImage(data: data) {
            image.draw(in: aspectFitRect(for: image, in: rect), from: .zero, operation: .sourceOver, fraction: availability.contentAlpha, respectFlipped: true, hints: nil)
            return
        }
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            image.draw(in: aspectFitRect(for: image, in: rect), from: .zero, operation: .sourceOver, fraction: availability.contentAlpha, respectFlipped: true, hints: nil)
            return
        }

        let color = isSelectedService
            ? NSColor.white
            : AppDesign.textSecondary.withAlphaComponent(AppDesign.textSecondary.alphaComponent * availability.contentAlpha)
        color.setFill()
        let center = NSPoint(x: rect.midX, y: rect.midY)
        for angle in stride(from: CGFloat(0), to: CGFloat.pi * 2, by: CGFloat.pi / 3) {
            let dot = NSRect(
                x: center.x + cos(angle) * 3.1 - 1.6,
                y: center.y + sin(angle) * 3.1 - 1.6,
                width: 3.2,
                height: 3.2
            )
            NSBezierPath(ovalIn: dot).fill()
        }
        NSBezierPath(ovalIn: NSRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)).fill()
    }

    private func adaptedSVG(_ svg: String) -> String {
        guard let service = mode.service else { return svg }
        let color = isSelectedService
            ? NSColor.white
            : AppDesign.textSecondary.withAlphaComponent(AppDesign.textSecondary.alphaComponent * availability.contentAlpha)
        switch service {
        case .codex:
            return svgReplacingFills(svg, with: color)
        case .claude:
            return svgReplacingFills(svg, with: color)
        }
    }
}

private final class MenuHeaderView: NSView {
    private let titleText: String

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: 40)
    }

    init(title: String) {
        self.titleText = title
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: 40)))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let iconContainer = NSRect(x: MenuDesign.separatorX, y: 0, width: 40, height: 40)
        (AppDesign.isSystemDarkMode ? NSColor.white.withAlphaComponent(0.12) : NSColor.white).setFill()
        NSBezierPath(roundedRect: iconContainer, xRadius: 10.388, yRadius: 10.388).fill()

        TrafficLightStatusIcon.staticPillImage().draw(
            in: NSRect(x: iconContainer.minX + 3.3, y: iconContainer.minY + 13.79, width: 33.4, height: 12.43)
        )

        let titleAttributes = textAttributes(
            font: .systemFont(ofSize: 13, weight: .bold),
            color: AppDesign.textPrimary
        )
        drawText(
            titleText,
            in: NSRect(x: 60, y: 4, width: 220, height: 16),
            attributes: titleAttributes
        )
        drawText(
            "For account switching & status indication",
            in: NSRect(x: 60, y: 22, width: 230, height: 14),
            attributes: textAttributes(
                font: .systemFont(ofSize: 11, weight: .medium),
                color: AppDesign.textTertiary
            )
        )
    }

    private func textAttributes(font: NSFont, color: NSColor, kern: CGFloat = 0) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .kern: kern,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class PlainTextButton: NSControl {
    override var isFlipped: Bool { true }

    private let titleText: String
    private let textColor: NSColor
    private let buttonFont: NSFont
    private var isHovered = false
    private var hoverTrackingArea: NSTrackingArea?

    init(
        title: String,
        frame: NSRect,
        textColor: NSColor,
        font: NSFont = AppDesign.pingFang(size: 12, weight: .semibold),
        target: AnyObject?,
        action: Selector?
    ) {
        self.titleText = title
        self.textColor = textColor
        self.buttonFont = font
        super.init(frame: frame)
        self.target = target
        self.action = action
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: buttonFont,
            .foregroundColor: isHovered ? AppDesign.linkBlue : textColor
        ]
        (titleText as NSString).draw(
            with: bounds,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }
}

private final class ProfileTabButton: NSControl {
    override var isFlipped: Bool { true }

    let service: AccountService
    let profile: String
    private let accountType: String
    private let subtitle: String
    private let isActiveProfile: Bool
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    init(item: ProfileTabItem, frame: NSRect, target: AnyObject?, action: Selector?) {
        self.service = item.service
        self.accountType = item.accountType
        self.profile = item.profile
        self.subtitle = item.subtitle
        self.isActiveProfile = item.isActive
        super.init(frame: frame)
        self.target = target
        self.action = action
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isActiveProfile else { return }
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        guard !isActiveProfile else { return }
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard !isActiveProfile else { return }
        isPressed = true
        needsDisplay = true
        isPressed = false
        needsDisplay = true

        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: MenuDesign.moduleCornerRadius, yRadius: MenuDesign.moduleCornerRadius)
        if isActiveProfile {
            AppDesign.blue.setFill()
        } else {
            (isHovered || isPressed ? AppDesign.hoverBackground : AppDesign.moduleBackground).setFill()
        }
        path.fill()

        let titleColor = isActiveProfile ? NSColor.white : AppDesign.textPrimary
        let subtitleColor = isActiveProfile ? NSColor.white.withAlphaComponent(0.45) : AppDesign.textTertiary
        let textWidth = bounds.width - 24
        let hasSubtitle = !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let titleRect = NSRect(x: 12, y: hasSubtitle ? 6 : 13, width: textWidth, height: 22)
        let subtitleRect = NSRect(x: 12, y: 28, width: textWidth, height: 14)

        drawText(
            profile,
            in: titleRect,
            attributes: textAttributes(font: AppDesign.pingFang(size: 14, weight: .medium), color: titleColor)
        )
        if hasSubtitle {
            drawText(
                subtitle,
                in: subtitleRect,
                attributes: textAttributes(font: AppDesign.pingFang(size: 10, weight: .medium), color: subtitleColor)
            )
        }
    }

    private func textAttributes(font: NSFont, color: NSColor) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class AddAccountButton: NSControl {
    override var isFlipped: Bool { true }

    let service: AccountService
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    init(service: AccountService, frame frameRect: NSRect) {
        self.service = service
        super.init(frame: frameRect)
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
        isPressed = false
        needsDisplay = true

        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Borderless plus glyph (matches the Figma 18×18 icon: black 0.45,
        // 1.5pt strokes, arms spanning ~3.75…14.25).
        let color = (isHovered || isPressed) ? AppDesign.textSecondary : AppDesign.textTertiary
        if isHovered || isPressed {
            AppDesign.hoverBackground.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        }
        color.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: bounds.midX - 5.25, y: bounds.midY))
        path.line(to: NSPoint(x: bounds.midX + 5.25, y: bounds.midY))
        path.move(to: NSPoint(x: bounds.midX, y: bounds.midY - 5.25))
        path.line(to: NSPoint(x: bounds.midX, y: bounds.midY + 5.25))
        path.stroke()
    }
}

private final class AddAccountRowView: NSControl {
    override var isFlipped: Bool { true }

    let service: AccountService
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: 34)
    }

    init(service: AccountService, target: AnyObject?, action: Selector?) {
        self.service = service
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: 34)))
        self.target = target
        self.action = action
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
        isPressed = false
        needsDisplay = true

        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = NSRect(x: MenuDesign.horizontalPadding, y: 0, width: MenuDesign.contentWidth, height: 24)
        AppDesign.moduleBackground.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

        AppDesign.textTertiary.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: rect.midX - 4, y: rect.midY))
        path.line(to: NSPoint(x: rect.midX + 4, y: rect.midY))
        path.move(to: NSPoint(x: rect.midX, y: rect.midY - 4))
        path.line(to: NSPoint(x: rect.midX, y: rect.midY + 4))
        path.stroke()
    }
}

private final class AccountSectionMenuView: NSView {
    private static let height: CGFloat = 72
    private static let headerHeight: CGFloat = 18
    private static let headerToRailGap: CGFloat = 6
    private static let railHeight: CGFloat = 48
    private static let gap: CGFloat = 6
    private static let addSize: CGFloat = 18
    private static let accountRailWidth: CGFloat = MenuDesign.separatorWidth
    private let service: AccountService
    private let accountCount: Int

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: Self.height)
    }

    init(
        items: [ProfileTabItem],
        service: AccountService,
        target: AnyObject?,
        switchAction: Selector,
        addAction: Selector
    ) {
        self.service = service
        self.accountCount = items.count
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: Self.height)))

        let railFrame = NSRect(
            x: MenuDesign.separatorX,
            y: Self.headerHeight + Self.headerToRailGap,
            width: Self.accountRailWidth,
            height: Self.railHeight
        )
        let scrollView = AccountRailScrollView(frame: railFrame)
        let tabWidth = Self.accountCardWidth(for: items.count)
        let contentWidth = max(
            Self.accountRailWidth,
            CGFloat(items.count) * tabWidth + CGFloat(max(items.count - 1, 0)) * Self.gap
        )
        let contentView = AccountRailContentView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: railFrame.height))

        var x: CGFloat = 0

        for item in items {
            let button = ProfileTabButton(
                item: item,
                frame: NSRect(x: x, y: 0, width: tabWidth, height: Self.railHeight),
                target: target,
                action: item.isActive ? nil : switchAction
            )
            contentView.addSubview(button)
            x += tabWidth + Self.gap
        }

        scrollView.documentView = contentView
        addSubview(scrollView)

        // Add-account control lives in the section header (top-right) now.
        let addButton = AddAccountButton(
            service: service,
            frame: NSRect(
                x: MenuDesign.separatorX + Self.accountRailWidth - Self.addSize,
                y: 0,
                width: Self.addSize,
                height: Self.addSize
            )
        )
        addButton.target = target
        addButton.action = addAction
        addSubview(addButton)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private static func accountCardWidth(for count: Int) -> CGFloat {
        switch count {
        case ..<2:
            return accountRailWidth
        case 2:
            return (accountRailWidth - gap) / 2
        default:
            return (accountRailWidth - gap * 2) / 3
        }
    }

    private func textWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let headerFont = AppDesign.pingFang(size: 12, weight: .semibold)
        let headerTitle = "\(service.displayTitle) Accounts"
        drawText(
            headerTitle,
            in: NSRect(x: MenuDesign.separatorX, y: 0, width: 160, height: Self.headerHeight),
            attributes: textAttributes(
                font: headerFont,
                color: AppDesign.textPrimary
            )
        )

        // Count sits right after the label, not pinned far right.
        let countX = MenuDesign.separatorX + textWidth(headerTitle, font: headerFont) + 4
        drawText(
            "\(accountCount)",
            in: NSRect(x: countX, y: 0, width: 40, height: Self.headerHeight),
            attributes: textAttributes(
                font: AppDesign.pingFang(size: 12, weight: .regular),
                color: AppDesign.textTertiary
            )
        )
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class AccountRailContentView: NSView {
    override var isFlipped: Bool { true }
}

private final class AccountRailScrollView: NSScrollView {
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        borderType = .noBorder
        hasVerticalScroller = false
        hasHorizontalScroller = false
        autohidesScrollers = true
        horizontalScrollElasticity = .allowed
        verticalScrollElasticity = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func scrollWheel(with event: NSEvent) {
        guard let documentView else {
            super.scrollWheel(with: event)
            return
        }

        let maxX = max(0, documentView.bounds.width - contentView.bounds.width)
        guard maxX > 0 else {
            super.scrollWheel(with: event)
            return
        }

        let dominantDelta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX
            : event.scrollingDeltaY
        let proposedX = contentView.bounds.origin.x + dominantDelta
        let clampedX = min(max(proposedX, 0), maxX)
        contentView.scroll(to: NSPoint(x: clampedX, y: 0))
        reflectScrolledClipView(contentView)
    }
}

private enum AccountListRowIntent {
    case switchProfile
    case deleteProfile
    case expandAccounts
}

private enum AccountRowClipStyle {
    case single
    case first
    case middle
    case last
}

private final class CurrentAccountRowView: NSControl {
    override var isFlipped: Bool { true }

    let service: AccountService
    let profile: String

    private let showsChevron: Bool
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: 48)
    }

    init(service: AccountService, profile: String, showsChevron: Bool, target: AnyObject?, action: Selector?) {
        self.service = service
        self.profile = profile
        self.showsChevron = showsChevron
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: 48)))
        self.target = target
        self.action = action
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true

        let point = convert(event.locationInWindow, from: nil)
        if showsChevron, bounds.contains(point), let action {
            NSApp.sendAction(action, to: target, from: self)
        }

        DispatchQueue.main.async { [weak self] in
            self?.isPressed = false
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let cardRect = NSRect(x: MenuDesign.separatorX, y: 0, width: MenuDesign.separatorWidth, height: 48)
        (isHovered || isPressed ? AppDesign.raisedHoverBackground : AppDesign.moduleBackground).setFill()
        NSBezierPath(roundedRect: cardRect, xRadius: MenuDesign.moduleCornerRadius, yRadius: MenuDesign.moduleCornerRadius).fill()

        drawSystemSymbol(
            "person",
            in: NSRect(x: cardRect.minX + 12, y: cardRect.minY + 16, width: 15, height: 16),
            pointSize: 13,
            color: AppDesign.textPrimary
        )
        drawText(
            profile.isEmpty ? "No Account" : profile,
            in: NSRect(x: cardRect.minX + 35, y: cardRect.minY + 16, width: 130, height: 16),
            attributes: textAttributes(font: .systemFont(ofSize: 13, weight: .medium), color: AppDesign.textPrimary)
        )
        drawText(
            "Current Account",
            in: NSRect(
                x: showsChevron ? cardRect.maxX - 116 : cardRect.maxX - 112,
                y: cardRect.minY + 17,
                width: showsChevron ? 88 : 100,
                height: 14
            ),
            attributes: textAttributes(font: .systemFont(ofSize: 11, weight: .medium), color: AppDesign.textTertiary, alignment: .right)
        )
        if showsChevron {
            drawSystemSymbol(
                "chevron.right",
                in: NSRect(x: cardRect.maxX - 24, y: cardRect.minY + 16, width: 12, height: 16),
                pointSize: 13,
                color: AppDesign.textPrimary
            )
        }
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class CompactAccountListView: NSView {
    override var isFlipped: Bool { true }

    private let rowCount: Int

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: CGFloat(max(rowCount, 1)) * 48)
    }

    init(service: AccountService, profiles: [String], activeProfile: String, target: AnyObject?, action: Selector?) {
        let sortedProfiles = profiles.sorted { lhs, rhs in
            if lhs == activeProfile { return true }
            if rhs == activeProfile { return false }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        self.rowCount = max(sortedProfiles.count, 1)
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: CGFloat(rowCount) * 48)))

        if sortedProfiles.isEmpty {
            return
        }

        for (index, profile) in sortedProfiles.enumerated() {
            let row = CompactAccountRowButton(
                service: service,
                profile: profile,
                isActive: profile == activeProfile,
                clipStyle: Self.clipStyle(at: index, count: sortedProfiles.count),
                frame: NSRect(
                    x: MenuDesign.separatorX,
                    y: CGFloat(index) * 48,
                    width: MenuDesign.separatorWidth,
                    height: 48
                )
            )
            row.target = target
            row.action = action
            addSubview(row)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let cardRect = NSRect(x: MenuDesign.separatorX, y: 0, width: MenuDesign.separatorWidth, height: CGFloat(max(rowCount, 1)) * 48)
        AppDesign.moduleBackground.setFill()
        NSBezierPath(roundedRect: cardRect, xRadius: MenuDesign.moduleCornerRadius, yRadius: MenuDesign.moduleCornerRadius).fill()

        if subviews.isEmpty {
            drawSystemSymbol(
                "person",
                in: NSRect(x: cardRect.minX + 12, y: cardRect.minY + 16, width: 16, height: 16),
                pointSize: 13,
                color: AppDesign.textTertiary
            )
            drawText(
                "No Account",
                in: NSRect(x: cardRect.minX + 36, y: cardRect.minY + 16, width: cardRect.width - 48, height: 16),
                attributes: textAttributes(font: .systemFont(ofSize: 13, weight: .medium), color: AppDesign.textTertiary)
            )
        }
    }

    private static func clipStyle(at index: Int, count: Int) -> AccountRowClipStyle {
        guard count > 1 else { return .single }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class CompactAccountRowButton: NSControl {
    override var isFlipped: Bool { true }

    let service: AccountService
    let profile: String
    var intent: AccountListRowIntent?

    private let isActiveProfile: Bool
    private let clipStyle: AccountRowClipStyle
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    init(service: AccountService, profile: String, isActive: Bool, clipStyle: AccountRowClipStyle, frame: NSRect) {
        self.service = service
        self.profile = profile
        self.isActiveProfile = isActive
        self.clipStyle = clipStyle
        super.init(frame: frame)
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let action, !isActiveProfile else { return }
        isPressed = true
        needsDisplay = true
        intent = point.x >= bounds.width - 72 && point.x < bounds.width - 38 ? .deleteProfile : .switchProfile
        NSApp.sendAction(action, to: target, from: self)
        DispatchQueue.main.async { [weak self] in
            self?.isPressed = false
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isHovered || isPressed
        if highlighted {
            AppDesign.hoverBackground.setFill()
            hoverFillPath().fill()
        }

        drawSystemSymbol(
            "person",
            in: NSRect(x: 12, y: 16, width: 16, height: 16),
            pointSize: 13,
            color: AppDesign.textPrimary
        )
        drawText(
            profile,
            in: NSRect(x: 36, y: 16, width: bounds.width - 132, height: 16),
            attributes: textAttributes(font: .systemFont(ofSize: 13, weight: .medium), color: AppDesign.textPrimary)
        )

        if isActiveProfile {
            drawText(
                "Current Account",
                in: NSRect(x: bounds.width - 112, y: 17, width: 100, height: 14),
                attributes: textAttributes(font: .systemFont(ofSize: 11, weight: .medium), color: AppDesign.textTertiary, alignment: .right)
            )
        } else if highlighted {
            drawText(
                "Delete",
                in: NSRect(x: bounds.width - 72, y: 17, width: 34, height: 14),
                attributes: textAttributes(font: .systemFont(ofSize: 11, weight: .medium), color: AppDesign.textTertiary, alignment: .right)
            )
            drawText(
                "Switch",
                in: NSRect(x: bounds.width - 34, y: 17, width: 34, height: 14),
                attributes: textAttributes(font: .systemFont(ofSize: 11, weight: .medium), color: AppDesign.textSecondary, alignment: .right)
            )
        }
    }

    private func hoverFillPath() -> NSBezierPath {
        let radius = MenuDesign.moduleCornerRadius
        let rect = bounds
        switch clipStyle {
        case .single:
            return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        case .middle:
            return NSBezierPath(rect: rect)
        case .first:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.minX, y: rect.minY + radius))
            path.curve(
                to: NSPoint(x: rect.minX + radius, y: rect.minY),
                controlPoint1: NSPoint(x: rect.minX, y: rect.minY + radius * 0.45),
                controlPoint2: NSPoint(x: rect.minX + radius * 0.45, y: rect.minY)
            )
            path.line(to: NSPoint(x: rect.maxX - radius, y: rect.minY))
            path.curve(
                to: NSPoint(x: rect.maxX, y: rect.minY + radius),
                controlPoint1: NSPoint(x: rect.maxX - radius * 0.45, y: rect.minY),
                controlPoint2: NSPoint(x: rect.maxX, y: rect.minY + radius * 0.45)
            )
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
            path.close()
            return path
        case .last:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - radius))
            path.curve(
                to: NSPoint(x: rect.maxX - radius, y: rect.maxY),
                controlPoint1: NSPoint(x: rect.maxX, y: rect.maxY - radius * 0.45),
                controlPoint2: NSPoint(x: rect.maxX - radius * 0.45, y: rect.maxY)
            )
            path.line(to: NSPoint(x: rect.minX + radius, y: rect.maxY))
            path.curve(
                to: NSPoint(x: rect.minX, y: rect.maxY - radius),
                controlPoint1: NSPoint(x: rect.minX + radius * 0.45, y: rect.maxY),
                controlPoint2: NSPoint(x: rect.minX, y: rect.maxY - radius * 0.45)
            )
            path.close()
            return path
        }
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class AccountListSectionView: NSView {
    private static let headerHeight: CGFloat = 18
    private static let headerToCardGap: CGFloat = 6
    private static let rowHeight: CGFloat = 40

    private let accountCount: Int
    private let rowCount: Int
    private let sectionHeight: CGFloat

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: sectionHeight)
    }

    init(
        service: AccountService,
        profiles: [String],
        activeProfile: String,
        isExpanded: Bool,
        animateExpansion: Bool,
        target: AnyObject?,
        rowAction: Selector,
        addAction: Selector
    ) {
        let sortedProfiles = profiles.sorted { lhs, rhs in
            if lhs == activeProfile { return true }
            if rhs == activeProfile { return false }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        let visibleProfiles: [String]
        if isExpanded {
            visibleProfiles = sortedProfiles
        } else if let active = sortedProfiles.first(where: { $0 == activeProfile }) {
            visibleProfiles = [active]
        } else if let firstProfile = sortedProfiles.first {
            visibleProfiles = [firstProfile]
        } else {
            visibleProfiles = []
        }
        self.accountCount = sortedProfiles.count
        self.rowCount = max(visibleProfiles.count, 1)
        self.sectionHeight = Self.headerHeight
            + Self.headerToCardGap
            + CGFloat(rowCount) * Self.rowHeight
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: sectionHeight)))

        let cardY = Self.headerHeight + Self.headerToCardGap
        let shouldAnimateRows = animateExpansion && isExpanded && visibleProfiles.count > 1
        for (index, profile) in visibleProfiles.enumerated() {
            let finalFrame = NSRect(
                x: MenuDesign.separatorX,
                y: cardY + CGFloat(index) * Self.rowHeight,
                width: MenuDesign.separatorWidth,
                height: Self.rowHeight
            )
            let row = AccountListRowButton(
                service: service,
                profile: profile,
                isActive: profile == activeProfile,
                showsExpandArrow: !isExpanded && sortedProfiles.count > 1 && profile == activeProfile,
                clipStyle: Self.clipStyle(at: index, count: visibleProfiles.count),
                frame: finalFrame
            )
            row.target = target
            row.action = rowAction
            if shouldAnimateRows && index > 0 {
                row.alphaValue = 0
                row.frame = finalFrame.offsetBy(dx: 0, dy: -8)
                DispatchQueue.main.async { [weak row] in
                    guard let row else { return }
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.22
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        row.animator().alphaValue = 1
                        row.animator().frame = finalFrame
                    }
                }
            }
            addSubview(row)
        }

        let addButton = AccountHeaderAddButton(
            service: service,
            frame: NSRect(
                x: MenuDesign.separatorX + MenuDesign.separatorWidth - 16,
                y: 1,
                width: 16,
                height: 16
            )
        )
        addButton.target = target
        addButton.action = addAction
        addSubview(addButton)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        drawText(
            "Accounts",
            in: NSRect(x: MenuDesign.separatorX, y: 0, width: 120, height: Self.headerHeight),
            attributes: textAttributes(font: AppDesign.pingFang(size: 12, weight: .semibold), color: AppDesign.textPrimary)
        )

        let cardRect = NSRect(
            x: MenuDesign.separatorX,
            y: Self.headerHeight + Self.headerToCardGap,
            width: MenuDesign.separatorWidth,
            height: sectionHeight - Self.headerHeight - Self.headerToCardGap
        )
        AppDesign.moduleBackground.setFill()
        NSBezierPath(roundedRect: cardRect, xRadius: MenuDesign.moduleCornerRadius, yRadius: MenuDesign.moduleCornerRadius).fill()

        if accountCount == 0 {
            drawText(
                "No saved accounts",
                in: NSRect(x: cardRect.minX + 10, y: cardRect.minY + 11, width: cardRect.width - 20, height: 18),
                attributes: textAttributes(font: AppDesign.pingFang(size: 12, weight: .medium), color: AppDesign.textSecondary)
            )
        }
    }

    private static func clipStyle(at index: Int, count: Int) -> AccountRowClipStyle {
        guard count > 1 else { return .single }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class AccountHeaderAddButton: NSControl {
    override var isFlipped: Bool { true }

    let service: AccountService
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    init(service: AccountService, frame frameRect: NSRect) {
        self.service = service
        super.init(frame: frameRect)
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true

        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point), let action {
            NSApp.sendAction(action, to: target, from: self)
        }

        DispatchQueue.main.async { [weak self] in
            self?.isPressed = false
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let iconRect = bounds.insetBy(dx: 2, dy: 2)
        (isHovered || isPressed ? AppDesign.linkBlue : AppDesign.textTertiary).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: iconRect.minX + 2, y: iconRect.midY))
        path.line(to: NSPoint(x: iconRect.maxX - 2, y: iconRect.midY))
        path.move(to: NSPoint(x: iconRect.midX, y: iconRect.minY + 2))
        path.line(to: NSPoint(x: iconRect.midX, y: iconRect.maxY - 2))
        path.stroke()
    }

    private func textAttributes(font: NSFont, color: NSColor) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class AccountListRowButton: NSControl {
    override var isFlipped: Bool { true }

    let service: AccountService
    let profile: String
    var intent: AccountListRowIntent?

    private let isActiveProfile: Bool
    private let showsExpandArrow: Bool
    private let clipStyle: AccountRowClipStyle
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    init(service: AccountService, profile: String, isActive: Bool, showsExpandArrow: Bool, clipStyle: AccountRowClipStyle, frame: NSRect) {
        self.service = service
        self.profile = profile
        self.isActiveProfile = isActive
        self.showsExpandArrow = showsExpandArrow
        self.clipStyle = clipStyle
        super.init(frame: frame)
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let action else { return }
        if isActiveProfile, !showsExpandArrow { return }

        isPressed = true
        needsDisplay = true
        if isActiveProfile {
            intent = .expandAccounts
        } else {
            intent = point.x >= bounds.width - 72 && point.x < bounds.width - 38 ? .deleteProfile : .switchProfile
        }
        NSApp.sendAction(action, to: target, from: self)

        DispatchQueue.main.async { [weak self] in
            self?.isPressed = false
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isHovered || isPressed
        if highlighted {
            AppDesign.hoverBackground.setFill()
            hoverFillPath().fill()
        }

        let trailingWidth: CGFloat = isActiveProfile ? (showsExpandArrow ? 72 : 52) : (highlighted ? 78 : 10)

        drawText(
            profile,
            in: NSRect(x: 10, y: 11, width: min(216, bounds.width - 20 - trailingWidth), height: 18),
            attributes: textAttributes(font: AppDesign.pingFang(size: 12, weight: .medium), color: AppDesign.textPrimary)
        )

        if isActiveProfile {
            let currentRect: NSRect
            let arrowRect = NSRect(x: bounds.width - 26, y: 12, width: 16, height: 16)
            if showsExpandArrow {
                currentRect = NSRect(x: arrowRect.minX - 46, y: 12, width: 42, height: 16)
            } else {
                currentRect = NSRect(x: bounds.width - 52, y: 12, width: 42, height: 16)
            }
            drawText(
                "Current",
                in: currentRect,
                attributes: textAttributes(
                    font: AppDesign.pingFang(size: 10, weight: .regular),
                    color: AppDesign.textTertiary,
                    alignment: .right
                )
            )
            if showsExpandArrow {
                drawDownChevron(in: arrowRect)
            }
        } else if highlighted {
            drawText(
                "删除",
                in: NSRect(x: bounds.width - 70, y: 12, width: 24, height: 16),
                attributes: textAttributes(
                    font: AppDesign.pingFang(size: 10, weight: .regular),
                    color: AppDesign.textTertiary,
                    alignment: .right
                )
            )
            drawText(
                "切换",
                in: NSRect(x: bounds.width - 34, y: 12, width: 24, height: 16),
                attributes: textAttributes(
                    font: AppDesign.pingFang(size: 10, weight: .regular),
                    color: AppDesign.textSecondary,
                    alignment: .right
                )
            )
        }
    }

    private func drawDownChevron(in rect: NSRect) {
        AppDesign.textTertiary.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.25
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: NSPoint(x: rect.midX - 4, y: rect.midY - 2))
        path.line(to: NSPoint(x: rect.midX, y: rect.midY + 2))
        path.line(to: NSPoint(x: rect.midX + 4, y: rect.midY - 2))
        path.stroke()
    }

    private func hoverFillPath() -> NSBezierPath {
        let radius = MenuDesign.moduleCornerRadius
        let rect = bounds
        switch clipStyle {
        case .single:
            return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        case .middle:
            return NSBezierPath(rect: rect)
        case .first:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.minX, y: rect.minY + radius))
            path.curve(
                to: NSPoint(x: rect.minX + radius, y: rect.minY),
                controlPoint1: NSPoint(x: rect.minX, y: rect.minY + radius * 0.45),
                controlPoint2: NSPoint(x: rect.minX + radius * 0.45, y: rect.minY)
            )
            path.line(to: NSPoint(x: rect.maxX - radius, y: rect.minY))
            path.curve(
                to: NSPoint(x: rect.maxX, y: rect.minY + radius),
                controlPoint1: NSPoint(x: rect.maxX - radius * 0.45, y: rect.minY),
                controlPoint2: NSPoint(x: rect.maxX, y: rect.minY + radius * 0.45)
            )
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
            path.close()
            return path
        case .last:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - radius))
            path.curve(
                to: NSPoint(x: rect.maxX - radius, y: rect.maxY),
                controlPoint1: NSPoint(x: rect.maxX, y: rect.maxY - radius * 0.45),
                controlPoint2: NSPoint(x: rect.maxX - radius * 0.45, y: rect.maxY)
            )
            path.line(to: NSPoint(x: rect.minX + radius, y: rect.maxY))
            path.curve(
                to: NSPoint(x: rect.minX, y: rect.maxY - radius),
                controlPoint1: NSPoint(x: rect.minX + radius * 0.45, y: rect.maxY),
                controlPoint2: NSPoint(x: rect.minX, y: rect.maxY - radius * 0.45)
            )
            path.close()
            return path
        }
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class AccountMenuRowView: NSControl {
    override var isFlipped: Bool { true }

    let service: AccountService
    private let activeProfile: String
    private var isHovered = false
    private var hoverTrackingArea: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: 18)
    }

    init(service: AccountService, activeProfile: String, target: AnyObject?, action: Selector?) {
        self.service = service
        self.activeProfile = activeProfile
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: 18)))
        self.target = target
        self.action = action
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            AppDesign.moduleBackground.setFill()
            NSBezierPath(
                roundedRect: NSRect(x: MenuDesign.separatorX - 4, y: -2, width: MenuDesign.separatorWidth + 8, height: 22),
                xRadius: 6,
                yRadius: 6
            ).fill()
        }

        drawText(
            "Account",
            in: NSRect(x: MenuDesign.separatorX, y: 0, width: 120, height: 18),
            attributes: textAttributes(font: AppDesign.pingFang(size: 12, weight: .semibold), color: AppDesign.textPrimary)
        )

        let displayName = activeProfile.isEmpty ? "Add account" : activeProfile
        let font = AppDesign.pingFang(size: 12, weight: .regular)
        let nameWidth = min(textWidth(displayName, font: font), 210)
        let chevronRect = NSRect(
            x: MenuDesign.separatorX + MenuDesign.separatorWidth - 12,
            y: 3,
            width: 12,
            height: 12
        )
        let nameRect = NSRect(
            x: chevronRect.minX - 4 - nameWidth,
            y: 0,
            width: nameWidth,
            height: 18
        )
        drawText(
            displayName,
            in: nameRect,
            attributes: textAttributes(font: font, color: AppDesign.textTertiary, alignment: .right)
        )
        drawChevron(in: chevronRect)
    }

    private func drawChevron(in rect: NSRect) {
        AppDesign.textTertiary.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: NSPoint(x: rect.midX - 2, y: rect.midY - 3))
        path.line(to: NSPoint(x: rect.midX + 2, y: rect.midY))
        path.line(to: NSPoint(x: rect.midX - 2, y: rect.midY + 3))
        path.stroke()
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }

    private func textWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

private final class AccountDropdownPanelView: NSView {
    override var isFlipped: Bool { true }

    private static let width: CGFloat = 144
    private static let horizontalPadding: CGFloat = 4
    private static let topPadding: CGFloat = 6
    private static let rowHeight: CGFloat = 22
    private static let rowGap: CGFloat = 2
    private static let separatorTopGap: CGFloat = 6
    private static let separatorToAddGap: CGFloat = 6
    private static let bottomPadding: CGFloat = 6

    private let panelSize: NSSize

    override var intrinsicContentSize: NSSize {
        panelSize
    }

    init(
        service: AccountService,
        profiles: [String],
        activeProfile: String,
        target: AnyObject?,
        switchAction: Selector,
        addAction: Selector
    ) {
        let sortedProfiles = profiles.sorted { lhs, rhs in
            if lhs == activeProfile { return true }
            if rhs == activeProfile { return false }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        let rowsHeight = CGFloat(sortedProfiles.count) * Self.rowHeight + CGFloat(max(sortedProfiles.count - 1, 0)) * Self.rowGap
        let totalHeight = Self.topPadding
            + rowsHeight
            + Self.separatorTopGap
            + 1
            + Self.separatorToAddGap
            + Self.rowHeight
            + Self.bottomPadding
        self.panelSize = NSSize(width: Self.width, height: totalHeight)

        super.init(frame: NSRect(origin: .zero, size: panelSize))
        wantsLayer = true
        layer?.cornerRadius = MenuDesign.panelCornerRadius
        layer?.masksToBounds = true

        var y = Self.topPadding
        for profile in sortedProfiles {
            let row = AccountDropdownRowButton(
                service: service,
                profile: profile,
                title: profile,
                isSelected: profile == activeProfile,
                isAddRow: false
            )
            row.target = target
            row.action = switchAction
            row.frame = NSRect(x: Self.horizontalPadding, y: y, width: Self.width - Self.horizontalPadding * 2, height: Self.rowHeight)
            addSubview(row)
            y += Self.rowHeight + Self.rowGap
        }

        y = Self.topPadding + rowsHeight + Self.separatorTopGap + 1 + Self.separatorToAddGap
        let addRow = AccountDropdownRowButton(
            service: service,
            profile: nil,
            title: "Add account",
            isSelected: false,
            isAddRow: true
        )
        addRow.target = target
        addRow.action = addAction
        addRow.frame = NSRect(x: Self.horizontalPadding, y: y, width: Self.width - Self.horizontalPadding * 2, height: Self.rowHeight)
        addSubview(addRow)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.25, dy: 0.25)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: rect, xRadius: MenuDesign.panelCornerRadius, yRadius: MenuDesign.panelCornerRadius).fill()
        NSColor.black.withAlphaComponent(0.15).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: MenuDesign.panelCornerRadius, yRadius: MenuDesign.panelCornerRadius)
        border.lineWidth = 0.5
        border.stroke()

        let separatorY = subviews
            .compactMap { $0 as? AccountDropdownRowButton }
            .filter { !$0.isAddRow }
            .map { $0.frame.maxY }
            .max()
            .map { $0 + Self.separatorTopGap }
            ?? (Self.topPadding + Self.separatorTopGap)
        NSColor.separatorColor.setStroke()
        let line = NSBezierPath()
        line.lineWidth = 1
        line.move(to: NSPoint(x: 16, y: separatorY + 0.5))
        line.line(to: NSPoint(x: 128, y: separatorY + 0.5))
        line.stroke()
    }
}

private final class AccountDropdownRowButton: NSControl {
    override var isFlipped: Bool { true }

    let service: AccountService
    let profile: String?
    let isAddRow: Bool
    private let titleText: String
    private let isSelectedRow: Bool
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    init(service: AccountService, profile: String?, title: String, isSelected: Bool, isAddRow: Bool) {
        self.service = service
        self.profile = profile
        self.titleText = title
        self.isSelectedRow = isSelected
        self.isAddRow = isAddRow
        super.init(frame: .zero)
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
        DispatchQueue.main.async { [weak self] in
            self?.isPressed = false
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isSelectedRow || isHovered || isPressed
        if highlighted {
            (isSelectedRow ? AppDesign.blue : AppDesign.hoverBackground).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        }

        let foreground = isSelectedRow ? NSColor.white : AppDesign.textPrimary
        if isAddRow {
            drawPlusIcon(in: NSRect(x: 4, y: 5, width: 12, height: 12), color: foreground)
        } else if isSelectedRow {
            drawCheckIcon(in: NSRect(x: 4, y: 5, width: 12, height: 12), color: foreground)
        }

        drawText(
            titleText,
            in: NSRect(x: 20, y: 2, width: bounds.width - 32, height: 18),
            attributes: textAttributes(
                font: AppDesign.pingFang(size: 12, weight: .semibold),
                color: foreground
            )
        )
    }

    private func drawCheckIcon(in rect: NSRect, color: NSColor) {
        color.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.4
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: NSPoint(x: rect.minX + 2.2, y: rect.midY))
        path.line(to: NSPoint(x: rect.minX + 4.8, y: rect.maxY - 3.2))
        path.line(to: NSPoint(x: rect.maxX - 2, y: rect.minY + 3))
        path.stroke()
    }

    private func drawPlusIcon(in rect: NSRect, color: NSColor) {
        color.withAlphaComponent(color.alphaComponent * 0.72).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.3
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: rect.midX, y: rect.minY + 2.5))
        path.line(to: NSPoint(x: rect.midX, y: rect.maxY - 2.5))
        path.move(to: NSPoint(x: rect.minX + 2.5, y: rect.midY))
        path.line(to: NSPoint(x: rect.maxX - 2.5, y: rect.midY))
        path.stroke()
    }

    private func textAttributes(font: NSFont, color: NSColor) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class PanelSpacerView: NSView {
    private let spacerHeight: CGFloat
    override var isFlipped: Bool { true }

    init(height: CGFloat) {
        self.spacerHeight = height
        super.init(frame: NSRect(x: 0, y: 0, width: MenuDesign.width, height: height))
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: spacerHeight)
    }
}

private final class PanelSeparatorView: NSView {
    private static let separatorHeight: CGFloat = 1
    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: Self.separatorHeight)
    }

    init() {
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: Self.separatorHeight)))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: NSPoint(x: MenuDesign.separatorX, y: 0.5))
        path.line(to: NSPoint(x: MenuDesign.separatorX + MenuDesign.separatorWidth, y: 0.5))
        path.stroke()
    }
}

private final class PanelBackgroundView: NSView {
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = MenuDesign.panelCornerRadius
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.25, dy: 0.25)
        let path = NSBezierPath(roundedRect: rect, xRadius: MenuDesign.panelCornerRadius, yRadius: MenuDesign.panelCornerRadius)
        (AppDesign.isSystemDarkMode
            ? NSColor.black.withAlphaComponent(0.12)
            : NSColor(calibratedRed: 245 / 255, green: 245 / 255, blue: 245 / 255, alpha: 0.67)
        ).setFill()
        path.fill()
        NSColor.black.withAlphaComponent(AppDesign.isSystemDarkMode ? 0.35 : 0.10).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}

private final class PanelVisualEffectView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = MenuDesign.panelCornerRadius
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class LiquidGlassOverlayView: NSView {
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = MenuDesign.panelCornerRadius
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let cornerRadius = MenuDesign.panelCornerRadius
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

        NSColor.white.withAlphaComponent(0.20).setFill()
        path.fill()

        NSGraphicsContext.saveGraphicsState()
        path.addClip()

        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.42),
            NSColor.white.withAlphaComponent(0.10),
            NSColor.white.withAlphaComponent(0.03)
        ])?.draw(in: rect, angle: -90)

        let sheenRect = NSRect(
            x: rect.minX + 10,
            y: rect.minY + 8,
            width: rect.width - 20,
            height: max(24, rect.height * 0.18)
        )
        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.34),
            NSColor.white.withAlphaComponent(0.08),
            NSColor.clear
        ])?.draw(
            in: NSBezierPath(roundedRect: sheenRect, xRadius: max(8, cornerRadius - 4), yRadius: max(8, cornerRadius - 4)),
            angle: -90
        )

        let sideGlow = NSBezierPath()
        sideGlow.move(to: NSPoint(x: rect.minX + 1, y: rect.minY + 14))
        sideGlow.curve(
            to: NSPoint(x: rect.minX + 1, y: rect.maxY - 20),
            controlPoint1: NSPoint(x: rect.minX + 8, y: rect.height * 0.35),
            controlPoint2: NSPoint(x: rect.minX + 6, y: rect.height * 0.75)
        )
        NSColor.white.withAlphaComponent(0.32).setStroke()
        sideGlow.lineWidth = 1
        sideGlow.stroke()

        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.54).setStroke()
        path.lineWidth = 1
        path.stroke()

        let innerPath = NSBezierPath(
            roundedRect: rect.insetBy(dx: 1, dy: 1),
            xRadius: max(0, cornerRadius - 1),
            yRadius: max(0, cornerRadius - 1)
        )
        NSColor.black.withAlphaComponent(0.08).setStroke()
        innerPath.lineWidth = 0.5
        innerPath.stroke()
    }
}

private final class AgentStatusPanelView: NSView {
    private let panelSize: NSSize

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        panelSize
    }

    init(views: [NSView], verticalPadding: CGFloat = 8) {
        let totalHeight = views.reduce(CGFloat(0)) { partial, view in
            partial + max(0, view.intrinsicContentSize.height)
        } + verticalPadding * 2
        self.panelSize = NSSize(width: MenuDesign.width, height: totalHeight)
        super.init(frame: NSRect(origin: .zero, size: panelSize))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = MenuDesign.panelCornerRadius
        layer?.masksToBounds = true
        layer?.borderWidth = 0

        let visualEffectView = PanelVisualEffectView(frame: bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        addSubview(visualEffectView)

        let backgroundView = PanelBackgroundView(frame: bounds)
        backgroundView.autoresizingMask = [.width, .height]
        addSubview(backgroundView)

        var y: CGFloat = verticalPadding
        for view in views {
            let height = max(0, view.intrinsicContentSize.height)
            view.frame = NSRect(x: 0, y: y, width: MenuDesign.width, height: height)
            addSubview(view)
            y += height
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()
    }
}

private final class AutoPanelFooterView: NSView {
    override var isFlipped: Bool { true }
    private static let footerHeight: CGFloat = 32

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: Self.footerHeight)
    }

    init(target: AnyObject?, addAccountAction: Selector, openProfilesAction: Selector, quitAction: Selector) {
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: Self.footerHeight)))

        let addButton = PanelIconButton(systemSymbolName: "person.badge.plus", pointSize: 16)
        addButton.target = target
        addButton.action = addAccountAction
        addButton.frame = NSRect(x: MenuDesign.separatorX, y: 0, width: 32, height: 32)
        addSubview(addButton)

        let profilesButton = PanelIconButton(systemSymbolName: "folder.badge.person.crop", pointSize: 13)
        profilesButton.target = target
        profilesButton.action = openProfilesAction
        profilesButton.frame = NSRect(x: MenuDesign.separatorX + 40, y: 0, width: 32, height: 32)
        addSubview(profilesButton)

        let quitButton = PanelIconButton(systemSymbolName: "xmark.circle", pointSize: 13)
        quitButton.target = target
        quitButton.action = quitAction
        quitButton.frame = NSRect(
            x: MenuDesign.separatorX + MenuDesign.separatorWidth - 32,
            y: 0,
            width: 32,
            height: 32
        )
        addSubview(quitButton)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class PanelIconButton: NSControl {
    override var isFlipped: Bool { true }

    private let systemSymbolName: String
    private let pointSize: CGFloat
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    init(systemSymbolName: String, pointSize: CGFloat) {
        self.systemSymbolName = systemSymbolName
        self.pointSize = pointSize
        super.init(frame: .zero)
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true

        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point), let action {
            NSApp.sendAction(action, to: target, from: self)
        }

        DispatchQueue.main.async { [weak self] in
            self?.isPressed = false
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isHovered || isPressed
        (highlighted ? AppDesign.raisedHoverBackground : AppDesign.moduleBackground).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: MenuDesign.moduleCornerRadius, yRadius: MenuDesign.moduleCornerRadius).fill()

        let color = highlighted ? AppDesign.textPrimary : AppDesign.textTertiary
        if let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: .medium)) {
            drawTemplateImage(
                image,
                in: NSRect(
                    x: floor((bounds.width - 18) / 2),
                    y: floor((bounds.height - 18) / 2),
                    width: 18,
                    height: 18
                ),
                color: color
            )
            return
        }

        color.setStroke()
        let fallback = NSBezierPath(ovalIn: bounds.insetBy(dx: 10, dy: 10))
        fallback.lineWidth = 1.4
        fallback.stroke()
    }
}

private final class PanelFooterView: NSView {
    override var isFlipped: Bool { true }
    private static let footerHeight: CGFloat = 32
    private static let buttonHeight: CGFloat = 32

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: Self.footerHeight)
    }

    init(target: AnyObject?, openProfilesAction: Selector, quitAction: Selector) {
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: Self.footerHeight)))

        let openWidth: CGFloat = 119
        let quitWidth: CGFloat = 60
        let y: CGFloat = 0

        let openButton = PanelActionButton(title: "Profiles Folder", icon: .folder)
        openButton.target = target
        openButton.action = openProfilesAction
        openButton.frame = NSRect(x: MenuDesign.separatorX, y: y, width: openWidth, height: Self.buttonHeight)
        addSubview(openButton)

        let quitButton = PanelActionButton(title: "Quit", icon: .quit)
        quitButton.target = target
        quitButton.action = quitAction
        quitButton.frame = NSRect(
            x: MenuDesign.separatorX + MenuDesign.separatorWidth - quitWidth,
            y: y,
            width: quitWidth,
            height: Self.buttonHeight
        )
        addSubview(quitButton)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private static func separator(atY y: CGFloat) -> NSBox {
        let separator = NSBox(frame: NSRect(
            x: MenuDesign.separatorX,
            y: y,
            width: MenuDesign.separatorWidth,
            height: 1
        ))
        separator.boxType = .separator
        separator.autoresizingMask = [.width]
        return separator
    }
}

private final class PanelActionButton: NSControl {
    override var isFlipped: Bool { true }

    enum Icon {
        case folder
        case quit
    }

    private let titleText: String
    private let icon: Icon
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    init(title: String, icon: Icon) {
        self.titleText = title
        self.icon = icon
        super.init(frame: .zero)
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
        isPressed = false
        needsDisplay = true

        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        let hovered = isHovered || isPressed

        (hovered ? AppDesign.raisedHoverBackground : AppDesign.moduleBackground).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

        let foregroundColor = AppDesign.menuItemText
        drawIcon(in: NSRect(x: 8, y: 8, width: 16, height: 16), color: foregroundColor)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: AppDesign.pingFang(size: 12, weight: .medium),
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraphStyle
        ]
        let attributedTitle = NSAttributedString(string: titleText, attributes: attributes)
        attributedTitle.draw(
            in: NSRect(
                x: 28,
                y: 7,
                width: bounds.width - 36,
                height: 18
            )
        )
    }

    private func drawIcon(in rect: NSRect, color: NSColor) {
        if let image = svgImage(for: icon, color: color) {
            image.draw(in: rect)
            return
        }

        color.withAlphaComponent(color.alphaComponent * 0.72).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        switch icon {
        case .folder:
            let body = NSRect(x: rect.minX + 2.5, y: rect.minY + 4.5, width: 11, height: 8.5)
            NSBezierPath(roundedRect: body, xRadius: 1.2, yRadius: 1.2).stroke()
            path.move(to: NSPoint(x: rect.minX + 4, y: rect.minY + 4.5))
            path.line(to: NSPoint(x: rect.minX + 5.5, y: rect.minY + 2.8))
            path.line(to: NSPoint(x: rect.minX + 8.5, y: rect.minY + 2.8))
            path.line(to: NSPoint(x: rect.minX + 10, y: rect.minY + 4.5))
            path.stroke()
        case .quit:
            NSBezierPath(roundedRect: rect.insetBy(dx: 4.5, dy: 3), xRadius: 1.2, yRadius: 1.2).stroke()
            path.move(to: NSPoint(x: rect.midX, y: rect.minY + 5))
            path.line(to: NSPoint(x: rect.midX, y: rect.maxY - 5))
            path.move(to: NSPoint(x: rect.midX - 2, y: rect.midY))
            path.line(to: NSPoint(x: rect.midX + 2, y: rect.midY))
            path.stroke()
        }
    }

    private func svgImage(for icon: Icon, color: NSColor) -> NSImage? {
        let opacity = color == NSColor.white ? "1" : "0.45"
        let fill = color == NSColor.white ? "white" : "black"
        let svg = (icon == .folder ? Self.folderSVG : Self.quitSVG)
            .replacingOccurrences(of: #"fill="black" fill-opacity="0.45""#, with: #"fill="\#(fill)" fill-opacity="\#(opacity)""#)
        guard let data = svg.data(using: .utf8) else { return nil }
        return NSImage(data: data)
    }

    private static let folderSVG = #"""
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">
  <path d="M8.2763 3.33333H14.0002C14.3684 3.33333 14.6668 3.63181 14.6668 4V13.3333C14.6668 13.7015 14.3684 14 14.0002 14H2.00016C1.63198 14 1.3335 13.7015 1.3335 13.3333V2.66667C1.3335 2.29848 1.63198 2 2.00016 2H6.94296L8.2763 3.33333ZM2.66683 3.33333V12.6667H13.3335V4.66667H7.72403L6.39069 3.33333H2.66683ZM5.3335 12C5.3335 10.5273 6.5274 9.33333 8.00016 9.33333C9.4729 9.33333 10.6668 10.5273 10.6668 12H5.3335ZM8.00016 8.66667C7.0797 8.66667 6.3335 7.92047 6.3335 7C6.3335 6.07953 7.0797 5.33333 8.00016 5.33333C8.92063 5.33333 9.66683 6.07953 9.66683 7C9.66683 7.92047 8.92063 8.66667 8.00016 8.66667Z" fill="black" fill-opacity="0.45"/>
</svg>
"""#

    private static let quitSVG = #"""
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">
  <path d="M11.9987 2C12.3669 2 12.6653 2.29848 12.6653 2.66667V13.3333C12.6653 13.7015 12.3669 14 11.9987 14H3.9987C3.6305 14 3.33203 13.7015 3.33203 13.3333V2.66667C3.33203 2.29848 3.6305 2 3.9987 2H11.9987ZM11.332 3.33333H4.66536V12.6667H11.332V3.33333ZM9.99866 7.33333V8.66667H8.66533V7.33333H9.99866Z" fill="black" fill-opacity="0.45"/>
</svg>
"""#
}

private final class SessionExpandButton: NSControl {
    override var isFlipped: Bool { true }

    private let isExpandedState: Bool
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    init(isExpanded: Bool) {
        self.isExpandedState = isExpanded
        super.init(frame: .zero)
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
        isPressed = false
        needsDisplay = true

        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        let active = isHovered || isPressed
        if active {
            AppDesign.hoverBackground.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: MenuDesign.innerCornerRadius, yRadius: MenuDesign.innerCornerRadius).fill()
        }

        AppDesign.textTertiary.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.25
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let arrowX = bounds.midX
        if isExpandedState {
            path.move(to: NSPoint(x: arrowX - 5, y: bounds.midY + 2))
            path.line(to: NSPoint(x: arrowX, y: bounds.midY - 2))
            path.line(to: NSPoint(x: arrowX + 5, y: bounds.midY + 2))
        } else {
            path.move(to: NSPoint(x: arrowX - 5, y: bounds.midY - 2))
            path.line(to: NSPoint(x: arrowX, y: bounds.midY + 2))
            path.line(to: NSPoint(x: arrowX + 5, y: bounds.midY - 2))
        }
        path.stroke()
    }
}

private enum SessionRowClipStyle {
    case single
    case first
    case middle
    case last
}

private enum ProjectStatusPresentationStyle {
    case section
    case compactList
}

private final class SessionRowButton: NSControl {
    let session: ProjectConversationSession
    private let tickProvider: () -> Int
    private let clipStyle: SessionRowClipStyle
    private let showsServiceIcon: Bool
    private var isHovered = false
    private var isPressed = false
    private var hoverTrackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }

    init(session: ProjectConversationSession, tickProvider: @escaping () -> Int, clipStyle: SessionRowClipStyle, showsServiceIcon: Bool) {
        self.session = session
        self.tickProvider = tickProvider
        self.clipStyle = clipStyle
        self.showsServiceIcon = showsServiceIcon
        super.init(frame: .zero)
        focusRingType = .none
        toolTip = "Open in \(session.service.displayTitle)"
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true

        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point), let action {
            NSApp.sendAction(action, to: target, from: self)
        }

        DispatchQueue.main.async { [weak self] in
            self?.isPressed = false
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isHovered || isPressed
        if highlighted {
            AppDesign.hoverBackground.setFill()
            hoverFillPath().fill()
        }

        let textX: CGFloat
        if showsServiceIcon {
            drawServiceIcon(in: NSRect(x: 12, y: 18, width: 16, height: 16), highlighted: false)
            textX = 36
        } else {
            textX = 12
        }
        let textWidth: CGFloat = max(40, bounds.width - textX - 88)
        let titleColor = AppDesign.textPrimary
        let secondaryColor = AppDesign.textTertiary
        let statusColor = AppDesign.textSecondary
        drawText(
            session.title,
            in: NSRect(x: textX, y: 10, width: textWidth, height: 16),
            attributes: textAttributes(
                font: .systemFont(ofSize: 13, weight: .medium),
                color: titleColor
            )
        )
        drawText(
            session.subtitle,
            in: NSRect(x: textX, y: 28, width: textWidth, height: 14),
            attributes: textAttributes(
                font: .systemFont(ofSize: 11, weight: .medium),
                color: secondaryColor
            )
        )

        let dotRect = NSRect(x: bounds.width - 20, y: 22, width: 8, height: 8)
        Self.sessionDotColor(for: session.state).setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        drawText(
            session.state.title,
            in: NSRect(x: bounds.width - 72, y: 19, width: 48, height: 14),
            attributes: textAttributes(
                font: .systemFont(ofSize: 11, weight: .medium),
                color: statusColor,
                alignment: .right
            )
        )
    }

    private func drawServiceIcon(in rect: NSRect, highlighted: Bool) {
        let resourceName = session.service == .codex ? "CodexTabIcon" : "ClaudeTabIcon"
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "svg"),
           let svg = try? String(contentsOf: url, encoding: .utf8) {
            let normalizedSVG = svgReplacingFills(svg, with: AppDesign.textSecondary)
            if let data = normalizedSVG.data(using: .utf8),
               let image = NSImage(data: data) {
                image.draw(in: aspectFitRect(for: image, in: rect), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                return
            }
        }
        AppDesign.textTertiary.setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3)).fill()
    }

    // A single status dot per session: green = working/done, yellow = needs
    // your input, red = blocked, gray = idle/paused.
    private static func sessionDotColor(for state: ProjectConversationState) -> NSColor {
        switch state {
        case .active, .completed:
            return NSColor(calibratedRed: 7 / 255, green: 171 / 255, blue: 75 / 255, alpha: 1)
        case .needsReview, .permission:
            return NSColor(calibratedRed: 1, green: 188 / 255, blue: 32 / 255, alpha: 1)
        case .blocked, .stale:
            return NSColor(calibratedRed: 240 / 255, green: 51 / 255, blue: 46 / 255, alpha: 1)
        case .idle, .paused:
            return AppDesign.textTertiary
        }
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }

    private func textWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private func hoverFillPath() -> NSBezierPath {
        let radius = MenuDesign.moduleCornerRadius
        let rect = bounds

        switch clipStyle {
        case .single:
            return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        case .middle:
            return NSBezierPath(rect: rect)
        case .first:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.minX, y: rect.minY + radius))
            path.curve(
                to: NSPoint(x: rect.minX + radius, y: rect.minY),
                controlPoint1: NSPoint(x: rect.minX, y: rect.minY + radius * 0.45),
                controlPoint2: NSPoint(x: rect.minX + radius * 0.45, y: rect.minY)
            )
            path.line(to: NSPoint(x: rect.maxX - radius, y: rect.minY))
            path.curve(
                to: NSPoint(x: rect.maxX, y: rect.minY + radius),
                controlPoint1: NSPoint(x: rect.maxX - radius * 0.45, y: rect.minY),
                controlPoint2: NSPoint(x: rect.maxX, y: rect.minY + radius * 0.45)
            )
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
            path.close()
            return path
        case .last:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - radius))
            path.curve(
                to: NSPoint(x: rect.maxX - radius, y: rect.maxY),
                controlPoint1: NSPoint(x: rect.maxX, y: rect.maxY - radius * 0.45),
                controlPoint2: NSPoint(x: rect.maxX - radius * 0.45, y: rect.maxY)
            )
            path.line(to: NSPoint(x: rect.minX + radius, y: rect.maxY))
            path.curve(
                to: NSPoint(x: rect.minX, y: rect.maxY - radius),
                controlPoint1: NSPoint(x: rect.minX + radius * 0.45, y: rect.maxY),
                controlPoint2: NSPoint(x: rect.minX, y: rect.maxY - radius * 0.45)
            )
            path.close()
            return path
        }
    }
}

private final class ProjectStatusMenuView: NSView {
    private let snapshot: ProjectConversationSnapshot
    private let tickProvider: () -> Int
    private let isExpanded: Bool
    private let showsServiceIcons: Bool
    private let presentationStyle: ProjectStatusPresentationStyle
    private static let headerHeight: CGFloat = 18
    private static let headerToBlockGap: CGFloat = 6
    private static let blockPadding: CGFloat = 0
    private static let rowHeight: CGFloat = 52
    private static let rowGap: CGFloat = 0
    private static let topPadding: CGFloat = 0
    private static let bottomPadding: CGFloat = 0
    private static let visibleSessionLimit = 3

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuDesign.width, height: viewHeight)
    }

    init(
        snapshot: ProjectConversationSnapshot,
        tickProvider: @escaping () -> Int,
        isExpanded: Bool,
        showsServiceIcons: Bool,
        presentationStyle: ProjectStatusPresentationStyle = .section,
        target: AnyObject?,
        toggleAction: Selector,
        sessionAction: Selector
    ) {
        self.snapshot = snapshot
        self.tickProvider = tickProvider
        self.isExpanded = isExpanded
        self.showsServiceIcons = showsServiceIcons
        self.presentationStyle = presentationStyle
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: MenuDesign.width, height: Self.height(for: snapshot, isExpanded: isExpanded, presentationStyle: presentationStyle))))

        let sessions = displaySessions()
        for (index, session) in sessions.enumerated() {
            let button = SessionRowButton(
                session: session,
                tickProvider: tickProvider,
                clipStyle: Self.clipStyle(at: index, count: sessions.count),
                showsServiceIcon: showsServiceIcons
            )
            button.frame = sessionRowFrame(at: index)
            button.target = target
            button.action = sessionAction
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if snapshot.sessions.isEmpty {
            let blockRect = NSRect(x: MenuDesign.separatorX, y: contentTop, width: MenuDesign.separatorWidth, height: blockHeight)
            AppDesign.moduleBackground.setFill()
            NSBezierPath(roundedRect: blockRect, xRadius: MenuDesign.moduleCornerRadius, yRadius: MenuDesign.moduleCornerRadius).fill()
            if presentationStyle == .compactList {
                drawSystemSymbol(
                    "bubble",
                    in: NSRect(x: blockRect.minX + 12, y: blockRect.minY + 16, width: 18, height: 16),
                    pointSize: 13,
                    color: AppDesign.textPrimary
                )
                drawText(
                    "No Recent Sessions",
                    in: NSRect(x: blockRect.minX + 38, y: blockRect.minY + 16, width: blockRect.width - 50, height: 16),
                    attributes: textAttributes(font: .systemFont(ofSize: 13, weight: .medium), color: AppDesign.textPrimary)
                )
            } else {
                drawText(
                    "No active sessions now",
                    in: NSRect(x: blockRect.minX + 12, y: blockRect.minY + 16, width: blockRect.width - 24, height: 18),
                    attributes: textAttributes(font: .systemFont(ofSize: 13, weight: .medium), color: AppDesign.textPrimary)
                )
            }
            return
        }

        let blockRect = NSRect(x: MenuDesign.separatorX, y: contentTop, width: MenuDesign.separatorWidth, height: blockHeight)
        AppDesign.moduleBackground.setFill()
        NSBezierPath(roundedRect: blockRect, xRadius: MenuDesign.moduleCornerRadius, yRadius: MenuDesign.moduleCornerRadius).fill()

    }

    private var visibleLimit: Int {
        Self.visibleSessionLimit
    }

    private var blockHeight: CGFloat {
        Self.blockHeight(for: snapshot, isExpanded: isExpanded, presentationStyle: presentationStyle)
    }

    private var viewHeight: CGFloat {
        Self.height(for: snapshot, isExpanded: isExpanded, presentationStyle: presentationStyle)
    }

    private var contentTop: CGFloat {
        switch presentationStyle {
        case .compactList:
            return 0
        case .section:
            return 0
        }
    }

    private func displaySessions() -> [ProjectConversationSession] {
        Array(snapshot.sessions.sorted { lhs, rhs in
            let lhsDate = sessionActivityDate(lhs)
            let rhsDate = sessionActivityDate(rhs)
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return lhs.state.priority > rhs.state.priority
        }.prefix(visibleLimit))
    }

    private func sessionActivityDate(_ session: ProjectConversationSession) -> Date {
        session.updatedAt ?? session.startedAt ?? .distantPast
    }

    private func sessionRowFrame(at index: Int) -> NSRect {
        let y = contentTop + CGFloat(index) * (Self.rowHeight + Self.rowGap)
        return NSRect(x: MenuDesign.separatorX, y: y, width: MenuDesign.separatorWidth, height: Self.rowHeight)
    }

    private static func height(
        for snapshot: ProjectConversationSnapshot,
        isExpanded: Bool,
        presentationStyle: ProjectStatusPresentationStyle
    ) -> CGFloat {
        let block = blockHeight(for: snapshot, isExpanded: isExpanded, presentationStyle: presentationStyle)
        switch presentationStyle {
        case .compactList:
            return block
        case .section:
            return block
        }
    }

    private static func blockHeight(
        for snapshot: ProjectConversationSnapshot,
        isExpanded: Bool,
        presentationStyle: ProjectStatusPresentationStyle
    ) -> CGFloat {
        guard !snapshot.sessions.isEmpty else {
            return presentationStyle == .compactList ? 48 : 40
        }
        let rowCount = min(snapshot.sessions.count, visibleSessionLimit)
        let rowGaps = CGFloat(max(rowCount - 1, 0)) * rowGap
        return CGFloat(rowCount) * rowHeight + rowGaps
    }

    private static func clipStyle(at index: Int, count: Int) -> SessionRowClipStyle {
        if count <= 1 {
            return .single
        }
        if index == 0 {
            return .first
        }
        if index == count - 1 {
            return .last
        }
        return .middle
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }

    private func textWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
}

private final class UsageBarsMenuView: NSView {
    private static let menuWidth: CGFloat = MenuDesign.width
    private static let headerX: CGFloat = MenuDesign.nativeTextX
    private static let leftInset: CGFloat = 24
    private static let barWidth: CGFloat = 272
    private static let headerHeight: CGFloat = 24
    private static let headerGap: CGFloat = 4
    private static let rowHeight: CGFloat = 58
    private static let updatedHeight: CGFloat = 28
    private static let barHeight: CGFloat = 6
    private static let refreshTitle = "Refresh now"
    private static let footerGap: CGFloat = 4

    private let rows: [UsageBarRow]
    private let updatedText: String

    override var isFlipped: Bool { true }

    private static func contentHeight(rowCount: Int) -> CGFloat {
        headerHeight + headerGap + CGFloat(rowCount) * rowHeight + updatedHeight
    }

    private static func rowsTop() -> CGFloat {
        headerHeight + headerGap
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.menuWidth, height: Self.contentHeight(rowCount: rows.count))
    }

    init(rows: [UsageBarRow], updatedText: String, target: AnyObject?, refreshAction: Selector) {
        self.rows = rows
        self.updatedText = updatedText
        let initialSize = NSSize(width: Self.menuWidth, height: Self.contentHeight(rowCount: rows.count))
        super.init(frame: NSRect(origin: .zero, size: initialSize))

        let footerFont = AppDesign.pingFang(size: 12, weight: .medium)
        let refreshWidth = Self.textWidth(Self.refreshTitle, font: footerFont)
        let footerY = Self.rowsTop() + CGFloat(rows.count) * Self.rowHeight + 8
        let refreshX = Self.refreshX(refreshWidth: refreshWidth)
        let refreshButton = PlainTextButton(
            title: Self.refreshTitle,
            frame: NSRect(
                x: refreshX,
                y: footerY,
                width: refreshWidth + 2,
                height: 16
            ),
            textColor: AppDesign.textPrimary,
            target: target,
            action: refreshAction
        )
        addSubview(refreshButton)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let titleAttributes = textAttributes(
            font: AppDesign.pingFang(size: 12, weight: .medium),
            color: AppDesign.textPrimary
        )
        let valueAttributes = textAttributes(
            font: AppDesign.pingFang(size: 10, weight: .medium),
            color: AppDesign.textSecondary
        )
        let resetAttributes = textAttributes(
            font: AppDesign.pingFang(size: 10, weight: .medium),
            color: AppDesign.textSecondary,
            alignment: .right
        )
        let footerAttributes = textAttributes(
            font: AppDesign.pingFang(size: 12, weight: .regular),
            color: AppDesign.textTertiary
        )
        let trackColor = AppDesign.moduleBackground
        let fillGradient = NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 157 / 255, blue: 59 / 255, alpha: 1),
            NSColor(calibratedRed: 252 / 255, green: 113 / 255, blue: 31 / 255, alpha: 1)
        ])

        // Section header.
        drawText(
            "Usage",
            in: NSRect(x: Self.headerX, y: 2, width: 120, height: Self.headerHeight - 4),
            attributes: textAttributes(
                font: AppDesign.nativeMenuFont,
                color: AppDesign.textPrimary
            )
        )

        // Card background behind the bars and the updated/refresh row.
        let cardRect = NSRect(
            x: MenuDesign.separatorX,
            y: Self.rowsTop(),
            width: MenuDesign.separatorWidth,
            height: CGFloat(rows.count) * Self.rowHeight + Self.updatedHeight
        )
        AppDesign.moduleBackground.setFill()
        NSBezierPath(roundedRect: cardRect, xRadius: MenuDesign.usageCornerRadius, yRadius: MenuDesign.usageCornerRadius).fill()

        for (index, row) in rows.enumerated() {
            let blockTop = Self.rowsTop() + CGFloat(index) * Self.rowHeight
            drawText(row.title, in: NSRect(x: Self.leftInset, y: blockTop + 8, width: Self.barWidth, height: 18), attributes: titleAttributes)

            let trackRect = NSRect(
                x: Self.leftInset,
                y: blockTop + 30,
                width: Self.barWidth,
                height: Self.barHeight
            )
            trackColor.setFill()
            NSBezierPath(roundedRect: trackRect, xRadius: Self.barHeight / 2, yRadius: Self.barHeight / 2).fill()

            let percent = clampedPercent(row.usedPercent)
            if percent > 0 {
                let fillWidth = max(Self.barHeight, trackRect.width * CGFloat(percent / 100))
                let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: min(fillWidth, trackRect.width), height: trackRect.height)
                let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: Self.barHeight / 2, yRadius: Self.barHeight / 2)
                NSGraphicsContext.saveGraphicsState()
                fillPath.addClip()
                fillGradient?.draw(in: fillRect, angle: 0)
                NSGraphicsContext.restoreGraphicsState()
            }

            let textY = blockTop + 40
            let halfWidth = Self.barWidth / 2
            drawText(
                "\(formatPercent(row.usedPercent)) used",
                in: NSRect(x: Self.leftInset, y: textY, width: halfWidth, height: 14),
                attributes: valueAttributes
            )
            drawText(
                row.resetText,
                in: NSRect(x: Self.leftInset + halfWidth, y: textY, width: halfWidth, height: 14),
                attributes: resetAttributes
            )
        }

        let footerY = Self.rowsTop() + CGFloat(rows.count) * Self.rowHeight + 8
        let footerFont = AppDesign.pingFang(size: 12, weight: .medium)
        let refreshWidth = Self.textWidth(Self.refreshTitle, font: footerFont)
        drawText(
            updatedText,
            in: NSRect(
                x: Self.leftInset,
                y: footerY,
                width: Self.updatedTextWidth(updatedText, font: footerFont, refreshWidth: refreshWidth),
                height: 16
            ),
            attributes: footerAttributes
        )
    }

    private static func updatedTextWidth(_ text: String, font: NSFont, refreshWidth: CGFloat) -> CGFloat {
        let availableWidth = refreshX(refreshWidth: refreshWidth) - leftInset - footerGap
        return min(textWidth(text, font: font), availableWidth)
    }

    private static func refreshX(refreshWidth: CGFloat) -> CGFloat {
        MenuDesign.separatorX + MenuDesign.separatorWidth - 12 - refreshWidth
    }

    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func clampedPercent(_ value: Double?) -> Double {
        guard let value, value.isFinite else { return 0 }
        return min(max(value, 0), 100)
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--%" }
        return "\(Int(min(max(value, 0), 100).rounded()))%"
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

private final class CompactUsageBarsMenuView: NSView {
    private static let menuWidth: CGFloat = MenuDesign.width
    private static let contentHeight: CGFloat = 166
    private static let cardX: CGFloat = MenuDesign.separatorX
    private static let cardWidth: CGFloat = MenuDesign.separatorWidth
    private static let leftInset: CGFloat = MenuDesign.separatorX + 12
    private static let barWidth: CGFloat = 272
    private static let rowHeight: CGFloat = 66
    private static let footerHeight: CGFloat = 34
    private static let barHeight: CGFloat = 6
    private static let refreshTitle = "Refresh now"

    private let rows: [UsageBarRow]
    private let updatedText: String

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.menuWidth, height: Self.contentHeight)
    }

    init(rows: [UsageBarRow], updatedText: String, target: AnyObject?, refreshAction: Selector) {
        self.rows = rows
        self.updatedText = updatedText
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: Self.menuWidth, height: Self.contentHeight)))

        let refreshFont = NSFont.systemFont(ofSize: 11, weight: .medium)
        let refreshButton = PlainTextButton(
            title: Self.refreshTitle,
            frame: NSRect(
                x: Self.cardX + 218,
                y: CGFloat(rows.count) * Self.rowHeight + 10,
                width: 68,
                height: 14
            ),
            textColor: AppDesign.textPrimary,
            font: refreshFont,
            target: target,
            action: refreshAction
        )
        addSubview(refreshButton)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let cardRect = NSRect(x: Self.cardX, y: 0, width: Self.cardWidth, height: Self.contentHeight)
        AppDesign.moduleBackground.setFill()
        NSBezierPath(roundedRect: cardRect, xRadius: MenuDesign.usageCornerRadius, yRadius: MenuDesign.usageCornerRadius).fill()

        let titleAttributes = textAttributes(font: .systemFont(ofSize: 10, weight: .bold), color: AppDesign.textSecondary)
        let valueAttributes = textAttributes(font: .systemFont(ofSize: 13, weight: .medium), color: AppDesign.textTertiary)
        let resetAttributes = textAttributes(font: .systemFont(ofSize: 11, weight: .medium), color: AppDesign.textTertiary, alignment: .right)

        for (index, row) in rows.prefix(2).enumerated() {
            let y = CGFloat(index) * Self.rowHeight
            drawText(row.title, in: NSRect(x: Self.leftInset, y: y + 10, width: Self.barWidth, height: 12), attributes: titleAttributes)

            let trackRect = NSRect(x: Self.leftInset, y: y + 28, width: Self.barWidth, height: Self.barHeight)
            AppDesign.moduleBackground.setFill()
            NSBezierPath(roundedRect: trackRect, xRadius: 4, yRadius: 4).fill()

            if let percent = row.usedPercent, percent.isFinite, percent > 0 {
                let clamped = min(max(percent, 0), 100)
                let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: trackRect.width * CGFloat(clamped / 100), height: trackRect.height)
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(roundedRect: fillRect, xRadius: 4, yRadius: 4).addClip()
                NSGradient(colors: [
                    NSColor(calibratedRed: 1.0, green: 187 / 255, blue: 52 / 255, alpha: 1),
                    NSColor(calibratedRed: 1.0, green: 123 / 255, blue: 36 / 255, alpha: 1)
                ])?.draw(in: fillRect, angle: 0)
                NSGraphicsContext.restoreGraphicsState()
            }

            drawText(
                usedText(row.usedPercent),
                in: NSRect(x: Self.leftInset, y: y + 40, width: 110, height: 16),
                attributes: valueAttributes
            )
            drawText(
                row.resetText,
                in: NSRect(x: Self.leftInset + Self.barWidth - 100, y: y + 41, width: 100, height: 14),
                attributes: resetAttributes
            )
        }

        drawText(
            updatedText,
            in: NSRect(x: Self.leftInset, y: CGFloat(rows.count) * Self.rowHeight + 10, width: 180, height: 14),
            attributes: textAttributes(font: .systemFont(ofSize: 11, weight: .medium), color: AppDesign.textTertiary)
        )
    }

    private func usedText(_ percent: Double?) -> String {
        guard let percent, percent.isFinite else { return "-- used" }
        return "\(Int(percent.rounded()))% used"
    }

    private func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func drawText(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

final class UsageFetcher {
    private let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let tokenEndpoint = URL(string: "https://auth.openai.com/oauth/token")!
    private let codexClientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    func fetch(authURL: URL, completion: @escaping (UsageSnapshot) -> Void) {
        guard let auth = readAuth(authURL), let accessToken = auth.tokens?.accessToken else {
            completion(UsageSnapshot(fetchedAt: Date(), fiveHour: nil, weekly: nil, error: "No Codex auth token"))
            return
        }

        fetchUsage(authURL: authURL, auth: auth, accessToken: accessToken, allowRefresh: true, completion: completion)
    }

    private func fetchUsage(
        authURL: URL,
        auth: AuthFile,
        accessToken: String,
        allowRefresh: Bool,
        completion: @escaping (UsageSnapshot) -> Void
    ) {
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

            if (http.statusCode == 401 || http.statusCode == 403), allowRefresh {
                self.refreshAuth(authURL: authURL, auth: auth) { refreshedAuth in
                    guard let refreshedAuth, let refreshedAccessToken = refreshedAuth.tokens?.accessToken else {
                        completion(UsageSnapshot(fetchedAt: Date(), fiveHour: nil, weekly: nil, error: "Sign in again"))
                        return
                    }
                    self.fetchUsage(
                        authURL: authURL,
                        auth: refreshedAuth,
                        accessToken: refreshedAccessToken,
                        allowRefresh: false,
                        completion: completion
                    )
                }
                return
            }

            if http.statusCode == 401 || http.statusCode == 403 {
                completion(UsageSnapshot(fetchedAt: Date(), fiveHour: nil, weekly: nil, error: "Sign in again"))
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

    private func refreshAuth(authURL: URL, auth: AuthFile, completion: @escaping (AuthFile?) -> Void) {
        guard let refreshToken = auth.tokens?.refreshToken else {
            completion(nil)
            return
        }

        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let params = [
            "client_id": codexClientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": "openid profile email"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: params)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data,
                  let refreshed = try? JSONDecoder().decode(OAuthTokenResponse.self, from: data),
                  let accessToken = refreshed.accessToken else {
                completion(nil)
                return
            }

            let accountId = refreshed.accountId ?? self.accountIdFromJWT(accessToken) ?? auth.tokens?.accountId
            guard self.writeRefreshedAuth(authURL: authURL, response: refreshed, accessToken: accessToken, accountId: accountId),
                  let updatedAuth = self.readAuth(authURL) else {
                completion(nil)
                return
            }

            completion(updatedAuth)
        }.resume()
    }

    private func formBody(_ params: [String: String]) -> Data {
        let body = params
            .map { key, value in "\(urlEncode(key))=\(urlEncode(value))" }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    private func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func writeRefreshedAuth(
        authURL: URL,
        response: OAuthTokenResponse,
        accessToken: String,
        accountId: String?
    ) -> Bool {
        guard let data = try? Data(contentsOf: authURL),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        var tokens = object["tokens"] as? [String: Any] ?? [:]
        tokens["access_token"] = accessToken
        if let refreshToken = response.refreshToken {
            tokens["refresh_token"] = refreshToken
        }
        if let idToken = response.idToken {
            tokens["id_token"] = idToken
        }
        if let accountId {
            tokens["account_id"] = accountId
        }

        object["tokens"] = tokens
        object["last_refresh"] = ISO8601DateFormatter().string(from: Date())

        do {
            let updated = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            try updated.write(to: authURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: authURL.path)
            return true
        } catch {
            return false
        }
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

private final class StatusPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var panelWindow: StatusPanelWindow?
    private var accountDropdownWindow: StatusPanelWindow?
    private var panelAnchorTopY: CGFloat?
    private var panelAnchorMinX: CGFloat?
    private var panelEventMonitors: [Any] = []
    private let scriptPath: String
    private let usageFetcher = UsageFetcher()
    private let projectMonitor = ProjectConversationMonitor()
    private var usageByProfile: [String: UsageSnapshot] = [:]
    private var projectSnapshot: ProjectConversationSnapshot = .idle
    private var usageTimer: Timer?
    private var projectStatusTimer: Timer?
    private var animationTimer: Timer?
    private var animationTick = 0
    private var isRefreshingUsage = false
    private var isRefreshingProjectStatus = false
    private var isRefreshingNativeMenu = false
    private var isProjectSessionsExpanded = false
    private var isAccountsExpanded = false
    private var shouldAnimateAccountsExpansion = false
    private var selectionMode: ServiceSelectionMode = .auto
    private var serviceTabAnimationOriginMode: ServiceSelectionMode?
    private lazy var nativeMenu: NSMenu = {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        return menu
    }()

    private var selectedService: AccountService {
        switch selectionMode {
        case .service(let service):
            return service
        case .auto:
            return autoResolvedService() ?? .codex
        }
    }

    private var isAutoMode: Bool {
        selectionMode == .auto
    }

    private var appSupportHome: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AgentStatusIndicator")
    }

    private var legacyAppSupportHome: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexAccountSwitcher")
    }

    private var usageCacheURL: URL {
        appSupportHome.appendingPathComponent("usage-cache.json")
    }

    private var codexAuthURL: URL {
        if let path = ProcessInfo.processInfo.environment["CODEX_AUTH_FILE"], !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("auth.json")
    }

    override init() {
        if let bundled = Bundle.main.path(forResource: "agent-status-indicator", ofType: "sh") {
            scriptPath = bundled
        } else {
            scriptPath = FileManager.default.currentDirectoryPath + "/agent-status-indicator.sh"
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateLegacyAppSupportIfNeeded()
        registerBundledFonts()
        statusItem = NSStatusBar.system.statusItem(withLength: TrafficLightStatusIcon.menuBarSize.width)
        projectSnapshot = .idle
        configureStatusItemIcon()
        loadUsageCache()
        rebuildMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshUsage()
            self?.refreshProjectStatus()
        }
        usageTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshUsage()
        }
        projectStatusTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            self?.refreshProjectStatus()
        }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.advanceStatusAnimation()
        }
    }

    private func registerBundledFonts() {
    }

    private func migrateLegacyAppSupportIfNeeded() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: legacyAppSupportHome.path),
              !fileManager.fileExists(atPath: appSupportHome.path) else {
            return
        }

        do {
            try fileManager.createDirectory(
                at: appSupportHome.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.moveItem(at: legacyAppSupportHome, to: appSupportHome)
        } catch {
            // Existing profiles can still be recreated manually if migration fails.
        }
    }

    @objc private func rebuildMenu() {
        normalizeSelectionModeIfNeeded()
        let currentSnapshot = isAutoMode ? autoProjectSnapshot() : panelProjectSnapshot(for: selectedService)
        if currentSnapshot.sessions.count <= 3 {
            isProjectSessionsExpanded = false
        }

        updateStatusBarTitle()
        updatePopoverContentIfNeeded()
        scheduleNativeMenuRefresh()
    }

    private func normalizeSelectionModeIfNeeded() {
        guard let service = selectionMode.service,
              !serviceAvailability(for: service).isSelectable else {
            return
        }
        selectionMode = .auto
        isProjectSessionsExpanded = false
        isAccountsExpanded = false
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === nativeMenu else { return }
        populateNativeMenu(menu)
    }

    private func scheduleNativeMenuRefresh(force: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self, force || self.nativeMenuHasVisibleCustomViews else { return }
            self.refreshNativeMenuContents()
        }
    }

    private var nativeMenuHasVisibleCustomViews: Bool {
        nativeMenu.items.contains { $0.view?.window != nil }
    }

    private func refreshNativeMenuContents() {
        guard !isRefreshingNativeMenu else { return }
        isRefreshingNativeMenu = true
        defer { isRefreshingNativeMenu = false }
        populateNativeMenu(nativeMenu, preservingTopArea: true)
        refreshVisibleMenuViews()
    }

    private func makePanelView(animateAccountsExpansion: Bool = false) -> AgentStatusPanelView {
        let resolvedService = selectedService
        let active = (!isAutoMode && resolvedService.supportsProfiles) ? activeProfile(for: resolvedService) : ""
        let panelProjectSnapshot = isAutoMode ? autoProjectSnapshot() : panelProjectSnapshot(for: resolvedService)
        var views: [NSView] = [
            MenuHeaderView(
                title: AppDesign.appName
            ),
            PanelSpacerView(height: 12),
            ServiceTabsMenuView(
                selectionMode: selectionMode,
                animationOriginMode: serviceTabAnimationOriginMode,
                serviceStates: serviceTabStates(),
                serviceAvailability: serviceAvailabilities(),
                tickProvider: { [weak self] in self?.animationTick ?? 0 },
                target: self,
                action: #selector(switchServiceTab(_:))
            ),
            PanelSpacerView(height: 12)
        ]

        if isAutoMode {
            views.append(
                ProjectStatusMenuView(
                    snapshot: panelProjectSnapshot,
                    tickProvider: { [weak self] in self?.animationTick ?? 0 },
                    isExpanded: false,
                    showsServiceIcons: true,
                    presentationStyle: .compactList,
                    target: self,
                    toggleAction: #selector(toggleProjectSessionsExpanded(_:)),
                    sessionAction: #selector(openSession(_:))
                )
            )
            views.append(PanelSpacerView(height: 12))
            views.append(
                AutoPanelFooterView(
                    target: self,
                    addAccountAction: #selector(captureCurrent(_:)),
                    openProfilesAction: #selector(openProfilesFolder),
                    quitAction: #selector(quit)
                )
            )
            return AgentStatusPanelView(views: views, verticalPadding: 12)
        }

        if !isAutoMode, resolvedService.supportsProfiles {
            if isAccountsExpanded {
                views.append(
                    CompactAccountListView(
                        service: resolvedService,
                        profiles: profileNames(for: resolvedService),
                        activeProfile: active,
                        target: self,
                        action: #selector(accountListRowAction(_:))
                    )
                )
            } else {
                views.append(
                    CurrentAccountRowView(
                        service: resolvedService,
                        profile: active,
                        showsChevron: profileNames(for: resolvedService).count > 1,
                        target: self,
                        action: #selector(accountListRowAction(_:))
                    )
                )
            }
            views.append(PanelSpacerView(height: 12))
        }

        views.append(
            ProjectStatusMenuView(
                snapshot: panelProjectSnapshot,
                tickProvider: { [weak self] in self?.animationTick ?? 0 },
                isExpanded: isProjectSessionsExpanded,
                showsServiceIcons: true,
                presentationStyle: .compactList,
                target: self,
                toggleAction: #selector(toggleProjectSessionsExpanded(_:)),
                sessionAction: #selector(openSession(_:))
            )
        )

        if !isAutoMode,
           resolvedService.supportsUsage,
           !active.isEmpty,
           let activeUsageSnapshot = usageSnapshot(profile: active, service: resolvedService),
           activeUsageSnapshot.error == nil {
            views.append(PanelSpacerView(height: 12))
            views.append(compactUsageView(snapshot: activeUsageSnapshot))
        }

        views.append(PanelSpacerView(height: 12))
        views.append(
            AutoPanelFooterView(
                target: self,
                addAccountAction: #selector(captureCurrent(_:)),
                openProfilesAction: #selector(openProfilesFolder),
                quitAction: #selector(quit)
            )
        )

        return AgentStatusPanelView(views: views, verticalPadding: 12)
    }

    private func autoResolvedService() -> AccountService? {
        autoProjectSnapshot().sessions.first?.service
    }

    private func serviceTabStates() -> [AccountService: ProjectConversationState] {
        Dictionary(uniqueKeysWithValues: AccountService.allCases.map { service in
            (service, panelProjectSnapshot(for: service).state)
        })
    }

    private func serviceAvailabilities() -> [AccountService: ServiceAvailability] {
        Dictionary(uniqueKeysWithValues: AccountService.allCases.map { service in
            (service, serviceAvailability(for: service))
        })
    }

    private func serviceAvailability(for service: AccountService) -> ServiceAvailability {
        if serviceAppURL(for: service) != nil {
            return .installed
        }
        if serviceHasHistory(service) {
            return .historyOnly
        }
        return .unavailable
    }

    private func serviceHasHistory(_ service: AccountService) -> Bool {
        if projectSnapshot.sessions.contains(where: { $0.service == service }) {
            return true
        }
        if service.supportsProfiles, !profileNames(for: service).isEmpty {
            return true
        }
        return false
    }

    private func serviceAppURL(for service: AccountService) -> URL? {
        let homeAppPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .appendingPathComponent("\(service.appName).app")
            .path
        let candidatePaths = [service.defaultAppPath, homeAppPath]
        return candidatePaths
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func autoProjectSnapshot() -> ProjectConversationSnapshot {
        let sessions = projectSnapshot.sessions.sorted { lhs, rhs in
            if sessionActivityDate(lhs) != sessionActivityDate(rhs) {
                return sessionActivityDate(lhs) > sessionActivityDate(rhs)
            }
            return lhs.state.priority > rhs.state.priority
        }

        guard !sessions.isEmpty else {
            return ProjectConversationSnapshot(
                state: .idle,
                detail: "No active agent sessions.",
                source: "All agent sessions",
                updatedAt: nil,
                activeSessionCount: 0,
                sessions: []
            )
        }
        let selectedSession = sessions.sorted { lhs, rhs in
            if lhs.state.priority != rhs.state.priority {
                return lhs.state.priority > rhs.state.priority
            }
            return sessionActivityDate(lhs) > sessionActivityDate(rhs)
        }[0]

        return ProjectConversationSnapshot(
            state: selectedSession.state,
            detail: selectedSession.detail,
            source: "All agent sessions",
            updatedAt: sessions.compactMap(\.updatedAt).max(),
            activeSessionCount: sessions.count,
            sessions: sessions
        )
    }

    private func autoStatusBarProjectSnapshot() -> ProjectConversationSnapshot {
        let baseSnapshot = autoProjectSnapshot()
        let serviceSessions = [
            panelProjectSnapshot(for: .codex).sessions.first,
            panelProjectSnapshot(for: .claude).sessions.first
        ].compactMap { $0 }

        guard !serviceSessions.isEmpty else {
            return baseSnapshot
        }

        let selectedSession: ProjectConversationSession
        if serviceSessions.count == 2,
           let firstSession = serviceSessions.first,
           serviceSessions.allSatisfy({ $0.state == firstSession.state }),
           shouldRotateStatusBarService(for: firstSession.state) {
            let selectedService = rotatingStatusBarService()
            selectedSession = serviceSessions.first { $0.service == selectedService } ?? firstSession
        } else {
            selectedSession = serviceSessions.sorted { lhs, rhs in
                if lhs.state.priority != rhs.state.priority {
                    return lhs.state.priority > rhs.state.priority
                }
                return sessionActivityDate(lhs) > sessionActivityDate(rhs)
            }[0]
        }

        var sessions = [selectedSession]
        sessions.append(contentsOf: baseSnapshot.sessions.filter {
            $0.service != selectedSession.service || $0.sessionID != selectedSession.sessionID
        })

        return ProjectConversationSnapshot(
            state: selectedSession.state,
            detail: selectedSession.detail,
            source: baseSnapshot.source,
            updatedAt: baseSnapshot.updatedAt,
            activeSessionCount: baseSnapshot.activeSessionCount,
            sessions: sessions
        )
    }

    private func shouldRotateStatusBarService(for state: ProjectConversationState) -> Bool {
        switch state {
        case .active, .needsReview, .permission, .blocked, .stale, .paused:
            return true
        case .idle, .completed:
            return false
        }
    }

    private func rotatingStatusBarService() -> AccountService {
        let bucket = Int(Date().timeIntervalSince1970 / 5)
        return bucket.isMultiple(of: 2) ? .codex : .claude
    }

    private func panelProjectSnapshot(for service: AccountService) -> ProjectConversationSnapshot {
        let sessions = projectSnapshot.sessions
            .filter { $0.service == service }
            .sorted { lhs, rhs in
                if lhs.state.priority != rhs.state.priority {
                    return lhs.state.priority > rhs.state.priority
                }
                return sessionSortDate(lhs) > sessionSortDate(rhs)
            }

        guard let selectedSession = sessions.first else {
            return ProjectConversationSnapshot(
                state: .idle,
                detail: "No active \(service.displayTitle) sessions.",
                source: "\(service.displayTitle) sessions",
                updatedAt: nil,
                activeSessionCount: 0,
                sessions: []
            )
        }

        return ProjectConversationSnapshot(
            state: selectedSession.state,
            detail: selectedSession.detail,
            source: combinedSessionSource(sessions),
            updatedAt: sessions.compactMap(\.updatedAt).max(),
            activeSessionCount: sessions.count,
            sessions: sessions
        )
    }

    private func sessionSortDate(_ session: ProjectConversationSession) -> Date {
        session.startedAt ?? session.updatedAt ?? .distantPast
    }

    private func sessionActivityDate(_ session: ProjectConversationSession) -> Date {
        session.updatedAt ?? session.startedAt ?? .distantPast
    }

    private func combinedSessionSource(_ sessions: [ProjectConversationSession]) -> String {
        var sources: [String] = []
        for session in sessions where !sources.contains(session.source) {
            sources.append(session.source)
        }
        return sources.isEmpty ? "Local agent sessions" : sources.joined(separator: " + ")
    }

    private func updatePopoverContentIfNeeded() {
        guard let panelWindow, panelWindow.isVisible else { return }
        closeAccountDropdown()
        let animateAccountsExpansion = shouldAnimateAccountsExpansion
        shouldAnimateAccountsExpansion = false
        let panelView = makePanelView(animateAccountsExpansion: animateAccountsExpansion)
        let currentFrame = panelWindow.frame
        let contentSize = panelView.intrinsicContentSize
        let topY = panelAnchorTopY ?? currentFrame.maxY
        let minX = panelAnchorMinX ?? currentFrame.minX
        let newFrame = NSRect(
            x: minX,
            y: topY - contentSize.height,
            width: contentSize.width,
            height: contentSize.height
        )
        panelWindow.contentView = panelView
        let constrainedFrame = constrainedPanelResizeFrame(newFrame)
        if abs(constrainedFrame.height - currentFrame.height) > 0.5 ||
            abs(constrainedFrame.origin.y - currentFrame.origin.y) > 0.5 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animateAccountsExpansion ? 0.24 : 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panelWindow.animator().setFrame(constrainedFrame, display: true)
            }
        } else {
            panelWindow.setFrame(constrainedFrame, display: true)
        }
    }

    private func makeItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = [.command]
        }
        return item
    }

    private func populateNativeMenu(_ menu: NSMenu, preservingTopArea: Bool = false) {
        if preservingTopArea, let tabIndex = serviceTabsMenuItemIndex(in: menu) {
            menu.items[tabIndex].view = makeServiceTabsMenuView()
            let bodyStartIndex = min(tabIndex + 1, menu.items.count)
            while menu.items.count > bodyStartIndex {
                menu.removeItem(at: bodyStartIndex)
            }
            appendNativeMenuBody(to: menu)
            return
        }

        while menu.items.isEmpty == false {
            menu.removeItem(at: 0)
        }
        appendNativeMenuHeaderAndTabs(to: menu)
        appendNativeMenuBody(to: menu)
    }

    private func appendNativeMenuHeaderAndTabs(to menu: NSMenu) {
        addCustomView(MenuHeaderView(title: AppDesign.appName), to: menu)
        addCustomView(PanelSpacerView(height: 8), to: menu)
        menu.addItem(.separator())

        addCustomView(PanelSpacerView(height: 8), to: menu)
        addCustomView(makeServiceTabsMenuView(), to: menu)
    }

    private func makeServiceTabsMenuView() -> ServiceTabsMenuView {
        ServiceTabsMenuView(
            selectionMode: selectionMode,
            animationOriginMode: serviceTabAnimationOriginMode,
            serviceStates: serviceTabStates(),
            serviceAvailability: serviceAvailabilities(),
            tickProvider: { [weak self] in self?.animationTick ?? 0 },
            target: self,
            action: #selector(switchServiceTab(_:))
        )
    }

    private func serviceTabsMenuItemIndex(in menu: NSMenu) -> Int? {
        menu.items.firstIndex { $0.view is ServiceTabsMenuView }
    }

    private func appendNativeMenuBody(to menu: NSMenu) {
        let resolvedService = selectedService
        let active = (!isAutoMode && resolvedService.supportsProfiles) ? activeProfile(for: resolvedService) : ""
        let statusSnapshot = statusBarProjectSnapshot()

        addCustomView(PanelSpacerView(height: 8), to: menu)
        if !isAutoMode, resolvedService.supportsProfiles {
            addAccountSubmenu(to: menu, service: resolvedService, activeProfile: active)
        }

        menu.addItem(.separator())
        addCustomView(PanelSpacerView(height: 4), to: menu)
        addCustomView(
            ProjectStatusMenuView(
                snapshot: statusSnapshot,
                tickProvider: { [weak self] in self?.animationTick ?? 0 },
                isExpanded: false,
                showsServiceIcons: isAutoMode,
                target: self,
                toggleAction: #selector(toggleProjectSessionsExpanded(_:)),
                sessionAction: #selector(openSession(_:))
            ),
            to: menu
        )

        if !isAutoMode, resolvedService.supportsUsage {
            let usage = active.isEmpty ? nil : usageSnapshot(profile: active, service: resolvedService)
            addCustomView(PanelSpacerView(height: 6), to: menu)
            menu.addItem(.separator())
            addCustomView(PanelSpacerView(height: 4), to: menu)
            addCustomView(usageView(snapshot: usage), to: menu)
        }

        addCustomView(PanelSpacerView(height: 6), to: menu)
        menu.addItem(.separator())
        if isAutoMode || !resolvedService.supportsUsage {
            menu.addItem(makeItem(title: "Refresh Now", action: #selector(refreshNow)))
        }
        let profilesFolderTitle = isAutoMode
            ? "Open Profiles Folder"
            : "Open \(resolvedService.displayTitle) Profiles Folder"
        menu.addItem(makeItem(title: profilesFolderTitle, action: #selector(openProfilesFolder)))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Quit \(AppDesign.appName)", action: #selector(quit), keyEquivalent: "q"))
    }

    private func nativeStatusLine(for snapshot: ProjectConversationSnapshot) -> String {
        if snapshot.activeSessionCount <= 0 {
            return "Status: \(snapshot.state.title)"
        }
        return "Status: \(snapshot.state.title) - \(snapshot.activeSessionCount) sessions"
    }

    private func addModeSubmenu(to menu: NSMenu) {
        let modeTitle: String
        switch selectionMode {
        case .auto:
            modeTitle = "Mode: Auto"
        case .service(let service):
            modeTitle = "Mode: \(service.displayTitle)"
        }

        let modeItem = NSMenuItem(title: modeTitle, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        let autoItem = makeItem(title: "Auto", action: #selector(selectAutoMode(_:)))
        autoItem.state = selectionMode == .auto ? .on : .off
        submenu.addItem(autoItem)

        for service in AccountService.allCases {
            let item = makeItem(title: service.displayTitle, action: service == .codex ? #selector(selectCodexMode(_:)) : #selector(selectClaudeMode(_:)))
            item.state = selectionMode == .service(service) ? .on : .off
            item.isEnabled = serviceAvailability(for: service).isSelectable
            submenu.addItem(item)
        }

        modeItem.submenu = submenu
        menu.addItem(modeItem)
    }

    private func addAccountSubmenu(to menu: NSMenu, service: AccountService, activeProfile: String) {
        let title = activeProfile.isEmpty
            ? "\(service.displayTitle) Account"
            : "\(service.displayTitle) Account: \(activeProfile)"
        let accountItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        let profiles = profileNames(for: service).sorted { lhs, rhs in
            if lhs == activeProfile { return true }
            if rhs == activeProfile { return false }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        if profiles.isEmpty {
            addDisabled("No Saved Accounts", to: submenu)
        } else {
            for profile in profiles {
                let item = makeItem(title: profile, action: #selector(switchProfile(_:)))
                item.representedObject = ProfileMenuItemPayload(service: service, profile: profile)
                item.state = profile == activeProfile ? .on : .off
                item.isEnabled = profile != activeProfile
                submenu.addItem(item)
            }
        }

        submenu.addItem(.separator())
        let addItem = makeItem(title: "Add Current \(service.displayTitle) Account...", action: #selector(captureCurrent(_:)))
        addItem.representedObject = service.rawValue
        submenu.addItem(addItem)

        accountItem.submenu = submenu
        menu.addItem(accountItem)
    }

    private func addSessionsSubmenu(
        to menu: NSMenu,
        snapshot: ProjectConversationSnapshot,
        showsService: Bool
    ) {
        let title = snapshot.activeSessionCount > 0
            ? "Sessions: \(snapshot.activeSessionCount)"
            : "Sessions"
        let sessionsItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        let visibleSessions = Array(snapshot.sessions.prefix(3))
        if visibleSessions.isEmpty {
            addDisabled("No Active Sessions", to: submenu)
        } else {
            for session in visibleSessions {
                let item = makeItem(
                    title: nativeSessionTitle(session, showsService: showsService),
                    action: #selector(openSessionMenuItem(_:))
                )
                item.representedObject = SessionMenuItemPayload(session: session)
                item.image = TrafficLightStatusIcon.image(for: session.state, tick: animationTick)
                item.toolTip = nativeSessionToolTip(session)
                submenu.addItem(item)
            }

            let remaining = max(snapshot.sessions.count - visibleSessions.count, 0)
            if remaining > 0 {
                submenu.addItem(.separator())
                addDisabled("\(remaining) more recent sessions", to: submenu)
            }
        }

        sessionsItem.submenu = submenu
        menu.addItem(sessionsItem)
    }

    private func addUsageSubmenu(to menu: NSMenu, snapshot: UsageSnapshot?) {
        let usageItem = NSMenuItem(title: "Codex Usage", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        if isRefreshingUsage {
            addDisabled("Refreshing...", to: submenu)
        }

        guard let snapshot else {
            addDisabled("Usage Unavailable", to: submenu)
            submenu.addItem(.separator())
            submenu.addItem(makeItem(title: "Refresh Usage", action: #selector(refreshNow)))
            usageItem.submenu = submenu
            menu.addItem(usageItem)
            return
        }

        if let error = snapshot.error, !error.isEmpty {
            addDisabled("Usage Unavailable", to: submenu)
            addDisabled(error, to: submenu)
        } else {
            addDisabled(usageLine(title: "5hour", window: snapshot.fiveHour), to: submenu)
            addDisabled(usageLine(title: "Weekly", window: snapshot.weekly), to: submenu)
        }

        addDisabled("Updated \(formatUpdatedDate(snapshot.fetchedAt))", to: submenu)
        submenu.addItem(.separator())
        submenu.addItem(makeItem(title: "Refresh Usage", action: #selector(refreshNow)))

        usageItem.submenu = submenu
        menu.addItem(usageItem)
    }

    private func usageLine(title: String, window: UsageWindowSnapshot?) -> String {
        "\(title): \(formatPercent(window?.usedPercent)) used, \(formatResetDistance(window?.resetAt))"
    }

    private func nativeSessionTitle(_ session: ProjectConversationSession, showsService: Bool) -> String {
        let prefix = showsService ? "\(session.service.displayTitle) - " : ""
        return "\(session.state.title) - \(prefix)\(session.title)"
    }

    private func nativeSessionToolTip(_ session: ProjectConversationSession) -> String {
        let subtitle = session.subtitle.isEmpty ? session.source : session.subtitle
        return "\(session.service.displayTitle) - \(subtitle)\n\(session.detail)"
    }

    private func setSelectionMode(_ mode: ServiceSelectionMode) {
        guard selectionMode != mode else { return }
        if let service = mode.service,
           !serviceAvailability(for: service).isSelectable {
            return
        }
        rememberServiceTabAnimationOrigin(selectionMode)
        selectionMode = mode
        isProjectSessionsExpanded = false
        rebuildMenu()
        if !isAutoMode, selectedService.supportsUsage {
            refreshUsage()
        }
    }

    private func rememberServiceTabAnimationOrigin(_ mode: ServiceSelectionMode) {
        serviceTabAnimationOriginMode = mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [weak self] in
            guard self?.serviceTabAnimationOriginMode == mode else { return }
            self?.serviceTabAnimationOriginMode = nil
        }
    }

    @objc private func selectAutoMode(_ sender: Any?) {
        setSelectionMode(.auto)
    }

    @objc private func selectCodexMode(_ sender: Any?) {
        setSelectionMode(.service(.codex))
    }

    @objc private func selectClaudeMode(_ sender: Any?) {
        setSelectionMode(.service(.claude))
    }

    private func representedService(from sender: Any?) -> AccountService? {
        if let item = sender as? NSMenuItem,
           let rawValue = item.representedObject as? String {
            return AccountService(rawValue: rawValue)
        }
        return nil
    }

    private func addCustomView(_ view: NSView, to menu: NSMenu) {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.view = view
        menu.addItem(item)
    }

    @objc private func togglePopover(_ sender: Any?) {
        if panelWindow?.isVisible == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        isAccountsExpanded = false

        let panelView = makePanelView()
        let frame = panelFrame(for: panelView.intrinsicContentSize, relativeTo: button)
        let panelWindow = StatusPanelWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panelWindow.isReleasedWhenClosed = false
        panelWindow.isFloatingPanel = true
        panelWindow.hidesOnDeactivate = false
        panelWindow.backgroundColor = .clear
        panelWindow.isOpaque = false
        panelWindow.hasShadow = true
        panelWindow.level = .statusBar
        panelWindow.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panelWindow.contentView = panelView
        panelWindow.makeKeyAndOrderFront(nil)
        self.panelWindow = panelWindow
        panelAnchorTopY = frame.maxY
        panelAnchorMinX = frame.minX
        installPanelEventMonitors()
        refreshProjectStatus()
    }

    private func closePopover() {
        closeAccountDropdown()
        panelWindow?.orderOut(nil)
        panelWindow = nil
        panelAnchorTopY = nil
        panelAnchorMinX = nil
        removePanelEventMonitors()
    }

    private func panelFrame(for contentSize: NSSize, relativeTo button: NSStatusBarButton) -> NSRect {
        let windowFrame = button.convert(button.bounds, to: nil)
        let screenFrame = button.window?.convertToScreen(windowFrame)
            ?? NSRect(x: 0, y: NSScreen.main?.visibleFrame.maxY ?? 0, width: contentSize.width, height: 0)
        let screen = button.window?.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let horizontalInset: CGFloat = 8
        let verticalInset: CGFloat = 8
        let gap: CGFloat = 6

        let minX = visibleFrame.minX + horizontalInset
        let maxX = visibleFrame.maxX - contentSize.width - horizontalInset
        let proposedX = screenFrame.midX - contentSize.width / 2
        let originX = min(max(proposedX, minX), maxX)
        let proposedY = screenFrame.minY - contentSize.height - gap
        let originY = max(proposedY, visibleFrame.minY + verticalInset)

        return NSRect(
            x: floor(originX),
            y: floor(originY),
            width: contentSize.width,
            height: contentSize.height
        )
    }

    private func constrainedPanelFrame(_ frame: NSRect) -> NSRect {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) ?? NSScreen.main else {
            return frame
        }
        let visibleFrame = screen.visibleFrame
        let originX = min(max(frame.minX, visibleFrame.minX + 8), visibleFrame.maxX - frame.width - 8)
        let originY = min(max(frame.minY, visibleFrame.minY + 8), visibleFrame.maxY - frame.height - 8)
        return NSRect(x: floor(originX), y: floor(originY), width: frame.width, height: frame.height)
    }

    private func constrainedPanelResizeFrame(_ frame: NSRect) -> NSRect {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) ?? NSScreen.main else {
            return frame
        }
        let visibleFrame = screen.visibleFrame
        let originX = min(max(frame.minX, visibleFrame.minX + 8), visibleFrame.maxX - frame.width - 8)
        let originY = max(frame.minY, visibleFrame.minY + 8)
        return NSRect(x: floor(originX), y: floor(originY), width: frame.width, height: frame.height)
    }

    private func installPanelEventMonitors() {
        removePanelEventMonitors()
        if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            guard let self, let panelWindow = self.panelWindow else { return event }
            if event.window !== panelWindow && event.window !== self.accountDropdownWindow {
                self.closePopover()
            }
            return event
        }) {
            panelEventMonitors.append(localMonitor)
        }
        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            self?.closePopover()
        }) {
            panelEventMonitors.append(globalMonitor)
        }
    }

    private func removePanelEventMonitors() {
        for monitor in panelEventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        panelEventMonitors.removeAll()
    }

    private func addAccountsOverflowItem(to menu: NSMenu, profiles: [String], activeProfile: String) {
        let title = activeProfile.isEmpty ? "Accounts" : "Accounts  \(activeProfile)"
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = accountsSubmenu(profiles: profiles, activeProfile: activeProfile)
        menu.addItem(item)
    }

    private func accountsSubmenu(profiles: [String], activeProfile: String) -> NSMenu {
        let submenu = NSMenu()

        for profile in profiles {
            let item = NSMenuItem(title: "\(profile)  \(profileSubtitle(profile))", action: #selector(switchProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile
            item.state = profile == activeProfile ? .on : .off
            item.isEnabled = profile != activeProfile
            submenu.addItem(item)
        }

        submenu.addItem(.separator())
        submenu.addItem(makeItem(title: "Add Account...", action: #selector(captureCurrent(_:))))

        return submenu
    }

    private func configureStatusItemIcon() {
        guard let button = statusItem.button else { return }
        statusItem.menu = nil
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.image = nil
        button.imagePosition = .imageLeft
        button.title = ""
        button.toolTip = AppDesign.appName
    }

    private func statusIcon(size: CGFloat) -> NSImage? {
        if let url = Bundle.main.url(forResource: "StatusIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: size, height: size)
            image.isTemplate = true
            return image
        }
        return nil
    }

    @objc private func switchServiceTab(_ sender: Any) {
        guard let button = sender as? ServiceTabButton,
              button.mode != selectionMode else {
            return
        }
        if let service = button.mode.service,
           !serviceAvailability(for: service).isSelectable {
            return
        }

        rememberServiceTabAnimationOrigin(selectionMode)
        selectionMode = button.mode
        isProjectSessionsExpanded = false
        isAccountsExpanded = false
        rebuildMenu()
        if !isAutoMode, selectedService.supportsUsage {
            refreshUsage()
        }
    }

    @objc private func switchProfile(_ sender: NSMenuItem) {
        if let payload = sender.representedObject as? ProfileMenuItemPayload {
            confirmSwitch(to: payload.profile, service: payload.service)
            return
        }
        guard let profile = sender.representedObject as? String else { return }
        confirmSwitch(to: profile)
    }

    @objc private func switchProfileButton(_ sender: Any) {
        guard let button = sender as? ProfileTabButton else { return }
        confirmSwitch(to: button.profile, service: button.service)
    }

    @objc private func accountListRowAction(_ sender: Any) {
        if let row = sender as? CurrentAccountRowView {
            guard profileNames(for: row.service).count > 1 else { return }
            isAccountsExpanded = true
            shouldAnimateAccountsExpansion = true
            rebuildMenu()
            return
        }

        if let row = sender as? CompactAccountRowButton {
            switch row.intent ?? .switchProfile {
            case .switchProfile:
                confirmSwitch(to: row.profile, service: row.service)
            case .deleteProfile:
                confirmDelete(profile: row.profile, service: row.service)
            case .expandAccounts:
                break
            }
            return
        }

        guard let row = sender as? AccountListRowButton else { return }
        switch row.intent ?? .switchProfile {
        case .switchProfile:
            confirmSwitch(to: row.profile, service: row.service)
        case .deleteProfile:
            confirmDelete(profile: row.profile, service: row.service)
        case .expandAccounts:
            isAccountsExpanded = true
            shouldAnimateAccountsExpansion = true
            rebuildMenu()
        }
    }

    @objc private func switchProfileDropdown(_ sender: Any) {
        guard let button = sender as? AccountDropdownRowButton,
              let profile = button.profile else { return }
        closeAccountDropdown()
        confirmSwitch(to: profile, service: button.service)
    }

    @objc private func toggleAccountDropdown(_ sender: Any) {
        guard let row = sender as? AccountMenuRowView else { return }
        if accountDropdownWindow?.isVisible == true {
            closeAccountDropdown()
            return
        }
        showAccountDropdown(anchor: row)
    }

    private func showAccountDropdown(anchor: AccountMenuRowView) {
        closeAccountDropdown()
        guard let panelWindow else { return }
        let service = anchor.service
        let profiles = profileNames(for: service)
        let active = activeProfile(for: service)
        let dropdownView = AccountDropdownPanelView(
            service: service,
            profiles: profiles,
            activeProfile: active,
            target: self,
            switchAction: #selector(switchProfileDropdown(_:)),
            addAction: #selector(captureCurrent(_:))
        )
        let size = dropdownView.intrinsicContentSize
        let anchorFrame = anchor.convert(anchor.bounds, to: nil)
        let screenFrame = anchor.window?.convertToScreen(anchorFrame) ?? panelWindow.frame
        var frame = NSRect(
            x: screenFrame.maxX - 7,
            y: screenFrame.minY - size.height - 12,
            width: size.width,
            height: size.height
        )
        if let screen = panelWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            frame.origin.y = min(max(frame.origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        }

        let dropdownWindow = StatusPanelWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        dropdownWindow.isReleasedWhenClosed = false
        dropdownWindow.isFloatingPanel = true
        dropdownWindow.hidesOnDeactivate = false
        dropdownWindow.backgroundColor = .clear
        dropdownWindow.isOpaque = false
        dropdownWindow.hasShadow = true
        dropdownWindow.level = .statusBar
        dropdownWindow.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        dropdownWindow.contentView = dropdownView
        dropdownWindow.makeKeyAndOrderFront(nil)
        accountDropdownWindow = dropdownWindow
    }

    private func closeAccountDropdown() {
        accountDropdownWindow?.orderOut(nil)
        accountDropdownWindow = nil
    }

    private func confirmSwitch(to profile: String, service: AccountService? = nil) {
        let service = service ?? selectedService
        closePopover()

        guard profile != activeProfile(for: service) else { return }
        let alert = NSAlert()
        alert.messageText = "Switch \(service.displayTitle) to \(profile)?"
        alert.informativeText = "\(service.displayTitle) will quit, the saved account state will be restored, and \(service.displayTitle) will reopen."
        alert.addButton(withTitle: "Switch")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.run(["switch", profile], service: service)
            DispatchQueue.main.async {
                if result.status != 0 {
                    self.showError(result.output)
                }
                self.selectionMode = .service(service)
                self.rebuildMenu()
                if service.supportsUsage {
                    self.refreshUsage()
                }
            }
        }
    }

    private func confirmDelete(profile: String, service: AccountService) {
        let alert = NSAlert()
        alert.messageText = "Delete \(service.displayTitle) account \(profile)?"
        alert.informativeText = "The saved profile will be removed from Agent Status Indicator. This does not delete the account from \(service.displayTitle)."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.run(["delete", profile], service: service)
            DispatchQueue.main.async {
                if result.status != 0 {
                    self.showError(result.output)
                }
                self.rebuildMenu()
                if service.supportsUsage {
                    self.refreshUsage()
                }
            }
        }
    }

    @objc private func captureCurrent(_ sender: Any?) {
        let service = (sender as? AddAccountRowView)?.service
            ?? (sender as? AddAccountButton)?.service
            ?? (sender as? AccountHeaderAddButton)?.service
            ?? (sender as? AccountListRowButton)?.service
            ?? (sender as? AccountDropdownRowButton)?.service
            ?? representedService(from: sender)
            ?? selectedService
        closePopover()

        let alert = NSAlert()
        alert.messageText = "Capture Current \(service.displayTitle) Account"
        alert.informativeText = "\(service.displayTitle) will quit first so its login state is fully written. Use a short profile name, such as personal or work."
        alert.addButton(withTitle: "Capture")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "profile-name"
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let profile = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profile.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.run(["capture", profile], service: service)
            DispatchQueue.main.async {
                if result.status != 0 {
                    self.showError(result.output)
                }
                self.selectionMode = .service(service)
                self.rebuildMenu()
                if service.supportsUsage {
                    self.refreshUsage()
                }
            }
        }
    }

    @objc private func refreshNow() {
        refreshProjectStatus()
        rebuildMenu()
        if !isAutoMode, selectedService.supportsUsage {
            refreshUsage()
        }
    }

    @objc private func toggleProjectSessionsExpanded(_ sender: Any) {
        isProjectSessionsExpanded.toggle()
        rebuildMenu()
    }

    @objc private func openProfilesFolder() {
        if isAutoMode {
            try? FileManager.default.createDirectory(at: appSupportHome, withIntermediateDirectories: true)
            NSWorkspace.shared.open(appSupportHome)
            return
        }
        _ = run(["open-folder"], service: selectedService)
    }

    @objc private func openCodex() {
        openServiceApplication(.codex)
    }

    @objc private func openSession(_ sender: Any) {
        guard let button = sender as? SessionRowButton else { return }
        closePopover()
        openAgentSession(button.session)
    }

    @objc private func openSessionMenuItem(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? SessionMenuItemPayload else { return }
        openAgentSession(payload.session)
    }

    private func openAgentSession(_ session: ProjectConversationSession) {
        switch session.service {
        case .codex:
            openCodexSession(session)
        case .claude:
            openClaudeSession(session)
        }
    }

    private func openCodexSession(_ session: ProjectConversationSession) {
        guard let threadID = agentSessionID(from: session),
              let encodedThreadID = threadID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "codex://threads/\(encodedThreadID)") else {
            openCodex()
            return
        }

        if !NSWorkspace.shared.open(url) {
            openCodex()
        }
    }

    private func openClaudeSession(_ session: ProjectConversationSession) {
        openServiceApplication(.claude)
    }

    private func agentSessionID(from session: ProjectConversationSession) -> String? {
        guard session.service == .codex else { return nil }
        let id = session.sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id != "aggregate" else { return nil }
        return id
    }

    private func openServiceApplication(_ service: AccountService) {
        guard let url = serviceAppURL(for: service) else {
            showError("\(service.displayTitle) is not installed in /Applications or ~/Applications.")
            return
        }
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { [weak self] _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.showError(error.localizedDescription)
            }
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func run(_ arguments: [String], service: AccountService = .codex) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["ACCOUNT_SERVICE"] = service.rawValue
        process.environment = environment

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

    private func profileNames(for service: AccountService) -> [String] {
        run(["list", "--plain"], service: service).output
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    private func activeProfile(for service: AccountService) -> String {
        run(["active"], service: service).output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func profileAuthURL(profile: String, service: AccountService) -> URL {
        var url = appSupportHome
        for component in service.profilePathComponents {
            url.appendPathComponent(component)
        }
        return url
            .appendingPathComponent(profile)
            .appendingPathComponent("auth")
            .appendingPathComponent(service.profileAuthFileName)
    }

    private func usageAuthURL(profile: String, activeProfile: String, service: AccountService) -> URL {
        profile == activeProfile ? codexAuthURL : profileAuthURL(profile: profile, service: service)
    }

    private func refreshUsage() {
        guard !isRefreshingUsage else { return }
        guard !isAutoMode else { return }
        guard selectedService.supportsUsage else { return }

        let service = selectedService
        let profiles = profileNames(for: service)
        let active = activeProfile(for: service)
        guard !profiles.isEmpty else {
            removeUsageSnapshots(for: service)
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
            usageFetcher.fetch(authURL: usageAuthURL(profile: profile, activeProfile: active, service: service)) { snapshot in
                lock.lock()
                updated[self.usageCacheKey(profile: profile, service: service)] = snapshot
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.removeUsageSnapshots(for: service)
            self.usageByProfile.merge(updated) { _, new in new }
            self.isRefreshingUsage = false
            self.saveUsageCache()
            if service == self.selectedService {
                self.rebuildMenu()
            }
        }
    }

    private func refreshProjectStatus() {
        guard !isRefreshingProjectStatus else { return }
        isRefreshingProjectStatus = true

        DispatchQueue.global(qos: .utility).async {
            let snapshot = self.projectMonitor.snapshot()
            DispatchQueue.main.async {
                self.isRefreshingProjectStatus = false
                guard snapshot != self.projectSnapshot else { return }
                self.projectSnapshot = snapshot
                self.rebuildMenu()
            }
        }
    }

    private func advanceStatusAnimation() {
        animationTick = (animationTick + 1) % 10_000
        updateStatusBarIcon()
        refreshVisibleMenuViews()
    }

    private func refreshVisibleMenuViews() {
        markNeedsDisplayRecursively(panelWindow?.contentView)
        for item in nativeMenu.items {
            markNeedsDisplayRecursively(item.view)
        }
    }

    private func markNeedsDisplayRecursively(_ view: NSView?) {
        guard let view else { return }
        view.needsDisplay = true
        for subview in view.subviews {
            markNeedsDisplayRecursively(subview)
        }
    }

    private func loadUsageCache() {
        guard let data = try? Data(contentsOf: usageCacheURL),
              let decoded = try? JSONDecoder().decode([String: UsageSnapshot].self, from: data) else {
            return
        }
        usageByProfile = migrateUsageCache(decoded)
    }

    private func saveUsageCache() {
        do {
            try FileManager.default.createDirectory(at: appSupportHome, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(usageByProfile)
            try data.write(to: usageCacheURL, options: .atomic)
        } catch {
            // The menu can still work without a persisted usage cache.
        }
    }

    private func migrateUsageCache(_ cache: [String: UsageSnapshot]) -> [String: UsageSnapshot] {
        var migrated: [String: UsageSnapshot] = [:]
        for (key, snapshot) in cache {
            if key.contains(":") {
                migrated[key] = snapshot
            } else {
                migrated[usageCacheKey(profile: key, service: .codex)] = snapshot
            }
        }
        return migrated
    }

    private func usageCacheKey(profile: String, service: AccountService) -> String {
        "\(service.rawValue):\(profile)"
    }

    private func usageSnapshot(profile: String, service: AccountService) -> UsageSnapshot? {
        usageByProfile[usageCacheKey(profile: profile, service: service)]
    }

    private func removeUsageSnapshots(for service: AccountService) {
        usageByProfile = usageByProfile.filter { entry in
            !entry.key.hasPrefix("\(service.rawValue):")
        }
    }

    private func profileTabItems(profiles: [String], activeProfile: String) -> [ProfileTabItem] {
        let sortedProfiles = profiles.sorted { lhs, rhs in
            if lhs == activeProfile { return true }
            if rhs == activeProfile { return false }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        return sortedProfiles.map { profile in
            ProfileTabItem(
                service: selectedService,
                accountType: selectedService.displayTitle,
                profile: profile,
                subtitle: profileSubtitle(profile),
                isActive: profile == activeProfile
            )
        }
    }

    private func profileSubtitle(_ profile: String) -> String {
        ""
    }

    private func usageView(snapshot: UsageSnapshot?) -> UsageBarsMenuView {
        guard let snapshot else {
            return makeUsageBars(fiveHour: nil, weekly: nil, updatedText: "Updated --")
        }

        if let error = snapshot.error {
            return makeUsageBars(
                fiveHour: nil,
                weekly: nil,
                updatedText: "Updated \(formatUpdatedDate(snapshot.fetchedAt)) · \(error)"
            )
        }

        return makeUsageBars(
            fiveHour: snapshot.fiveHour,
            weekly: snapshot.weekly,
            updatedText: "Updated \(formatUpdatedDate(snapshot.fetchedAt))"
        )
    }

    private func makeUsageBars(
        fiveHour: UsageWindowSnapshot?,
        weekly: UsageWindowSnapshot?,
        updatedText: String
    ) -> UsageBarsMenuView {
        UsageBarsMenuView(
            rows: [
                UsageBarRow(
                    title: "5hour",
                    usedPercent: fiveHour?.usedPercent,
                    resetText: formatResetDistance(fiveHour?.resetAt)
                ),
                UsageBarRow(
                    title: "Weekly",
                    usedPercent: weekly?.usedPercent,
                    resetText: formatResetDistance(weekly?.resetAt)
                )
            ],
            updatedText: updatedText,
            target: self,
            refreshAction: #selector(refreshNow)
        )
    }

    private func compactUsageView(snapshot: UsageSnapshot?) -> CompactUsageBarsMenuView {
        guard let snapshot else {
            return makeCompactUsageBars(fiveHour: nil, weekly: nil, updatedText: "Updated --")
        }

        if let error = snapshot.error {
            return makeCompactUsageBars(
                fiveHour: nil,
                weekly: nil,
                updatedText: "Updated \(formatUpdatedDate(snapshot.fetchedAt)) · \(error)"
            )
        }

        return makeCompactUsageBars(
            fiveHour: snapshot.fiveHour,
            weekly: snapshot.weekly,
            updatedText: "Updated \(formatUpdatedDate(snapshot.fetchedAt))"
        )
    }

    private func makeCompactUsageBars(
        fiveHour: UsageWindowSnapshot?,
        weekly: UsageWindowSnapshot?,
        updatedText: String
    ) -> CompactUsageBarsMenuView {
        CompactUsageBarsMenuView(
            rows: [
                UsageBarRow(
                    title: "5hour",
                    usedPercent: fiveHour?.usedPercent,
                    resetText: formatResetDistance(fiveHour?.resetAt)
                ),
                UsageBarRow(
                    title: "Weekly",
                    usedPercent: weekly?.usedPercent,
                    resetText: formatResetDistance(weekly?.resetAt)
                )
            ],
            updatedText: updatedText,
            target: self,
            refreshAction: #selector(refreshNow)
        )
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func updateStatusBarTitle() {
        guard let button = statusItem.button else { return }
        let statusSnapshot = statusBarProjectSnapshot()
        let service = statusBarService(for: statusSnapshot)
        let activeProfile = service.supportsProfiles ? activeProfile(for: service) : ""

        button.image = TrafficLightStatusIcon.menuBarImage(service: service, state: statusSnapshot.state, tick: animationTick)
        button.imagePosition = .imageLeft
        button.title = ""

        if activeProfile.isEmpty {
            button.toolTip = projectToolTip(snapshot: statusSnapshot, service: service)
            return
        }

        let snapshot = usageSnapshot(profile: activeProfile, service: service)

        let projectText = projectToolTip(snapshot: statusSnapshot, service: service)
        if service.supportsUsage, let snapshot, snapshot.error == nil {
            button.toolTip = "\(activeProfile): 5h \(formatPercent(snapshot.fiveHour?.remainingPercent)), 1w \(formatPercent(snapshot.weekly?.remainingPercent))\n\(projectText)"
        } else if service.supportsUsage {
            button.toolTip = "\(activeProfile): usage unavailable\n\(projectText)"
        } else {
            button.toolTip = "\(service.displayTitle) \(activeProfile): saved state\n\(projectText)"
        }
    }

    private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
        let statusSnapshot = statusBarProjectSnapshot()
        let service = statusBarService(for: statusSnapshot)
        button.image = TrafficLightStatusIcon.menuBarImage(service: service, state: statusSnapshot.state, tick: animationTick)
        button.imagePosition = .imageLeft
        button.title = ""
    }

    private func statusBarProjectSnapshot() -> ProjectConversationSnapshot {
        isAutoMode ? autoStatusBarProjectSnapshot() : panelProjectSnapshot(for: selectedService)
    }

    private func statusBarService(for snapshot: ProjectConversationSnapshot) -> AccountService {
        snapshot.sessions.first?.service ?? selectedService
    }

    private func projectToolTip(snapshot: ProjectConversationSnapshot, service: AccountService) -> String {
        let updatedText: String
        if let updatedAt = snapshot.updatedAt {
            updatedText = " · \(formatDate(updatedAt))"
        } else {
            updatedText = ""
        }
        return "\(service.displayTitle) \(snapshot.state.shortTitle): \(snapshot.detail) (\(snapshot.source)\(updatedText))"
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    private func formatResetDistance(_ epochSeconds: Double?) -> String {
        guard let epochSeconds, epochSeconds.isFinite else { return "Reset unavailable" }

        let resetDate = Date(timeIntervalSince1970: epochSeconds)
        let seconds = Int(resetDate.timeIntervalSinceNow.rounded())
        guard seconds > 0 else { return "Resets soon" }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return hours > 0 ? "Resets in \(days)d \(hours)h" : "Resets in \(days)d"
        }

        if hours > 0 {
            return minutes > 0 ? "Resets in \(hours)h \(minutes)m" : "Resets in \(hours)h"
        }

        return "Resets in \(max(minutes, 1))m"
    }

    private func formatUpdatedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        if calendar.isDateInToday(date) {
            return "today \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "tomorrow \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "yesterday \(timeFormatter.string(from: date))"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: date)
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
        alert.messageText = AppDesign.appName
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
