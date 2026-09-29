import 'dart:math';

import 'package:flutter/foundation.dart' show compute;

import 'xiangqi.dart';

enum Level { easy, normal, hard }

/// Alpha-Beta(负极大值)搜索: 吃子按 MVV-LVA 优先排序, 叶子做只看吃子的静态搜索, 避免在交换中途误判。
/// 评估 = 子力 + 兵过河加成 + 位置小分。
/// ponytail: 无置换表/迭代加深/长将判定, 困难档深度 4; 要更强再加置换表与迭代加深。
class Ai {
  Ai(this.level, [Random? rng]) : _rng = rng ?? Random();
  final Level level;
  final Random _rng;

  static const _mate = 100000;
  static const _vals = [0, 900, 400, 200, 200, 0, 450, 100];
  static int value(int kind) => _vals[kind];

  int get _depth => switch (level) { Level.easy => 2, Level.normal => 3, Level.hard => 4 };

  /// 返回最佳着法; 当前方无合法着法返回 null。不修改 [g]。
  Move? move(Xiangqi g) {
    final b = g.copy();
    final ms = _sorted(b, b.legalMoves());
    if (ms.isEmpty) return null;

    final scored = <(int, Move)>[];
    var alpha = -_mate * 2;
    for (final m in ms) {
      b.push(m);
      // 窗口下沿放宽 1, 使得与当前最优并列的着法也得到精确分, 而不是被剪成上界
      final v = -_search(b, _depth - 1, 1, -_mate * 2, -(alpha - 1));
      b.undo();
      scored.add((v, m));
      // 简单档要看到全部着法的分数才能随机挑, 不能用 alpha 剪枝
      if (level != Level.easy && v > alpha) alpha = v;
    }
    scored.sort((a, c) => c.$1.compareTo(a.$1));
    if (level == Level.easy) return scored[_rng.nextInt(min(3, scored.length))].$2;
    // 同分随机, 避免每盘一模一样
    final top = scored.where((s) => s.$1 == scored.first.$1).toList();
    return top[_rng.nextInt(top.length)].$2;
  }

  int _search(Xiangqi g, int depth, int ply, int alpha, int beta) {
    if (depth <= 0) return _quiesce(g, alpha, beta, 4);
    final ms = g.legalMoves();
    if (ms.isEmpty) return -_mate + ply; // 被将死: 离根越近越差, 所以会选最快的杀法、拖最久的败局
    var best = -_mate * 2;
    for (final m in _sorted(g, ms)) {
      g.push(m);
      final v = -_search(g, depth - 1, ply + 1, -beta, -alpha);
      g.undo();
      if (v > best) best = v;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  int _quiesce(Xiangqi g, int alpha, int beta, int depth) {
    final stand = _eval(g);
    if (depth == 0 || stand >= beta) return stand;
    if (stand > alpha) alpha = stand;
    final caps = g.legalMoves().where((m) => g.cells[m.to] != 0).toList();
    for (final m in _sorted(g, caps)) {
      g.push(m);
      final v = -_quiesce(g, -beta, -alpha, depth - 1);
      g.undo();
      if (v >= beta) return v;
      if (v > alpha) alpha = v;
    }
    return alpha;
  }

  List<Move> _sorted(Xiangqi g, List<Move> ms) {
    int key(Move m) {
      final t = g.cells[m.to];
      return t == 0 ? 0 : 10 * _vals[kindOf(t)] - _vals[kindOf(g.cells[m.from])] + 1;
    }

    return ms..sort((a, b) => key(b).compareTo(key(a)));
  }

  /// 当前走子方视角的分数。
  int _eval(Xiangqi g) {
    var s = 0;
    for (var i = 0; i < g.cells.length; i++) {
      final p = g.cells[i];
      if (p == 0) continue;
      final side = sideOf(p), k = kindOf(p), x = i % cols, y = i ~/ cols;
      var v = _vals[k];
      final adv = side == 1 ? 9 - y : y; // 前进步数
      if (k == bing) {
        v += adv >= 5 ? 100 + (4 - (x - 4).abs()) * 10 : 0; // 过河兵值钱, 居中更值钱
      } else if (k == che || k == ma || k == pao) {
        v += (4 - (x - 4).abs()) * 4 + min(adv, 6) * 2; // 靠中路、向前活跃
      }
      s += side == g.turn ? v : -v;
    }
    return s;
  }
}

Move? _run((List<int>, int, int) a) =>
    Ai(Level.values[a.$3]).move(Xiangqi.from(a.$1, turn: a.$2));

/// 在后台 isolate 里思考, 界面不卡(Web 端 compute 会退化为主线程执行)。
Future<Move?> aiMove(Xiangqi g, Level l) => compute(_run, (List.of(g.cells), g.turn, l.index));
