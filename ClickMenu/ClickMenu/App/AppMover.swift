import AppKit
import os

/// 「移到应用程序文件夹」：Finder 扩展只有在 App 位于「应用程序」文件夹时才会被系统注册。
/// 用户直接在 DMG 里、「下载」文件夹里运行（或被 App Translocation 随机路径运行）时，提示一键移动：
/// 复制到 /Applications（没有写权限时改用 ~/Applications）→ 从新位置重新打开 →
/// 新实例负责推出安装盘、把「下载」里的原件移到废纸篓。
@MainActor
enum AppMover {
    nonisolated private static let log = Logger(subsystem: "io.github.stackzeng.clickmenu", category: "AppMover")

    private static let ejectArg = "--cm-eject-volume"
    private static let trashArg = "--cm-trash-original"

    /// 需要移动时弹窗处理；返回 true 表示当前实例即将退出（调用方不要继续启动流程）
    static func moveIfNeeded() -> Bool {
        #if DEBUG
        return false   // Xcode 调试时 App 总在构建目录里，不提示
        #else
        let current = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard !isInApplicationsFolder(current) else { return false }

        let original = originalURL(for: current)   // App Translocation 时取回真实位置
        let onDiskImage = isOnReadOnlyVolume(original)
        log.notice("App 不在「应用程序」文件夹：\(original.path, privacy: .public)")

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "将 ClickMenu 移到「应用程序」文件夹？"
        alert.informativeText = "ClickMenu 需要放在「应用程序」文件夹中，Finder 右键菜单才能正常工作。"
            + (onDiskImage ? "\n\n移动完成后会自动推出安装盘。" : "")
        alert.addButton(withTitle: "移到「应用程序」文件夹")
        alert.addButton(withTitle: "暂不移动")
        guard alert.runModal() == .alertFirstButtonReturn else {
            log.notice("用户选择暂不移动")
            return false
        }

        do {
            let destination = try install(from: current)
            relaunch(at: destination, original: original, onDiskImage: onDiskImage)
            return true
        } catch {
            log.error("移动失败：\(error.localizedDescription, privacy: .public)")
            let failure = NSAlert()
            failure.alertStyle = .warning
            failure.messageText = "无法自动移动 ClickMenu"
            failure.informativeText = "\(error.localizedDescription)\n\n请手动把 ClickMenu 拖到「应用程序」文件夹，然后从那里打开。"
            failure.addButton(withTitle: "好")
            failure.runModal()
            return false
        }
        #endif
    }

    /// 新实例启动时调用：推出安装盘 / 清理原件
    static func finishPendingCleanup() {
        let args = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        let eject = value(after: ejectArg)
        let trash = value(after: trashArg)
        guard eject != nil || trash != nil else { return }

        // 等旧实例完全退出后再处理，否则卷还在被占用
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let eject {
                do {
                    try NSWorkspace.shared.unmountAndEjectDevice(at: URL(fileURLWithPath: eject))
                    log.notice("已推出安装盘：\(eject, privacy: .public)")
                } catch {
                    log.error("推出安装盘失败：\(error.localizedDescription, privacy: .public)")
                }
            }
            if let trash, FileManager.default.fileExists(atPath: trash) {
                do {
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: trash), resultingItemURL: nil)
                    log.notice("原件已移到废纸篓：\(trash, privacy: .public)")
                } catch {
                    log.error("清理原件失败：\(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    // MARK: - 位置判断

    /// 安装目标，按优先级排列：先 /Applications，没有写权限时再用 ~/Applications。
    /// 注意 FileManager.urls(for:in:) 返回的顺序是用户目录在前，不能直接用。
    private static var applicationsFolders: [URL] {
        let fm = FileManager.default
        let local = fm.urls(for: .applicationDirectory, in: .localDomainMask)
        let user = fm.urls(for: .applicationDirectory, in: .userDomainMask)
        return (local + user).map { $0.resolvingSymlinksInPath() }
    }

    private static func isInApplicationsFolder(_ url: URL) -> Bool {
        let path = url.path
        return applicationsFolders.contains { path.hasPrefix($0.path + "/") }
    }

    private static func isOnReadOnlyVolume(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) ?? false
    }

    /// App Translocation（隔离的 App 从「下载」等位置首次打开时，系统会挂到一个随机只读路径运行）时，返回原始位置
    private static func originalURL(for url: URL) -> URL {
        guard url.path.contains("/AppTranslocation/"),
              let handle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let symbol = dlsym(handle, "SecTranslocateCreateOriginalPathForURL") else { return url }
        typealias Fn = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
        let fn = unsafeBitCast(symbol, to: Fn.self)
        guard let result = fn(url as CFURL, nil)?.takeRetainedValue() else { return url }
        return result as URL
    }

    // MARK: - 复制与重新打开

    private static func install(from source: URL) throws -> URL {
        let fm = FileManager.default
        var lastError: Error?
        for folder in applicationsFolders {
            let destination = folder.appendingPathComponent(source.lastPathComponent)
            do {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                if fm.fileExists(atPath: destination.path) {
                    // 已有旧版本：先结束它，再移到废纸篓
                    for app in NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
                    where app.bundleURL?.resolvingSymlinksInPath() == destination.resolvingSymlinksInPath() {
                        app.terminate()
                    }
                    try fm.trashItem(at: destination, resultingItemURL: nil)
                }
                try fm.copyItem(at: source, to: destination)
                log.notice("已复制到：\(destination.path, privacy: .public)")
                return destination
            } catch {
                lastError = error
                log.error("复制到 \(folder.path, privacy: .public) 失败：\(error.localizedDescription, privacy: .public)")
            }
        }
        throw lastError ?? CocoaError(.fileWriteUnknown)
    }

    private static func relaunch(at destination: URL, original: URL, onDiskImage: Bool) {
        var args: [String] = []
        if onDiskImage {
            if let volume = try? original.resourceValues(forKeys: [.volumeURLKey]).volume {
                args += [ejectArg, volume.path]
            }
        } else {
            args += [trashArg, original.path]
        }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.arguments = args
        NSWorkspace.shared.openApplication(at: destination, configuration: config) { _, error in
            if let error { log.error("重新打开失败：\(error.localizedDescription, privacy: .public)") }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
