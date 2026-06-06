import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../domain/user_account.dart';

/// Official Minecraft Launcher Client ID (v1.0 MSA)
const _clientId = '00000000402b5328';
const _scopes = 'service::user.auth.xboxlive.com::MBI_SSL';
const _redirectUri = 'https://login.live.com/oauth20_desktop.srf';

/// Full production Microsoft → Xbox → Minecraft OAuth chain using MSA v1.0.
class MsAuthService {
  final _dio = Dio();

  MsAuthService() {
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: false, // multipart bodies are messy to log
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  // ── Main entry point ──────────────────────────────────────────────────────

  /// Full login flow. Opens a WebView popup, waits for code, exchanges tokens,
  /// authenticates with Xbox + Minecraft, and returns a [UserAccount].
  Future<UserAccount> loginWithBrowser() async {
    // Build authorization URL (MSA v1.0)
    final authUrl = Uri.https(
      'login.live.com',
      '/oauth20_authorize.srf',
      {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': _scopes,
      },
    );

    // Get auth code via WebView
    final code = await _getCodeFromWebView(authUrl.toString());

    // Exchange code for MS tokens (MSA v1.0)
    final msTokens = await _exchangeCodeForMsToken(
      code: code,
      redirectUri: _redirectUri,
    );

    // Xbox Live
    final xblToken = await _authenticateWithXbl(msTokens['access_token']!);

    // XSTS
    final xstsResult = await _authenticateWithXsts(xblToken);

    // Minecraft
    final mcTokens = await _loginWithMinecraft(
      xstsResult['xstsToken']!,
      xstsResult['userHash']!,
    );

    // Profile
    final profile = await _fetchMinecraftProfile(mcTokens['accessToken']!);
    final skinUrl = _extractSkinUrl(profile);
    final capes = _extractCapes(profile);
    final activeCapeId = _extractActiveCapeId(profile);

    final expiresAt = DateTime.now().add(
      Duration(seconds: int.parse(msTokens['expires_in'] ?? '86400')),
    );

    return UserAccount(
      uuid: _formatUuid(profile['id'] as String),
      username: profile['name'] as String,
      type: 'microsoft',
      accessToken: mcTokens['accessToken']!,
      refreshToken: msTokens['refresh_token'] ?? '',
      expiresAt: expiresAt,
      isActive: true,
      skinUrl: skinUrl,
      capes: capes,
      activeCapeId: activeCapeId,
    );
  }

  // ── Refresh tokens ────────────────────────────────────────────────────────

  /// Refreshes a Microsoft access token using the stored refresh token,
  /// then re-authenticates with Xbox → XSTS → Minecraft.
  Future<UserAccount> refreshAccount(UserAccount account) async {
    if (account.type != 'microsoft') return account;

    final msTokens = await _refreshMsToken(account.refreshToken);
    final xblToken = await _authenticateWithXbl(msTokens['access_token']!);
    final xstsResult = await _authenticateWithXsts(xblToken);
    final mcTokens = await _loginWithMinecraft(
      xstsResult['xstsToken']!,
      xstsResult['userHash']!,
    );

    // Re-fetch profile to get updated skin URL and capes
    final profile = await _fetchMinecraftProfile(mcTokens['accessToken']!);
    final skinUrl = _extractSkinUrl(profile);
    final capes = _extractCapes(profile);
    final activeCapeId = _extractActiveCapeId(profile);

    return account.copyWith(
      accessToken: mcTokens['accessToken']!,
      refreshToken: msTokens['refresh_token'] ?? account.refreshToken,
      expiresAt: DateTime.now().add(
        Duration(seconds: int.parse(msTokens['expires_in'] ?? '86400')),
      ),
      skinUrl: skinUrl ?? account.skinUrl,
      capes: capes,
      activeCapeId: activeCapeId,
    );
  }

  // ── Skin upload ───────────────────────────────────────────────────────────

  /// Uploads a new skin file to the Minecraft profile.
  /// [variant] must be 'classic' or 'slim'.
  Future<void> uploadSkin({
    required String mcAccessToken,
    required String filePath,
    required String variant,
  }) async {
    final file = File(filePath);
    final formData = FormData.fromMap({
      'variant': variant,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: 'skin.png',
      ),
    });

    await _dio.post(
      'https://api.minecraftservices.com/minecraft/profile/skins',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $mcAccessToken',
        },
      ),
    );
  }

  Future<void> equipCape({
    required String mcAccessToken,
    required String capeId,
  }) async {
    await _dio.put(
      'https://api.minecraftservices.com/minecraft/profile/capes/active',
      data: {'capeId': capeId},
      options: Options(
        headers: {
          'Authorization': 'Bearer $mcAccessToken',
        },
      ),
    );
  }

  Future<void> unequipCape({
    required String mcAccessToken,
  }) async {
    await _dio.delete(
      'https://api.minecraftservices.com/minecraft/profile/capes/active',
      options: Options(
        headers: {
          'Authorization': 'Bearer $mcAccessToken',
        },
      ),
    );
  }

  /// Fetches the current profile for an account by re-fetching the profile.
  Future<String?> fetchSkinUrl(String mcAccessToken) async {
    final profile = await _fetchMinecraftProfile(mcAccessToken);
    return _extractSkinUrl(profile);
  }

  // ── WebView popup ─────────────────────────────────────────────────────────

  Future<String> _getCodeFromWebView(String url) async {
    final completer = Completer<String>();

    final dir = await getApplicationSupportDirectory();
    final webviewDir = Directory(p.join(dir.path, 'webview_cache'));
    
    // Safely wipe the cookies via Dart to prevent the C++ plugin race condition
    try {
      if (await webviewDir.exists()) {
        await webviewDir.delete(recursive: true);
      }
    } catch (_) {
      // Ignore if a background WebView2 process is lingering and holding a file lock
    }
    
    if (!await webviewDir.exists()) {
      await webviewDir.create(recursive: true);
    }
    final webviewPath = webviewDir.path;
    
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        windowHeight: 700,
        windowWidth: 500,
        title: 'Sign in to Microsoft',
        userDataFolderWindows: webviewPath,
      ),
    );

    webview.setOnUrlRequestCallback((urlStr) {
      if (urlStr.startsWith(_redirectUri)) {
        final uri = Uri.parse(urlStr);
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        if (code != null) {
          if (!completer.isCompleted) completer.complete(code);
          webview.close();
        } else if (error != null) {
          if (!completer.isCompleted) completer.completeError(Exception(error));
          webview.close();
        }
      }
      return false; // allow navigation by default
    });

    webview.onClose.whenComplete(() {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Login cancelled by user.'));
      }
    });

    webview.launch(url);

    return completer.future;
  }

  // ── Internal: OAuth token exchange (MSA v1.0) ───────────────────────────

  Future<Map<String, String>> _exchangeCodeForMsToken({
    required String code,
    required String redirectUri,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      'https://login.live.com/oauth20_token.srf',
      data: {
        'client_id': _clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'scope': _scopes,
      },
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        responseType: ResponseType.json,
      ),
    );
    final data = resp.data!;
    return {
      'access_token': data['access_token'] as String,
      'refresh_token': data['refresh_token'] as String? ?? '',
      'expires_in': data['expires_in'].toString(),
    };
  }

  Future<Map<String, String>> _refreshMsToken(String refreshToken) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      'https://login.live.com/oauth20_token.srf',
      data: {
        'client_id': _clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'scope': _scopes,
      },
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        responseType: ResponseType.json,
      ),
    );
    final data = resp.data!;
    return {
      'access_token': data['access_token'] as String,
      'refresh_token': data['refresh_token'] as String? ?? refreshToken,
      'expires_in': data['expires_in'].toString(),
    };
  }

  // ── Internal: Xbox Live ───────────────────────────────────────────────────

  Future<String> _authenticateWithXbl(String msAccessToken) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      'https://user.auth.xboxlive.com/user/authenticate',
      data: {
        'Properties': {
          'AuthMethod': 'RPS',
          'SiteName': 'user.auth.xboxlive.com',
          'RpsTicket': 't=$msAccessToken',
        },
        'RelyingParty': 'http://auth.xboxlive.com',
        'TokenType': 'JWT',
      },
      options: Options(
        contentType: 'application/json',
        headers: {'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
    return resp.data!['Token'] as String;
  }

  // ── Internal: XSTS ───────────────────────────────────────────────────────

  Future<Map<String, String>> _authenticateWithXsts(String xblToken) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      'https://xsts.auth.xboxlive.com/xsts/authorize',
      data: {
        'Properties': {
          'SandboxId': 'RETAIL',
          'UserTokens': [xblToken],
        },
        'RelyingParty': 'rp://api.minecraftservices.com/',
        'TokenType': 'JWT',
      },
      options: Options(
        contentType: 'application/json',
        headers: {'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );

    final data = resp.data!;
    final xErr = data['XErr'];
    if (xErr != null) {
      final msg = _xstsError(xErr.toString());
      throw Exception(msg);
    }

    final userHash =
        (data['DisplayClaims']['xui'] as List).first['uhs'] as String;
    final xstsToken = data['Token'] as String;
    return {'xstsToken': xstsToken, 'userHash': userHash};
  }

  String _xstsError(String xErr) {
    return switch (xErr) {
      '2148916233' =>
        'This Microsoft account has no Xbox account. Please create one at xbox.com.',
      '2148916235' => 'Xbox is not available in your region.',
      '2148916236' ||
      '2148916237' =>
        'Your account requires adult verification on xbox.com.',
      '2148916238' =>
        'This is a child account. Add it to a Microsoft Family to continue.',
      _ => 'Xbox authentication error: $xErr',
    };
  }

  // ── Internal: Minecraft auth ──────────────────────────────────────────────

  Future<Map<String, String>> _loginWithMinecraft(
    String xstsToken,
    String userHash,
  ) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      'https://api.minecraftservices.com/authentication/login_with_xbox',
      data: {'identityToken': 'XBL3.0 x=$userHash;$xstsToken'},
      options: Options(
        contentType: 'application/json',
        headers: {'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
    final data = resp.data!;
    return {
      'accessToken': data['access_token'] as String,
      'expiresIn': data['expires_in'].toString(),
    };
  }

  // ── Internal: MC profile ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchMinecraftProfile(
      String mcAccessToken) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      'https://api.minecraftservices.com/minecraft/profile',
      options: Options(
        headers: {
          'Authorization': 'Bearer $mcAccessToken',
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
        validateStatus: (s) => true, // handle 404 manually
      ),
    );
    if (resp.statusCode == 404) {
      throw Exception(
        'This Microsoft account does not own Minecraft.\n'
        'Please purchase Minecraft at minecraft.net and try again.',
      );
    }
    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to fetch Minecraft profile (${resp.statusCode}).');
    }
    return resp.data!;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extracts the active skin URL from a Minecraft profile response.
  String? _extractSkinUrl(Map<String, dynamic> profile) {
    final skins = profile['skins'] as List<dynamic>?;
    if (skins == null || skins.isEmpty) return null;
    // Find the active skin
    for (final skin in skins) {
      if ((skin as Map<String, dynamic>)['state'] == 'ACTIVE') {
        return skin['url'] as String?;
      }
    }
    // Fallback to first skin
    return (skins.first as Map<String, dynamic>)['url'] as String?;
  }

  List<MinecraftCape> _extractCapes(Map<String, dynamic> profile) {
    final capesList = profile['capes'] as List<dynamic>?;
    if (capesList == null || capesList.isEmpty) return [];

    return capesList.map((c) {
      final map = c as Map<String, dynamic>;
      return MinecraftCape(
        id: map['id'] as String,
        alias: map['alias'] as String,
        url: map['url'] as String,
      );
    }).toList();
  }

  String? _extractActiveCapeId(Map<String, dynamic> profile) {
    final capesList = profile['capes'] as List<dynamic>?;
    if (capesList == null || capesList.isEmpty) return null;

    for (final c in capesList) {
      final map = c as Map<String, dynamic>;
      if (map['state'] == 'ACTIVE') {
        return map['id'] as String?;
      }
    }
    return null;
  }

  String _formatUuid(String raw) {
    // Mojang returns UUID without hyphens
    if (raw.contains('-')) return raw;
    return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-'
        '${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20)}';
  }
}
