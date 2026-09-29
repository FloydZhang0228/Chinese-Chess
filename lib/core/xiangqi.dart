/// 中国象棋规则。9 列 × 10 行, 红方在下(y 大), 红先。
/// 棋子编码: 0 空, 红 1..7, 黑 8..14; 种类见下方常量。
const cols = 9, rows = 10;
const che = 1, ma = 2, xiang = 3, shi = 4, jiang = 5, pao = 6, bing = 7;

int piece(int side, int kind) => (side - 1) * 7 + kind;
int sideOf(int p) => p == 0 ? 0 : (p <= 7 ? 1 : 2);
int kindOf(int p) => p == 0 ? 0 : (p - 1) % 7 + 1;

class Move {
  const Move(this.from, this.to);
  final int from, to; // y * cols + x

  @override
  bool operator ==(Object other) => other is Move && other.from == from && other.to == to;
  @override
  int get hashCode => from * 100 + to;
}

class Xiangqi {
  Xiangqi() : this.from(_initial());
  Xiangqi.from(List<int> c, {this.turn = 1}) : cells = List.of(c);

  final List<int> cells;
  int turn; // 1 红 / 2 黑
  final history = <Move>[];
  final _taken = <int>[];

  static List<int> _initial() {
    final c = List<int>.filled(cols * rows, 0);
    const back = [che, ma, xiang, shi, jiang, shi, xiang, ma, che];
    for (var x = 0; x < cols; x++) {
      c[x] = piece(2, back[x]);
      c[9 * cols + x] = piece(1, back[x]);
    }
    for (final x in const [1, 7]) {
      c[2 * cols + x] = piece(2, pao);
      c[7 * cols + x] = piece(1, pao);
    }
    for (var x = 0; x < cols; x += 2) {
      c[3 * cols + x] = piece(2, bing);
      c[6 * cols + x] = piece(1, bing);
    }
    return c;
  }

  Xiangqi copy() => Xiangqi.from(cells, turn: turn);

  bool get inCheck => _inCheckOf(turn);
  bool get over => legalMoves().isEmpty;
  int get winner => over ? 3 - turn : 0; // 无着可走者输

  /// 不校验地走一步(AI 内部与合法性过滤用)。
  void push(Move m) {
    _taken.add(cells[m.to]);
    cells[m.to] = cells[m.from];
    cells[m.from] = 0;
    history.add(m);
    turn = 3 - turn;
  }

  void undo() {
    if (history.isEmpty) return;
    final m = history.removeLast();
    cells[m.from] = cells[m.to];
    cells[m.to] = _taken.removeLast();
    turn = 3 - turn;
  }

  bool play(Move m) {
    if (!legalMoves(from: m.from).contains(m)) return false;
    push(m);
    return true;
  }

  /// 当前方全部合法着法; 传 [from] 只取该格棋子的着法。
  List<Move> legalMoves({int? from}) {
    final ps = <Move>[];
    if (from != null) {
      if (sideOf(cells[from]) == turn) _gen(from, ps);
    } else {
      for (var i = 0; i < cells.length; i++) {
        if (sideOf(cells[i]) == turn) _gen(i, ps);
      }
    }
    final me = turn;
    final out = <Move>[];
    for (final m in ps) {
      push(m);
      if (!_inCheckOf(me)) out.add(m);
      undo();
    }
    return out;
  }

  static bool _in(int x, int y) => x >= 0 && x < cols && y >= 0 && y < rows;

