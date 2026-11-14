import 'package:flutter/material.dart';

import '../services/news_service.dart';
import 'news_article_screen.dart';

const _newsBg = Color(0xFF111111);
const _newsSurface = Color(0xFF242428);
const _newsGold = Color(0xFFD1AC67);

class NdrlNewsScreen extends StatefulWidget {
  const NdrlNewsScreen({super.key});
  @override
  State<NdrlNewsScreen> createState() => _NdrlNewsScreenState();
}

class _NdrlNewsScreenState extends State<NdrlNewsScreen> {
  int? _year;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = NdrlNewsService.list();
  }

  void _load({int? year}) {
    setState(() {
      _year = year;
      _future = NdrlNewsService.list(year: year);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _newsBg,
    appBar: AppBar(
      backgroundColor: _newsBg,
      title: const Text('NDRL News'),
      actions: [
        IconButton(
          tooltip: 'Refresh news',
          icon: const Icon(Icons.refresh),
          onPressed: () => _load(year: _year),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load NDRL news.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _load(year: _year),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final data = snapshot.data!;
        final years = (data['years'] as List)
            .whereType<num>()
            .map((y) => y.toInt())
            .toList();
        final articles = (data['articles'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        return RefreshIndicator(
          onRefresh: () async {
            final next = NdrlNewsService.list(year: _year);
            setState(() {
              _future = next;
            });
            await next;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PRESS RELEASES',
                      style: TextStyle(
                        color: _newsGold,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  DropdownButton<int?>(
                    value: _year,
                    dropdownColor: _newsSurface,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All years'),
                      ),
                      for (final year in years)
                        DropdownMenuItem<int?>(
                          value: year,
                          child: Text('$year'),
                        ),
                    ],
                    onChanged: (year) => _load(year: year),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (articles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No press releases found.'),
                ),
              for (final article in articles)
                Card(
                  color: _newsSurface,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      (article['title'] ?? '').toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${article['date'] ?? ''}  •  ${article['author'] ?? ''}',
                            style: const TextStyle(color: _newsGold),
                          ),
                          if ((article['excerpt'] ?? '')
                              .toString()
                              .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text((article['excerpt'] ?? '').toString()),
                          ],
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NdrlNewsArticleScreen(
                          slug: (article['slug'] ?? '').toString(),
                          title: (article['title'] ?? '').toString(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
