class NewsItem {
  final String id;
  final String title;
  final String category;
  final String date;
  final String text;
  final String imageUrl;
  final String readMoreLink;

  NewsItem({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.text,
    required this.imageUrl,
    required this.readMoreLink,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    String imageUrl = '';
    final playPageImage = json['playPageImage'] as Map<String, dynamic>?;
    final newsPageImage = json['newsPageImage'] as Map<String, dynamic>?;

    if (newsPageImage != null && newsPageImage['url'] != null) {
      imageUrl = 'https://launchercontent.mojang.com' + newsPageImage['url'].toString();
    } else if (playPageImage != null && playPageImage['url'] != null) {
      imageUrl = 'https://launchercontent.mojang.com' + playPageImage['url'].toString();
    }

    return NewsItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? 'News',
      date: json['date'] ?? '',
      text: json['text'] ?? '',
      imageUrl: imageUrl,
      readMoreLink: json['readMoreLink'] ?? '',
    );
  }
}
