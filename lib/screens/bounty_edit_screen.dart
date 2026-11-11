import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/bounty_submission_service.dart';
import '../services/my_bounties_service.dart';

const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _surface = Color(0xFF111626);

enum _ImageAction { keep, replace, remove }

class NdrlBountyEditScreen extends StatefulWidget {
  const NdrlBountyEditScreen({
    super.key,
    required this.authService,
    required this.bountyId,
  });
  final AuthService authService;
  final int bountyId;

  @override
  State<NdrlBountyEditScreen> createState() => _NdrlBountyEditScreenState();
}

class _NdrlBountyEditScreenState extends State<NdrlBountyEditScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _picker = ImagePicker();
  late final _service = MyBountiesService(widget.authService);
  late final _submission = BountySubmissionService(widget.authService);
  MyBounty? _bounty;
  List<EligibleBountyRacer> _racers = [];
  int _registrationId = 0;
  String _selectedName = '';
  final Map<String, _ImageAction> _actions = {
    'target': _ImageAction.keep,
    'poster': _ImageAction.keep,
  };
  final Map<String, XFile> _files = {};
  bool _loading = true;
  bool _busy = false;
  bool _detailsSaved = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final bounty = await _service.detail(widget.bountyId);
      if (!mounted) return;
      if (initial) {
        _title.text = bounty.title;
        _description.text = bounty.description;
        _amount.text = bounty.rawAmount;
        _registrationId = bounty.registrationId;
        _selectedName = '${bounty.racerName} · ${bounty.className}';
      }
      setState(() => _bounty = bounty);
      if (bounty.editable && bounty.eventId > 0) {
        try {
          final racers = await _submission.eligibleRacers(bounty.eventId);
          if (mounted) setState(() => _racers = racers);
        } catch (e) {
          if (mounted) {
            setState(
              () => _notice =
                  'Racer list unavailable: $e. You can keep the current target.',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseRacer() async {
    String query = '';
    final chosen = await showModalBottomSheet<EligibleBountyRacer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) {
          final filtered = _racers
              .where((r) => r.searchText.contains(query.toLowerCase()))
              .toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                18,
                16,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * .65,
                child: Column(
                  children: [
                    const Text(
                      'SELECT TARGET RACER',
                      style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      onChanged: (v) => update(() => query = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search racer, class or car',
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final r = filtered[i];
                          return ListTile(
                            title: Text(r.name),
                            subtitle: Text(
                              '${r.className} · #${r.carNumber} · ${r.carDescription}',
                            ),
                            onTap: () => Navigator.pop(sheetContext, r),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        _registrationId = chosen.registrationId;
        _selectedName =
            '${chosen.name} · ${chosen.className} · #${chosen.carNumber}';
        _detailsSaved = false;
      });
    }
  }

  Future<void> _pick(String type) async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const AuthException('Images must be 5 MB or smaller.');
      }
      final ext = file.name.toLowerCase();
      if (!['.jpg', '.jpeg', '.png', '.webp'].any(ext.endsWith)) {
        throw const AuthException('Choose a JPEG, PNG or WebP image.');
      }
      if (mounted) {
        setState(() {
          _files[type] = file;
          _actions[type] = _ImageAction.replace;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _save() async {
    if (_busy || _bounty?.editable != true || !_form.currentState!.validate()) {
      return;
    }
    if (_registrationId <= 0) {
      setState(() => _error = 'Select a valid target racer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    var savedText = _detailsSaved;
    try {
      // Always check current permissions before modifying anything.
      final latest = await _service.detail(widget.bountyId);
      if (!latest.editable) {
        if (mounted) {
          setState(() {
            _bounty = latest;
            _error = 'This bounty is no longer editable. Refresh to view the approved details.';
          });
        }
        return;
      }
      if (!savedText) {
        await _service.update(
          bountyId: widget.bountyId,
          registrationId: _registrationId,
          title: _title.text.trim(),
          description: _description.text.trim(),
          amount: double.parse(_amount.text.trim()).toStringAsFixed(2),
        );
        savedText = true;
        _detailsSaved = true;
      }
      for (final type in ['target', 'poster']) {
        final action = _actions[type] ?? _ImageAction.keep;
        if (action == _ImageAction.keep) continue;
        try {
          if (action == _ImageAction.remove) {
            await _service.removeImage(widget.bountyId, type);
          } else {
            await _submission.upload(widget.bountyId, type, _files[type]!);
          }
          _actions[type] = _ImageAction.keep;
          _files.remove(type);
        } catch (e) {
          if (mounted) {
            setState(
              () => _error =
                  'Bounty details saved, but the $type image change failed: $e. Tap Save to retry the remaining image changes.',
            );
          }
          break;
        }
      }
      final refreshed = await _service.detail(widget.bountyId);
      if (!mounted) return;
      setState(() => _bounty = refreshed);
      if (!refreshed.editable) {
        setState(
          () => _error ??=
              'The bounty is now locked. No further edits are allowed.',
        );
      } else if (_error == null) {
        setState(() => _notice = 'Changes saved successfully.');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              '$e. Refresh details before retrying if approval status changed.',
        );
        try {
          final latest = await _service.detail(widget.bountyId);
          if (mounted) setState(() => _bounty = latest);
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _imageEditor(String type) {
    final current = type == 'target' ? _bounty?.targetPhoto : _bounty?.poster;
    final action = _actions[type] ?? _ImageAction.keep;
    final file = _files[type];
    return Card(
      color: _surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type == 'target' ? 'TARGET PHOTO' : 'CUSTOM POSTER',
              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (action == _ImageAction.remove)
              const Text('Image will be removed when saved.'),
            if (action == _ImageAction.replace && file != null)
              Image.file(
                File(file.path),
                height: 150,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            if (action == _ImageAction.keep && current != null)
              Image.network(
                current.toString(),
                height: 150,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
            if (action == _ImageAction.keep && current == null)
              const Text('No image selected'),
            Wrap(
              spacing: 6,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : () => _pick(type),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(current == null ? 'Add' : 'Replace'),
                ),
                if (current != null || action == _ImageAction.replace)
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _actions[type] = _ImageAction.remove;
                            _files.remove(type);
                          }),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                if (action != _ImageAction.keep)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _actions[type] = _ImageAction.keep;
                            _files.remove(type);
                          }),
                    child: const Text('Undo'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editable = _bounty?.editable == true;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: const Color(0xFF111111),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111111),
          title: const Text('EDIT BOUNTY'),
          actions: [
            IconButton(
              tooltip: 'Refresh status',
              onPressed: _busy ? null : () => _load(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _notice!,
                        style: const TextStyle(color: _gold),
                      ),
                    ),
                  if (_bounty == null)
                    const Text('Bounty details unavailable.'),
                  if (_bounty != null && !editable) ...[
                    const Icon(Icons.lock_outline, color: _gold, size: 42),
                    const Text(
                      'This bounty is read-only. Editing is not permitted.',
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to details'),
                    ),
                  ],
                  if (_bounty != null && editable) ...[
                    Text(
                      _bounty!.eventName,
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy || _racers.isEmpty
                                ? null
                                : _chooseRacer,
                            icon: const Icon(Icons.person_search),
                            label: Text(
                              _selectedName.isEmpty
                                  ? 'Select target racer'
                                  : _selectedName,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _title,
                            maxLength: 150,
                            enabled: !_busy,
                            onChanged: (_) => _detailsSaved = false,
                            decoration: const InputDecoration(
                              labelText: 'Bounty title',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Title is required'
                                : null,
                          ),
                          TextFormField(
                            controller: _description,
                            maxLength: 5000,
                            maxLines: 3,
                            enabled: !_busy,
                            onChanged: (_) => _detailsSaved = false,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                            ),
                          ),
                          TextFormField(
                            controller: _amount,
                            enabled: !_busy,
                            onChanged: (_) => _detailsSaved = false,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Reward amount (USD)',
                              prefixText: '\$ ',
                            ),
                            validator: (v) {
                              final raw = v?.trim() ?? '';
                              if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$')
                                      .hasMatch(raw) ||
                                  (double.tryParse(raw) ?? 0) <= 0) {
                                return 'Enter a positive USD amount (up to 2 decimals)';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    _imageEditor('target'),
                    _imageEditor('poster'),
                    if (_busy) const LinearProgressIndicator(color: _red),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save changes'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Cancel / Back'),
                    ),
                    const Text(
                      'Changes are allowed only while this bounty is pending and the server permits editing.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
