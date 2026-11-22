import Foundation

/// 「ClickMenu ▸」子菜单里的全部功能。
/// rawValue 同时用作 NSMenuItem.tag —— Finder 复制扩展菜单时只保留 tag，不保留 representedObject。
enum MenuAction: Int, CaseIterable, Identifiable {
    case copyName = 1
    case copyPath = 2
    case openTerminal = 3
    case copyBaseName = 4
    case copyEscapedPath = 5
    case copyTildePath = 6
    case openInEditor = 7

    var id: Int { rawValue }

    /// 选中文件 / 文件夹右键时的标题
    var title: String {
        switch self {
        case .copyName: return "复制文件名"
        case .copyPath: return "复制完整路径"
        case .openTerminal: return "在此处打开终端"
        case .copyBaseName: return "复制文件名（不含扩展名）"
        case .copyEscapedPath: return "复制转义路径"
        case .copyTildePath: return "复制 ~ 短路径"
        case .openInEditor: return "用编辑器打开"
        }
    }

    /// 在 Finder 窗口空白处右键时的标题；nil 表示该功能不出现在空白处菜单
    var containerTitle: String? {
        switch self {
        case .copyPath: return "复制当前目录路径"
        case .copyEscapedPath: return "复制当前目录转义路径"
        case .copyTildePath: return "复制当前目录 ~ 路径"
        case .openTerminal: return "在此处打开终端"
        case .openInEditor: return "用编辑器打开当前目录"
        case .copyName, .copyBaseName: return nil
        }
    }

    /// Icons.xcassets 中的模板图标名
    var iconName: String {
        switch self {
        case .copyName: return "MenuName"
        case .copyPath: return "MenuPath"
        case .openTerminal: return "MenuTerminal"
        case .copyBaseName: return "MenuBaseName"
        case .copyEscapedPath: return "MenuEscaped"
        case .copyTildePath: return "MenuTilde"
        case .openInEditor: return "MenuEditor"
        }
    }

    /// 是否是写剪贴板的功能
    var isCopy: Bool {
        switch self {
        case .openTerminal, .openInEditor: return false
        default: return true
        }
    }

    /// 复制成功后 HUD 的标题
    func copiedTitle(count: Int, isContainer: Bool) -> String {
        if isContainer {
            switch self {
            case .copyEscapedPath: return "已复制当前目录转义路径"
            case .copyTildePath: return "已复制当前目录 ~ 路径"
            default: return "已复制当前目录路径"
            }
        }
        let n = count > 1 ? " \(count) 个" : ""
        switch self {
        case .copyName: return "已复制\(n)文件名"
        case .copyBaseName: return "已复制\(n)文件名（不含扩展名）"
        case .copyPath: return "已复制\(n)路径"
        case .copyEscapedPath: return "已复制\(n)转义路径"
        case .copyTildePath: return "已复制\(n) ~ 短路径"
        case .openTerminal, .openInEditor: return ""
        }
    }

    static let defaultEnabled: Set<MenuAction> = [.copyName, .copyPath, .openTerminal]
}
