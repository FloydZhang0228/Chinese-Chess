# 中国象棋 Chinese Chess

Flutter 跨平台中国象棋,支持 Windows / Linux / macOS / Android / iOS / Web。含人机对弈(Alpha-Beta 搜索,三档难度,可选执红/执黑)与双人对弈,黑透毛玻璃界面。

## 一. 目录结构

```
lib/core/       规则(xiangqi.dart)与 AI(ai.dart),纯逻辑,不依赖 UI
lib/ui/         主题、毛玻璃组件、棋盘绘制、自绘标题栏
lib/main.dart   入口与页面
test/           core/ 规则与 AI 测试, ui/ 界面测试
scripts/        build.sh(Linux/macOS/Git Bash), build.ps1(Windows PowerShell)
packaging/      应用图标 icon.png, Linux AppImage 资源
build/<平台>/   构建产物
docs/           设计文档与实现计划
```

`android/ ios/ linux/ macos/ windows/ web/` 是 Flutter 平台壳工程,**不入库**,由构建脚本按需自动生成(应用名、图标、Linux 无边框窗口补丁也由脚本套用)。

桌面端(Windows / Linux / macOS)使用 `lib/ui/title_bar.dart` 自绘的半透明矮标题栏,基于 `window_manager`;macOS 保留系统红绿灯按钮。

### 1. 规则与 AI

<1>. 规则:七种棋子的走法,含蹩马腿、塞象眼、炮隔子吃、将帅不能照面、不能送将;无合法着法者判负。开局 1/2/3 层着法总数(44 / 1920 / 79666)与公认值一致,由 perft 测试保证。

<2>. AI:负极大值 Alpha-Beta,吃子按 MVV-LVA 优先排序,叶子做只看吃子的静态搜索;评估为子力 + 兵过河加成 + 位置分。简单 / 普通 / 困难的搜索深度为 2 / 3 / 4。搜索在后台 isolate 中运行,界面不卡。

<3>. 暂未实现:长将 / 长捉判和、无吃子步数和棋、置换表、开局库。

## 二. 环境准备

