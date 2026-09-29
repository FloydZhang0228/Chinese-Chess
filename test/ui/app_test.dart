import 'package:chinese_chess/core/xiangqi.dart';
import 'package:chinese_chess/main.dart';
import 'package:chinese_chess/ui/board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t) async {
  await t.binding.setSurfaceSize(const Size(1100, 760));
  await t.pumpWidget(const ChessApp());
}

/// 棋盘格点 (x, y) 的屏幕坐标, 与 BoardView 的几何一致。
Offset _at(WidgetTester t, int x, int y, {bool flipped = false}) {
  final r = t.getRect(find.descendant(of: find.byType(BoardView), matching: find.byType(CustomPaint)).last);
  final geo = Geo(r.size);
  return r.topLeft + geo.pos(x, y, flipped);
}

/// 越过 AI 的 300ms 假时钟延迟, 再等真实 isolate 算完, 最后刷新界面。
Future<void> _aiDone(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 400));
  await t.runAsync(() => Future.delayed(const Duration(seconds: 3)));
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('人机: 选子-走子-电脑应手, 悔棋撤两步', (t) async {
    await _pump(t);
    expect(find.text('轮到你落子'), findsOneWidget);

    await t.tapAt(_at(t, 1, 7)); // 红炮
    await t.pump();
    await t.tapAt(_at(t, 4, 7)); // 炮二平五
    await t.pump();
    expect(find.text('电脑思考中…'), findsOneWidget);
    await _aiDone(t);
    expect(find.text('第 2 手'), findsOneWidget);
    expect(find.text('轮到你落子'), findsOneWidget);

    await t.tap(find.text('悔棋'));
    await t.pump();
    expect(find.text('第 0 手'), findsOneWidget);
  });

  testWidgets('执黑后手时电脑(红)先走, 棋盘翻转后点击映射正确', (t) async {
    await _pump(t);
    await t.tap(find.text('执黑后手'));
    await t.pump();
    await _aiDone(t);
    expect(find.text('第 1 手'), findsOneWidget);

    // 翻转后黑方在下: 黑炮(1,2)显示在 (7,7) 的位置
    await t.tapAt(_at(t, 1, 2, flipped: true));
    await t.pump();
    await t.tapAt(_at(t, 4, 2, flipped: true));
    await t.pump();
    expect(find.text('第 2 手'), findsOneWidget);
    await _aiDone(t); // 排空电脑的下一次应手, 避免测试结束时还有挂起的定时器
  });

  testWidgets('双人: 红先黑后, 点空格/对方子不落子', (t) async {
    await _pump(t);
    await t.tap(find.text('双人'));
    await t.pump();
    expect(find.text('红方落子'), findsOneWidget);

    await t.tapAt(_at(t, 1, 2)); // 轮到红, 点黑炮无效
    await t.pump();
    await t.tapAt(_at(t, 1, 3));
    await t.pump();
    expect(find.text('第 0 手'), findsOneWidget);

    await t.tapAt(_at(t, 0, 6)); // 红兵
    await t.pump();
    await t.tapAt(_at(t, 0, 5));
    await t.pump();
    expect(find.text('第 1 手'), findsOneWidget);
    expect(find.text('黑方落子'), findsOneWidget);
  });

  testWidgets('切换到双人模式后隐藏难度选项', (t) async {
    await _pump(t);
    expect(find.text('困难'), findsOneWidget);
    await t.tap(find.text('双人'));
    await t.pump();
    expect(find.text('困难'), findsNothing);
  });

  test('Geo: 翻转前后命中格点互为对称, 棋盘外返回 null', () {
    final geo = Geo(const Size(500, 560));
    for (final (x, y) in const [(0, 0), (8, 9), (3, 4)]) {
      expect(geo.hit(geo.pos(x, y, false), false), y * cols + x);
      expect(geo.hit(geo.pos(x, y, true), true), y * cols + x);
    }
    expect(geo.hit(const Offset(-30, 5), false), isNull);
  });
}
