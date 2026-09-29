import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/xiangqi.dart';
import 'theme.dart';

/// 棋盘几何: 格点 (x, y) 与像素互转, [flipped] 时上下左右翻转(黑方在下)。
class Geo {
  Geo(Size box)
      : step = min(box.width / (cols - 1 + 2 * margin), box.height / (rows - 1 + 2 * margin)) {
    size = Size(step * (cols - 1 + 2 * margin), step * (rows - 1 + 2 * margin));
  }
  static const margin = 0.62;
  static double aspect = (cols - 1 + 2 * margin) / (rows - 1 + 2 * margin);
  final double step;
  late final Size size;

  Offset pos(int x, int y, bool flipped) {
    final dx = flipped ? cols - 1 - x : x, dy = flipped ? rows - 1 - y : y;
    return Offset((margin + dx) * step, (margin + dy) * step);
  }

  /// 像素 → 格点索引 y*cols+x; 点在棋盘外返回 null。
  int? hit(Offset p, bool flipped) {
    var x = (p.dx / step - margin).round(), y = (p.dy / step - margin).round();
    if (x < 0 || y < 0 || x >= cols || y >= rows) return null;
    if (flipped) {
      x = cols - 1 - x;
      y = rows - 1 - y;
    }
    return y * cols + x;
  }
}

const _redName = ['', '車', '馬', '相', '仕', '帥', '炮', '兵'];
const _blackName = ['', '車', '馬', '象', '士', '將', '砲', '卒'];

