import 'package:flutter/material.dart';

import '../services/bounty_service.dart';
import 'bounty_detail_screen.dart';
import 'bounty_submit_screen.dart';
import 'my_bounties_screen.dart';
import '../services/auth_service.dart';

const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _surface = Color(0xFF111626);

class NdrlBountyBoardScreen extends StatefulWidget {
  const NdrlBountyBoardScreen({super.key, required this.authService});
  final AuthService authService;
  @override
  State<NdrlBountyBoardScreen> createState() => _NdrlBountyBoardScreenState();
}

class _NdrlBountyBoardScreenState extends State<NdrlBountyBoardScreen> {
  final BountyService _service = BountyService();
  BountyBoardData? _board;
  bool _loading = true;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final board = await _service.load();
      if (mounted) setState(() => _board = board);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to load the Bounty Board. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final items = board == null
        ? <BountyRecord>[]
        : board.bounties
              .where((b) => _tab == 0 ? !b.isClaimed : b.isClaimed)
              .toList();
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: const Text('BOUNTY BOARD'),
        backgroundColor: const Color(0xFF111111),
        actions: [
          IconButton(
            tooltip: 'My Bounties',
            icon: const Icon(Icons.assignment_outlined, color: _gold),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    NdrlMyBountiesScreen(authService: widget.authService),
              ),
            ),
          ),
          if (board != null)
            IconButton(
              tooltip: 'Submit bounty',
              icon: const Icon(Icons.add_circle_outline, color: _gold),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NdrlBountySubmitScreen(
                    authService: widget.authService,
                    event: board.event,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _red,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'NDRL BOUNTY BOARD',
              style: TextStyle(
                color: _gold,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              board?.event.name ?? 'Current event',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Active'),
                  icon: Icon(Icons.gps_fixed),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Claimed'),
                  icon: Icon(Icons.emoji_events_outlined),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(color: _red),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
            if (!_loading && _error == null && board == null)
              const _EmptyMessage('No current event is available.'),
            if (!_loading && _error == null && board != null && items.isEmpty)
              _EmptyMessage(
                _tab == 0
                    ? 'No active bounties for this event.'
                    : 'No claimed bounties for this event.',
              ),
            if (!_loading && _error == null)
              for (final bounty in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BountyCard(bounty: bounty),
                ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 65),
    child: Column(
      children: [
        const Icon(Icons.flag_outlined, color: _gold, size: 48),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );
}

class _BountyCard extends StatelessWidget {
  const _BountyCard({required this.bounty});
  final BountyRecord bounty;

  @override
  Widget build(BuildContext context) {
    final claimed = bounty.isClaimed;
    final showingClaimPhoto = claimed && bounty.claimPhoto != null;
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NdrlBountyDetailScreen(bounty: bounty),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (claimed)
              Container(
                width: double.infinity,
                color: const Color(0xFF302817),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.emoji_events, color: _gold, size: 20),
                    SizedBox(width: 9),
                    Text(
                      'BOUNTY COLLECTED',
                      style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            _BountyImage(
              url: claimed
                  ? bounty.claimPhoto ?? bounty.artwork
                  : bounty.artwork,
              height: 180,
            ),
            if (showingClaimPhoto)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 7, 16, 0),
                child: Text(
                  'CLAIM PHOTO',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bounty.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bounty.amount,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'TARGET RACER',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${bounty.targetName} · ${bounty.className}${bounty.carNumber.isEmpty ? '' : ' · #${bounty.carNumber}'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (bounty.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      bounty.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (claimed) ...[
                    const Divider(color: Color(0xFF303647), height: 18),
                    const Text(
                      'BOUNTY CLAIMED BY',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      bounty.claimedBy,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Elimination round: ${bounty.round}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242428),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF4C5260)),
                      ),
                      child: Text(
                        'PAYMENT: ${bounty.paymentStatus.toUpperCase()}',
                        style: const TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ] else
                    const Text(
                      'ACTIVE · UNCLAIMED',
                      style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BountyImage extends StatelessWidget {
  const _BountyImage({required this.url, required this.height});
  final Uri? url;
  final double height;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFF242428),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 48, color: _gold),
          SizedBox(height: 8),
          Text(
            'NDRL BOUNTY BOARD',
            style: TextStyle(color: _gold, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
    if (url == null) return fallback;
    return Image.network(
      url.toString(),
      width: double.infinity,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : SizedBox(
              height: height,
              child: const Center(
                child: CircularProgressIndicator(color: _gold),
              ),
            ),
    );
  }
}
