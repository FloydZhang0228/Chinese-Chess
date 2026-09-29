# 中国象棋 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Flutter 单代码库中国象棋,六端,黑透玻璃 UI,Alpha-Beta 人机 + 双人,build.sh + GitHub Actions。

**Architecture:** `lib/core` 纯逻辑(规则、AI),`lib/ui` 复制五子棋主题/标题栏并新写棋盘,`lib/main.dart` 页面。构建脚本与 CI 由五子棋版改名而来。

**Tech Stack:** Flutter 3.47 / Dart 3.13, window_manager ^0.5.2, flutter_launcher_icons。

**Spec:** `docs/superpowers/specs/2026-09-29-chinese-chess-design.md`

## Global Constraints

- 应用名 `中国象棋`;包名 `chinese_chess`;ORG `io.github.chinesechess`;产物前缀 `Chinese-Chess-`。
- 产物仅在 `build/<平台>/`;build 下无中间目录。
- 平台壳工程不入库(`.gitignore`),由 `build.sh` 的 `ensure_runner` 生成。
- 分支 `master`;README 编号层级 一. → 1. → <1>. → ①。
- 回复与文档使用简体中文。

## Review Focus

- 将帅同列且中间无子(照面)→ 该着非法,`legalMoves` 不含(Task 1 测试)。
- 被将军时只能应将;无合法着法即输,`winner` 正确(Task 1 测试)。
- 悔棋连续多次后局面与初始完全一致,含被吃子还原(Task 1 测试)。
- AI 在只有一步应将时必须选它;有一步杀时必须选它(Task 2 测试)。
- 执黑翻转后点击坐标映射正确(Task 3 测试)。

---

### Task 1: 规则 `lib/core/xiangqi.dart`

**Files:** Create `lib/core/xiangqi.dart`, `test/core/xiangqi_test.dart`

**Interfaces:**
- Produces: `const cols=9, rows=10`; 棋子编码 `int`,0 空,红 1..7 / 黑 8..14,类型 `1 车 2 马 3 象 4 士 5 将 6 炮 7 兵`,`side(p)`,`kind(p)`;`class Move{int from,to; ==,hashCode}`;`class Xiangqi{ List<int> cells; int turn(1红/2黑); List<Move> history; int winner; bool get inCheck; bool get over; List<Move> legalMoves({int? from}); bool play(Move); void undo(); Xiangqi copy(); }`

- [ ] 写测试: 开局红方合法着法 44 个;蹩马腿;塞象眼;炮隔子吃;将帅照面非法;送将非法;绝杀局面 `over` 且 `winner`;多次 undo 还原
- [ ] 跑测试确认失败
- [ ] 实现规则
- [ ] 跑测试通过,commit

### Task 2: AI `lib/core/ai.dart`

**Files:** Create `lib/core/ai.dart`, `test/core/ai_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `Xiangqi`、`Move`
- Produces: `enum Level{easy,normal,hard}`; `class Ai{ Ai(Level,[Random?]); Move? move(Xiangqi) }`(不修改入参);`Future<Move?> aiMove(Xiangqi g, Level l)`(`compute` 后台执行)

- [ ] 测试: 一步杀必选;唯一应将着必选;困难对简单 2 局(交换先后)不输;困难单步耗时上限
- [ ] 实现 alpha-beta + MVV-LVA 排序 + 静态搜索 + 子力/位置评估
- [ ] 通过,commit

### Task 3: UI 与页面

**Files:** Copy `lib/ui/theme.dart`, `lib/ui/title_bar.dart`(改标题文字);Create `lib/ui/board_view.dart`, `lib/main.dart`, `test/ui/app_test.dart`, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

**Interfaces:**
- Consumes: Task 1/2
- Produces: `BoardView(game, flipped, selected, targets, onTap(int x,int y), enabled)`;`GeoXq` 坐标(格→像素、像素→格,支持翻转);`HomePage` 状态机

- [ ] 测试: 人机点选-走子-电脑应手;悔棋撤两步;执黑先手电脑先走;模式切换;翻转点击映射
- [ ] 实现棋盘绘制(河界、九宫、炮/兵标记、玻璃棋子、合法点、最后一步、将军环)与页面/面板
- [ ] `flutter analyze` + `flutter test` 通过,commit

### Task 4: 构建脚本与 CI

**Files:** Create `scripts/build.sh`, `scripts/build.ps1`, `.github/workflows/build.yml`, `packaging/icon.png`, `packaging/linux/chinese_chess.desktop`, `chinese_chess.svg`

- [ ] 由五子棋版改名(APP_NAME、ORG、project-name、产物前缀、二进制名、desktop/svg)
- [ ] `scripts/build.sh linux` 与 `web` 本地跑通,确认 build/ 下只有平台目录和产物
- [ ] commit

### Task 5: README 与收尾

**Files:** Create `README.md`

- [ ] 写 README(一. 目录结构 … 五. GitHub Actions,层级规范)
- [ ] 全量 analyze/test,commit
