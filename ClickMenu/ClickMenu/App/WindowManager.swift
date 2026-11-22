import AppKit
import SwiftUI

/// 用 AppKit 管理设置窗口和引导窗口。
/// 菜单栏 App（LSUIElement）用 SwiftUI Window 场景时，启动行为和激活行为不好控制，这里统一手动管理。
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    let settingsNavigation = SettingsNavigation()
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func showSettings(tab: SettingsTab? = nil) {
        if let tab { settingsNavigation.tab = tab }
        if settingsWindow == nil {
            let root = SettingsView()
                .environmentObject(settingsNavigation)
                .environmentObject(AppSettings.shared)
                .environmentObject(ExtensionStatus.shared)
                .environmentObject(UpdaterController.shared)
            let window = NSWindow(contentViewController: NSHostingController(rootView: root))
            window.title = "ClickMenu 设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        present(settingsWindow)
    }

    func showOnboarding(step: Int = 0) {
        if onboardingWindow == nil {
            let model = OnboardingModel()
            let root = OnboardingView(model: model)
                .environmentObject(AppSettings.shared)
                .environmentObject(ExtensionStatus.shared)
            let window = NSWindow(contentViewController: NSHostingController(rootView: root))
            window.title = "欢迎使用 ClickMenu"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.center()
            onboardingWindow = window
            OnboardingModel.current = model
        }
        OnboardingModel.current?.step = step
        present(onboardingWindow)
    }

    func closeOnboarding() {
        onboardingWindow?.close()
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
