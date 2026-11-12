import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/tech_cards_service.dart';
import '../widgets/sponsor_ad_widget.dart';
import 'account_screen.dart';
import 'tech_card_details_screen.dart';

const _background = Color(0xFF111111);
const _surface = Color(0xFF111626);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlMyTechCardsScreen extends StatefulWidget {
  const NdrlMyTechCardsScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<NdrlMyTechCardsScreen> createState() => _NdrlMyTechCardsScreenState();
}

class _NdrlMyTechCardsScreenState extends State<NdrlMyTechCardsScreen> {
  late TechCardsService _service;
  List<TechCardRecord> _vehicles = [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _service = TechCardsService(widget.authService);
    widget.authService.addListener(_authChanged);
    if (widget.authService.signedIn) _refresh();
  }

  @override
  void didUpdateWidget(covariant NdrlMyTechCardsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService) {
      oldWidget.authService.removeListener(_authChanged);
      widget.authService.addListener(_authChanged);
      _service = TechCardsService(widget.authService);
      _authChanged();
    }
  }

  void _authChanged() {
    if (!mounted) return;
    if (!widget.authService.signedIn) {
      _requestId++;
      setState(() {
        _vehicles = [];
        _error = null;
        _loading = false;
      });
    } else if (_vehicles.isEmpty && !_loading && _error == null) {
      _refresh();
    } else {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    if (!widget.authService.signedIn) return;
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicles = await _service.vehicles();
      if (!mounted || request != _requestId) return;
      setState(() => _vehicles = vehicles);
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted && request == _requestId) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _requestId++;
    widget.authService.removeListener(_authChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authService;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('MY TECH CARDS'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || !auth.signedIn ? null : _refresh,
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
              'YOUR VEHICLES',
              style: TextStyle(
                color: _gold,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select an existing Tech Card to view or edit vehicle basics.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            if (!auth.signedIn && auth.loading)
              const Center(child: CircularProgressIndicator(color: _red)),
            if (!auth.signedIn && !auth.loading) ...[
              const Text('Sign in to view your Tech Cards.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NdrlAccountScreen(authService: auth),
                    ),
                  );
                  if (mounted && auth.signedIn) _refresh();
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign in'),
              ),
            ],
            if (auth.signedIn && _loading)
              const LinearProgressIndicator(color: _red),
            if (auth.signedIn && _error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
            if (auth.signedIn &&
                !_loading &&
                _error == null &&
                _vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No eligible vehicles were found.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            if (auth.signedIn && !_loading && _error == null)
              for (final vehicle in _vehicles)
                Card(
                  color: _surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: !vehicle.hasCard || vehicle.vehicleId <= 0
                        ? null
                        : () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => NdrlTechCardDetailsScreen(
                                  authService: widget.authService,
                                  vehicle: vehicle,
                                ),
                              ),
                            );
                            if (mounted) _refresh();
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.className,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${vehicle.seasonName}${vehicle.carNumber.isEmpty ? '' : '  ·  Car #${vehicle.carNumber}'}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                vehicle.hasCard
                                    ? Icons.assignment_outlined
                                    : Icons.info_outline,
                                size: 18,
                                color: _gold,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  vehicle.hasCard
                                      ? 'Tech Card: ${vehicle.status}'
                                      : 'No Tech Card on file',
                                  style: const TextStyle(
                                    color: _gold,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (vehicle.isLocked)
                                const Icon(
                                  Icons.lock_outline,
                                  color: _gold,
                                  size: 18,
                                ),
                              if (vehicle.hasCard)
                                const Icon(Icons.chevron_right, color: _gold),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 20),
            const NdrlSponsorAdWidget(
              placement: 'home_featured',
              heading: 'FEATURED NDRL PARTNER',
            ),
          ],
        ),
      ),
    );
  }
}
