import AppKit
import os

/// 打开终端
@MainActor
enum Launcher {
    nonisolated private static let log = Logger(subsystem: "io.github.stackzeng.clickmenu", category: "Launcher")

    static func openTerminal(at path: String) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            HUDController.shared.show(title: "目录不存在", detail: path, style: .warning)
            return
        }
        let dirURL = URL(fileURLWithPath: path, isDirectory: true)

        let settings = AppSettings.shared
        var bundleID = settings.terminalBundleID
        var appURL = settings.terminal?.url
        if appURL == nil {
            // 选择的终端未安装 → 回退到系统终端（PRD 边界情况）
            let name = settings.terminal?.name ?? bundleID
            bundleID = ExternalApps.terminals[0].bundleID
            appURL = ExternalApps.terminals[0].url
            HUDController.shared.show(title: "未找到 \(name)", detail: "已改用系统终端，可在设置中修改", style: .warning)
        }
        guard let appURL else { return }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        if bundleID == "org.alacritty" {
            // Alacritty 不支持以「打开文件夹」的方式启动，用参数指定工作目录
            config.arguments = ["--working-directory", path]
            config.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                if let error { log.error("打开 Alacritty 失败：\(error.localizedDescription, privacy: .public)") }
            }
        } else {
            NSWorkspace.shared.open([dirURL], withApplicationAt: appURL, configuration: config) { _, error in
                if let error { log.error("打开终端失败：\(error.localizedDescription, privacy: .public)") }
            }
        }
    }

}
