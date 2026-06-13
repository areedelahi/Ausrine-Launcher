import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MicrosoftLoginScreen extends StatefulWidget {
  final String authUrl;
  final String redirectUri;

  const MicrosoftLoginScreen({
    super.key,
    required this.authUrl,
    required this.redirectUri,
  });

  @override
  State<MicrosoftLoginScreen> createState() => _MicrosoftLoginScreenState();
}

class _MicrosoftLoginScreenState extends State<MicrosoftLoginScreen> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  bool _isCompleting = false;
  bool _cookiesCleared = false;

  @override
  void initState() {
    super.initState();
    _setupAndClearCookies();
  }

  Future<void> _setupAndClearCookies() async {
    await _clearCookies();
    if (mounted) {
      setState(() {
        _cookiesCleared = true;
      });
    }
  }

  Future<void> _clearCookies() async {
    final cookieManager = CookieManager.instance();
    await cookieManager.deleteAllCookies();
  }

  bool _handleAuthUrl(Uri uri) {
    if (!uri.toString().startsWith(widget.redirectUri) || _isCompleting) {
      return false;
    }

    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (code != null) {
      unawaited(_finish(code));
    } else if (error != null) {
      final description = uri.queryParameters['error_description'];
      unawaited(_finish(Exception(description ?? error)));
    }

    return true;
  }

  Future<void> _finish(Object result) async {
    if (_isCompleting) return;
    _isCompleting = true;
    
    // Clean up one more time before popping
    await _clearCookies();

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to Microsoft', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1D24),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF0C0E13),
      body: _cookiesCleared 
        ? InAppWebView(
            key: webViewKey,
            initialUrlRequest: URLRequest(url: WebUri(widget.authUrl)),
        initialSettings: InAppWebViewSettings(
          clearCache: true,
          clearSessionCache: true,
          javaScriptEnabled: true,
          transparentBackground: true,
        ),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        onLoadStart: (controller, url) {
          if (url != null) _handleAuthUrl(url);
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final uri = navigationAction.request.url;
          if (uri != null && _handleAuthUrl(uri)) {
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      )
      : const Center(
          child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
        ),
    );
  }
}
