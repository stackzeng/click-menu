import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let log = Logger(subsystem: "io.github.stackzeng.clickmenu", category: "App")

    func applicationWillFinishLaunching(_ notification: Notification) {
        installURLHandler()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI 会在启动过程中注册自己的 URL 处理器（用于场景路由），这里再装一次，确保由我们处理
        installURLHandler()
        log.notice("ClickMenu 已启动")
        Task { @MainActor in
            // 不在「应用程序」文件夹时先提示移动；正在移动并重新打开时不继续启动流程
            if AppMover.moveIfNeeded() { return }
            AppMover.finishPendingCleanup()

            ExtensionStatus.shared.start()
            _ = UpdaterController.shared   // 启动 Sparkle，开始后台检查
            if !AppSettings.shared.hasCompletedOnboarding {
                WindowManager.shared.showOnboarding()
            } else {
                self.checkVersionChange()
            }
            UserDefaults.standard.set(Self.currentVersion, forKey: "lastLaunchedVersion")
        }
    }

    // MARK: - 更新后提示重启访达

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// 更新后（含从没有记录版本号的 1.0.0 升级上来）首次启动：Finder 还在运行旧版扩展，提示重启访达
    @MainActor
    private func checkVersionChange() {
        let last = UserDefaults.standard.string(forKey: "lastLaunchedVersion")
        guard last != Self.currentVersion else { return }
        log.notice("版本变化：\(last ?? "1.0.0", privacy: .public) → \(Self.currentVersion, privacy: .public)")

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "ClickMenu 已更新到 \(Self.currentVersion)"
        alert.informativeText = "需要重启「访达」才能加载新版右键菜单。重启时打开的访达窗口会自动恢复。"
        alert.addButton(withTitle: "重启访达")
        alert.addButton(withTitle: "稍后")
        alert.addButton(withTitle: "查看更新说明")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Self.restartFinder()
        case .alertThirdButtonReturn:
            NSWorkspace.shared.open(URL(string: "https://github.com/stackzeng/click-menu/releases/tag/v\(Self.currentVersion)")!)
        default:
            break
        }
    }

    private static func restartFinder() {
        // Finder 被结束后由系统自动重新启动，并重新加载 Finder 扩展
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Finder"]
        try? p.run()
    }

    // MARK: - clickmenu:// 指令（来自 Finder 扩展）

    private func installURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }
        guard let command = HostCommand(url: url) else {
            log.error("无法识别的 URL：\(string, privacy: .public)")
            return
        }
        log.notice("收到指令：\(url.host ?? "", privacy: .public)")
        Task { @MainActor in self.handle(command) }
    }

    @MainActor
    private func handle(_ command: HostCommand) {
        switch command {
        case let .hud(title, detail):
            HUDController.shared.show(title: title, detail: detail)
        case let .terminal(path):
            Launcher.openTerminal(at: path)
        case .settings:
            WindowManager.shared.showSettings()
        }
    }

    /// 菜单栏图标被隐藏时，再次打开 App（Dock / 启动台 / Finder 双击）进入设置
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in WindowManager.shared.showSettings() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
