# dmgbuild 配置：ClickMenu 安装窗口布局
# 由 scripts/release.sh 调用：
#   dmgbuild -s scripts/dmg/settings.py -D app=<ClickMenu.app> -D background=<tiff> -D volicon=<icns> "<卷名>" <输出.dmg>
# 图标坐标与 make_background.swift 中的背景图保持一致（窗口 640×400，图标中心 y=205）。
import os.path

app = defines["app"]  # noqa: F821  dmgbuild 注入
app_name = os.path.basename(app)
apps_link = "应用程序"

# 镜像格式：ULFO（LZFSE 压缩，体积更小，macOS 10.11+ 支持）
format = "ULFO"
filesystem = "HFS+"
size = None

files = [app]
symlinks = {apps_link: "/Applications"}
hide_extensions = [app_name]

# 卷图标（挂载后在桌面和访达侧边栏显示）
icon = defines.get("volicon")  # noqa: F821

# 窗口外观
background = defines.get("background")  # noqa: F821
window_rect = ((200, 140), (640, 428))  # 高度含标题栏约 28pt，内容区正好 640×400
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0

# 图标视图
arrange_by = None
icon_size = 128
text_size = 13
label_pos = "bottom"
icon_locations = {
    app_name: (160, 205),
    apps_link: (480, 205),
}
