import Foundation

/// 把 Finder 选中的 URL 转成要写入剪贴板的文本。纯逻辑，便于单元测试。
enum PathFormatter {

    /// 剪贴板文本；多选时每项一行。非复制类功能返回 nil。
    static func text(for action: MenuAction, urls: [URL]) -> String? {
        let lines: [String]
        switch action {
        case .copyName: lines = urls.map(name)
        case .copyPath: lines = urls.map(path)
        case .openTerminal: return nil
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func name(_ url: URL) -> String {
        url.lastPathComponent
    }

    /// 绝对路径，不带末尾斜杠
    static func path(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    /// 打开终端的目标目录：文件夹 → 自身；文件或 .app 等包 → 所在目录
    static func directory(for url: URL) -> URL {
        isDirectory(url) ? url : url.deletingLastPathComponent()
    }

    /// 是普通文件夹（不含 .app 这类包）
    static func isDirectory(_ url: URL) -> Bool {
        if let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]), let isDir = v.isDirectory {
            return isDir && !(v.isPackage ?? false)
        }
        // 沙盒内读不到元数据时，退回看 URL 是否以 / 结尾（Finder 给的文件夹 URL 带斜杠）
        return url.hasDirectoryPath
    }
}
