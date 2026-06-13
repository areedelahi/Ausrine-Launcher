import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'shell/app_router.dart';
import 'src/rust/frb_generated.dart';
import 'src/rust/api/discord.dart';

import 'dart:async';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
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
    
    _logInfo('Initializing Discord RPC');
    try {
      await initDiscordRpc(clientId: "1515240427786076250");
      await setDiscordPresence(state: "Idle", details: "In Launcher", startTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000);
      _logInfo('Discord RPC set to Idle');
    } catch (e) {
      _logInfo('Failed to init discord: $e');
    }

    _logInfo('Initializing acrylic/window libraries');
    await Window.initialize();
    await windowManager.ensureInitialized();
    _logInfo('Window libraries initialized');

    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble('window_width') ?? 1280.0;
    final height = prefs.getDouble('window_height') ?? 800.0;
    final x = prefs.getDouble('window_x');
    final y = prefs.getDouble('window_y');
    final isMaximized = prefs.getBool('window_maximized') ?? false;

    // macOS hides native title bar for custom window chrome
    final options = WindowOptions(
      size: Size(width, height),
      minimumSize: const Size(960, 640),
      center: x == null || y == null,
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

    // ProviderScope enables Riverpod state management throughout app
    _logInfo('Running Flutter app');
    runApp(const ProviderScope(child: AusrineLauncherApp()));

    _logInfo('Waiting until window is ready to show');
    await windowManager.waitUntilReadyToShow(options, () async {
      _logInfo('Showing main window');
      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
      await windowManager.setBackgroundColor(const Color(0xFF0C0E13));
      await windowManager.show();
      await windowManager.focus();
      if (isMaximized) {
        if (Platform.isWindows) {
          // Delay to ensure the window is fully mapped before maximizing
          await Future.delayed(const Duration(milliseconds: 250));
        }
        await windowManager.maximize();
      }
      _logInfo('Main window shown');
    });
  }, (error, stack) {
    _logError('Uncaught asynchronous error', error, stack);
  });
}

class AusrineLauncherApp extends StatefulWidget {
  const AusrineLauncherApp({super.key});

  @override
  State<AusrineLauncherApp> createState() => _AusrineLauncherAppState();
}

class _AusrineLauncherAppState extends State<AusrineLauncherApp> with WindowListener {
  Timer? _saveTimer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _saveTimer?.cancel();
    super.dispose();
  }

  void _scheduleSave() {
    if (_isClosing) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveWindowBounds);
  }

  Future<void> _saveWindowBounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // On Windows, checking isMaximized during close might return false.
      // So we rely on the state being correctly saved during the events.
      final isMaximized = await windowManager.isMaximized();
      await prefs.setBool('window_maximized', isMaximized);

      if (!isMaximized) {
        final bounds = await windowManager.getBounds();
        // Prevent saving bounds if the window is minimized or collapsed
        if (bounds.width > 0 && bounds.height > 0) {
          await prefs.setDouble('window_width', bounds.width);
          await prefs.setDouble('window_height', bounds.height);
          await prefs.setDouble('window_x', bounds.left);
          await prefs.setDouble('window_y', bounds.top);
        }
      }
    } catch (_) {
      // Ignore errors if window is closing
    }
  }

  @override
  void onWindowClose() {
    _isClosing = true;
    _saveTimer?.cancel();
    super.onWindowClose();
  }

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

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
