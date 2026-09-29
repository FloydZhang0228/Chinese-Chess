#!/usr/bin/env bash
# 中国象棋构建打包脚本, Linux / macOS / Windows(Git Bash) 通用。
#
# 用法: scripts/build.sh <目标> [版本号]
#   目标: linux | windows | macos | android | ios | web | all
#   all : 构建"当前系统能构建"的全部目标
# 产物: build/<平台>/Chinese-Chess-<版本>-*
#
# 各目标对构建机的要求(Flutter 不支持跨系统编译桌面端):
#   linux            Linux
#   windows          Windows
#   macos, ios       macOS (需要 Xcode)
#   android, web     Linux / macOS / Windows 均可
set -euo pipefail

SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0") # 先记绝对路径, 之后 cd 会让相对的 $0 失效
cd "$(dirname "$SELF")/.."
ROOT=$PWD
APP_NAME="中国象棋"
ORG="io.github.chinesechess"
VER=${2:-$(grep -m1 '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')}

case "$(uname -s)" in
  Linux*) HOST=linux ;;
  Darwin*) HOST=macos ;;
  MINGW* | MSYS* | CYGWIN*) HOST=windows ;;
  *) echo "不支持的系统: $(uname -s)" >&2; exit 1 ;;
esac

usage() { sed -n '2,15p' "$SELF" | sed 's/^# \{0,1\}//'; exit 1; }
command -v flutter >/dev/null || { echo "未找到 flutter, 请先安装并加入 PATH" >&2; exit 1; }

need_host() { # need_host <系统>: 当前系统不符则报错
  [ "$HOST" = "$1" ] || { echo "错误: 该目标只能在 $1 上构建, 当前是 $HOST" >&2; return 1; }
}

# 用 sed -i 的跨平台写法(macOS 的 sed 需要 -i '')
sedi() { if [ "$HOST" = macos ]; then sed -i '' "$@"; else sed -i "$@"; fi; }

# Linux: 无边框窗口(标题栏由 Flutter 自绘), 显示时机交给 window_manager 控制。
patch_linux_runner() {
  python3 - <<'PY'
import re
p = "linux/runner/my_application.cc"
s = open(p, encoding="utf-8").read()
s = s.replace("  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));\n",
              "  (void)self;\n  (void)view; // 显示时机由 window_manager 控制\n")
i = s.index("  gboolean use_header_bar = TRUE;")
j = s.index("  gtk_window_set_default_size")
s = s[:i] + '  gtk_window_set_title(window, "中国象棋");\n  gtk_window_set_decorated(window, FALSE);\n\n' + s[j:]
open(p, "w", encoding="utf-8").write(s)
PY
}

# 平台壳工程不入库: 缺失时现场生成, 再套用应用名与图标。已存在则跳过, 不覆盖手工修改。
ensure_runner() {
  local p=$1
  [ -d "$p" ] && return 0
  echo "==> 生成 $p 壳工程"
  flutter create --platforms="$p" --project-name chinese_chess --org "$ORG" . >/dev/null
  rm -f test/widget_test.dart # flutter create 自带的模板测试, 引用不存在的 MyApp
  case $p in
    android) sedi "s/android:label=\"chinese_chess\"/android:label=\"$APP_NAME\"/" android/app/src/main/AndroidManifest.xml ;;
    linux)   patch_linux_runner ;;
    windows) sedi "s/L\"chinese_chess\"/L\"$APP_NAME\"/" windows/runner/main.cpp ;;
    web)     sedi "s#<title>chinese_chess</title>#<title>$APP_NAME</title>#" web/index.html ;;
  esac
  apply_icon "$p"
}

# 只对刚生成的这一个平台套用图标: flutter_launcher_icons 若配置了尚不存在的平台会直接崩溃,
# 所以每个平台单独写一份临时配置。
apply_icon() {
  local p=$1 cfg=$ROOT/build/_icons_$1.yaml
  mkdir -p build
  case $p in
    android) printf 'flutter_launcher_icons:\n  image_path: packaging/icon.png\n  android: true\n' >"$cfg" ;;
    ios)     printf 'flutter_launcher_icons:\n  image_path: packaging/icon.png\n  ios: true\n  remove_alpha_ios: true\n' >"$cfg" ;;
    web)     printf 'flutter_launcher_icons:\n  image_path: packaging/icon.png\n  web:\n    generate: true\n' >"$cfg" ;;
    windows) printf 'flutter_launcher_icons:\n  image_path: packaging/icon.png\n  windows:\n    generate: true\n    icon_size: 256\n' >"$cfg" ;;
    macos)   printf 'flutter_launcher_icons:\n  image_path: packaging/icon.png\n  macos:\n    generate: true\n' >"$cfg" ;;
    *) return 0 ;; # linux 图标由 AppImage 打包步骤提供
  esac
  dart run flutter_launcher_icons -f "$cfg" >/dev/null 2>&1 || echo "警告: $p 图标生成失败, 沿用默认图标" >&2
  rm -f "$cfg"
}

# 产物目录 build/<平台>/ 与 Flutter 中间产物同处, 只清理旧的 Chinese-Chess-*, 不能整目录删除
out() { mkdir -p "$ROOT/build/$1"; rm -rf "$ROOT/build/$1"/Chinese-Chess-*; echo "$ROOT/build/$1"; }

