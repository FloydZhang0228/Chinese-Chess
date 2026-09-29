import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'theme.dart' show fontFamily;

/// 仅 Windows / Linux / macOS 桌面端使用自绘标题栏。
bool get hasCustomTitleBar => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// 在 runApp 之前调用: 隐藏系统标题栏, 窗口背景透明。
Future<void> setupWindow() async {
  if (!hasCustomTitleBar) return;
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: Size(1280, 880),
      minimumSize: Size(800, 600),
      center: true,
      title: '中国象棋',
      backgroundColor: Colors.transparent,
      // macOS 保留系统红绿灯按钮, 其余平台完全自绘
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: Platform.isMacOS,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

const titleBarHeight = 32.0;

/// 半透明矮标题栏: 拖动移动窗口, 双击最大化, 右侧 最小化/最大化/关闭。
class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: titleBarHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.02)],
            ),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          ),
          child: Row(children: [
            Expanded(
              child: DragToMoveArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () async => await windowManager.isMaximized()
                      ? windowManager.unmaximize()
                      : windowManager.maximize(),
                  child: Padding(
                    padding: EdgeInsets.only(left: Platform.isMacOS ? 0 : 14),
                    child: Align(
                      alignment: Platform.isMacOS ? Alignment.center : Alignment.centerLeft,
                      child: Text('中国象棋',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            letterSpacing: 2,
                            color: Colors.white.withValues(alpha: 0.7),
                          )),
                    ),
                  ),
                ),
              ),
            ),
            if (!Platform.isMacOS) ...[
              _Btn(icon: Icons.remove, tip: '最小化', onTap: windowManager.minimize),
              _Btn(
                icon: Icons.crop_square,
                tip: '最大化',
                onTap: () async =>
                    await windowManager.isMaximized() ? windowManager.unmaximize() : windowManager.maximize(),
              ),
              _Btn(icon: Icons.close, tip: '关闭', onTap: windowManager.close, danger: true),
            ],
          ]),
        ),
      );
}

class _Btn extends StatefulWidget {
  const _Btn({required this.icon, required this.tip, required this.onTap, this.danger = false});
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final bool danger;
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  var hover = false;

  @override
  // 标题栏位于 Navigator 之外, 没有 Overlay, 不能用 Tooltip; 用 Semantics 保留无障碍标签
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.tip,
        child: MouseRegion(
          onEnter: (_) => setState(() => hover = true),
          onExit: (_) => setState(() => hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 44,
              height: titleBarHeight,
              color: hover
                  ? (widget.danger ? const Color(0xCCE53950) : Colors.white.withValues(alpha: 0.14))
                  : Colors.transparent,
              child: Icon(widget.icon, size: 15, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ),
      );
}
