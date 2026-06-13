import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/news_item.dart';

class NewsNotifier extends AsyncNotifier<List<NewsItem>> {
  @override
  Future<List<NewsItem>> build() async {
    return _fetchNews();
  }

  Future<List<NewsItem>> _fetchNews() async {
    final dio = Dio();
    final response = await dio.get('https://launchercontent.mojang.com/news.json');

    if (response.statusCode == 200) {

      final Map<String, dynamic> data = response.data is String ? jsonDecode(response.data) : response.data;
      final entries = data['entries'] as List<dynamic>?;

      if (entries != null) {
        return entries.map((e) => NewsItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    }

    throw Exception('Failed to load news');
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchNews);
  }
}

final newsProvider = AsyncNotifierProvider<NewsNotifier, List<NewsItem>>(() {
  return NewsNotifier();
});
