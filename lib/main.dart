import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'shell/app_router.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'src/rust/frb_generated.dart';

import 'dart:async';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

File? _globalLogFile;

void _logError(String message, [Object? error, StackTrace? stack]) {
  final now = DateTime.now().toIso8601String();
  final logMsg = '[$now] ERROR: $message\n${error ?? ''}\n${stack ?? ''}\n';
  print(logMsg);
  try {
    _globalLogFile?.writeAsStringSync(logMsg, mode: FileMode.append);
  } catch (_) {}
}

Future<void> main(List<String> args) async {
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize logger file
    try {
      final dir = await getApplicationSupportDirectory();
      final logDir = Directory(p.join(dir.path, 'logs'));
      if (!await logDir.exists()) await logDir.create(recursive: true);
      _globalLogFile = File(p.join(logDir.path, 'latest.log'));
      
      // Wipe old log on fresh startup
      if (await _globalLogFile!.exists()) {
        await _globalLogFile!.delete();
      }
      _globalLogFile!.writeAsStringSync('[${DateTime.now().toIso8601String()}] Meridix Launcher Started\n');
    } catch (_) {}

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError('Flutter framework error', details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _logError('Platform dispatcher error', error, stack);
      return true;
    };

    await RustLib.init();

    // ── Window setup ────────────────────────────────────────────────────────
    await Window.initialize();
    await windowManager.ensureInitialized();

    final options = WindowOptions(
      size: const Size(1280, 800),
      minimumSize: const Size(960, 640),
      center: true,
      backgroundColor: const Color(0xFF0C0E13),
      skipTaskbar: false,
      titleBarStyle: Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
      title: 'Meridix Launcher',
    );

    if (Platform.isWindows) {
      await Window.setEffect(
        effect: WindowEffect.acrylic,
        color: const Color(0xCC0C0E13),
      );
    } else if (Platform.isMacOS) {
      await Window.setEffect(
        effect: WindowEffect.hudWindow,
        color: const Color(0xFF0C0E13),
      );
    } else {
      await Window.setEffect(
        effect: WindowEffect.transparent,
        color: const Color(0xFF0C0E13),
      );
    }

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setBackgroundColor(const Color(0xFF0C0E13));
      await windowManager.show();
      await windowManager.focus();
    });

    runApp(const ProviderScope(child: MeridixLauncherApp()));
  }, (error, stack) {
    _logError('Uncaught asynchronous error', error, stack);
  });
}

class MeridixLauncherApp extends StatelessWidget {
  const MeridixLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Meridix Launcher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: appRouter,
    );
  }
}
