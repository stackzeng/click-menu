import SwiftUI

/// 点击菜单栏图标展开的菜单（原型 ②）
struct MenuBarContent: View {
    @EnvironmentObject private var status: ExtensionStatus
    @EnvironmentObject private var updater: UpdaterController

    var body: some View {
        Text(status.isEnabled ? "🟢 Finder 扩展已启用" : "🔴 Finder 扩展未启用")

        if !status.isEnabled {
            Button("去启用 Finder 扩展…") {
                WindowManager.shared.showOnboarding(step: 1)
            }
        }

        Divider()

        if let version = updater.availableVersion {
            Button("⬆︎ 新版本 \(version) 可用…") { updater.checkForUpdates() }
            Divider()
        }

        Button("设置…") { WindowManager.shared.showSettings() }
            .keyboardShortcut(",")
        Button("检查更新…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
        Button("显示使用引导") { WindowManager.shared.showOnboarding() }

        Divider()

        Button("关于 ClickMenu") { WindowManager.shared.showSettings(tab: .about) }
        Button("退出 ClickMenu") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
