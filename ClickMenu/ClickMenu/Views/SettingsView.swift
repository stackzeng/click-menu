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
                    }
                } label: {
                    Text("Finder 扩展")
                    Text("在「系统设置 → 通用 → 登录项与扩展 → 访达」中启用")
                }
            }
            Section {
                Toggle("登录时自动启动", isOn: $settings.launchAtLogin)
                Toggle(isOn: $settings.showMenuBarIcon) {
                    Text("在菜单栏显示图标")
                    Text("关闭后可再次打开 ClickMenu 进入设置")
                }
                Toggle("复制成功后显示提示", isOn: $settings.showHUD)
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
                    }
                    .padding(.vertical, 4)
                }
                .onMove { settings.menuOrder.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 12)

            Text("「复制文件名」「复制文件名（不含扩展名）」只在选中文件时出现；空白处右键时作用于当前目录。")
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
            Section("「用编辑器打开」使用") {
                AppPicker(apps: ExternalApps.editors, selection: $settings.editorBundleID)
                    .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}

/// 应用选择卡片，显示真实 App 图标，未安装的置灰不可选
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
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "版本 \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            Text("ClickMenu").font(.title2.bold())
            Text(version).foregroundStyle(.secondary)
            Text("让 Finder 右键菜单更好用")
                .padding(.top, 6)
            Spacer()
            Text("不联网 · 不收集任何数据")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }
}
