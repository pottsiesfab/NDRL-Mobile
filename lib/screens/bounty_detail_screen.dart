import 'package:flutter/material.dart';

import '../services/bounty_service.dart';

const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _background = Color(0xFF111111);
const _surface = Color(0xFF111626);

/// Read-only bounty details using the record already loaded by the board.
/// No additional API endpoint or authentication is required.
class NdrlBountyDetailScreen extends StatelessWidget {
  const NdrlBountyDetailScreen({super.key, required this.bounty});

  final BountyRecord bounty;

  @override
  Widget build(BuildContext context) {
    final claimed = bounty.isClaimed;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('BOUNTY DETAILS'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: claimed
                  ? const Color(0xFF302817)
                  : const Color(0xFF222A24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  claimed ? Icons.emoji_events : Icons.gps_fixed,
                  color: _gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    claimed ? 'BOUNTY COLLECTED' : 'ACTIVE BOUNTY',
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            bounty.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bounty.amount,
            style: const TextStyle(
              color: _gold,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          if (bounty.poster != null) ...[
            const _SectionLabel('BOUNTY POSTER'),
            _Photo(url: bounty.poster),
            const SizedBox(height: 16),
          ],
          const _SectionLabel('TARGET RACER'),
          _InfoPanel(
            children: [
              _InfoLine(label: 'Racer', value: bounty.targetName),
              _InfoLine(label: 'Class', value: bounty.className),
              if (bounty.carNumber.isNotEmpty)
                _InfoLine(label: 'Car number', value: '#${bounty.carNumber}'),
              if (bounty.carDescription.isNotEmpty)
                _InfoLine(label: 'Car', value: bounty.carDescription),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionLabel('TARGET PHOTO'),
          _Photo(url: bounty.targetPhoto),
          if (bounty.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionLabel('BOUNTY DESCRIPTION'),
            _InfoPanel(
              children: [
                Text(
                  bounty.description,
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (claimed) ...[
            const _SectionLabel('CLAIM INFORMATION'),
            _InfoPanel(
              children: [
                _InfoLine(label: 'Claimed by', value: bounty.claimedBy),
                _InfoLine(label: 'Elimination round', value: bounty.round),
                _InfoLine(
                  label: 'Payment',
                  value: bounty.paymentStatus.toUpperCase(),
                ),
              ],
            ),
            if (bounty.claimPhoto != null) ...[
              const SizedBox(height: 16),
              const _SectionLabel('CLAIM PHOTO'),
              _Photo(url: bounty.claimPhoto),
            ],
          ] else
            const _InfoPanel(
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_outlined, color: _gold, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This bounty has not been claimed.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'NDRL BOUNTY BOARD',
              style: TextStyle(
                color: _red,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        color: _gold,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
    ],
  );
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});
  final Uri? url;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: 200,
      width: double.infinity,
      color: const Color(0xFF242428),
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, color: _gold, size: 42),
          SizedBox(height: 8),
          Text(
            'NO PHOTO AVAILABLE',
            style: TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: url == null
          ? fallback
          : Image.network(
              url.toString(),
              width: double.infinity,
              height: 260,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => fallback,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 260,
                      child: Center(
                        child: CircularProgressIndicator(color: _gold),
                      ),
                    ),
            ),
    );
  }
}
