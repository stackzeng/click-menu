import AppKit
import SwiftUI

/// 鼠标悬停时显示手型光标；控件被禁用时不显示。
/// 用 push/pop 管理光标栈，并在视图消失、变为禁用时恢复，避免光标卡在手型。
private struct PointingHandCursor: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in update(inside && isEnabled) }
            .onChange(of: isEnabled) { enabled in if !enabled { update(false) } }
            .onDisappear { update(false) }
    }

    private func update(_ showHand: Bool) {
        if showHand, !pushed {
            NSCursor.pointingHand.push()
            pushed = true
        } else if !showHand, pushed {
            NSCursor.pop()
            pushed = false
        }
    }
}

extension View {
    /// 可点击元素统一使用手型光标。注意放在 `.disabled()` 之前，才能感知禁用状态。
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursor())
    }
}

/// 设置里的开关行：左边标题和说明，右边开关。手型光标只出现在开关上（点标题不会切换）。
struct SwitchRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        LabeledContent {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .pointingHandCursor()
        } label: {
            Text(title)
            if let subtitle { Text(subtitle) }
        }
    }
}
