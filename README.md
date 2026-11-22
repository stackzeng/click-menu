<p align="center">
  <img src="ClickMenu/ClickMenu/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="ClickMenu">
</p>

<h1 align="center">ClickMenu</h1>

<p align="center">让 macOS Finder 右键菜单更好用 —— 一键复制文件名、复制完整路径、在此处打开终端。</p>

---

## 功能

在 Finder 里右键，所有功能都收在一个 **「ClickMenu ▸」** 子菜单里，不会把右键菜单撑长。

| 功能 | 说明 |
|---|---|
| 复制文件名 | 复制 `报告 2026.pdf`；多选时每行一个 |
| 复制完整路径 | 复制 `/Users/you/Desktop/报告 2026.pdf`；在空白处右键时复制当前目录路径 |
| 在此处打开终端 | 选中文件夹 → 进入该文件夹；选中文件 → 进入所在目录；空白处 → 当前目录 |

- 支持终端：系统终端、iTerm2、Warp、Ghostty、Alacritty
- 设置中可以调整菜单项顺序、关闭不需要的功能
- 复制成功后右上角显示轻提示，可关闭
- 支持自动更新：有新版本时在菜单栏提示，一键安装
- 只在检查更新时联网，不收集任何数据

## 安装

1. 到 [Releases](https://github.com/stackzeng/click-menu/releases/latest) 下载最新的 `ClickMenu-x.y.z.dmg`
2. 打开 DMG，把 **ClickMenu** 拖到「应用程序」文件夹
3. 打开 ClickMenu，按引导启用 Finder 扩展：
   **系统设置 → 通用 → 登录项与扩展 → 访达**，打开 **ClickMenu** 的开关
4. 在 Finder 里任意文件上右键 →「ClickMenu ▸」

> 系统要求：macOS 13 Ventura 及以上，支持 Apple 芯片和 Intel 芯片。
> App 已经过 Apple 公证，可以直接双击打开。

### 右键菜单里没有出现？

- 确认第 3 步的扩展开关已经打开
- 在终端执行 `killall Finder` 重启 Finder
- 确认 ClickMenu 在「应用程序」文件夹中，而不是直接从 DMG 里运行

## 从源码构建

需要 Xcode 16 及以上和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
brew install xcodegen
cd ClickMenu
xcodegen generate
open ClickMenu.xcodeproj
```

签名团队在 `ClickMenu/project.yml` 的 `DEVELOPMENT_TEAM` 中，换成你自己的团队 ID 后再编译。

发布新版本：修改 `project.yml` 中的 `MARKETING_VERSION`，然后运行 `ClickMenu/scripts/release.sh`（详见脚本开头的说明）。

## 项目结构

```
click-menu/
├── doc/                          产品文档（与代码分离）
│   ├── PRD.md                    产品需求文档
│   └── prototype/index.html      交互原型
└── ClickMenu/                    Xcode 工程
    ├── project.yml               工程定义（XcodeGen）
    ├── ClickMenu/                菜单栏 App：设置、引导、提示、打开终端
    ├── ClickMenuFinderExtension/ Finder 右键菜单扩展
    ├── Shared/                   App 与扩展共用的代码和图标
    ├── ClickMenuTests/           单元测试
    └── scripts/release.sh        打包、签名、公证、生成 DMG
```
