import Foundation

/// 「ClickMenu ▸」子菜单里的全部功能。
/// rawValue 同时用作 NSMenuItem.tag —— Finder 复制扩展菜单时只保留 tag，不保留 representedObject。
/// 注意：rawValue 4–7 曾用于已移除的功能，新增功能请从 8 开始，避免和老用户保存的设置冲突。
enum MenuAction: Int, CaseIterable, Identifiable {
    case copyName = 1
    case copyPath = 2
    case openTerminal = 3

    var id: Int { rawValue }

    /// 选中文件 / 文件夹右键时的标题
    var title: String {
        switch self {
        case .copyName: return "复制文件名"
        case .copyPath: return "复制完整路径"
        case .openTerminal: return "在此处打开终端"
        }
    }

    /// 在 Finder 窗口空白处右键时的标题；nil 表示该功能不出现在空白处菜单
    var containerTitle: String? {
        switch self {
        case .copyName: return nil
        case .copyPath: return "复制当前目录路径"
        case .openTerminal: return "在此处打开终端"
        }
    }

    /// Icons.xcassets 中的图标名
    var iconName: String {
        switch self {
        case .copyName: return "MenuName"
        case .copyPath: return "MenuPath"
        case .openTerminal: return "MenuTerminal"
        }
    }

    /// 复制成功后 HUD 的标题
    func copiedTitle(count: Int, isContainer: Bool) -> String {
        if isContainer { return "已复制当前目录路径" }
        let n = count > 1 ? " \(count) 个" : ""
        switch self {
        case .copyName: return "已复制\(n)文件名"
        case .copyPath: return "已复制\(n)路径"
        case .openTerminal: return ""
        }
    }

    static let defaultEnabled: Set<MenuAction> = Set(allCases)
}
