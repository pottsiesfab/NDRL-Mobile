import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'bounty_edit_screen.dart';
import '../services/my_bounties_service.dart';

const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _surface = Color(0xFF111626);

class NdrlMyBountiesScreen extends StatefulWidget {
  const NdrlMyBountiesScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<NdrlMyBountiesScreen> createState() => _NdrlMyBountiesScreenState();
}

class _NdrlMyBountiesScreenState extends State<NdrlMyBountiesScreen> {
  late final MyBountiesService _service = MyBountiesService(widget.authService);
  List<MyBounty> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.list();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF111111),
    appBar: AppBar(
      backgroundColor: const Color(0xFF111111),
      title: const Text('MY BOUNTIES'),
      actions: [
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
            'YOUR SUBMISSIONS',
            style: TextStyle(
              color: _gold,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Review bounties you have submitted.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          if (_loading) const LinearProgressIndicator(color: _red),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
          if (!_loading && _error == null && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 55),
              child: Center(
                child: Text(
                  'You have not submitted any bounties yet.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          if (!_loading && _error == null)
            for (final bounty in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: _surface,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: bounty.id <= 0
                        ? null
                        : () => Navigator.of(context)
                              .push(
                                MaterialPageRoute<void>(
                                  builder: (_) => NdrlMyBountyDetailScreen(
                                    authService: widget.authService,
                                    bountyId: bounty.id,
                                  ),
                                ),
                              )
                              .then((_) => _refresh()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bounty.image != null)
                          Image.network(
                            bounty.image.toString(),
                            height: 145,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                                  height: 80,
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      bounty.title,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _StatusChip(bounty.statusLabel),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                bounty.amount,
                                style: const TextStyle(
                                  color: _gold,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${bounty.racerName}${bounty.className.isEmpty ? '' : ' · ${bounty.className}'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bounty.eventName,
                                style: const TextStyle(color: Colors.white54),
                              ),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Icon(
                                    bounty.editable
                                        ? Icons.edit_outlined
                                        : Icons.lock_outline,
                                    size: 16,
                                    color: _gold,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    bounty.editable
                                        ? 'Pending · Details available'
                                        : 'Read-only',
                                    style: const TextStyle(
                                      color: _gold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right, color: _gold),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}

class NdrlMyBountyDetailScreen extends StatefulWidget {
  const NdrlMyBountyDetailScreen({
    super.key,
    required this.authService,
    required this.bountyId,
  });
  final AuthService authService;
  final int bountyId;

  @override
  State<NdrlMyBountyDetailScreen> createState() =>
      _NdrlMyBountyDetailScreenState();
}

class _NdrlMyBountyDetailScreenState extends State<NdrlMyBountyDetailScreen> {
  MyBounty? _bounty;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bounty = await MyBountiesService(widget.authService)
          .detail(widget.bountyId);
      if (mounted) setState(() => _bounty = bounty);
    } catch (error) {
      if (mounted) {
        setState(() {
          _bounty = null;
          _error = '$error';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounty = _bounty;
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('BOUNTY DETAILS'),
        actions: [
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
            if (_loading) const LinearProgressIndicator(color: _red),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
            if (!_loading && bounty != null) ...[
              if (bounty.image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    bounty.image.toString(),
                    height: 210,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 120,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bounty.title,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusChip(bounty.statusLabel),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                bounty.amount,
                style: const TextStyle(
                  color: _gold,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _InfoRow('Event', bounty.eventName),
              _InfoRow('Target', bounty.racerName),
              if (bounty.className.isNotEmpty)
                _InfoRow('Class', bounty.className),
              if (bounty.carNumber.isNotEmpty)
                _InfoRow('Car number', '#${bounty.carNumber}'),
              _InfoRow('Approval', bounty.statusLabel),
              _InfoRow('Claim', bounty.claimStatus.toUpperCase()),
              if (bounty.description.isNotEmpty)
                _InfoRow('Description', bounty.description),
              const SizedBox(height: 15),
              if (bounty.editable) ...[
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NdrlBountyEditScreen(
                          authService: widget.authService,
                          bountyId: bounty.id,
                        ),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit pending bounty'),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Icon(
                    bounty.editable ? Icons.info_outline : Icons.lock_outline,
                    color: _gold,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      bounty.editable
                          ? 'This bounty is pending and currently editable.'
                          : 'This bounty is locked and cannot be edited.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF302817),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: _gold,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _gold,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ],
    ),
  );
}
