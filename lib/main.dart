import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'shell/app_router.dart';
import 'src/rust/frb_generated.dart';

import 'dart:async';
import 'dart:ui';
import 'core/platform/file_service.dart';
import 'package:path/path.dart' as p;

File? _globalLogFile;

void _logInfo(String message) {
  final now = DateTime.now().toIso8601String();
  final logMsg = '[$now] INFO: $message\n';
  print(logMsg);
  try {
    _globalLogFile?.writeAsStringSync(logMsg, mode: FileMode.append);
  } catch (_) {}
}

void _logError(String message, [Object? error, StackTrace? stack]) {
  final now = DateTime.now().toIso8601String();
  final logMsg = '[$now] ERROR: $message\n${error ?? ''}\n${stack ?? ''}\n';
  print(logMsg);
  try {
    _globalLogFile?.writeAsStringSync(logMsg, mode: FileMode.append);
  } catch (_) {}
}

Future<void> main(List<String> args) async {
  // Catch uncaught async errors that bypass Flutter's error handlers
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      final dir = await getAusrineSupportDirectory();
      final logDir = Directory(p.join(dir.path, 'logs'));
      if (!await logDir.exists()) await logDir.create(recursive: true);
      _globalLogFile = File(p.join(logDir.path, 'latest.log'));

      if (await _globalLogFile!.exists()) {
        await _globalLogFile!.delete();
      }
      _globalLogFile!.writeAsStringSync(
          '[${DateTime.now().toIso8601String()}] Ausrine Launcher Started\n');
      _logInfo('Logger initialized');
    } catch (_) {}

    _logInfo('Installing Flutter error handlers');
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError('Flutter framework error', details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _logError('Platform dispatcher error', error, stack);
      return true;
    };

    _logInfo('Initializing Rust bridge');
    await RustLib.init();
    _logInfo('Rust bridge initialized');

    _logInfo('Initializing acrylic/window libraries');
    await Window.initialize();
    await windowManager.ensureInitialized();
    _logInfo('Window libraries initialized');

    // macOS hides native title bar for custom window chrome
    final options = WindowOptions(
      size: const Size(1280, 800),
      minimumSize: const Size(960, 640),
      center: true,
      backgroundColor: const Color(0xFF0C0E13),
      skipTaskbar: false,
      titleBarStyle:
          Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
      title: 'Ausrine Launcher',
    );

    if (Platform.isWindows) {
      _logInfo('Applying Windows acrylic effect');
      await Window.setEffect(
        effect: WindowEffect.acrylic,
        color: const Color(0xCC0C0E13),
      );
    } else if (Platform.isMacOS) {
      _logInfo('Applying macOS HUD window effect');
      await Window.setEffect(
        effect: WindowEffect.hudWindow,
        color: const Color(0xFF0C0E13),
      );
    } else {
      _logInfo('Applying transparent window effect');
      await Window.setEffect(
        effect: WindowEffect.transparent,
        color: const Color(0xFF0C0E13),
      );
    }

    _logInfo('Waiting until window is ready to show');
    await windowManager.waitUntilReadyToShow(options, () async {
      _logInfo('Showing main window');
      await windowManager.setBackgroundColor(const Color(0xFF0C0E13));
      await windowManager.show();
      await windowManager.focus();
      _logInfo('Main window shown');
    });

    // ProviderScope enables Riverpod state management throughout app
    _logInfo('Running Flutter app');
    runApp(const ProviderScope(child: AusrineLauncherApp()));
  }, (error, stack) {
    _logError('Uncaught asynchronous error', error, stack);
  });
}

class AusrineLauncherApp extends StatelessWidget {
  const AusrineLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ausrine Launcher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: appRouter,
    );
  }
}
