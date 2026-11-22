#!/bin/bash
# ClickMenu 发布脚本：打包 → Developer ID 签名 → 公证 → 生成 DMG
#
# 用法：
#   scripts/release.sh          正式发布（Developer ID 签名 + Apple 公证）
#   scripts/release.sh --dev    本地试跑（Apple Development 签名，跳过公证；产物不能分发给别人）
#
# 正式发布前需要：
#   1. 钥匙串里有「Developer ID Application」证书（Xcode → Settings → Accounts → Manage Certificates）
#   2. 已保存公证凭证（只需一次）：
#        xcrun notarytool store-credentials clickmenu-notary
#
# 可用环境变量：
#   NOTARY_PROFILE  公证凭证名，默认 clickmenu-notary
#   TEAM_ID         签名团队，默认取 project.yml 中的 DEVELOPMENT_TEAM
#
# 自动更新：脚本最后会用 Sparkle 的 EdDSA 私钥（存在钥匙串里）给 DMG 签名，并更新仓库根目录的 appcast.xml。
# 更新说明写在 ReleaseNotes/<版本号>.md（正式发布时必须有）。
# 发布顺序：先把 DMG 上传到 GitHub Release，再提交并推送 appcast.xml（否则老版本会下载到 404）。
set -euo pipefail

MODE="release"
[[ "${1:-}" == "--dev" ]] && MODE="dev"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

APP_NAME="ClickMenu"
NOTARY_PROFILE="${NOTARY_PROFILE:-clickmenu-notary}"
TEAM_ID="${TEAM_ID:-$(awk '/DEVELOPMENT_TEAM:/{print $2; exit}' project.yml)}"
VERSION="$(awk -F'"' '/MARKETING_VERSION:/{print $2; exit}' project.yml)"
BUILD="$(awk -F'"' '/CURRENT_PROJECT_VERSION:/{print $2; exit}' project.yml)"
MIN_OS="$(awk -F'"' '/MACOSX_DEPLOYMENT_TARGET:/{print $2; exit}' project.yml)"
NOTES="$ROOT/ReleaseNotes/$VERSION.md"
APPCAST="$ROOT/../appcast.xml"
SPARKLE_ACCOUNT="io.github.stackzeng.clickmenu"
REPO_URL="https://github.com/stackzeng/click-menu"
OUT="$ROOT/build/release"
ARCHIVE="$OUT/$APP_NAME.xcarchive"
APP="$OUT/$APP_NAME.app"
DMG="$OUT/$APP_NAME-$VERSION.dmg"

if [[ "$MODE" == "release" ]]; then
  IDENTITY="Developer ID Application"
else
  IDENTITY="Apple Development"
