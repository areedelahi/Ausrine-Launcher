import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../domain/user_account.dart';
import '../presentation/microsoft_login_screen.dart';

const _clientId = '00000000402b5328';
const _scopes = 'service::user.auth.xboxlive.com::MBI_SSL';
const _redirectUri = 'https://login.live.com/oauth20_desktop.srf';

class MsAuthService {
  final _dio = Dio();

  MsAuthService() {
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: false, 
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  Future<UserAccount> loginWithBrowser(BuildContext context) async {

    final authUrl = Uri.https(
      'login.live.com',
      '/oauth20_authorize.srf',
      {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri':
            _redirectUri, 
        'scope': _scopes,
      },
    );

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MicrosoftLoginScreen(
          authUrl: authUrl.toString(),
          redirectUri: _redirectUri,
        ),
      ),
    );

    if (result == null) {
      throw Exception('Login cancelled by user.');
    }
    
    String code = result as String;

    final msTokens = await _exchangeCodeForMsToken(
      code: code,
      redirectUri: _redirectUri,
    );

    final xblToken = await _authenticateWithXbl(msTokens['access_token']!);

    final xstsResult = await _authenticateWithXsts(xblToken);

    final mcTokens = await _loginWithMinecraft(
      xstsResult['xstsToken']!,
      xstsResult['userHash']!,
    );

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

  Future<UserAccount> refreshAccount(UserAccount account) async {
    if (account.type != 'microsoft') return account;

    final msTokens = await _refreshMsToken(account.refreshToken);
    final xblToken = await _authenticateWithXbl(msTokens['access_token']!);
    final xstsResult = await _authenticateWithXsts(xblToken);
    final mcTokens = await _loginWithMinecraft(
      xstsResult['xstsToken']!,
      xstsResult['userHash']!,
    );

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

  Future<String?> fetchSkinUrl(String mcAccessToken) async {
    final profile = await _fetchMinecraftProfile(mcAccessToken);
    return _extractSkinUrl(profile);
  }



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
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        'https://login.live.com/oauth20_token.srf',
        data: {
          'client_id': _clientId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'redirect_uri': _redirectUri,
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(
            "Your Microsoft session has expired. Please sign in again.");
      }
      rethrow;
    }
  }

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
        validateStatus: (s) => true, 
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

  String? _extractSkinUrl(Map<String, dynamic> profile) {
    final skins = profile['skins'] as List<dynamic>?;
    if (skins == null || skins.isEmpty) return null;

    for (final skin in skins) {
      if ((skin as Map<String, dynamic>)['state'] == 'ACTIVE') {
        return skin['url'] as String?;
      }
    }

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

    if (raw.contains('-')) return raw;
    return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-'
        '${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20)}';
  }
}
