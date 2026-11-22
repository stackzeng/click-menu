import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case menu = "菜单"
    case terminal = "终端"
    case about = "关于"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .menu: return "list.bullet.rectangle"
        case .terminal: return "terminal"
        case .about: return "info.circle"
        }
    }
}

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var tab: SettingsTab = .general
}

/// 设置窗口（原型 ③）：顶部图标标签栏 + 4 个页面
struct SettingsView: View {
    @EnvironmentObject private var nav: SettingsNavigation

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    TabButton(tab: tab, selected: nav.tab == tab) { nav.tab = tab }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.bar)

            Divider()

            Group {
                switch nav.tab {
                case .general: GeneralSettings()
                case .menu: MenuSettings()
                case .terminal: TerminalSettings()
                case .about: AboutSettings()
                }
            }
            .frame(width: 620, height: 420, alignment: .top)
        }
    }
}

private struct TabButton: View {
    let tab: SettingsTab
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol).font(.system(size: 18))
                Text(tab.rawValue).font(.system(size: 11))
            }
            .frame(width: 64, height: 44)
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.primary.opacity(0.07) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

// MARK: - 通用

private struct GeneralSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var status: ExtensionStatus

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HStack(spacing: 10) {
                        StatusBadge(enabled: status.isEnabled)
                        Button("打开系统设置") { status.openSystemSettings() }
                            .pointingHandCursor()
                    }
                } label: {
                    Text("Finder 扩展")
                    Text("在「系统设置 → 通用 → 登录项与扩展 → 访达」中启用")
                }
            }
            Section {
                SwitchRow(title: "登录时自动启动", isOn: $settings.launchAtLogin)
                SwitchRow(title: "在菜单栏显示图标", subtitle: "关闭后可再次打开 ClickMenu 进入设置", isOn: $settings.showMenuBarIcon)
                SwitchRow(title: "复制成功后显示提示", isOn: $settings.showHUD)
            }
        }
        .formStyle(.grouped)
    }
}

struct StatusBadge: View {
    let enabled: Bool
    var body: some View {
        Text(enabled ? "● 已启用" : "● 未启用")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .foregroundStyle(enabled ? Color.green : Color.red)
            .background(Capsule().fill((enabled ? Color.green : Color.red).opacity(0.15)))
    }
}

// MARK: - 菜单

private struct MenuSettings: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("所有功能统一收在右键菜单的「ClickMenu ▸」子菜单里。拖动调整顺序，开关控制是否显示。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            List {
                ForEach(settings.menuOrder) { action in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                        Image(action.iconName).resizable().frame(width: 18, height: 18)
                        Text(action.title)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.isEnabled(action) },
                            set: { settings.setEnabled(action, $0) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .pointingHandCursor()
                    }
                    .padding(.vertical, 4)
                }
                .onMove { settings.menuOrder.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 12)

            Text("「复制文件名」只在选中文件时出现；在空白处右键时，「复制路径」和「打开终端」作用于当前目录。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
        }
    }
}

// MARK: - 终端

private struct TerminalSettings: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("默认终端") {
                AppPicker(apps: ExternalApps.terminals, selection: $settings.terminalBundleID)
                    .padding(.vertical, 4)
            }
            Section {
                Text("选中文件时进入文件所在的目录；选中文件夹时进入该文件夹；空白处右键时进入当前目录。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// 终端选择卡片，显示真实 App 图标，未安装的置灰不可选
private struct AppPicker: View {
    let apps: [ExternalApp]
    @Binding var selection: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
            ForEach(apps) { app in
                let installed = app.isInstalled
                let selected = selection == app.bundleID
                Button {
                    selection = app.bundleID
                } label: {
                    VStack(spacing: 4) {
                        AppIcon(app: app).frame(width: 36, height: 36)
                        Text(app.name).font(.system(size: 12, weight: .semibold))
                        Text(installed ? "已安装" : "未安装").font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.12) : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .disabled(!installed)
                .opacity(installed ? 1 : 0.45)
            }
        }
    }
}

private struct AppIcon: View {
    let app: ExternalApp
    var body: some View {
        if let url = app.url {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
        } else {
            Image(systemName: "app.dashed").resizable().foregroundStyle(.tertiary)
        }
    }
}

// MARK: - 关于

private struct AboutSettings: View {
    @EnvironmentObject private var updater: UpdaterController

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "版本 \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                Text("ClickMenu").font(.title2.bold())
                Text(version).foregroundStyle(.secondary)
            }
            .padding(.top, 18)

            Form {
                Section {
                    LabeledContent {
                        Button("检查更新") { updater.checkForUpdates() }
                            .pointingHandCursor()
                            .disabled(!updater.canCheckForUpdates)
                    } label: {
                        Text("软件更新")
                        Text(updater.statusText)
                    }
                    SwitchRow(title: "自动检查更新", subtitle: "每天在后台检查一次，有新版本时在菜单栏提示",
                              isOn: $updater.automaticallyChecks)
                    SwitchRow(title: "自动下载并安装更新", subtitle: "下载完成后在退出 App 时安装，无需确认",
                              isOn: $updater.automaticallyDownloads)
                        .disabled(!updater.automaticallyChecks)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: 190)

            Link("GitHub 主页", destination: URL(string: "https://github.com/stackzeng/click-menu")!)
                .pointingHandCursor()
                .padding(.top, 4)
            Text("只在检查更新时联网 · 不收集任何数据")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
