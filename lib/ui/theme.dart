import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

/// 黑透配色: 近黑底 + 烟熏玻璃, 点缀只用一种冷银青。
class Palette {
  static const neon = Color(0xFF9FE8F2); // 网格/星位/高亮的冷银青
  static const accent = Color(0xFFFF4D6D); // 仅用于最后一手与获胜连线
  static const blackGlow = Color(0xFF7F8794);
  static const whiteGlow = Color(0xFFFFFFFF);
  static const bg0 = Color(0xFF050608);
  static const bg1 = Color(0xFF0B0D12);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: Palette.neon, brightness: Brightness.dark),
      scaffoldBackgroundColor: Colors.transparent,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.03),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: Colors.white.withValues(alpha: 0.18))),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
      ),
    );

/// 动态渐变背景 + 漂浮光斑, 让毛玻璃有东西可"透"。
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;
  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2029), Color(0xFF0B0E13), Color(0xFF151B24)],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(painter: _Blobs(_c.value)),
        ),
        widget.child,
      ]);
}

class _Blobs extends CustomPainter {
  _Blobs(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Color c, double phase, double rx, double ry, double radius) {
      final a = (t + phase) * 2 * pi;
      final o = Offset(
        size.width * (0.5 + rx * sin(a)),
        size.height * (0.5 + ry * sin(a * 0.8 + 1)),
      );
      final rad = radius * size.shortestSide;
      canvas.drawCircle(
        o,
        rad,
        Paint()
          ..shader = RadialGradient(colors: [c, c.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: o, radius: rad)),
      );
    }

    // 低饱和的冷灰暗光, 只为让玻璃有东西可"透", 不抢棋盘
    blob(const Color(0x8CA6B4CC), 0.0, 0.35, 0.3, 0.5);
    blob(const Color(0x735A6E8C), 0.33, 0.4, 0.35, 0.45);
    blob(const Color(0x6B8091A8), 0.66, 0.3, 0.4, 0.5);
  }

  @override
  bool shouldRepaint(_Blobs old) => old.t != t;
}

/// 烟熏黑玻璃卡片: 背景模糊 + 半透明黑 + 细高光描边。
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 20});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.black.withValues(alpha: 0.42), Colors.black.withValues(alpha: 0.26)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: child,
          ),
        ),
      );
}
