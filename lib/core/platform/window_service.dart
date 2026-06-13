import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

abstract class WindowService {
  Future<void> initialize({Size minSize, String title});
  Future<void> show();
  Future<void> hide();
  Future<void> minimize();
  Future<void> maximize();
  Future<void> unmaximize();
  Future<void> close();
  Future<bool> isMaximized();
  Future<void> startDragging();
  Future<Size> getSize();
  Future<void> setSize(Size size);
  Future<void> center();

  bool get needsCustomTitleBar;

  bool get isMacStyle;
}

class DesktopWindowService implements WindowService {
  @override
  bool get needsCustomTitleBar => true;

  @override
  bool get isMacStyle => Platform.isMacOS;

  @override
  Future<void> initialize({
    Size minSize = const Size(960, 640),
    String title = 'Ausrine Launcher',
  }) async {
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: const Size(1280, 800),
      minimumSize: minSize,
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: title,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> hide() => windowManager.hide();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> maximize() => windowManager.maximize();

  @override
  Future<void> unmaximize() => windowManager.unmaximize();

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  Future<Size> getSize() => windowManager.getSize();

  @override
  Future<void> setSize(Size size) => windowManager.setSize(size);

  @override
  Future<void> center() => windowManager.center();
}