fi

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m错误：%s\033[0m\n' "$*" >&2; exit 1; }

# ---------- 检查 ----------
step "检查环境（模式：$MODE，版本：$VERSION，团队：$TEAM_ID）"
command -v xcodegen >/dev/null || fail "未安装 xcodegen：brew install xcodegen"
# 按证书里的 OU（团队 ID）匹配；Apple Development 证书名括号里的不是团队 ID
find_identity() {
  local hash
  for hash in $(security find-identity -v -p codesigning | awk -v id="\"$IDENTITY: " 'index($0, id) {print $2}'); do
    if security find-certificate -a -Z -p 2>/dev/null \
        | awk -v h="$hash" '/^SHA-1 hash:/{p=($3==h)} p' \
        | openssl x509 -noout -subject 2>/dev/null | grep -q "OU *= *$TEAM_ID"; then
      echo "$hash"; return
    fi
  done
}
IDENTITY_HASH="$(find_identity)"
[[ -n "$IDENTITY_HASH" ]] || fail "钥匙串中没有团队 $TEAM_ID 的「$IDENTITY」证书"
if [[ "$MODE" == "release" ]]; then
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "找不到公证凭证 $NOTARY_PROFILE，请先运行：xcrun notarytool store-credentials $NOTARY_PROFILE"
fi

if [[ "$MODE" == "release" ]]; then
  [[ -f "$NOTES" ]] || fail "缺少更新说明 $NOTES"
  grep -q "<sparkle:version>$BUILD</sparkle:version>" "$APPCAST" 2>/dev/null \
    && fail "appcast.xml 中已有 build $BUILD，请先递增 project.yml 的 CURRENT_PROJECT_VERSION"
fi

rm -rf "$OUT"
mkdir -p "$OUT"

# ---------- 构建 ----------
step "生成工程并运行单元测试"
xcodegen generate --quiet
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -derivedDataPath build/derived test -quiet

step "Release 打包并签名（$IDENTITY）"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -archivePath "$ARCHIVE" -derivedDataPath build/derived archive -quiet \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

ditto "$ARCHIVE/Products/Applications/$APP_NAME.app" "$APP"

step "重新签名 Sparkle 组件"
# 宿主 App 未开沙盒，用不到 Sparkle 的 XPC 服务（官方文档允许删除）；
# 其余辅助程序要用我们的证书 + Hardened Runtime + 时间戳签名，才能通过公证
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
rm -rf "$SPARKLE/Versions/B/XPCServices"
codesign -f -s "$IDENTITY_HASH" -o runtime --timestamp "$SPARKLE/Versions/B/Autoupdate"
codesign -f -s "$IDENTITY_HASH" -o runtime --timestamp "$SPARKLE/Versions/B/Updater.app"
codesign -f -s "$IDENTITY_HASH" -o runtime --timestamp "$SPARKLE"
codesign -d --entitlements - --xml "$APP" > "$OUT/app.entitlements" 2>/dev/null
codesign -f -s "$IDENTITY_HASH" -o runtime --timestamp --entitlements "$OUT/app.entitlements" "$APP"

step "校验签名"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "^Authority=|^TeamIdentifier=|flags=" | head -4
codesign -dvv "$APP/Contents/PlugIns/${APP_NAME}FinderExtension.appex" 2>&1 | grep -E "^Authority=" | head -1

notarize() {  # $1 = 要提交的文件
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --timeout 30m \
    | tee "$OUT/notary.log"
  grep -q "status: Accepted" "$OUT/notary.log" || {
    id=$(awk '/^  id:/{print $2; exit}' "$OUT/notary.log")
    [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE"
    fail "公证未通过，详见上方日志"
  }
}

if [[ "$MODE" == "release" ]]; then
  step "公证 App"
  ditto -c -k --keepParent "$APP" "$OUT/$APP_NAME.zip"
  notarize "$OUT/$APP_NAME.zip"
  xcrun stapler staple "$APP"
  rm "$OUT/$APP_NAME.zip"
fi

# ---------- DMG ----------
step "制作 DMG（带安装引导布局）"
# 窗口背景、图标位置、卷图标见 scripts/dmg/；用 dmgbuild 直接写布局，不依赖 Finder 脚本
VENV="$ROOT/build/tools/venv"
if [[ ! -x "$VENV/bin/dmgbuild" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q --disable-pip-version-check "dmgbuild==1.6.2"
fi
"$VENV/bin/dmgbuild" -s scripts/dmg/settings.py \
  -D app="$APP" -D background="$ROOT/scripts/dmg/background.tiff" -D volicon="$ROOT/scripts/dmg/VolumeIcon.icns" \
  "$APP_NAME $VERSION" "$DMG" >/dev/null
codesign --sign "$IDENTITY_HASH" --timestamp "$DMG"

if [[ "$MODE" == "release" ]]; then
  step "公证 DMG"
  notarize "$DMG"
  xcrun stapler staple "$DMG"

  step "Gatekeeper 检查"
  spctl -a -vv -t exec "$APP"
  spctl -a -vv -t open --context context:primary-signature "$DMG"
fi

shasum -a 256 "$DMG" | tee "$DMG.sha256"

# ---------- 自动更新 appcast ----------
step "生成 Sparkle 更新签名与 appcast"
SIGN_UPDATE="$(find build/derived/SourcePackages/artifacts -path '*Sparkle/bin/sign_update' -type f | head -1)"
[[ -x "$SIGN_UPDATE" ]] || fail "找不到 Sparkle 的 sign_update 工具"
ED_ATTRS="$("$SIGN_UPDATE" --account "$SPARKLE_ACCOUNT" "$DMG")" || fail "Sparkle 签名失败（钥匙串里没有 EdDSA 私钥？）"
echo "$ED_ATTRS"
if [[ "$MODE" == "release" ]]; then
  python3 scripts/update_appcast.py --appcast "$APPCAST" --version "$VERSION" --build "$BUILD" --min-os "$MIN_OS" \
    --url "$REPO_URL/releases/download/v$VERSION/$(basename "$DMG")" --sparkle-attrs "$ED_ATTRS" --notes "$NOTES"
  echo "已更新 $APPCAST —— 上传 DMG 到 GitHub Release 之后再提交推送它"
else
  # 本地测试用 appcast，指向本地 DMG
  [[ -f "$NOTES" ]] || NOTES=/dev/null
  python3 scripts/update_appcast.py --appcast "$OUT/appcast-dev.xml" --version "$VERSION" --build "$BUILD" --min-os "$MIN_OS" \
    --url "file://$DMG" --sparkle-attrs "$ED_ATTRS" --notes "$NOTES"
fi

step "完成：$DMG"
[[ "$MODE" == "dev" ]] && echo "（--dev 产物未公证，只能本机使用，不能发布）"
exit 0
