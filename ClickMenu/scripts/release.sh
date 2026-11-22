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
step "制作 DMG"
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/应用程序"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" -ov -format UDZO -fs HFS+ "$DMG" -quiet
rm -rf "$STAGE"
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
step "完成：$DMG"
[[ "$MODE" == "dev" ]] && echo "（--dev 产物未公证，只能本机使用，不能发布）"
exit 0
