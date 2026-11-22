import Foundation

/// 把 Finder 选中的 URL 转成要写入剪贴板的文本。纯逻辑，便于单元测试。
enum PathFormatter {

    /// 剪贴板文本；多选时每项一行。非复制类功能返回 nil。
    static func text(for action: MenuAction, urls: [URL], home: String = realHomeDirectory) -> String? {
        let lines: [String]
        switch action {
        case .copyName: lines = urls.map(name)
        case .copyBaseName: lines = urls.map(baseName)
        case .copyPath: lines = urls.map(path)
        case .copyEscapedPath: lines = urls.map { escaped(path($0)) }
        case .copyTildePath: lines = urls.map { tilde(path($0), home: home) }
        case .openTerminal, .openInEditor: return nil
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func name(_ url: URL) -> String {
        url.lastPathComponent
    }

    /// 去掉扩展名；文件夹、无扩展名文件、以点开头的隐藏文件（如 .zshrc）保持原样
    static func baseName(_ url: URL) -> String {
        let name = url.lastPathComponent
        if isDirectory(url) { return name }
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return name }
        return String(name[..<dot])
    }

    /// 绝对路径，不带末尾斜杠
    static func path(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    /// shell 转义：在特殊字符前加反斜杠，可直接粘贴进终端
    static func escaped(_ path: String) -> String {
        let special: Set<Character> = [" ", "\t", "!", "\"", "#", "$", "&", "'", "(", ")", "*", ",",
                                       ";", "<", "=", ">", "?", "[", "\\", "]", "^", "`", "{", "|", "}", "~"]
        var out = ""
        out.reserveCapacity(path.count)
        for ch in path {
            if special.contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out
    }

    /// 主目录前缀替换为 ~
    static func tilde(_ path: String, home: String = realHomeDirectory) -> String {
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
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

    /// 真实主目录。沙盒扩展里 NSHomeDirectory() 返回的是容器路径，不能用。
    static var realHomeDirectory: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }
}