  void _gen(int i, List<Move> out) {
    final p = cells[i], s = sideOf(p), x = i % cols, y = i ~/ cols;
    void add(int nx, int ny) {
      if (_in(nx, ny) && sideOf(cells[ny * cols + nx]) != s) out.add(Move(i, ny * cols + nx));
    }

    bool palace(int nx, int ny) => nx >= 3 && nx <= 5 && (s == 1 ? ny >= 7 : ny <= 2);

    switch (kindOf(p)) {
      case che:
      case pao:
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          var nx = x + dx, ny = y + dy, screen = false;
          while (_in(nx, ny)) {
            final t = cells[ny * cols + nx];
            if (!screen) {
              if (t == 0) {
                out.add(Move(i, ny * cols + nx));
              } else if (kindOf(p) == che) {
                if (sideOf(t) != s) out.add(Move(i, ny * cols + nx));
                break;
              } else {
                screen = true;
              }
            } else if (t != 0) {
              if (sideOf(t) != s) out.add(Move(i, ny * cols + nx));
              break;
            }
            nx += dx;
            ny += dy;
          }
        }
      case ma:
        for (final (dx, dy, lx, ly) in const [
          (1, 2, 0, 1), (-1, 2, 0, 1), (1, -2, 0, -1), (-1, -2, 0, -1),
          (2, 1, 1, 0), (2, -1, 1, 0), (-2, 1, -1, 0), (-2, -1, -1, 0),
        ]) {
          if (_in(x + lx, y + ly) && cells[(y + ly) * cols + x + lx] == 0) {
            add(x + dx, y + dy);
          }
        }
      case xiang:
        for (final (dx, dy) in const [(2, 2), (2, -2), (-2, 2), (-2, -2)]) {
          final nx = x + dx, ny = y + dy;
          if (!_in(nx, ny) || (s == 1 ? ny < 5 : ny > 4)) continue;
          if (cells[(y + dy ~/ 2) * cols + x + dx ~/ 2] == 0) add(nx, ny);
        }
      case shi:
        for (final (dx, dy) in const [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
          if (palace(x + dx, y + dy)) add(x + dx, y + dy);
        }
      case jiang:
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          if (palace(x + dx, y + dy)) add(x + dx, y + dy);
        }
      case bing:
        add(x, y + (s == 1 ? -1 : 1));
        if (s == 1 ? y <= 4 : y >= 5) {
          add(x - 1, y);
          add(x + 1, y);
        }
    }
  }

  bool _inCheckOf(int side) {
    final k = cells.indexOf(piece(side, jiang));
    if (k < 0) return false;
    final kx = k % cols, ky = k ~/ cols, e = 3 - side;
    // 直线: 车、炮(隔一子)、将帅照面(竖直方向遇到对方将)
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      var x = kx + dx, y = ky + dy, screen = false;
      while (_in(x, y)) {
        final p = cells[y * cols + x];
        if (p != 0) {
          if (!screen) {
            if (sideOf(p) == e && (kindOf(p) == che || (kindOf(p) == jiang && dx == 0))) return true;
            screen = true;
          } else {
            if (sideOf(p) == e && kindOf(p) == pao) return true;
            break;
          }
        }
        x += dx;
        y += dy;
      }
    }
    // 马: 从 K 反推马所在格, 马腿在马的移动方向上紧邻马的一格
    for (final (a, b) in const [(1, 2), (-1, 2), (1, -2), (-1, -2), (2, 1), (2, -1), (-2, 1), (-2, -1)]) {
      final sx = kx + a, sy = ky + b;
      if (!_in(sx, sy) || cells[sy * cols + sx] != piece(e, ma)) continue;
      final lx = sx + (a.abs() == 2 ? (-a) ~/ 2 : 0), ly = sy + (b.abs() == 2 ? (-b) ~/ 2 : 0);
      if (cells[ly * cols + lx] == 0) return true;
    }
    // 兵
    final fwd = e == 1 ? -1 : 1;
    bool isBing(int x, int y) => _in(x, y) && cells[y * cols + x] == piece(e, bing);
    if (isBing(kx, ky - fwd)) return true;
    if (e == 1 ? ky <= 4 : ky >= 5) {
      if (isBing(kx - 1, ky) || isBing(kx + 1, ky)) return true;
    }
    return false;
  }
}