/// 棋盘: 黑色磨砂玻璃底板 + 银线 + 玻璃圆盘棋子。
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.game,
    required this.flipped,
    required this.selected,
    required this.targets,
    required this.enabled,
    required this.onTap,
  });
  final Xiangqi game;
  final bool flipped, enabled;
  final int? selected;
  final Set<int> targets;
  final void Function(int x, int y) onTap;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
        final geo = Geo(box.biggest);
        return Center(
          child: SizedBox.fromSize(
            size: geo.size,
            child: GestureDetector(
              onTapUp: (d) {
                final c = geo.hit(d.localPosition, widget.flipped);
                if (c != null && widget.enabled) widget.onTap(c % cols, c ~/ cols);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(geo.step * 0.5),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: AnimatedBuilder(
                    animation: _clock,
                    builder: (_, __) => CustomPaint(
                      size: geo.size,
                      painter: _Painter(widget.game, geo, widget.flipped, widget.selected, widget.targets, _clock.value),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      });
}

class _Painter extends CustomPainter {
  _Painter(this.g, this.geo, this.flip, this.sel, this.targets, this.t);
  final Xiangqi g;
  final Geo geo;
  final bool flip;
  final int? sel;
  final Set<int> targets;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final step = geo.step;
    Offset p(int x, int y) => geo.pos(x, y, flip);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(step * 0.5));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black.withValues(alpha: 0.42), Colors.black.withValues(alpha: 0.26)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.38), Colors.white.withValues(alpha: 0.08)],
        ).createShader(rect),
    );

    // 网格: 横线整条; 竖线在河界处断开(两侧边线除外)
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var y = 0; y < rows; y++) {
      canvas.drawLine(p(0, y), p(cols - 1, y), line);
    }
    for (var x = 0; x < cols; x++) {
      if (x == 0 || x == cols - 1) {
        canvas.drawLine(p(x, 0), p(x, rows - 1), line);
      } else {
        canvas.drawLine(p(x, 0), p(x, 4), line);
        canvas.drawLine(p(x, 5), p(x, rows - 1), line);
      }
    }
    // 九宫斜线
    for (final y0 in const [0, 7]) {
      canvas.drawLine(p(3, y0), p(5, y0 + 2), line);
      canvas.drawLine(p(5, y0), p(3, y0 + 2), line);
    }
    // 炮位、兵位标记
    final mark = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    void tick(int x, int y) {
      final o = p(x, y), d = step * 0.09, l = step * 0.2;
      for (final sx in const [-1, 1]) {
        if ((x == 0 && sx < 0) || (x == cols - 1 && sx > 0)) continue;
        for (final sy in const [-1, 1]) {
          canvas.drawLine(o + Offset(sx * d, sy * d), o + Offset(sx * (d + l), sy * d), mark);
          canvas.drawLine(o + Offset(sx * d, sy * d), o + Offset(sx * d, sy * (d + l)), mark);
        }
      }
    }
    for (final (x, y) in const [(1, 2), (7, 2), (1, 7), (7, 7)]) {
      tick(x, y);
    }
    for (final y in const [3, 6]) {
      for (var x = 0; x < cols; x += 2) {
        tick(x, y);
      }
    }
    // 楚河汉界
    final mid = Offset(0, (p(0, 4).dy + p(0, 5).dy) / 2);
    void river(String s, double cx) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: step * 0.55,
            letterSpacing: step * 0.35,
            color: Colors.white.withValues(alpha: 0.28),
            fontWeight: FontWeight.w300,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, mid.dy - tp.height / 2));
    }

    river('楚河', size.width * 0.27);
    river('汉界', size.width * 0.73);

    final r = step * 0.43;

    // 最后一步: 起点淡环 + 终点扩散光环
    if (g.history.isNotEmpty) {
      final m = g.history.last;
      final a = p(m.from % cols, m.from ~/ cols), b = p(m.to % cols, m.to ~/ cols);
      canvas.drawCircle(a, r * 0.5, Paint()..color = Palette.accent.withValues(alpha: 0.35));
      canvas.drawCircle(
        b,
        r * (1.05 + 0.25 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Palette.accent.withValues(alpha: 0.9 * (1 - t)),
      );
    }

    // 棋子
    final checkKing = g.inCheck ? g.cells.indexOf(piece(g.turn, jiang)) : -1;
    for (var i = 0; i < g.cells.length; i++) {
      final pc = g.cells[i];
      if (pc == 0) continue;
      final o = p(i % cols, i ~/ cols), red = sideOf(pc) == 1, selected = i == sel;
      final rr = selected ? r * 1.08 : r;
      canvas.drawCircle(
        o + Offset(rr * 0.08, rr * 0.22),
        rr,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rr * 0.22),
      );
      canvas.drawCircle(
        o,
        rr,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            radius: 1,
            colors: red
                ? const [Color(0xFF6A2A34), Color(0xFF2A1015), Color(0xFF12070A)]
                : const [Color(0xFF5B616C), Color(0xFF1B1E25), Color(0xFF07080B)],
            stops: const [0, 0.6, 1],
          ).createShader(Rect.fromCircle(center: o, radius: rr)),
      );
      final ink = red ? const Color(0xFFFF6B7D) : const Color(0xFFE3E8F0);
      canvas.drawCircle(
        o,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2 : 1
          ..color = selected ? Palette.neon : ink.withValues(alpha: 0.45),
      );
      canvas.drawCircle(
        o,
        rr * 0.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ink.withValues(alpha: 0.3),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: (red ? _redName : _blackName)[kindOf(pc)],
          style: TextStyle(fontSize: rr * 1.05, fontWeight: FontWeight.w700, color: ink, height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));

      if (i == checkKing) {
        canvas.drawCircle(
          o,
          rr * (1.15 + 0.15 * sin(t * 2 * pi)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Palette.accent.withValues(alpha: 0.6 + 0.4 * sin(t * 2 * pi)),
        );
      }
    }

    // 合法落点: 空位画实心点, 吃子画环
    for (final i in targets) {
      final o = p(i % cols, i ~/ cols);
      if (g.cells[i] == 0) {
        canvas.drawCircle(o, step * 0.11, Paint()..color = Palette.neon.withValues(alpha: 0.85));
      } else {
        canvas.drawCircle(
          o,
          r * 1.12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Palette.accent.withValues(alpha: 0.9),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Painter old) => true;
}
