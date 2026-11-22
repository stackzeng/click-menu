import AppKit
import Sparkle
import os

/// 自动更新（Sparkle 2）。
/// - 后台每天检查一次 appcast；发现新版本时不弹窗打扰（gentle reminder），只在菜单栏图标和菜单中提示
/// - 用户点「检查更新…」或菜单里的「新版本可用…」时，弹出 Sparkle 的更新窗口
@MainActor
final class UpdaterController: NSObject, ObservableObject {
    static let shared = UpdaterController()

    nonisolated private let log = Logger(subsystem: "io.github.stackzeng.clickmenu", category: "Updater")
    private var controller: SPUStandardUpdaterController!
    private var observations: [NSKeyValueObservation] = []

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var lastCheckDate: Date?
    /// 后台发现、尚未安装的新版本号；nil 表示没有可用更新
    @Published private(set) var availableVersion: String?
    @Published private(set) var lastResult: String?

    @Published var automaticallyChecks = true {
        didSet { if updater.automaticallyChecksForUpdates != automaticallyChecks { updater.automaticallyChecksForUpdates = automaticallyChecks } }
    }
    @Published var automaticallyDownloads = false {
        didSet { if updater.automaticallyDownloadsUpdates != automaticallyDownloads { updater.automaticallyDownloadsUpdates = automaticallyDownloads } }
    }

    var updater: SPUUpdater { controller.updater }

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
        automaticallyChecks = updater.automaticallyChecksForUpdates
        automaticallyDownloads = updater.automaticallyDownloadsUpdates
        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { u, _ in
                let value = u.canCheckForUpdates
                Task { @MainActor in UpdaterController.shared.canCheckForUpdates = value }
            },
            updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { u, _ in
                let value = u.lastUpdateCheckDate
                Task { @MainActor in UpdaterController.shared.lastCheckDate = value }
            },
        ]
    }

    /// 手动检查更新：弹出 Sparkle 窗口（有新版本 → 更新窗口；没有 → 「已是最新版本」）
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    /// 设置 → 关于 中显示的状态文字
    var statusText: String {
        if let availableVersion { return "发现新版本 \(availableVersion)，点击「检查更新」安装" }
        guard let lastCheckDate else { return "尚未检查更新" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.unitsStyle = .full
        let when = f.localizedString(for: lastCheckDate, relativeTo: Date())
        return "上次检查：\(when)" + (lastResult.map { " · \($0)" } ?? "")
    }

    fileprivate func found(_ version: String) {
        availableVersion = version
        lastResult = "发现新版本 \(version)"
        log.notice("发现新版本 \(version, privacy: .public)")
    }
}

// MARK: - SPUUpdaterDelegate

extension UpdaterController: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor in self.found(version) }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        log.notice("已是最新版本")
        Task { @MainActor in
            self.availableVersion = nil
            self.lastResult = "已是最新版本"
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        // 「没有更新」也会走到这里，忽略
        guard !(nsError.domain == SUSparkleErrorDomain && nsError.code == Int(SUError.noUpdateError.rawValue)) else { return }
        log.error("检查更新失败：\(error.localizedDescription, privacy: .public)")
        Task { @MainActor in self.lastResult = "检查失败，请稍后重试" }
    }
}

// MARK: - SPUStandardUserDriverDelegate（菜单栏 App 的温和提醒）

extension UpdaterController: SPUStandardUserDriverDelegate {
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// 后台定时检查发现更新时：如果 App 正在前台（用户刚好在看设置窗口）就直接弹窗，否则只做菜单栏提示
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        let version = update.displayVersionString
        Task { @MainActor in
            self.found(version)
            if handleShowingUpdate { NSApp.activate(ignoringOtherApps: true) }
        }
    }
}
