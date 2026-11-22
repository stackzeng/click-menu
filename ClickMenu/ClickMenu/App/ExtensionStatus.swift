import FinderSync
import SwiftUI

/// 轮询 Finder 扩展是否已在系统设置中启用
@MainActor
final class ExtensionStatus: ObservableObject {
    static let shared = ExtensionStatus()

    @Published private(set) var isEnabled = FIFinderSyncController.isExtensionEnabled
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in ExtensionStatus.shared.refresh() }
        }
    }

    func refresh() {
        let value = FIFinderSyncController.isExtensionEnabled
        if value != isEnabled { isEnabled = value }
    }

    /// 打开「系统设置 → 登录项与扩展」中的扩展管理界面
    func openSystemSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