所有平台都需要 [Flutter SDK](https://docs.flutter.dev/get-started/install)(stable),并确保 `flutter` 在 PATH 中。

| 目标 | 构建机 | 额外依赖 |
|---|---|---|
| Linux | Linux | `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev curl` |
| Windows | Windows | Visual Studio(勾选"使用 C++ 的桌面开发")、[Git for Windows](https://git-scm.com/download/win)(提供 bash) |
| macOS / iOS | macOS | Xcode |
| Android | Linux / macOS / Windows | JDK 17、Android SDK(`flutter doctor --android-licenses`) |
| Web | Linux / macOS / Windows | 无 |

Flutter 不支持跨系统编译桌面端,所以想产出全部平台,需要 Linux + Windows + macOS 三台机器,或使用下文的 GitHub Actions。

## 三. 开发与测试

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d linux        # 或 windows / macos / chrome
```

## 四. 通过脚本编译打包

三个系统使用同一个脚本 `scripts/build.sh`:

```bash
scripts/build.sh <目标> [版本号]
```

### 1. 参数说明

<1>. `目标`:`linux` `windows` `macos` `android` `ios` `web` `all`

<2>. `all`:构建当前系统能构建的全部目标,并列出跳过的目标;某个平台失败不影响其余平台,最终以非零状态退出

<3>. `版本号`:可选,默认取 `pubspec.yaml` 的 `version`

### 2. 各系统用法

<1>. Linux

```bash
scripts/build.sh linux          # 只有 Linux
scripts/build.sh all            # Linux + Android + Web
```

<2>. macOS

```bash
scripts/build.sh macos          # dmg
scripts/build.sh ios            # 未签名 ipa
scripts/build.sh all            # macOS + iOS + Android + Web
```

<3>. Windows,有两种方式:

① 在 **Git Bash** 中:

```bash
scripts/build.sh windows
scripts/build.sh all            # Windows + Android + Web
```

② 在 **PowerShell** 中(会转调 Git Bash 里的脚本):

```powershell
scripts\build.ps1 windows
```

### 3. 产物

| 目标 | 产物 | 说明 |
|---|---|---|
| linux | `build/linux/ChineseChess-<版本>-linux-x86_64.AppImage` | 单文件,`chmod +x` 后直接运行 |
| windows | `build/windows/ChineseChess-<版本>-windows-x64.zip` | 解压运行 `chinese_chess.exe`,已内置 VC++ 运行库 |
| macos | `build/macos/ChineseChess-<版本>-macos-universal.dmg` | 拖入应用程序;未签名,首次需右键"打开" |
| android | `build/android/ChineseChess-<版本>-android.apk` | 直接安装,需允许未知来源 |
| ios | `build/ios/ChineseChess-<版本>-ios-unsigned.ipa` | 未签名,用 AltStore / Sideloadly 重签后安装 |
| web | `build/web/ChineseChess-<版本>-web.zip` | 解压后放到任意 HTTP 服务器;`build/web/` 内也有可直接部署的站点文件 |

### 4. 常见问题

<1>. 提示"只能在 xxx 上构建":该目标不能跨系统编译,换对应系统,或用 CI。

<2>. 首次构建会自动生成壳工程并套用图标,稍慢;之后复用已生成的目录。想重置某平台,删除对应目录(如 `rm -rf android`)再构建。

<3>. `build/` 目录的内容:

① 只保留各平台目录和其中的 `ChineseChess-*` 产物(web 目录额外保留可直接部署的站点文件)。

② 脚本构建前后会自动清掉 Flutter 的中间目录;想保留它们排查问题,设置环境变量 `KEEP_BUILD=1`。

③ Linux 打包需要的 `appimagetool` 缓存在 `~/.cache/gomoku/`,不放在 `build/` 里。

<4>. 不要直接运行 `flutter build` 后又手动删 `build/` 下的目录,会让 `.dart_tool/flutter_build` 缓存与实际不一致而报错(如找不到 `native_assets`)。出现时执行 `rm -rf .dart_tool/flutter_build build`,或直接用 `scripts/build.sh`。

## 五. GitHub Actions

工作流文件 `.github/workflows/build.yml`,CI 的构建步骤就是 `scripts/build.sh <平台> <版本号>`,与本地完全一致,本地能跑通,CI 就能跑通。

### 1. 触发方式与产物去向

<1>. 推送 `master` 分支:先 `flutter analyze` + `flutter test`,通过后六个平台并行构建,并更新 **Releases 里的"最新构建"**(标签 `latest`,预发布)。

<2>. 推送 `v*` 标签:创建带版本号的正式 GitHub Release,附上六个平台的产物。

<3>. Pull Request:只跑分析、测试和构建,产物在该次运行的 Artifacts 里,**不发布** Release。

<4>. 也可在 Actions 页面手动触发(`workflow_dispatch`)。

### 2. 发布正式版

```bash
git tag v0.1.0
git push origin v0.1.0
```

### 3. Release 的行为说明

<1>. 六个平台的产物缺任何一个,`release` 任务会失败,不会发布残缺的 Release。

<2>. "最新构建"每次推送 `master` 都会先删除旧的 `latest` Release 和标签,再重新创建,所以里面永远只有最近一次构建的产物,不会越积越多。

<3>. Artifacts 里没有嵌套压缩包:

① Linux / Windows / macOS / Android / iOS:每个平台一个 Artifact,内容就是产物文件本身(AppImage、zip、dmg、apk、ipa)。

② Web:Artifact 名为 `web-site`,内容是站点文件夹(`index.html`、`main.dart.js`、`assets/` 等),可直接部署;Release 里则是同一份站点打成的 `ChineseChess-<版本>-web.zip`。

### 4. 首次推送到 GitHub

<1>. 在 GitHub 新建空仓库,默认分支设为 `master`。

<2>. 本地关联并推送:

```bash
git remote add origin <仓库地址>
git push -u origin master
```

<3>. 仓库 Settings → Actions → General → Workflow permissions 需允许写入(Release 需要 `contents: write`,工作流里已声明)。
