import Foundation
import ServiceManagement
import os

/// 供 SwiftUI 绑定的设置模型；写入时同步到 App Group，Finder 扩展下次弹出菜单时即生效。
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let log = Logger(subsystem: "io.github.stackzeng.clickmenu", category: "Settings")
    private let local = UserDefaults.standard

    @Published var menuOrder: [MenuAction] { didSet { SharedSettings.menuOrder = menuOrder } }
    @Published var enabledActions: Set<MenuAction> { didSet { SharedSettings.enabledActions = enabledActions } }
    @Published var showHUD: Bool { didSet { SharedSettings.showHUD = showHUD } }
    @Published var terminalBundleID: String { didSet { SharedSettings.terminalBundleID = terminalBundleID } }

    @Published var showMenuBarIcon: Bool { didSet { local.set(showMenuBarIcon, forKey: "showMenuBarIcon") } }
    @Published var hasCompletedOnboarding: Bool { didSet { local.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") } }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                log.error("设置登录启动失败：\(error.localizedDescription, privacy: .public)")
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private init() {
        menuOrder = SharedSettings.menuOrder
        enabledActions = SharedSettings.enabledActions
        showHUD = SharedSettings.showHUD
        terminalBundleID = SharedSettings.terminalBundleID
        showMenuBarIcon = local.object(forKey: "showMenuBarIcon") as? Bool ?? true
        hasCompletedOnboarding = local.bool(forKey: "hasCompletedOnboarding")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func isEnabled(_ action: MenuAction) -> Bool { enabledActions.contains(action) }

    func setEnabled(_ action: MenuAction, _ on: Bool) {
        if on { enabledActions.insert(action) } else { enabledActions.remove(action) }
    }

    var terminal: ExternalApp? { ExternalApps.terminals.first { $0.bundleID == terminalBundleID } }
}
