import SwiftUI

@main
struct ClickMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var status = ExtensionStatus.shared

    var body: some Scene {
        // 菜单栏常驻图标。设置窗口与引导窗口由 WindowManager 用 AppKit 管理，便于从任意入口打开。
        MenuBarExtra(isInserted: menuBarIconBinding) {
            MenuBarContent()
                .environmentObject(status)
        } label: {
            Image("StatusBrand")  // 菜单栏保持单色，跟随系统深浅色
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
    }

    /// MenuBarExtra 会在视图更新过程中回写 isInserted，直接绑定 @Published 会刷屏
    /// "Publishing changes from within view updates"。这里只在值真正变化时、在下一轮主循环里写入。
    private var menuBarIconBinding: Binding<Bool> {
        Binding(
            get: { settings.showMenuBarIcon },
            set: { newValue in
                guard newValue != settings.showMenuBarIcon else { return }
                DispatchQueue.main.async { settings.showMenuBarIcon = newValue }
            })
    }
}
