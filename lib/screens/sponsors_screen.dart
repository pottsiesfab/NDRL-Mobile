import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sponsor.dart';
import '../services/sponsor_service.dart';

const _background = Color(0xFF111111);
const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);

class NdrlSponsorsScreen extends StatefulWidget {
  const NdrlSponsorsScreen({super.key});

  @override
  State<NdrlSponsorsScreen> createState() => _NdrlSponsorsScreenState();
}

class _NdrlSponsorsScreenState extends State<NdrlSponsorsScreen> {
  List<NdrlSponsor>? _sponsors;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sponsors = await SponsorService.getSponsors();
      if (!mounted) return;
      setState(() => _sponsors = sponsors);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            'Unable to load sponsors. Check your connection and try again.',
      );
      debugPrint('Sponsor directory load failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWebsite(Uri url) async {
    try {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showLinkError();
    } catch (_) {
      if (mounted) _showLinkError();
    }
  }

  void _showLinkError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open sponsor website.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('Our Sponsors'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'NDRL SPONSORS',
              style: TextStyle(
                color: _gold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thank you to the businesses supporting nostalgia drag racing.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            if (_loading && _sponsors == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_sponsors != null && _sponsors!.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No sponsors are listed yet.')),
              ),
            if (_sponsors != null)
              for (final sponsor in _sponsors!) ...[
                _SponsorCard(
                  sponsor: sponsor,
                  onVisit: sponsor.clickUrl == null
                      ? null
                      : () => _openWebsite(sponsor.clickUrl!),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _SponsorCard extends StatelessWidget {
  const _SponsorCard({required this.sponsor, required this.onVisit});

  final NdrlSponsor sponsor;
  final VoidCallback? onVisit;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _surface,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sponsor.logoUrl != null) ...[
              Center(
                child: Image.network(
                  sponsor.logoUrl.toString(),
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 70,
                    child: Center(
                      child: Icon(
                        Icons.business,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              sponsor.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (sponsor.description != null &&
                sponsor.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                sponsor.description!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if (onVisit != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onVisit,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Visit Website'),
                  style: TextButton.styleFrom(foregroundColor: _gold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
