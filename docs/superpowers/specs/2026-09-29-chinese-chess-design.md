# 中国象棋 设计文档

## 目标
Flutter 单代码库中国象棋,覆盖 Linux / Windows / macOS / Android / iOS / Web。界面沿用五子棋(`/home/floyd/WorkSpace/Gomoku`)的黑透玻璃风格。支持人机(三档难度、可选红/黑方)与双人对弈、悔棋、重开。统一构建脚本 + GitHub Actions 六端构建并发布 Release。

## 约束与假设
- "alpha go" 理解为 Alpha-Beta 搜索(不做神经网络 / MCTS)。
- 独立新仓库 `/home/floyd/WorkSpace/ChineseChess`,分支 `master`;平台壳工程不入库,由 `build.sh` 现场生成。
- 产物只在 `build/<平台>/ChineseChess-<版本>-*`,build/ 下不留中间目录。
- 不做:长将/长捉判和、无吃子步数和棋、置换表、开局库、联网对弈。

## 目录
```
lib/core/xiangqi.dart   规则(纯逻辑)
lib/core/ai.dart        Alpha-Beta AI
lib/ui/theme.dart       复制自五子棋(极光背景/Glass)
lib/ui/title_bar.dart   复制自五子棋(改应用名)
lib/ui/board_view.dart  棋盘绘制与点选
lib/main.dart           入口与页面/面板
test/core, test/ui
scripts/build.sh, build.ps1
.github/workflows/build.yml
packaging/icon.png, packaging/linux/*
```

## 规则 `Xiangqi`
- 棋盘 9 列 × 10 行,`cells[y*9+x]`,0 空;红 = 1..7,黑 = 8..14(类型 车马象士将炮兵),红方在下(y 大)。红先。
- `legalMoves()`:生成伪合法着法(车/炮直线,马蹩腿,象塞眼且不过河,士将限九宫,兵过河前只进,过河后可横进),再滤掉走后己方被将军或将帅照面的着法。
- `play(Move)` / `undo()`(存被吃子);`inCheck`、`over`(当前方无合法着法即负)、`winner`。
- 通用 `Move(from, to)`,索引为 `y*9+x`。

## AI
- 负极大值 alpha-beta + 着法排序(吃子按 MVV-LVA 优先)+ 静态搜索(仅吃子,限深)。
- 评估:子力价值(车 900 炮 450 马 400 象/士 200 兵 100+过河加成)+ 位置小表,己方 − 对方。
- 深度:简单 2(前 3 名随机)、普通 3、困难 5。无着法 = 被将死。
- 在后台 isolate 中运行(`compute`),界面不卡,Web 用其回退实现。传入棋盘快照,返回 Move。

## 界面
- 棋盘:黑透磨砂玻璃底板、细银线;河界、九宫斜线、炮/兵定位标记;棋子为玻璃圆盘,红方红字、黑方银字,汉字棋子。
- 交互:点选己方棋子 → 显示合法落点圆点 → 点落点走子;最后一步起止高亮;被将军时将/帅红环脉冲;将死时提示。
- 人机执黑时棋盘翻转(黑在下)。
- 面板:标题、状态卡、人机/双人、难度、执红先手/执黑后手、悔棋(人机撤两步)、重开。
- 窄屏(<820)面板置顶,与五子棋一致。

## 构建与 CI
- `build.sh`/`build.ps1`/`build.yml` 由五子棋版本改名而来:`APP_NAME=中国象棋`、`ORG=io.github.chinesechess`、`project-name chinese_chess`、产物前缀 `ChineseChess-`。
- 产物文件名、artifact 处理(单文件 `archive:false`、web 站点文件夹、release `skip-decompress`、校验 6 个文件、master 滚动 `latest`、`v*` 正式版)保持五子棋已验证的做法。
- 图标:`packaging/icon.png` 用 SVG 生成(红色圆盘"象棋"意象)。

## 测试
- 规则:开局着法数 44、各子走法、蹩马腿、塞象眼、炮打隔子、将帅照面非法、送将非法、将死判负、悔棋还原。
- AI:必杀一步棋(一步杀)找得到、不送将、困难对简单自我对弈获胜、困难单步耗时上限。
- UI:点选-走子流程、人机应手、悔棋、模式切换、执黑翻转。
- `flutter analyze` 无告警。

## 风险
- 深度 5 的耗时需实测,超标则降到 4 或加窄候选。
- 远程仓库地址未给出,CI 无法验证;本地先完成全部并通过 `build.sh linux` / `web`。
