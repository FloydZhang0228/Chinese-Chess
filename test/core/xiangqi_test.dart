import 'package:chinese_chess/core/xiangqi.dart';
import 'package:flutter_test/flutter_test.dart';

int at(int x, int y) => y * cols + x;

/// 摆残局: {(x,y): 棋子}
Xiangqi pos(Map<(int, int), int> m, {int turn = 1}) {
  final c = List<int>.filled(cols * rows, 0);
  m.forEach((k, v) => c[at(k.$1, k.$2)] = v);
  return Xiangqi.from(c, turn: turn);
}

final rK = piece(1, jiang), bK = piece(2, jiang);

void main() {
  test('开局红方 44 个着法', () => expect(Xiangqi().legalMoves().length, 44));

  test('蹩马腿', () {
    final g = pos({(4, 9): rK, (3, 0): bK, (4, 5): piece(1, ma), (4, 4): piece(1, bing)});
    final ms = g.legalMoves(from: at(4, 5));
    expect(ms.length, 6);
    expect(ms.any((m) => m.to == at(3, 3) || m.to == at(5, 3)), isFalse);
  });

  test('塞象眼与不过河', () {
    var g = pos({(4, 9): rK, (3, 0): bK, (2, 9): piece(1, xiang), (3, 8): piece(1, bing)});
    expect(g.legalMoves(from: at(2, 9)).map((m) => m.to), [at(0, 7)]);
    g = pos({(4, 9): rK, (3, 0): bK, (2, 5): piece(1, xiang)});
    expect(g.legalMoves(from: at(2, 5)).map((m) => m.to).toSet(), {at(0, 7), at(4, 7)});
  });

  test('炮隔子吃, 不能直接吃隔壁', () {
    final g = pos({
      (4, 9): rK, (3, 0): bK, (0, 5): piece(1, pao),
      (0, 4): piece(2, bing), (0, 2): piece(2, che),
    });
    final to = g.legalMoves(from: at(0, 5)).map((m) => m.to).toSet();
    expect(to.contains(at(0, 2)), isTrue);
    expect(to.contains(at(0, 4)), isFalse);
    expect(to.contains(at(0, 3)), isFalse);
  });

  test('将帅照面: 挡在中间的子不能离开', () {
    final g = pos({(4, 9): rK, (4, 0): bK, (4, 5): piece(1, pao)});
    final ms = g.legalMoves(from: at(4, 5));
    expect(ms.length, 7);
    expect(ms.every((m) => m.to % cols == 4), isTrue);
  });

  test('不能送将', () {
    final g = pos({(4, 9): rK, (3, 0): bK, (3, 5): piece(2, che)});
    final to = g.legalMoves(from: at(4, 9)).map((m) => m.to).toSet();
    expect(to.contains(at(3, 9)), isFalse);
    expect(to, {at(5, 9), at(4, 8)});
  });

  test('被将军只能应将; 将死判负', () {
    final g = pos({(3, 9): rK, (4, 0): bK, (0, 1): piece(1, che), (8, 5): piece(1, che)});
    expect(g.play(Move(at(8, 5), at(8, 0))), isTrue);
    expect(g.inCheck, isTrue);
    expect(g.legalMoves(), isEmpty);
    expect(g.winner, 1);
    expect(g.over, isTrue);
    expect(g.play(Move(at(4, 0), at(4, 1))), isFalse);
    g.undo();
    expect(g.winner, 0);
    expect(g.turn, 1);
  });

  test('悔棋完全还原, 含被吃子', () {
    final g = Xiangqi();
    final init = List.of(g.cells);
    expect(g.play(Move(at(1, 7), at(1, 0))), isTrue); // 炮打马
    expect(g.cells[at(1, 0)], piece(1, pao));
    g.undo();
    expect(g.cells, init);
    expect(g.turn, 1);
    for (var i = 0; i < 6; i++) {
      g.play(g.legalMoves()[i * 3 % g.legalMoves().length]);
    }
    while (g.history.isNotEmpty) {
      g.undo();
    }
    expect(g.cells, init);
    expect(g.turn, 1);
  });

  test('非法着法被拒绝', () {
    final g = Xiangqi();
    expect(g.play(Move(at(0, 9), at(0, 5))), isFalse); // 车被自己的兵挡住
    expect(g.play(Move(at(0, 0), at(0, 1))), isFalse); // 轮到红方, 不能动黑子
  });

  test('perft: 开局 1/2/3 层着法总数与公认值一致', () {
    int perft(Xiangqi g, int d) {
      if (d == 0) return 1;
      var n = 0;
      for (final m in g.legalMoves()) {
        g.push(m);
        n += perft(g, d - 1);
        g.undo();
      }
      return n;
    }

    final g = Xiangqi();
    expect(perft(g, 1), 44);
    expect(perft(g, 2), 1920);
    expect(perft(g, 3), 79666);
  });
}
