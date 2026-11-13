import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/tech_cards_service.dart';
import '../widgets/sponsor_ad_widget.dart';
import 'tech_card_equipment_screen.dart';
import 'tech_card_modifications_screen.dart';

const _bg = Color(0xFF111111);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlTechCardReviewScreen extends StatefulWidget {
  const NdrlTechCardReviewScreen({
    super.key,
    required this.authService,
    required this.vehicle,
  });
  final AuthService authService;
  final TechCardRecord vehicle;

  @override
  State<NdrlTechCardReviewScreen> createState() =>
      _NdrlTechCardReviewScreenState();
}

class _NdrlTechCardReviewScreenState extends State<NdrlTechCardReviewScreen> {
  late final TechCardsService _service = TechCardsService(widget.authService);
  Map<String, dynamic>? _card;
  List<TechModification> _mods = [];
  List<Map<String, dynamic>> _items = [];
  Map<int, Map<String, dynamic>> _saved = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool _flag(Object? value) => value == true || '$value' == '1';
  bool get _locked {
    final c = _card;
    if (c == null) return true;
    return c['locked_at'] != null ||
        ['ready', 'approved'].contains('${c['status'] ?? ''}'.toLowerCase());
  }

  bool get _accepted =>
      _card?['accepted_at'] != null && '${_card?['accepted_at']}'.isNotEmpty;
  bool get _validEt =>
      (double.tryParse('${_card?['et_index'] ?? ''}') ?? 0) > 0;
  int get _attestedCount => _items.where((item) {
    final id = int.tryParse('${item['tech_item_def_id']}');
    final row = _saved[id];
    return row != null &&
        _flag(row['member_checked']) &&
        _flag(row['member_attested']);
  }).length;
  List<Map<String, dynamic>> get _missing => _items.where((item) {
    final id = int.tryParse('${item['tech_item_def_id']}');
    final row = _saved[id];
    return row == null ||
        !_flag(row['member_checked']) ||
        !_flag(row['member_attested']);
  }).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final card = await _service.card(widget.vehicle.vehicleId);
      final mods = await _service.cardModifications(widget.vehicle.vehicleId);
      // The backend owns the authoritative requirements calculation.
      final req = await _service.equipmentRequirements(
        widget.vehicle.vehicleId,
      );
      final saved = await _service.cardEquipment(widget.vehicle.vehicleId);
      if (!mounted) return;
      setState(() {
        _card = card;
        _mods = mods;
        _items = (req['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _saved = saved;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _accept() async {
    if (_busy || _locked || _loading) return;
    if (!await _confirm(
      'Accept Tech Card declaration',
      'I confirm that the information I have provided is accurate to the best of my knowledge. Record my acceptance?',
    ))
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.acceptCard(widget.vehicle.vehicleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Declaration accepted on DEV.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _load();
  }

  Future<void> _submit() async {
    if (_busy ||
        _loading ||
        _locked ||
        !_accepted ||
        !_validEt ||
        _missing.isNotEmpty)
      return;
    // Refresh the backend-resolved requirements immediately before submitting.
    await _load();
    if (!mounted ||
        _error != null ||
        _locked ||
        !_accepted ||
        !_validEt ||
        _missing.isNotEmpty)
      return;
    if (!await _confirm(
      'Submit for inspection',
      'Submit this Tech Card for inspection? Once submitted, you will no longer be able to edit it.',
    ))
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.submitCard(widget.vehicle.vehicleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tech Card submitted for inspection.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _load();
  }

  Widget _line(String name, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(
      '$name: ${value == null || '$value'.isEmpty ? 'Not entered' : value}',
      style: const TextStyle(color: Colors.white70),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('REVIEW TECH CARD'),
        actions: [
          IconButton(
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.vehicle.className,
            style: const TextStyle(
              color: _gold,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${widget.vehicle.seasonName} · Car #${widget.vehicle.carNumber}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (_loading || _busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(color: _red),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            TextButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            ),
          ],
          if (!_loading && card != null) ...[
            const SizedBox(height: 14),
            Text(
              'Status: ${card['status'] ?? 'Unknown'}',
              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            if (_locked)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Submitted or locked — read only.',
                  style: TextStyle(color: _gold),
                ),
              ),
            const SizedBox(height: 18),
            const Text(
              'VEHICLE INFORMATION',
              style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            for (final entry in <String, String>{
              'car_year': 'Year',
              'car_make': 'Make',
              'car_model': 'Model',
              'car_weight': 'Weight (lb)',
              'engine_make': 'Engine',
              'engine_cubic': 'Displacement',
              'horsepower': 'Horsepower',
              'et_index': 'ET index',
              'et_distance': 'Distance',
              'mph_trap': 'Trap MPH',
            }.entries)
              _line(entry.value, card[entry.key]),
            const SizedBox(height: 18),
            const Text(
              'MODIFICATIONS',
              style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            if (_mods.where((m) => m.answer == true).isEmpty)
              const Text(
                'None selected',
                style: TextStyle(color: Colors.white70),
              ),
            for (final mod in _mods.where((m) => m.answer == true))
              _line('•', mod.label),
            if (!_locked)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => NdrlTechCardModificationsScreen(
                              authService: widget.authService,
                              vehicleId: widget.vehicle.vehicleId,
                            ),
                          ),
                        );
                        if (mounted) _load();
                      },
                icon: const Icon(Icons.tune),
                label: const Text('Edit modifications'),
              ),
            const SizedBox(height: 18),
            const Text(
              'REQUIRED EQUIPMENT',
              style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            Text(
              '$_attestedCount of ${_items.length} checked and attested',
              style: const TextStyle(color: Colors.white70),
            ),
            for (final item in _items)
              Row(
                children: [
                  Icon(
                    _missing.any(
                          (m) =>
                              m['tech_item_def_id'] == item['tech_item_def_id'],
                        )
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle_outline,
                    size: 17,
                    color:
                        _missing.any(
                          (m) =>
                              m['tech_item_def_id'] == item['tech_item_def_id'],
                        )
                        ? Colors.orangeAccent
                        : _gold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item['label'] ?? 'Equipment'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            if (_missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Still needs member attestation:',
                style: TextStyle(color: Colors.orangeAccent),
              ),
              for (final item in _missing) _line('•', item['label']),
            ],
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NdrlTechCardEquipmentScreen(
                            authService: widget.authService,
                            vehicleId: widget.vehicle.vehicleId,
                          ),
                        ),
                      );
                      if (mounted) _load();
                    },
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                _locked
                    ? 'View equipment checklist'
                    : 'Complete equipment checklist',
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'DECLARATION',
              style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            Text(
              _accepted
                  ? 'Accepted: ${card['accepted_at']}'
                  : 'Not yet accepted',
              style: TextStyle(color: _accepted ? _gold : Colors.orangeAccent),
            ),
            if (!_locked && !_accepted)
              FilledButton.icon(
                onPressed: _busy ? null : _accept,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Accept declaration'),
              ),
            const SizedBox(height: 16),
            if (!_locked) ...[
              if (!_validEt)
                const Text(
                  'Save a valid ET index before submission.',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              if (_missing.isNotEmpty)
                const Text(
                  'Attest to all required equipment before submission.',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              if (!_accepted)
                const Text(
                  'Accept the declaration before submission.',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              FilledButton.icon(
                onPressed:
                    _busy || !_validEt || !_accepted || _missing.isNotEmpty
                    ? null
                    : _submit,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Submit for inspection'),
              ),
            ],
          ],
          const SizedBox(height: 24),
          const NdrlSponsorAdWidget(
            placement: 'home_featured',
            heading: 'FEATURED NDRL PARTNER',
          ),
        ],
      ),
    );
  }
}
