import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/tech_cards_service.dart';
import '../widgets/sponsor_ad_widget.dart';

const _bg = Color(0xFF111111);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlTechCardDetailsScreen extends StatefulWidget {
  const NdrlTechCardDetailsScreen({
    super.key,
    required this.authService,
    required this.vehicle,
  });

  final AuthService authService;
  final TechCardRecord vehicle;

  @override
  State<NdrlTechCardDetailsScreen> createState() =>
      _NdrlTechCardDetailsScreenState();
}

class _NdrlTechCardDetailsScreenState extends State<NdrlTechCardDetailsScreen> {
  late final TechCardsService _service = TechCardsService(widget.authService);
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  Map<String, dynamic>? _card;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  String _distance = '1/4';

  static const _names = [
    'et_index',
    'mph_trap',
    'car_year',
    'car_make',
    'car_model',
    'car_weight',
    'engine_make',
    'engine_cubic',
    'horsepower',
  ];

  @override
  void initState() {
    super.initState();
    for (final name in _names) {
      _fields[name] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _locked {
    final card = _card;
    if (card == null) return true;
    final status = '${card['status'] ?? ''}'.toLowerCase();
    return card['locked_at'] != null ||
        status == 'approved' ||
        status == 'ready';
  }

  Future<void> _load() async {
    if (_saving) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final card = await _service.card(widget.vehicle.vehicleId);
      if (!mounted) return;
      for (final name in _names) {
        _fields[name]!.text = card[name]?.toString() ?? '';
      }
      setState(() {
        _card = card;
        _distance = card['et_distance'] == '1/8' ? '1/8' : '1/4';
        _dirty = false;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _number(String? raw, {bool integer = false, bool positive = false}) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final parsed = integer
        ? int.tryParse(value)?.toDouble()
        : double.tryParse(value);
    if (parsed == null ||
        !parsed.isFinite ||
        parsed < 0 ||
        (positive && parsed <= 0)) {
      return positive
          ? 'Enter a positive number'
          : 'Enter a valid non-negative number';
    }
    return null;
  }

  Widget _field(
    String key,
    String label, {
    bool integer = false,
    bool positive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _fields[key],
        enabled: !_locked && !_saving,
        maxLength: integer || key == 'et_index' || key == 'mph_trap'
            ? null
            : 120,
        keyboardType: integer || key == 'et_index' || key == 'mph_trap'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: integer || key == 'et_index' || key == 'mph_trap'
            ? (value) => _number(value, integer: integer, positive: positive)
            : null,
        onChanged: (_) => setState(() => _dirty = true),
      ),
    );
  }

  Object? _optionalNumber(String key, {bool integer = false}) {
    final value = _fields[key]!.text.trim();
    if (value.isEmpty) return null;
    return integer ? int.parse(value) : double.parse(value);
  }

  Future<void> _save() async {
    if (_locked || _saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.saveBasics(widget.vehicle.vehicleId, {
        'et_index': _optionalNumber('et_index'),
        'et_distance': _distance,
        'mph_trap': _optionalNumber('mph_trap'),
        'car_year': _optionalNumber('car_year', integer: true),
        'car_make': _fields['car_make']!.text.trim(),
        'car_model': _fields['car_model']!.text.trim(),
        'car_weight': _optionalNumber('car_weight', integer: true),
        'engine_make': _fields['engine_make']!.text.trim(),
        'engine_cubic': _optionalNumber('engine_cubic', integer: true),
        'horsepower': _optionalNumber('horsepower', integer: true),
      });
      if (!mounted) return;
      // Saving basics invalidates downstream modification and acceptance steps.
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle basics saved to DEV.')),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Unsaved Tech Card changes will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saving || !mounted) return;
        if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          title: const Text('TECH CARD DETAILS'),
          actions: [
            IconButton(
              tooltip: 'Reload',
              onPressed: _loading || _saving
                  ? null
                  : () async {
                      if (await _confirmDiscard()) _load();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.vehicle.className,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.vehicle.seasonName} · Car #${widget.vehicle.carNumber}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            if (_loading) const LinearProgressIndicator(color: _red),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              TextButton.icon(
                onPressed: _loading || _saving ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry / reload'),
              ),
            ],
            if (!_loading && card != null) ...[
              Text(
                'Status: ${card['status'] ?? 'Unknown'}',
                style: const TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_locked)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'This card is locked or approved. Details are read-only.',
                    style: TextStyle(color: _gold),
                  ),
                ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VEHICLE',
                      style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field('car_year', 'Vehicle year', integer: true),
                    _field('car_make', 'Vehicle make'),
                    _field('car_model', 'Vehicle model'),
                    _field('car_weight', 'Vehicle weight (lb)', integer: true),
                    const SizedBox(height: 10),
                    const Text(
                      'ENGINE',
                      style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field('engine_make', 'Engine make'),
                    _field(
                      'engine_cubic',
                      'Displacement (cu in)',
                      integer: true,
                    ),
                    _field('horsepower', 'Horsepower', integer: true),
                    const SizedBox(height: 10),
                    const Text(
                      'PERFORMANCE',
                      style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      'et_index',
                      'ET index (required to complete basics)',
                      positive: true,
                    ),
                    DropdownButtonFormField<String>(
                      value: _distance,
                      decoration: const InputDecoration(
                        labelText: 'ET distance',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: '1/8', child: Text('1/8 mile')),
                        DropdownMenuItem(value: '1/4', child: Text('1/4 mile')),
                      ],
                      onChanged: _locked || _saving
                          ? null
                          : (value) {
                              if (value != null)
                                setState(() {
                                  _distance = value;
                                  _dirty = true;
                                });
                            },
                    ),
                    const SizedBox(height: 14),
                    _field('mph_trap', 'Trap speed (MPH)'),
                    if (!_locked) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Saving basics resets previously completed modifications and acceptance. Review them again before submission.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saving || _loading ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _saving ? 'Saving…' : 'Save vehicle basics',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
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
