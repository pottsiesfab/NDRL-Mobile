import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/tech_cards_service.dart';

const _bg = Color(0xFF111111);
const _surface = Color(0xFF111626);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlTechCardReferenceScreen extends StatefulWidget {
  const NdrlTechCardReferenceScreen({
    super.key,
    required this.authService,
    required this.vehicle,
  });

  final AuthService authService;
  final TechCardRecord vehicle;

  @override
  State<NdrlTechCardReferenceScreen> createState() =>
      _NdrlTechCardReferenceScreenState();
}

class _NdrlTechCardReferenceScreenState
    extends State<NdrlTechCardReferenceScreen> {
  late final TechCardsService _service = TechCardsService(widget.authService);
  Map<String, dynamic>? _card;
  List<TechModification> _mods = [];
  List<Map<String, dynamic>> _requirements = [];
  Map<int, Map<String, dynamic>> _equipment = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = widget.vehicle.vehicleId;
      final card = await _service.card(id);
      final mods = await _service.cardModifications(id);
      final requirements = await _service.equipmentRequirements(id);
      final equipment = await _service.cardEquipment(id);
      final raw = requirements['items'] as List;
      if (!mounted) return;
      setState(() {
        _card = card;
        _mods = mods;
        _requirements = raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _equipment = equipment;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _value(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty || value.toLowerCase() == 'null' ? '—' : value;
  }

  String _first(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = _value(item[key]);
      if (value != '—') return value;
    }
    return '—';
  }

  bool _yes(Object? raw) => raw == true || raw == 1 || raw == '1';

  Future<void> _copy(String label, String value) async {
    if (value == '—') return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Widget _section(String title, List<Widget> children) => Card(
    color: _surface,
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );

  Widget _entry(String label, Object? raw) {
    final value = _value(raw);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 3),
                SelectableText(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          if (value != '—')
            IconButton(
              tooltip: 'Copy $label',
              onPressed: () => _copy(label, value),
              icon: const Icon(Icons.copy_outlined, color: _gold, size: 19),
            ),
        ],
      ),
    );
  }

  Widget _equipmentItem(Map<String, dynamic> requirement) {
    final id = int.tryParse(
      '${requirement['tech_item_def_id'] ?? requirement['id'] ?? ''}',
    );
    final saved = id == null ? null : _equipment[id];
    final label = _first(requirement, [
      'label',
      'item_name',
      'name',
      'title',
      'code',
    ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 3),
          Text(
            saved == null
                ? 'No member details saved'
                : _yes(saved['member_checked']) &&
                      _yes(saved['member_attested'])
                ? 'Member attested'
                : 'Attestation incomplete',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (saved != null) ...[
            if (_yes(requirement['show_brand']) ||
                _value(saved['brand_name']) != '—')
              _entry('Brand / manufacturer', saved['brand_name']),
            if (_yes(requirement['requires_serial']) ||
                _value(saved['serial_no']) != '—')
              _entry('Serial number', saved['serial_no']),
            if (_yes(requirement['requires_expiry']) ||
                _value(saved['expires_on']) != '—')
              _entry('Expiration date', saved['expires_on']),
            if (_yes(requirement['requires_sfi']) ||
                _value(saved['sfi_no']) != '—')
              _entry('SFI number', saved['sfi_no']),
            if (_yes(requirement['requires_issuer']) ||
                _value(saved['issuer']) != '—')
              _entry('Issuer', saved['issuer']),
            if (_value(saved['notes']) != '—') _entry('Notes', saved['notes']),
          ],
          const Divider(color: Colors.white24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('TECH CARD REFERENCE'),
        actions: [
          IconButton(
            tooltip: 'Refresh saved information',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : card == null
          ? const Center(child: Text('No Tech Card found.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.vehicle.className,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.vehicle.seasonName} · Car #${widget.vehicle.carNumber}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                const Text(
                  'REFERENCE ONLY · Tap a copy icon to copy a value.',
                  style: TextStyle(color: _gold, fontSize: 12),
                ),
                const SizedBox(height: 16),
                _section('CARD', [
                  _entry('Status', card['status']),
                  _entry('Car number', widget.vehicle.carNumber),
                  _entry('Declaration accepted', card['accepted_at']),
                  _entry('Submitted', card['last_submitted_at']),
                ]),
                _section('VEHICLE', [
                  _entry('Year', card['car_year']),
                  _entry('Make', card['car_make']),
                  _entry('Model', card['car_model']),
                  _entry('Weight (lb)', card['car_weight']),
                ]),
                _section('ENGINE', [
                  _entry('Engine make', card['engine_make']),
                  _entry('Displacement (cu in)', card['engine_cubic']),
                  _entry('Horsepower', card['horsepower']),
                ]),
                _section('PERFORMANCE', [
                  _entry('ET index', card['et_index']),
                  _entry('ET distance', card['et_distance']),
                  _entry('Trap speed (MPH)', card['mph_trap']),
                ]),
                _section('VEHICLE MODIFICATIONS', [
                  if (_mods.where((mod) => mod.answer == true).isEmpty)
                    const Text(
                      'No selected modifications saved.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  for (final mod in _mods.where((mod) => mod.answer == true))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('• ${mod.label}'),
                    ),
                ]),
                _section('REQUIRED SAFETY EQUIPMENT', [
                  Text(
                    '${_requirements.length} items resolved for this vehicle',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  for (final requirement in _requirements)
                    _equipmentItem(requirement),
                ]),
                const Text(
                  'This reference displays saved NDRL information. It is not a tech inspection approval or certification for another racing organization.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
