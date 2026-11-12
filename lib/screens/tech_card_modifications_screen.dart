import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/tech_cards_service.dart';
import '../widgets/sponsor_ad_widget.dart';

const _background = Color(0xFF111111);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlTechCardModificationsScreen extends StatefulWidget {
  const NdrlTechCardModificationsScreen({
    super.key,
    required this.authService,
    required this.vehicleId,
  });

  final AuthService authService;
  final int vehicleId;

  @override
  State<NdrlTechCardModificationsScreen> createState() =>
      _NdrlTechCardModificationsScreenState();
}

class _NdrlTechCardModificationsScreenState
    extends State<NdrlTechCardModificationsScreen> {
  late final TechCardsService _service = TechCardsService(widget.authService);
  List<TechModification> _mods = [];
  final Map<int, bool?> _answers = {};
  final Map<int, bool?> _savedAnswers = {};
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _locked = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_saving) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final card = await _service.card(widget.vehicleId);
      final mods = await _service.cardModifications(widget.vehicleId);
      if (!mounted) return;
      final status = '${card['status'] ?? ''}'.toLowerCase();
      setState(() {
        _locked =
            card['locked_at'] != null ||
            status == 'approved' ||
            status == 'ready';
        _mods = mods;
        _answers
          ..clear()
          ..addEntries(mods.map((m) => MapEntry(m.id, m.answer)));
        _savedAnswers
          ..clear()
          ..addEntries(mods.map((m) => MapEntry(m.id, m.answer)));
        _dirty = false;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setAnswer(TechModification mod, bool? answer) {
    if (_locked || _saving) return;
    // Draft API cannot delete a previously saved answer by omitting its ID.
    if (answer == null && _savedAnswers[mod.id] != null) return;
    setState(() {
      if (answer == true && mod.mode == 'single' && mod.group.isNotEmpty) {
        for (final other in _mods) {
          if (other.id != mod.id &&
              other.mode == 'single' &&
              other.group == mod.group) {
            _answers[other.id] = false;
          }
        }
      }
      _answers[mod.id] = answer;
      _dirty = true;
    });
  }

  List<String> _orderedGroups() {
    final groups = _mods.map((m) => m.group).toSet();
    final ordered = <String>[];
    for (final preferred in ['car_type', 'trans_type']) {
      if (groups.remove(preferred)) ordered.add(preferred);
    }
    final remaining = groups.where((g) => g.isNotEmpty).toList()..sort();
    ordered.addAll(remaining);
    if (groups.contains('')) ordered.add('');
    return ordered;
  }

  String _groupTitle(String group) {
    switch (group.toLowerCase()) {
      case 'car_type':
        return 'Car Type';
      case 'trans_type':
        return 'Transmission Type';
      default:
        return group.isEmpty
            ? 'Other Modifications'
            : group.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _displayLabel(TechModification mod) {
    // Presentation-only correction; database label remains unchanged.
    if (mod.data['code'] == 'AUTOMATIC_TRANS') return 'Automatic Transmission';
    return mod.label;
  }

  String? _completionError() {
    if (_mods.isEmpty) return 'No active modifications were returned.';
    if (_mods.any((m) => _answers[m.id] == null)) {
      return 'Answer every modification before marking this section complete.';
    }
    final groups = <String, List<TechModification>>{};
    for (final mod in _mods) {
      if (mod.mode == 'single' && mod.group.isNotEmpty) {
        groups.putIfAbsent(mod.group, () => []).add(mod);
      }
    }
    for (final entry in groups.entries) {
      final count = entry.value.where((m) => _answers[m.id] == true).length;
      final required = entry.value.any((m) => m.required);
      if (count > 1 || (required && count != 1)) {
        return 'Select ${required ? 'exactly one' : 'at most one'} option in ${entry.key}.';
      }
    }
    return null;
  }

  Future<void> _save({required bool draft}) async {
    if (_locked || _saving || _loading) return;
    if (!draft) {
      final message = _completionError();
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (draft) {
        final answers = _mods
            .where((m) => _answers[m.id] != null)
            .map((m) => {'tech_mod_def_id': m.id, 'checked': _answers[m.id]!})
            .toList();
        await _service.saveModificationDraft(widget.vehicleId, answers);
      } else {
        final ids = _mods
            .where((m) => _answers[m.id] == true)
            .map((m) => m.id)
            .toList();
        await _service.completeModifications(widget.vehicleId, ids);
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft
                ? 'Modification draft saved to DEV.'
                : 'Modifications completed on DEV.',
          ),
        ),
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
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard unsaved answers?'),
            content: const Text(
              'Your unsaved modification answers will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final answered = _mods.where((m) => _answers[m.id] != null).length;
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saving || !mounted) return;
        final discard = await _confirmDiscard();
        if (discard && mounted) Navigator.of(this.context).pop();
      },
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          title: const Text('VEHICLE MODIFICATIONS'),
          actions: [
            IconButton(
              tooltip: 'Reload',
              onPressed: _loading || _saving
                  ? null
                  : () async {
                      if (await _confirmDiscard() && mounted) _load();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'MODIFICATIONS',
              style: TextStyle(
                color: _gold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose Yes or No for each item. Unanswered is available for questions not yet saved. Save a draft anytime; completing requires every answer.',
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(color: _red),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              TextButton.icon(
                onPressed: _saving ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
            if (!_loading && _locked)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'This card is submitted or locked. Modifications are read-only.',
                  style: TextStyle(color: _gold),
                ),
              ),
            if (!_loading && _error == null) ...[
              Text(
                '$answered of ${_mods.length} answered',
                style: const TextStyle(color: _gold),
              ),
              const SizedBox(height: 12),
              for (final group in _orderedGroups()) ...[
                if (_mods.any((m) => m.group == group)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 8),
                    child: Text(
                      _groupTitle(group).toUpperCase(),
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  for (final mod in _mods.where((m) => m.group == group))
                    Builder(
                      builder: (context) {
                        return Card(
                          color: const Color(0xFF242428),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayLabel(mod),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (mod.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    mod.description,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                                if (mod.mode == 'single' &&
                                    mod.group.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 5),
                                    child: Text(
                                      'Single-choice group',
                                      style: TextStyle(
                                        color: _gold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Yes'),
                                      selected: _answers[mod.id] == true,
                                      onSelected: _locked || _saving
                                          ? null
                                          : (_) => _setAnswer(mod, true),
                                    ),
                                    ChoiceChip(
                                      label: const Text('No'),
                                      selected: _answers[mod.id] == false,
                                      onSelected: _locked || _saving
                                          ? null
                                          : (_) => _setAnswer(mod, false),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Unanswered'),
                                      selected: _answers[mod.id] == null,
                                      onSelected:
                                          _locked ||
                                              _saving ||
                                              _savedAnswers[mod.id] != null
                                          ? null
                                          : (_) => _setAnswer(mod, null),
                                    ),
                                  ],
                                ),
                                if (mod.inspectorChecked)
                                  const Text(
                                    'Inspector checked',
                                    style: TextStyle(
                                      color: _gold,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ],
              if (!_locked) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(draft: true),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save draft'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _save(draft: false),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete modifications'),
                ),
              ],
            ],
            const SizedBox(height: 28),
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
