import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/news_service.dart';

class NdrlNewsArticleScreen extends StatefulWidget {
  const NdrlNewsArticleScreen({
    super.key,
    required this.slug,
    required this.title,
  });
  final String slug;
  final String title;

  @override
  State<NdrlNewsArticleScreen> createState() => _NdrlNewsArticleScreenState();
}

class _NdrlNewsArticleScreenState extends State<NdrlNewsArticleScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final articleUri = NdrlNewsService.articleUrl(widget.slug);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF111111))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted)
              setState(() {
                _loading = true;
                _failed = false;
              });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
          onNavigationRequest: (request) {
            final next = Uri.tryParse(request.url);
            if (next == null ||
                next.scheme != 'https' ||
                next.host != articleUri.host ||
                next.path != articleUri.path ||
                next.queryParameters['slug'] != widget.slug) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(articleUri);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF111111),
    appBar: AppBar(
      backgroundColor: const Color(0xFF111111),
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Reload article',
          icon: const Icon(Icons.refresh),
          onPressed: () => _controller.reload(),
        ),
      ],
    ),
    body: Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading) const LinearProgressIndicator(color: Color(0xFFB91C1C)),
        if (_failed)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load this article.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _controller.reload(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
