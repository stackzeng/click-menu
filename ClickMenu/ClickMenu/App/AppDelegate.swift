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
            ExtensionStatus.shared.start()
            if !AppSettings.shared.hasCompletedOnboarding {
                WindowManager.shared.showOnboarding()
            }
        }
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
        case let .editor(path):
            Launcher.openEditor(at: path)
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
