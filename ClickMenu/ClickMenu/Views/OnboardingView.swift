import SwiftUI

@MainActor
final class OnboardingModel: ObservableObject {
    static weak var current: OnboardingModel?
    @Published var step = 0
}

/// 首次引导（原型 ④）：欢迎 → 启用扩展 → 完成
struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var status: ExtensionStatus

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch model.step {
                case 0: welcome
                case 1: enable
                default: done
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Circle().fill(i == model.step ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                footerButtons
            }
        }
        .padding(.horizontal, 34)
        .padding(.top, 40)
        .padding(.bottom, 22)
        .frame(width: 560, height: 440)
        .onChange(of: status.isEnabled) { enabled in
            // 用户在系统设置中打开开关后自动进入下一步
            if enabled && model.step == 1 { model.step = 2 }
        }
    }

    // MARK: 步骤

    private var welcome: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 80, height: 80)
            Text("欢迎使用 ClickMenu").font(.system(size: 21, weight: .bold)).padding(.top, 10)
            Text("让 Finder 右键菜单更好用").foregroundStyle(.secondary).padding(.top, 4)
            HStack(spacing: 10) {
                Feature(icon: "MenuName", title: "复制文件名", text: "一键复制，多选按行分隔")
                Feature(icon: "MenuPath", title: "复制完整路径", text: "直接粘贴到终端或代码里")
                Feature(icon: "MenuTerminal", title: "在此处打开终端", text: "自动进入对应目录")
            }
            .padding(.top, 22)
        }
    }

    private var enable: some View {
        VStack(spacing: 0) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)))
            Text("启用 Finder 扩展").font(.system(size: 21, weight: .bold)).padding(.top, 14)
            Text("macOS 要求你手动打开一次扩展开关").foregroundStyle(.secondary).padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("1. 点击下方「打开系统设置」")
                Text("2. 进入「通用」›「登录项与扩展」")
                Text("3. 在「扩展」中找到「访达」，打开 **ClickMenu** 的开关")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
            .padding(.top, 18)

            HStack(spacing: 8) {
                if status.isEnabled {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("已检测到扩展启用")
                } else {
                    ProgressView().controlSize(.small)
                    Text("正在检测扩展状态…")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 14)
        }
    }

    private var done: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)))
            Text("一切就绪").font(.system(size: 21, weight: .bold)).padding(.top, 14)
            Text("打开 Finder，在任意文件上右键 →「ClickMenu ▸」试试吧").foregroundStyle(.secondary).padding(.top, 4)
            HStack(spacing: 6) {
                Text("ClickMenu 会常驻菜单栏")
                Image("StatusBrand").renderingMode(.template)
                Text("，在那里可以打开设置")
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
            .padding(.top, 18)

            Toggle("登录时自动启动 ClickMenu", isOn: $settings.launchAtLogin)
                .padding(.top, 14)
        }
    }

    @ViewBuilder
    private var footerButtons: some View {
        switch model.step {
        case 0:
            Button("继续") { model.step = 1 }
                .keyboardShortcut(.defaultAction)
        case 1:
            HStack {
                Button("返回") { model.step = 0 }
                if status.isEnabled {
                    Button("继续") { model.step = 2 }.keyboardShortcut(.defaultAction)
                } else {
                    Button("打开系统设置") { status.openSystemSettings() }.keyboardShortcut(.defaultAction)
                }
            }
        default:
            HStack {
                Button("重新查看") { model.step = 0 }
                Button("去试试") { finish() }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
        WindowManager.shared.closeOnboarding()
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        if let desktop { NSWorkspace.shared.open(desktop) }
    }
}

private struct Feature: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(icon).resizable().frame(width: 28, height: 28)
            Text(title).font(.system(size: 13, weight: .semibold)).padding(.top, 2)
            Text(text).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.15)))
    }
}
