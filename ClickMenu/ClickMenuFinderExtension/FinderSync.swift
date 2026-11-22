import Cocoa
import FinderSync
import os

/// Finder 右键菜单扩展：只注入一个「ClickMenu ▸」，所有功能都在它的子菜单里（PRD F0）。
final class FinderSync: FIFinderSync {

    private let log = Logger(subsystem: "io.github.stackzeng.clickmenu", category: "FinderSync")

    /// 最近一次弹出的菜单类型。Finder 调用 action 时不会告诉我们是哪种菜单，所以在这里记下来。
    private var lastMenuKind: FIMenuKind = .contextualMenuForItems

    override init() {
        super.init()
        // 监听整个文件系统，所有目录（含外接磁盘、iCloud 云盘）都显示菜单
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        log.notice("ClickMenu Finder 扩展已启动")
    }

    // MARK: - 菜单

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else { return nil }
        lastMenuKind = menuKind
        let isContainer = menuKind == .contextualMenuForContainer

        let submenu = NSMenu(title: "ClickMenu")
        for action in SharedSettings.visibleActions {
            let title = isContainer ? action.containerTitle : action.title
            guard let title else { continue }
            let item = NSMenuItem(title: title, action: #selector(performAction(_:)), keyEquivalent: "")
            item.tag = action.rawValue
            item.image = Self.icon(action.iconName)
            submenu.addItem(item)
        }
        guard !submenu.items.isEmpty else { return nil }

        let parent = NSMenuItem(title: "ClickMenu", action: nil, keyEquivalent: "")
        parent.image = Self.icon("MenuBrand")
        parent.submenu = submenu

        let menu = NSMenu(title: "")
        menu.addItem(parent)
        return menu
    }

    private static func icon(_ name: String) -> NSImage? {
        guard let image = NSImage(named: name) else { return nil }
        // 彩色图标（非模板），高亮时保持原色，和系统设置侧边栏一致
        image.isTemplate = false
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    // MARK: - 执行

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let action = MenuAction(rawValue: sender.tag) else { return }
        let controller = FIFinderSyncController.default()

        let isContainer = lastMenuKind == .contextualMenuForContainer
        let selected = isContainer ? [] : (controller.selectedItemURLs() ?? [])
        // 空白处右键（或没有选中项）时，作用于当前目录
        let targets = selected.isEmpty ? [controller.targetedURL()].compactMap { $0 } : selected
        guard let first = targets.first else {
            log.error("没有可操作的目标")
            return
        }

        switch action {
        case .openTerminal:
            let dir = PathFormatter.directory(for: first)
            send(.terminal(path: PathFormatter.path(dir)))

        case .copyName, .copyPath:
            guard let text = PathFormatter.text(for: action, urls: targets) else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
            log.notice("\(action.title, privacy: .public)：\(targets.count) 项")

            if SharedSettings.showHUD {
                let firstLine = text.components(separatedBy: "\n").first ?? text
                let detail = targets.count > 1 ? "\(firstLine) 等 \(targets.count) 项" : firstLine
                send(.hud(title: action.copiedTitle(count: targets.count, isContainer: selected.isEmpty), detail: detail))
            }
        }
    }

    /// 交给宿主 App 执行（沙盒内无法直接控制其他 App）
    private func send(_ command: HostCommand) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open(command.url, configuration: config) { [log] _, error in
            if let error { log.error("通知宿主 App 失败：\(error.localizedDescription, privacy: .public)") }
        }
    }
}
