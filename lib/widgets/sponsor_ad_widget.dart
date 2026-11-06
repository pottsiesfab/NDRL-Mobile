import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../models/sponsor_ad.dart';
import '../services/sponsor_service.dart';

/// A reusable placement. Only the currently active, visible placement rotates.
/// Reports one impression per genuinely visible, loaded advertisement display.
class NdrlSponsorAdWidget extends StatefulWidget {
  const NdrlSponsorAdWidget({
    super.key,
    required this.placement,
    this.isActive = true,
    this.heading,
  });

  final String placement;
  final bool isActive;
  final String? heading;

  @override
  State<NdrlSponsorAdWidget> createState() => _NdrlSponsorAdWidgetState();
}

class _NdrlSponsorAdWidgetState extends State<NdrlSponsorAdWidget>
    with WidgetsBindingObserver {
  final Random _random = Random();
  SponsorAdBatch? _batch;
  Timer? _rotationTimer;
  int _currentIndex = 0;
  bool _visible = false;
  bool _foreground = true;
  int _requestSerial = 0;
  int _displayGeneration = 0;
  int? _reportedGeneration;
  String? _loadedImageUrl;

  bool get _canReport => widget.isActive && _foreground && _visible;

  void _maybeReportImpression() {
    if (!_canReport || !mounted) return;
    final ads = _batch?.ads;
    if (ads == null || ads.isEmpty) return;
    final ad = ads[_currentIndex];
    if (_loadedImageUrl != ad.imageUrl.toString()) return;
    if (_reportedGeneration == _displayGeneration) return;
    final token = ad.impressionToken;
    if (token == null || token.isEmpty) return;
    _reportedGeneration = _displayGeneration;
    unawaited(SponsorService.recordImpression(token));
  }

  void _newDisplay({bool adChanged = false}) {
    _displayGeneration++;
    if (adChanged) _loadedImageUrl = null;
  }

  void _onImageLoaded(String imageUrl) {
    if (!mounted || _loadedImageUrl == imageUrl) return;
    final ads = _batch?.ads;
    if (ads == null ||
        ads.isEmpty ||
        ads[_currentIndex].imageUrl.toString() != imageUrl) {
      return;
    }
    _loadedImageUrl = imageUrl;
    _maybeReportImpression();
  }

  bool get _canRotate =>
      widget.isActive &&
      _foreground &&
      _visible &&
      (_batch?.ads.length ?? 0) > 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant NdrlSponsorAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _batch = null;
      _currentIndex = 0;
      _newDisplay();
      unawaited(_load());
    }
    if (!oldWidget.isActive && widget.isActive) {
      _newDisplay();
      _maybeReportImpression();
    }
    _updateTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    if (!wasForeground && _foreground) {
      _newDisplay();
      _maybeReportImpression();
    }
    _updateTimer();
  }

  Future<void> _load() async {
    final serial = ++_requestSerial;
    try {
      final batch = await SponsorService.getAds(widget.placement);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _batch = batch;
        _currentIndex = batch.ads.isEmpty ? 0 : _weightedIndex(batch.ads);
        _newDisplay(adChanged: true);
      });
      _updateTimer();
    } catch (_) {
      if (!mounted || serial != _requestSerial) return;
      setState(
        () => _batch = const SponsorAdBatch(rotationSeconds: 15, ads: []),
      );
      _updateTimer();
    }
  }

  int _weightedIndex(List<SponsorAd> ads, {int? exclude}) {
    final candidates = <int>[
      for (var i = 0; i < ads.length; i++)
        if (i != exclude) i,
    ];
    if (candidates.isEmpty) return exclude ?? 0;
    final total = candidates.fold<int>(0, (sum, i) => sum + ads[i].weight);
    var ticket = _random.nextInt(total);
    for (final index in candidates) {
      ticket -= ads[index].weight;
      if (ticket < 0) return index;
    }
    return candidates.last;
  }

  void _updateTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    if (!_canRotate) return;
    _rotationTimer = Timer.periodic(
      Duration(seconds: _batch!.rotationSeconds),
      (_) {
        if (!mounted || !_canRotate) return;
        setState(() {
          _currentIndex = _weightedIndex(_batch!.ads, exclude: _currentIndex);
          _newDisplay(adChanged: true);
        });
      },
    );
  }

  Future<void> _openSponsor(SponsorAd ad) async {
    try {
      final opened = await launchUrl(
        ad.clickUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open sponsor link.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open sponsor link.')),
      );
    }
  }

  @override
  void dispose() {
    _requestSerial++;
    _rotationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = _batch?.ads;
    if (ads == null || ads.isEmpty) return const SizedBox.shrink();
    final ad = ads[_currentIndex.clamp(0, ads.length - 1).toInt()];
    return VisibilityDetector(
      key: ValueKey('sponsor-${widget.placement}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction >= 0.5;
        if (visible == _visible) return;
        _visible = visible;
        if (visible) {
          _newDisplay();
          // Cached images may already have completed loading.
          _maybeReportImpression();
        }
        _updateTimer();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.heading != null) ...[
            Text(
              widget.heading!,
              style: const TextStyle(
                color: Color(0xFFD1AC67),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Semantics(
            label: ad.altText?.isNotEmpty == true
                ? ad.altText!
                : ad.sponsorName,
            button: true,
            child: Material(
              color: const Color(0xFF242428),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openSponsor(ad),
                child: Image.network(
                  ad.imageUrl.toString(),
                  width: double.infinity,
                  fit: BoxFit.contain,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (frame != null || wasSynchronouslyLoaded) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _onImageLoaded(ad.imageUrl.toString());
                          });
                        }
                        return child;
                      },
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stack) => SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        ad.sponsorName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'ADVERTISEMENT · ${ad.sponsorName}',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
