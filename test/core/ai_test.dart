import 'dart:math';

import 'package:chinese_chess/core/ai.dart';
import 'package:chinese_chess/core/xiangqi.dart';
import 'package:flutter_test/flutter_test.dart';

int at(int x, int y) => y * cols + x;

Xiangqi pos(Map<(int, int), int> m, {int turn = 1}) {
  final c = List<int>.filled(cols * rows, 0);
  m.forEach((k, v) => c[at(k.$1, k.$2)] = v);
  return Xiangqi.from(c, turn: turn);
}

final rK = piece(1, jiang), bK = piece(2, jiang);

void main() {
  for (final l in [Level.normal, Level.hard]) {
    test('${l.name}: 一步杀必选', () {
      final g = pos({(3, 9): rK, (4, 0): bK, (0, 1): piece(1, che), (8, 5): piece(1, che)});
      // 困毙同样判负, 所以只要求"走完对方无着可走"
      final m = Ai(l).move(g)!;
      g.push(m);
      expect(g.over, isTrue, reason: '${m.from}->${m.to}');
      expect(g.winner, 1);
    });
  }

  test('被将军时选的着法必须合法应将', () {
    final g = pos({(4, 9): rK, (3, 0): bK, (4, 3): piece(2, che)});
    expect(g.inCheck, isTrue);
    final m = Ai(Level.hard).move(g)!;
    expect(g.legalMoves(), contains(m));
  });

  test('有白吃的子就吃(无杀棋时)', () {
    // 黑将在角落远离, 红车可吃马且不涉及杀棋
    final g = pos({(4, 9): rK, (5, 0): bK, (0, 5): piece(1, che), (0, 4): piece(2, ma)});
    final m = Ai(Level.normal).move(g)!;
    g.push(m);
    final left = g.cells.where((p) => kindOf(p) == ma).length;
    expect(left == 0 || g.over, isTrue);
  });

  test('无着可走返回 null; 不修改入参', () {
    final g = Xiangqi();
    final before = List.of(g.cells);
    Ai(Level.normal).move(g);
    expect(g.cells, before);
    expect(g.history, isEmpty);
    final dead = pos({(3, 9): rK, (4, 0): bK, (0, 1): piece(1, che), (8, 0): piece(1, che)}, turn: 2);
    expect(Ai(Level.hard).move(dead), isNull);
  });

  test('困难对简单: 自我对弈不落下风, 单步耗时可接受', () {
    final g = Xiangqi();
    final hard = Ai(Level.hard), easy = Ai(Level.easy, Random(1));
    var worst = 0;
    for (var i = 0; i < 40 && !g.over; i++) {
      final sw = Stopwatch()..start();
      final m = (g.turn == 1 ? hard : easy).move(g)!;
      if (g.turn == 1) worst = max(worst, sw.elapsedMilliseconds);
      expect(g.play(m), isTrue);
    }
    // 子力差(红 - 黑), 困难档为红
    var d = 0;
    for (final p in g.cells) {
      if (p != 0) d += (sideOf(p) == 1 ? 1 : -1) * Ai.value(kindOf(p));
    }
    expect(d >= 0 || g.winner == 1, isTrue, reason: '子力差 $d');
    // ignore: avoid_print
    print('困难档最慢一步 ${worst}ms');
    expect(worst, lessThan(8000));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