build_linux() {
  need_host linux
  ensure_runner linux
  flutter build linux --release
  local o app=$ROOT/build/_appdir tool=${XDG_CACHE_HOME:-$HOME/.cache}/gomoku/appimagetool; o=$(out linux)
  rm -rf "$app"; mkdir -p "$app/usr/bin"
  cp -r build/linux/x64/release/bundle/* "$app/usr/bin/"
  cp packaging/linux/chinese_chess.desktop packaging/linux/chinese_chess.svg "$app/"
  ln -sf usr/bin/chinese_chess "$app/AppRun"
  mkdir -p "$(dirname "$tool")"
  [ -x "$tool" ] || { curl -fsSL -o "$tool" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage; chmod +x "$tool"; }
  ARCH=x86_64 "$tool" --appimage-extract-and-run "$app" "$o/Chinese-Chess-$VER-linux-x86_64.AppImage"
  rm -rf "$app"
}

build_windows() {
  need_host windows
  ensure_runner windows
  flutter build windows --release
  local o rel=build/windows/x64/runner/Release; o=$(out windows)
  # 内置 VC++ 运行库, 用户无需另装
  for d in msvcp140.dll vcruntime140.dll vcruntime140_1.dll; do
    cp "/c/Windows/System32/$d" "$rel/" 2>/dev/null || cp "$SYSTEMROOT/System32/$d" "$rel/"
  done
  if command -v 7z >/dev/null; then
    7z a -tzip "$o/Chinese-Chess-$VER-windows-x64.zip" "./$rel/*" >/dev/null
  else
    powershell -NoProfile -Command "Compress-Archive -Path '$rel/*' -DestinationPath '$o/Chinese-Chess-$VER-windows-x64.zip' -Force"
  fi
}

build_macos() {
  need_host macos
  ensure_runner macos
  flutter build macos --release
  local o stage=$ROOT/build/_stage; o=$(out macos)
  rm -rf "$stage"; mkdir -p "$stage"
  cp -R build/macos/Build/Products/Release/chinese_chess.app "$stage/"
  ln -s /Applications "$stage/Applications"
  hdiutil create -volname Chinese-Chess -srcfolder "$stage" -ov -format UDZO "$o/Chinese-Chess-$VER-macos-universal.dmg" >/dev/null
  rm -rf "$stage"
}

build_android() {
  ensure_runner android
  flutter build apk --release
  cp build/app/outputs/flutter-apk/app-release.apk "$(out android)/Chinese-Chess-$VER-android.apk"
}

build_ios() {
  need_host macos
  ensure_runner ios
  flutter build ios --release --no-codesign
  local o pay=$ROOT/build/_payload; o=$(out ios)
  rm -rf "$pay"; mkdir -p "$pay/Payload"
  cp -R build/ios/iphoneos/Runner.app "$pay/Payload/"
  (cd "$pay" && zip -qr "$o/Chinese-Chess-$VER-ios-unsigned.ipa" Payload)
  rm -rf "$pay"
}

build_web() {
  ensure_runner web
  flutter build web --release
  # Flutter 的 web 输出目录本身就是 build/web, 站点文件原地保留, 再打一个 zip
  rm -f build/web/Chinese-Chess-*
  local tmp; tmp=$(mktemp -d)
  (cd build/web && zip -qr "$tmp/Chinese-Chess-$VER-web.zip" . -x 'Chinese-Chess-*')
  mv "$tmp/Chinese-Chess-$VER-web.zip" build/web/
  rmdir "$tmp"
}

TARGET=${1:-}
[ -n "$TARGET" ] || usage

# 构建结束会清掉 build/ 下的中间目录, 而 .dart_tool/flutter_build 缓存记着"它们已生成"而跳过重建,
# 残留一半会导致下次构建报 "找不到 native_assets"。所以清理时必须连同这份缓存成套清掉。
clean_intermediates() {
  local d
  rm -rf .dart_tool/flutter_build
  for d in flutter_assets native_assets lib test_cache unit_test_assets _appdir _stage _payload; do
    rm -rf "build/$d"
  done
  for d in build/*/; do
    [ -d "$d" ] || continue
    [ "$d" = build/web/ ] && continue
    find "$d" -mindepth 1 -maxdepth 1 ! -name 'Chinese-Chess-*' -exec rm -rf {} +
  done
}
clean_intermediates
flutter pub get >/dev/null

case $TARGET in
  linux | windows | macos | android | ios | web) "build_$TARGET" ;;
  all)
    case $HOST in
      linux) list="linux android web"; skip="windows macos ios" ;;
      macos) list="macos ios android web"; skip="linux windows" ;;
      windows) list="windows android web"; skip="linux macos ios" ;;
    esac
    failed=""
    for p in $list; do
      echo "==> 构建 $p"
      # 子 shell 内 set -e 仍生效; 单个平台失败不影响其余平台
      if ! ("build_$p"); then failed="$failed $p"; fi
    done
    [ -z "$failed" ] || echo "失败的平台:$failed" >&2
    echo "已跳过(需在其他系统构建): $skip"
    ALL_FAILED=$failed
    ;;
  *) usage ;;
esac

# 收尾: Flutter 在 build/ 下留的中间目录名字固定, 无法改路径, 只能构建完清掉, 只留各平台目录里的 Chinese-Chess-* 产物。
cleanup() { clean_intermediates; }
[ "${KEEP_BUILD:-}" = 1 ] || cleanup

echo "完成, 产物:"
find build -mindepth 2 -maxdepth 2 -type f -name 'Chinese-Chess-*' -exec ls -lh {} \; | awk '{print "  "$NF"  "$5}'
[ -z "${ALL_FAILED:-}" ] || exit 1
