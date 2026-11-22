import AppKit

/// 宿主 App 与 Finder 扩展共享的配置，存放在 App Group 的 UserDefaults 中。
enum SharedSettings {
    static let appGroupID = "MKBCLL4LKF.io.github.stackzeng.clickmenu"
    static let defaults: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    private enum Key {
        static let order = "menuOrder"
        static let enabled = "enabledActions"
        static let showHUD = "showHUD"
        static let terminal = "terminalBundleID"
    }

    /// 子菜单中功能的顺序。新版本新增的功能自动补在末尾。
    static var menuOrder: [MenuAction] {
        get {
            let raw = defaults.array(forKey: Key.order) as? [Int] ?? []
            var list: [MenuAction] = []
            for value in raw {
                if let a = MenuAction(rawValue: value), !list.contains(a) { list.append(a) }
            }
            for a in MenuAction.allCases where !list.contains(a) { list.append(a) }
            return list
        }
        set { defaults.set(newValue.map(\.rawValue), forKey: Key.order) }
    }

    static var enabledActions: Set<MenuAction> {
        get {
            guard let raw = defaults.array(forKey: Key.enabled) as? [Int] else { return MenuAction.defaultEnabled }
            return Set(raw.compactMap(MenuAction.init(rawValue:)))
        }
        set { defaults.set(newValue.map(\.rawValue).sorted(), forKey: Key.enabled) }
    }

    /// 按顺序排列、已启用的功能
    static var visibleActions: [MenuAction] {
        let enabled = enabledActions
        return menuOrder.filter(enabled.contains)
    }

    static var showHUD: Bool {
        get { defaults.object(forKey: Key.showHUD) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showHUD) }
    }

    static var terminalBundleID: String {
        get { defaults.string(forKey: Key.terminal) ?? ExternalApps.terminals[0].bundleID }
        set { defaults.set(newValue, forKey: Key.terminal) }
    }

}

/// 可选择的终端
struct ExternalApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    var id: String { bundleID }

    var url: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
    var isInstalled: Bool { url != nil }
}

enum ExternalApps {
    static let terminals: [ExternalApp] = [
        ExternalApp(bundleID: "com.apple.Terminal", name: "终端"),
        ExternalApp(bundleID: "com.googlecode.iterm2", name: "iTerm2"),
        ExternalApp(bundleID: "dev.warp.Warp-Stable", name: "Warp"),
        ExternalApp(bundleID: "com.mitchellh.ghostty", name: "Ghostty"),
        ExternalApp(bundleID: "org.alacritty", name: "Alacritty"),
    ]

}

/// 扩展 → 宿主 App 的通信：通过 clickmenu:// URL Scheme。
/// 扩展运行在沙盒里，打开终端 / 显示 HUD 交给非沙盒的宿主 App 执行；宿主未运行时系统会自动启动它。
enum HostCommand {
    static let scheme = "clickmenu"

    case hud(title: String, detail: String?)
    case terminal(path: String)
    case settings

    var url: URL {
        var c = URLComponents()
        c.scheme = Self.scheme
        switch self {
        case let .hud(title, detail):
            c.host = "hud"
            c.queryItems = [URLQueryItem(name: "title", value: title)] + (detail.map { [URLQueryItem(name: "detail", value: $0)] } ?? [])
        case let .terminal(path):
            c.host = "terminal"
            c.queryItems = [URLQueryItem(name: "path", value: path)]
        case .settings:
            c.host = "settings"
        }
        return c.url!
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let q = Dictionary((c.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        switch c.host {
        case "hud":
            guard let title = q["title"] else { return nil }
            self = .hud(title: title, detail: q["detail"])
        case "terminal":
            guard let path = q["path"], !path.isEmpty else { return nil }
            self = .terminal(path: path)
        case "settings":
            self = .settings
        default:
            return nil
        }
    }
}
