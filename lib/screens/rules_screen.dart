import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/rules_service.dart';

const _background = Color(0xFF111111);
const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlRulesScreen extends StatefulWidget {
  const NdrlRulesScreen({super.key});
  @override
  State<NdrlRulesScreen> createState() => _NdrlRulesScreenState();
}

class _NdrlRulesScreenState extends State<NdrlRulesScreen> {
  late Future<Map<String, dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = NdrlRulesService.load();
  }

  void _reload() {
    setState(() {
      _request = NdrlRulesService.load();
    });
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _notify('The rulebook link is unavailable.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _notify('Unable to open the rulebook.');
      }
    } catch (_) {
      _notify('Unable to open the rulebook.');
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _card(String title, Widget content) => Card(
    color: _surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      title: const Text('NDRL Rules'),
      actions: [
        IconButton(
          tooltip: 'Refresh rules',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _red));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load the current rules.'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final payload = snapshot.data!;
        final rulebook = payload['rulebook'] as Map<String, dynamic>;
        final title = (rulebook['title'] ?? 'Official NDRL Rulebook')
            .toString();
        final edition = (rulebook['edition'] ?? '').toString();
        final effective = (rulebook['effective_date'] ?? '').toString();
        final pdf = (rulebook['pdf_url'] ?? '').toString();
        final classRules = payload['class_rules'];
        final classEnabled = classRules is Map && classRules['enabled'] == true;
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Center(
              child: Image.asset(
                'assets/images/ndrl_logo.png',
                height: 135,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            _card(
              'OFFICIAL RULEBOOK',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: _gold,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (edition.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Edition: $edition'),
                  ],
                  if (effective.isNotEmpty) Text('Effective: $effective'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _red),
                      onPressed: pdf.isEmpty ? null : () => _openPdf(pdf),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View Current Rulebook (PDF)'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Opens the official PDF in your device browser or PDF viewer.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            _card(
              'RULES BY CLASS',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classEnabled
                        ? 'Class-specific rules will be available here.'
                        : 'Coming soon: rules tailored to your racing class, including applicable general rules.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The official PDF above remains the authoritative source.',
                    style: TextStyle(color: _gold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
