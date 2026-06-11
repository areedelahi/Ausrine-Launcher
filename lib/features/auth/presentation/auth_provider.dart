import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/platform/file_service.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import '../domain/user_account.dart';
import '../data/ms_auth_service.dart';

const _kAccountsFileName = 'accounts.dat';
const _kAccountsKey = 'ausrine_launcher_accounts';

// Fixed encryption key - secure storage only used on non-macOS platforms
final _encKey = enc.Key(Uint8List.fromList(
  'Ausrinė LauncherV1SecretKey!XMCLS1'.codeUnits,
));
final _encrypter = enc.Encrypter(enc.AES(_encKey, mode: enc.AESMode.cbc));

enum AuthStatus { idle, signingIn, refreshing, error }

class AuthState {
  const AuthState({
    this.accounts = const [],
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.refreshingUuid,
  });

  final List<UserAccount> accounts;
  final AuthStatus status;
  final String? errorMessage;

  final String? refreshingUuid;

  UserAccount? get activeAccount {
    for (final a in accounts) {
      if (a.isActive) return a;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  bool get isSigningIn => status == AuthStatus.signingIn;

  bool get hasMicrosoftAccount => accounts.any((a) => a.type == 'microsoft');

  AuthState copyWith({
    List<UserAccount>? accounts,
    AuthStatus? status,
    String? errorMessage,
    String? refreshingUuid,
    bool clearRefreshingUuid = false,
    bool clearError = false,
  }) {
    return AuthState(
      accounts: accounts ?? this.accounts,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      refreshingUuid:
          clearRefreshingUuid ? null : (refreshingUuid ?? this.refreshingUuid),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    // Load persisted accounts from disk on startup
    _load();
  }

  final _ms = MsAuthService();
  final _uuid = const Uuid();

  // macOS uses unencrypted file storage; other platforms use secure storage
  static bool get _useSecureStorage => !Platform.isMacOS;

  final _secureStorage = const FlutterSecureStorage();

  Future<File> _getStorageFile() async {
    final dir = await getAusrineSupportDirectory();
    return File('${dir.path}/$_kAccountsFileName');
  }

  Future<void> _load() async {
    try {
      if (_useSecureStorage) {

        final raw = await _secureStorage.read(key: _kAccountsKey);
        if (raw == null) return;
        final list = (jsonDecode(raw) as List)
            .map((e) => UserAccount.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(accounts: list);
      } else {

        final file = await _getStorageFile();
        if (!await file.exists()) return;
        final raw = await file.readAsString();
        final parts = raw.split(':');
        if (parts.length != 2) return;
        final iv = enc.IV.fromBase64(parts[0]);
        final decrypted = _encrypter.decrypt64(parts[1], iv: iv);
        final list = (jsonDecode(decrypted) as List)
            .map((e) => UserAccount.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(accounts: list);
      }
    } catch (_) {

      if (_useSecureStorage) {
        await _secureStorage.delete(key: _kAccountsKey);
      } else {
        final file = await _getStorageFile();
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<void> _save() async {
    final plaintext =
        jsonEncode(state.accounts.map((a) => a.toJson()).toList());
    if (_useSecureStorage) {
      await _secureStorage.write(key: _kAccountsKey, value: plaintext);
    } else {
      final file = await _getStorageFile();
      final iv = enc.IV.fromSecureRandom(16);
      final encrypted = _encrypter.encrypt(plaintext, iv: iv);
      await file.writeAsString('${iv.base64}:${encrypted.base64}');
    }
  }

  Future<void> loginWithMicrosoft(BuildContext context) async {
    if (state.isSigningIn) return;
    state = state.copyWith(status: AuthStatus.signingIn, errorMessage: null);

    try {
      final account = await _ms.loginWithBrowser(context);

      final existingIndex =
          state.accounts.indexWhere((a) => a.uuid == account.uuid);

      List<UserAccount> updated;
      if (existingIndex >= 0) {

        updated = List.from(state.accounts);
        updated[existingIndex] = account.copyWith(isActive: true);

        updated = updated
            .asMap()
            .entries
            .map((e) => e.value.copyWith(isActive: e.key == existingIndex))
            .toList();
      } else {

        updated =
            state.accounts.map((a) => a.copyWith(isActive: false)).toList();
        updated.add(account.copyWith(isActive: true));
      }

      state = state.copyWith(accounts: updated, status: AuthStatus.idle);
      await _save();
    } on Exception catch (e, stack) {
      String msg = e.toString();
      if (e is DioException && e.response != null) {
        msg = 'DioError: ${e.response?.statusCode} - ${e.response?.data}';
      }
      print('OAUTH ERROR: $msg');
      print(stack);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyError(msg),
      );
    }
  }

  Future<void> refreshIfNeeded(String uuid) async {
    final index = state.accounts.indexWhere((a) => a.uuid == uuid);
    if (index < 0) return;
    final account = state.accounts[index];
    if (!account.isExpired || account.type != 'microsoft') return;

    try {
      final refreshed = await _ms.refreshAccount(account);
      final updated = List<UserAccount>.from(state.accounts);
      updated[index] = refreshed;
      state = state.copyWith(accounts: updated);
      await _save();
    } catch (_) {

    }
  }

  Future<void> refreshAccount(String uuid) async {
    final index = state.accounts.indexWhere((a) => a.uuid == uuid);
    if (index < 0) return;
    final account = state.accounts[index];
    if (account.type != 'microsoft') return;

    state = state.copyWith(
      status: AuthStatus.refreshing,
      refreshingUuid: uuid,
    );

    try {
      final refreshed = await _ms.refreshAccount(account);
      final updated = List<UserAccount>.from(state.accounts);
      updated[index] = refreshed;
      state = state.copyWith(
        accounts: updated,
        status: AuthStatus.idle,
        clearRefreshingUuid: true,
      );
      await _save();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.idle,
        clearRefreshingUuid: true,
      );
      rethrow;
    }
  }

  Future<void> uploadSkin({
    required String uuid,
    required String filePath,
    required String variant,
  }) async {
    final index = state.accounts.indexWhere((a) => a.uuid == uuid);
    if (index < 0) return;
    final account = state.accounts[index];
    if (account.type != 'microsoft') return;

    await _ms.uploadSkin(
      mcAccessToken: account.accessToken,
      filePath: filePath,
      variant: variant,
    );

    final currentSkinUrl = account.skinUrl;
    for (int i = 0; i < 12; i++) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        final newSkinUrl = await _ms.fetchSkinUrl(account.accessToken);
        if (newSkinUrl != currentSkinUrl) break; 
      } catch (_) {}
    }

    await refreshAccount(uuid);
  }

  Future<void> setCape({
    required String uuid,
    required String? capeId, 
  }) async {
    final index = state.accounts.indexWhere((a) => a.uuid == uuid);
    if (index < 0) return;
    final account = state.accounts[index];
    if (account.type != 'microsoft') return;

    if (capeId == null) {
      await _ms.unequipCape(mcAccessToken: account.accessToken);
    } else {
      await _ms.equipCape(
        mcAccessToken: account.accessToken,
        capeId: capeId,
      );
    }

    final updated = List<UserAccount>.from(state.accounts);
    updated[index] = account.copyWith(activeCapeId: capeId);
    state = state.copyWith(accounts: updated);
    await _save();

    refreshAccount(uuid);
  }

  void addOfflineAccount(String username) {

    if (!state.hasMicrosoftAccount) return;

    final trimmed = username.trim();
    if (trimmed.isEmpty) return;

    final exists = state.accounts.any(
      (a) =>
          a.type == 'offline' &&
          a.username.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) return;

    final id = _generateOfflineUuid(trimmed);
    final account = UserAccount(
      uuid: id,
      username: trimmed,
      type: 'offline',
      accessToken: '',
      refreshToken: '',
      expiresAt: DateTime(9999), 
      isActive: true,
    );

    final current =
        state.accounts.map((a) => a.copyWith(isActive: false)).toList();
    current.add(account);

    state = state.copyWith(accounts: current);
    _save();
  }

  String _generateOfflineUuid(String username) {
    final data = utf8.encode('OfflinePlayer:$username');
    final hashBytes = md5.convert(data).bytes;

    final modified = List<int>.from(hashBytes);

    modified[6] = (modified[6] & 0x0f) | 0x30;

    modified[8] = (modified[8] & 0x3f) | 0x80;

    String hex(List<int> bytes) =>
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '${hex(modified.sublist(0, 4))}-${hex(modified.sublist(4, 6))}-${hex(modified.sublist(6, 8))}-${hex(modified.sublist(8, 10))}-${hex(modified.sublist(10, 16))}';
  }

  void setActive(String uuid) {
    final updated = state.accounts.map((a) {
      return a.copyWith(isActive: a.uuid == uuid);
    }).toList();
    state = state.copyWith(accounts: updated);
    _save();
  }

  void removeAccount(String uuid) {
    var updated = state.accounts.where((a) => a.uuid != uuid).toList();

    if (updated.isNotEmpty && !updated.any((a) => a.isActive)) {
      updated = [updated.first.copyWith(isActive: true), ...updated.skip(1)];
    }
    state = state.copyWith(accounts: updated);
    _save();
  }

  void clearError() {
    state = state.copyWith(status: AuthStatus.idle, clearError: true);
  }

  String _friendlyError(String raw) {
    if (raw.contains('Could not open browser')) {
      return 'Could not open browser. Please set a default browser and try again.';
    }
    if (raw.contains('timed out')) return 'Login timed out. Please try again.';
    if (raw.contains('xbox.com')) return raw;
    if (raw.contains('child account')) return raw;

    return 'Sign-in failed: $raw';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
