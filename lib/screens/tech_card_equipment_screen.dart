import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/tech_cards_service.dart';
import '../widgets/sponsor_ad_widget.dart';

const _bg = Color(0xFF111111);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlTechCardEquipmentScreen extends StatefulWidget {
  const NdrlTechCardEquipmentScreen({
    super.key,
    required this.authService,
    required this.vehicleId,
  });

  final AuthService authService;
  final int vehicleId;

  @override
  State<NdrlTechCardEquipmentScreen> createState() =>
      _NdrlTechCardEquipmentScreenState();
}

class _NdrlTechCardEquipmentScreenState
    extends State<NdrlTechCardEquipmentScreen> {
  late final TechCardsService _service = TechCardsService(widget.authService);
  Map<String, dynamic>? _requirements;
  Map<int, Map<String, dynamic>> _saved = {};
  String? _error;
  bool _loading = true;
  bool _editing = false;
  bool _locked = true;

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
      final requirements = await _service.equipmentRequirements(
        widget.vehicleId,
      );
      final saved = await _service.cardEquipment(widget.vehicleId);
      final card = await _service.card(widget.vehicleId);
      final status = '${card['status'] ?? ''}'.toLowerCase();
      if (!mounted) return;
      setState(() {
        _requirements = requirements;
        _saved = saved;
        _locked =
            card['locked_at'] != null ||
            status == 'ready' ||
            status == 'approved';
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _flag(Object? value) => value == true || '$value' == '1';

  Future<void> _editItem(Map<String, dynamic> item) async {
    if (_editing || _locked) return;
    final id = int.tryParse('${item['tech_item_def_id']}');
    if (id == null || id <= 0) return;
    final previous = _saved[id] ?? <String, dynamic>{};
    const keys = [
      'brand_name',
      'serial_no',
      'expires_on',
      'issuer',
      'sfi_no',
      'notes',
    ];
    final controllers = <String, TextEditingController>{
      for (final key in keys)
        key: TextEditingController(text: '${previous[key] ?? ''}'),
    };
    var checked = _flag(previous['member_checked']);
    var attested = _flag(previous['member_attested']);
    var busy = false;
    String? error;
    final required = <String, bool>{
      'serial_no': _flag(item['requires_serial']),
      'expires_on': _flag(item['requires_expiry']),
      'issuer': _flag(item['requires_issuer']),
      'sfi_no': _flag(item['requires_sfi']),
    };
    final show = <String, bool>{
      'brand_name':
          _flag(item['show_brand']) ||
          '${previous['brand_name'] ?? ''}'.isNotEmpty,
      for (final entry in required.entries)
        entry.key: entry.value || '${previous[entry.key] ?? ''}'.isNotEmpty,
      'notes': true,
    };
    const labels = {
      'brand_name': 'Brand',
      'serial_no': 'Serial number',
      'expires_on': 'Expiration (YYYY-MM-DD)',
      'issuer': 'Issuer',
      'sfi_no': 'SFI number',
      'notes': 'Notes',
    };
    setState(() => _editing = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: Text('${item['label'] ?? 'Equipment'}'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ('${item['description'] ?? ''}'.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('${item['description']}'),
                      ),
                    for (final key in keys)
                      if (show[key] == true)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: controllers[key],
                            enabled: !busy,
                            maxLength: key == 'notes' ? 2000 : 120,
                            maxLines: key == 'notes' ? 3 : 1,
                            decoration: InputDecoration(
                              labelText:
                                  '${labels[key]}${required[key] == true ? ' *' : ''}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Equipment checked'),
                      value: checked,
                      onChanged: busy
                          ? null
                          : (v) => update(() {
                              checked = v ?? false;
                              if (!checked) attested = false;
                            }),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I attest this information is accurate',
                      ),
                      value: attested,
                      onChanged: busy || !checked
                          ? null
                          : (v) => update(() {
                              attested = v ?? false;
                            }),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final values = <String, dynamic>{};
                        for (final key in keys) {
                          final value = controllers[key]!.text.trim();
                          values[key] = value.isEmpty ? null : value;
                        }
                        final date = values['expires_on'] as String?;
                        if (date != null) {
                          final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
                              .firstMatch(date);
                          final parsed = match == null
                              ? null
                              : DateTime.tryParse(date);
                          if (parsed == null ||
                              parsed.year.toString().padLeft(4, '0') !=
                                  match!.group(1) ||
                              parsed.month.toString().padLeft(2, '0') !=
                                  match.group(2) ||
                              parsed.day.toString().padLeft(2, '0') !=
                                  match.group(3)) {
                            update(
                              () => error = 'Enter a valid date as YYYY-MM-DD.',
                            );
                            return;
                          }
                        }
                        values['member_checked'] = checked;
                        values['member_attested'] = attested;
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await _service.saveEquipment(
                            widget.vehicleId,
                            id,
                            values,
                          );
                          if (!mounted) return;
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext);
                          await _load();
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Equipment saved to DEV.'),
                              ),
                            );
                        } catch (e) {
                          if (dialogContext.mounted) update(() => error = '$e');
                        } finally {
                          if (dialogContext.mounted) update(() => busy = false);
                        }
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(busy ? 'Saving…' : 'Save equipment'),
              ),
            ],
          ),
        ),
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, dynamic>>[];
    final raw = _requirements?['items'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) items.add(Map<String, dynamic>.from(item));
      }
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    var attested = 0;
    for (final item in items) {
      final id = int.tryParse('${item['tech_item_def_id']}');
      final saved = id == null ? null : _saved[id];
      if (_flag(saved?['member_attested']) && _flag(saved?['member_checked'])) {
        attested++;
      }
      final category = '${item['category'] ?? 'Other'}'.trim();
      groups
          .putIfAbsent(category.isEmpty ? 'Other' : category, () => [])
          .add(item);
    }
    final categories = groups.keys.toList()..sort();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('EQUIPMENT CHECKLIST'),
        actions: [
          IconButton(
            tooltip: 'Reload equipment',
            onPressed: _loading || _editing ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'REQUIRED EQUIPMENT',
            style: TextStyle(
              color: _gold,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _locked ? 'This Tech Card is locked. Equipment is read-only.' : 'Tap an equipment item to enter details, save a draft, or attest completion.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          if (_loading) const LinearProgressIndicator(color: _red),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
          if (!_loading && _error == null) ...[
            Text(
              '$attested of ${items.length} attested',
              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: items.isEmpty ? 0 : attested / items.length,
              color: _red,
              backgroundColor: Colors.white24,
            ),
            const SizedBox(height: 18),
            for (final category in categories)
              Card(
                color: const Color(0xFF111626),
                child: ExpansionTile(
                  title: Text(
                    category,
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text('${groups[category]!.length} items'),
                  children: [
                    for (final item in groups[category]!)
                      Builder(
                        builder: (context) {
                          final id = int.tryParse(
                            '${item['tech_item_def_id']}',
                          );
                          final saved = id == null ? null : _saved[id];
                          final complete =
                              _flag(saved?['member_attested']) &&
                              _flag(saved?['member_checked']);
                          final fields = <String>[];
                          if (_flag(item['show_brand'])) fields.add('Brand');
                          if (_flag(item['requires_serial']))
                            fields.add('Serial');
                          if (_flag(item['requires_expiry']))
                            fields.add('Expiration');
                          if (_flag(item['requires_issuer']))
                            fields.add('Issuer');
                          if (_flag(item['requires_sfi'])) fields.add('SFI');
                          final description = '${item['description'] ?? ''}'
                              .trim();
                          return ListTile(
                            enabled: !_locked && !_editing,
                            onTap: _locked || _editing
                                ? null
                                : () => _editItem(item),
                            trailing: _locked
                                ? const Icon(Icons.lock_outline, size: 18)
                                : const Icon(Icons.edit_outlined, size: 18),
                            leading: Icon(
                              complete
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: complete
                                  ? Colors.greenAccent
                                  : Colors.white54,
                            ),
                            title: Text(
                              '${item['label'] ?? item['code'] ?? 'Equipment'}',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (description.isNotEmpty) Text(description),
                                if (fields.isNotEmpty)
                                  Text(
                                    'Fields: ${fields.join(', ')}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                if (saved != null) ...[
                                  if ('${saved['brand_name'] ?? ''}'.isNotEmpty)
                                    Text('Brand: ${saved['brand_name']}'),
                                  if ('${saved['notes'] ?? ''}'.isNotEmpty)
                                    Text('Notes: ${saved['notes']}'),
                                ],
                              ],
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 20),
          const NdrlSponsorAdWidget(
            placement: 'home_featured',
            heading: 'FEATURED NDRL PARTNER',
          ),
        ],
      ),
    );
  }
}
