// 生成 DMG 安装窗口背景：640×400 pt（输出 1x 和 2x 两张 PNG）
// 用法：swift make_background.swift <输出目录>
// 布局与 scripts/dmg/settings.py 中的图标坐标保持一致：
//   ClickMenu.app 图标中心 (160, 205)，「应用程序」图标中心 (480, 205)，图标 128pt
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let W: CGFloat = 640, H: CGFloat = 400

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)   // 逻辑尺寸固定为 640×400，2x 图像素翻倍
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // 坐标系翻转为左上角原点，和 Finder 图标坐标一致
    ctx.translateBy(x: 0, y: H)
    ctx.scaleBy(x: 1, y: -1)

    // 背景：浅色柔和渐变
    let bg = NSGradient(colors: [NSColor(srgbRed: 0.975, green: 0.98, blue: 0.995, alpha: 1),
                                 NSColor(srgbRed: 0.925, green: 0.935, blue: 0.965, alpha: 1)])!
    bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90)

    // 两个图标下方的柔和圆形底座，引导视线
    for cx in [160.0, 480.0] {
        let r: CGFloat = 92
        let halo = NSGradient(colors: [NSColor(srgbRed: 0.24, green: 0.48, blue: 1, alpha: 0.10),
                                       NSColor(srgbRed: 0.24, green: 0.48, blue: 1, alpha: 0.0)])!
        halo.draw(in: NSBezierPath(ovalIn: NSRect(x: cx - r, y: 205 - r, width: r * 2, height: r * 2)), relativeCenterPosition: .zero)
    }

    // 箭头：从左图标指向右图标，虚线 + 实心箭头
    let blue = NSColor(srgbRed: 0.18, green: 0.44, blue: 0.98, alpha: 0.9)
    blue.setStroke()
    blue.setFill()
    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: 252, y: 205))
    shaft.line(to: NSPoint(x: 372, y: 205))
    shaft.lineWidth = 4
    shaft.lineCapStyle = .round
    shaft.setLineDash([2, 10], count: 2, phase: 0)
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 392, y: 205))
    head.line(to: NSPoint(x: 374, y: 194))
    head.curve(to: NSPoint(x: 374, y: 216), controlPoint1: NSPoint(x: 377, y: 201), controlPoint2: NSPoint(x: 377, y: 209))
    head.close()
    head.lineJoinStyle = .round
    head.lineWidth = 3
    head.fill()
    head.stroke()

    // 文字（需要在翻转坐标里正向绘制）
    func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
        ctx.saveGState()
        ctx.translateBy(x: 0, y: y + size)
        ctx.scaleBy(x: 1, y: -1)
        (s as NSString).draw(in: NSRect(x: 0, y: 0, width: W, height: size * 1.6), withAttributes: attrs)
        ctx.restoreGState()
    }
    text("将 ClickMenu 拖到「应用程序」即可安装", size: 19, weight: .semibold,
         color: NSColor(srgbRed: 0.11, green: 0.12, blue: 0.15, alpha: 1), y: 52)
    text("安装后打开 ClickMenu，按引导启用 Finder 扩展", size: 12.5, weight: .regular,
         color: NSColor(srgbRed: 0.42, green: 0.44, blue: 0.5, alpha: 1), y: 340)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for (scale, name) in [(1.0, "background.png"), (2.0, "background@2x.png")] {
    let data = render(scale: scale).representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
    print("wrote", name)
}
