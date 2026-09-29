import 'package:flutter/material.dart';

import 'core/ai.dart';
import 'core/xiangqi.dart';
import 'ui/board_view.dart';
import 'ui/theme.dart';
import 'ui/title_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupWindow();
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '中国象棋',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (_, child) => AuroraBackground(
          child: Column(children: [
            if (hasCustomTitleBar) const AppTitleBar(),
            Expanded(child: child!),
          ]),
        ),
        home: const HomePage(),
      );
}

enum Mode { pvp, pve }

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var g = Xiangqi();
  var mode = Mode.pve;
  var level = Level.normal;
  var humanSide = 1; // 人机模式下玩家执子: 1 红(先手) / 2 黑
  var thinking = false;
  var gen = 0; // 局面代数, 让过期的 AI 回调作废
  int? selected;
  var targets = <int>{};

  bool get aiTurn => mode == Mode.pve && !g.over && g.turn != humanSide;
  bool get flipped => mode == Mode.pve && humanSide == 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _aiTurn());
  }

  void _restart() {
    gen++;
    thinking = false;
    selected = null;
    targets = {};
    g = Xiangqi();
    _aiTurn();
  }

  void _tap(int x, int y) {
    if (thinking || g.over || (mode == Mode.pve && g.turn != humanSide)) return;
    final i = y * cols + x;
    if (selected != null && targets.contains(i)) {
      g.play(Move(selected!, i));
      setState(() {
        selected = null;
        targets = {};
      });
      _aiTurn();
    } else if (sideOf(g.cells[i]) == g.turn) {
      setState(() {
        selected = i;
        targets = g.legalMoves(from: i).map((m) => m.to).toSet();
      });
    } else {
      setState(() {
        selected = null;
        targets = {};
      });
    }
  }

  Future<void> _aiTurn() async {
    if (!aiTurn) return;
    final my = ++gen;
    setState(() => thinking = true);
    // 先让界面刷出"思考中", 再在后台 isolate 里搜索
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || my != gen) return;
    final m = await aiMove(g, level);
    if (!mounted || my != gen) return;
    setState(() {
      thinking = false;
      if (m != null) g.play(m);
    });
  }

  void _undo() {
    if (g.history.isEmpty) return;
    gen++; // 取消进行中的 AI 思考
    setState(() {
      thinking = false;
      selected = null;
      targets = {};
      g.undo();
      // 人机: 撤回到轮到玩家为止(通常连同 AI 的一步)
      if (mode == Mode.pve && g.turn != humanSide && g.history.isNotEmpty) g.undo();
    });
    _aiTurn();
  }

  String get status {
    if (g.over) {
      final w = g.winner == 1 ? '红' : '黑';
      if (mode == Mode.pve) return g.winner == humanSide ? '你赢了!' : '电脑获胜';
      return '$w方获胜';
    }
    if (thinking) return '电脑思考中…';
    final chk = g.inCheck ? ' 将军!' : '';
    if (mode == Mode.pve) return '轮到你落子$chk';
    return '${g.turn == 1 ? "红" : "黑"}方落子$chk';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 820;
    final board = Padding(
      padding: const EdgeInsets.all(8),
      child: BoardView(
        align: wide ? Alignment.centerLeft : Alignment.center,
        game: g,
        flipped: flipped,
        selected: selected,
        targets: targets,
        enabled: !thinking && !g.over,
        onTap: _tap,
      ),
    );
    final panel = _Panel(
      status: status,
      turn: g.turn,
      over: g.over,
      thinking: thinking,
      moves: g.history.length,
      mode: mode,
      level: level,
      humanSide: humanSide,
      onMode: (m) => setState(() {
        mode = m;
        _restart();
      }),
      onLevel: (l) => setState(() {
        level = l;
        _restart();
      }),
      onSide: (s) => setState(() {
        humanSide = s;
        _restart();
      }),
      onUndo: g.history.isEmpty ? null : _undo,
      onRestart: () => setState(_restart),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: wide
            ? Row(children: [
                // 棋盘取满剩余空间并贴左, 面板固定宽度贴右
                Expanded(child: board),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
                  child: SizedBox(width: 300, child: SingleChildScrollView(child: panel)),
                ),
              ])
            : Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: panel),
                Expanded(child: board),
              ]),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.status,
    required this.turn,
    required this.over,
    required this.thinking,
    required this.moves,
    required this.mode,
    required this.level,
    required this.humanSide,
    required this.onMode,
    required this.onLevel,
    required this.onSide,
    required this.onUndo,
    required this.onRestart,
  });

  final String status;
  final int turn, moves, humanSide;
  final bool over, thinking;
  final Mode mode;
  final Level level;
  final ValueChanged<Mode> onMode;
  final ValueChanged<Level> onLevel;
  final ValueChanged<int> onSide;
  final VoidCallback? onUndo;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Palette.neon]).createShader(r),
          child: Text('中国象棋',
              style: t.headlineLarge?.copyWith(fontWeight: FontWeight.normal, color: Colors.white, letterSpacing: 6)),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(children: [
            _Stone(red: turn == 1, dim: over, pulse: thinking),
            const SizedBox(width: 12),
            Expanded(child: Text(status, style: t.titleLarge)),
            Text('第 $moves 手', style: t.bodyMedium?.copyWith(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 14),
        SegmentedButton<Mode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: Mode.pve, label: Text('人机'), icon: Icon(Icons.smart_toy_outlined)),
            ButtonSegment(value: Mode.pvp, label: Text('双人'), icon: Icon(Icons.people_outline)),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onMode(s.first),
        ),
        if (mode == Mode.pve) ...[
          const SizedBox(height: 10),
          SegmentedButton<Level>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: Level.easy, label: Text('简单')),
              ButtonSegment(value: Level.normal, label: Text('普通')),
              ButtonSegment(value: Level.hard, label: Text('困难')),
            ],
            selected: {level},
            onSelectionChanged: (s) => onLevel(s.first),
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text('执红先手')),
              ButtonSegment(value: 2, label: Text('执黑后手')),
            ],
            selected: {humanSide},
            onSelectionChanged: (s) => onSide(s.first),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onUndo,
              icon: const Icon(Icons.undo),
              label: const Text('悔棋'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: onRestart,
              style: FilledButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.9), foregroundColor: Colors.black),
              icon: const Icon(Icons.refresh),
              label: const Text('重开'),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// 当前落子方的棋子指示; 电脑思考时呼吸闪烁。
class _Stone extends StatefulWidget {
  const _Stone({required this.red, required this.dim, required this.pulse});
  final bool red, dim, pulse;
  @override
  State<_Stone> createState() => _StoneState();
}

class _StoneState extends State<_Stone> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final glow = widget.pulse ? 4 + 10 * _c.value : 4.0;
          return Opacity(
            opacity: widget.dim ? 0.4 : 1,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.4),
                  colors: widget.red
                      ? const [Color(0xFFFF6B7D), Color(0xFF5A1620)]
                      : const [Color(0xFF7A808B), Color(0xFF07080B)],
                ),
                boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: glow)],
              ),
            ),
          );
        },
      );
}
