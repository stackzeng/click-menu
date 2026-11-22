#!/usr/bin/env python3
"""把一个新版本写入 Sparkle appcast.xml（最新版本放在最前面）。

由 scripts/release.sh 调用。更新说明是简单的 Markdown：
  # / ## 标题、- 列表、普通段落，以及 **粗体** 和 `代码`。
"""
import argparse
import html
import os
import re
from email.utils import formatdate

HEADER = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>ClickMenu</title>
    <link>https://github.com/stackzeng/click-menu</link>
    <description>ClickMenu 版本更新</description>
    <language>zh-CN</language>
"""
FOOTER = """  </channel>
</rss>
"""


def inline(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    return re.sub(r"`(.+?)`", r"<code>\1</code>", text)


def markdown_to_html(md: str) -> str:
    out, in_list = [], False
    for raw in md.splitlines():
        line = raw.strip()
        if line.startswith(("- ", "* ")):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line[2:])}</li>")
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        if not line:
            continue
        m = re.match(r"(#{1,3})\s+(.*)", line)
        if m:
            level = len(m.group(1)) + 1  # # → h2
            out.append(f"<h{level}>{inline(m.group(2))}</h{level}>")
        else:
            out.append(f"<p>{inline(line)}</p>")
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--appcast", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--build", required=True)
    ap.add_argument("--min-os", required=True)
    ap.add_argument("--url", required=True)
    ap.add_argument("--sparkle-attrs", required=True, help='sign_update 的输出：sparkle:edSignature="…" length="…"')
    ap.add_argument("--notes", required=True)
    a = ap.parse_args()

    if not re.fullmatch(r'\s*sparkle:edSignature="[^"]+"\s+length="\d+"\s*', a.sparkle_attrs):
        raise SystemExit(f"无法识别 sign_update 输出：{a.sparkle_attrs!r}")

    notes = open(a.notes, encoding="utf-8").read() if os.path.exists(a.notes) else ""
    body = markdown_to_html(notes) or f"<p>ClickMenu {html.escape(a.version)}</p>"

    item = f"""    <item>
      <title>ClickMenu {html.escape(a.version)}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{html.escape(a.build)}</sparkle:version>
      <sparkle:shortVersionString>{html.escape(a.version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{html.escape(a.min_os)}</sparkle:minimumSystemVersion>
      <description><![CDATA[
{body}
      ]]></description>
      <enclosure url="{html.escape(a.url)}" type="application/octet-stream" {a.sparkle_attrs.strip()}/>
    </item>
"""

    existing = ""
    if os.path.exists(a.appcast):
        content = open(a.appcast, encoding="utf-8").read()
        existing = "".join(re.findall(r"    <item>.*?</item>\n", content, re.S))
        # 同一 build 重新发布时替换旧条目
        existing = re.sub(
            r"    <item>(?:(?!</item>).)*?<sparkle:version>" + re.escape(a.build) + r"</sparkle:version>.*?</item>\n",
            "", existing, flags=re.S)

    with open(a.appcast, "w", encoding="utf-8") as f:
        f.write(HEADER + item + existing + FOOTER)
    print(f"appcast 已写入：{a.appcast}（{a.version} / build {a.build}）")


if __name__ == "__main__":
    main()
