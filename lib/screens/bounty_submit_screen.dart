import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/bounty_service.dart';
import '../services/bounty_submission_service.dart';

const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _surface = Color(0xFF111626);

class NdrlBountySubmitScreen extends StatefulWidget {
  const NdrlBountySubmitScreen({
    super.key,
    required this.authService,
    required this.event,
  });
  final AuthService authService;
  final BountyEvent event;

  @override
  State<NdrlBountySubmitScreen> createState() => _NdrlBountySubmitScreenState();
}

class _NdrlBountySubmitScreenState extends State<NdrlBountySubmitScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _picker = ImagePicker();
  late final BountySubmissionService _service = BountySubmissionService(
    widget.authService,
  );
  List<EligibleBountyRacer> _racers = [];
  EligibleBountyRacer? _selected;
  XFile? _target;
  XFile? _poster;
  bool _loading = true;
  bool _busy = false;
  int? _createdId;
  final Set<String> _uploaded = {};
  String? _error;
  String _progress = '';

  @override
  void initState() {
    super.initState();
    _loadRacers();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadRacers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final racers = await _service.eligibleRacers(widget.event.id);
      if (mounted) setState(() => _racers = racers);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseRacer() async {
    String searchQuery = '';
    final choice = await showModalBottomSheet<EligibleBountyRacer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) {
          final filtered = _racers
              .where((r) => r.searchText.contains(searchQuery.toLowerCase()))
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
                      onChanged: (value) => update(() => searchQuery = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search racer, class or car',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final racer = filtered[i];
                          return ListTile(
                            title: Text(racer.name),
                            subtitle: Text(
                              '${racer.className} · #${racer.carNumber}${racer.carDescription.isEmpty ? '' : ' · ${racer.carDescription}'}',
                            ),
                            onTap: () => Navigator.pop(sheetContext, racer),
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
    if (choice != null && mounted) setState(() => _selected = choice);
  }

  Future<void> _pick(String type) async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.length();
      if (bytes > 5 * 1024 * 1024) {
        if (mounted) setState(() => _error = 'Images must be 5 MB or smaller.');
        return;
      }
      final ext = file.name.toLowerCase();
      if (!ext.endsWith('.jpg') &&
          !ext.endsWith('.jpeg') &&
          !ext.endsWith('.png') &&
          !ext.endsWith('.webp')) {
        if (mounted)
          setState(() => _error = 'Choose a JPEG, PNG or WebP image.');
        return;
      }
      if (mounted)
        setState(() {
          if (type == 'target') {
            _target = file;
          } else {
            _poster = file;
          }
          _error = null;
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to select image.');
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_createdId == null) {
      if (!_form.currentState!.validate()) return;
      if (_selected == null) {
        setState(() => _error = 'Select a target racer.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_createdId == null) {
        setState(() => _progress = 'Creating pending bounty...');
        final id = await _service.submit(
          eventId: widget.event.id,
          registrationId: _selected!.registrationId,
          title: _title.text.trim(),
          description: _description.text.trim(),
          amount: double.parse(_amount.text.trim()).toStringAsFixed(2),
        );
        if (!mounted) return;
        setState(() => _createdId = id);
      }
      for (final entry in <String, XFile?>{
        'target': _target,
        'poster': _poster,
      }.entries) {
        if (entry.value == null || _uploaded.contains(entry.key)) continue;
        if (mounted)
          setState(() => _progress = 'Uploading ${entry.key} image...');
        try {
          await _service.upload(_createdId!, entry.key, entry.value!);
          _uploaded.add(entry.key);
        } catch (e) {
          if (mounted) setState(() => _error = '${entry.key} image: $e');
          // Continue uploading the other optional image.
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _progress = '';
        });
    }
  }

  Widget _imageField(String type, XFile? file) {
    final uploaded = _uploaded.contains(type);
    return Card(
      color: _surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type == 'target'
                  ? 'TARGET PHOTO (OPTIONAL)'
                  : 'CUSTOM POSTER (OPTIONAL)',
              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (file != null) ...[
              Image.file(
                File(file.path),
                height: 155,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
              Text(
                uploaded ? 'Uploaded successfully' : file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            Row(
              children: [
                TextButton.icon(
                  onPressed: _busy || _createdId != null
                      ? null
                      : () => _pick(type),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(file == null ? 'Choose image' : 'Replace'),
                ),
                if (file != null && _createdId == null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            if (type == 'target') {
                              _target = null;
                            } else {
                              _poster = null;
                            }
                          }),
                    child: const Text('Remove'),
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
    final created = _createdId != null;
    final pendingUploads =
        (_target != null && !_uploaded.contains('target')) ||
        (_poster != null && !_uploaded.contains('poster'));
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: const Color(0xFF111111),
        appBar: AppBar(
          title: const Text('SUBMIT A BOUNTY'),
          backgroundColor: const Color(0xFF111111),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.event.name,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (created) ...[
                    Card(
                      color: _surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BOUNTY SUBMITTED',
                              style: TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              'Bounty #$_createdId is awaiting administrator approval.',
                            ),
                            if (pendingUploads)
                              const Text(
                                'One or more optional images still need uploading.',
                                style: TextStyle(color: Colors.orangeAccent),
                              ),
                            if (!pendingUploads)
                              const Text('All selected images are uploaded.'),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
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
                              _selected == null
                                  ? 'Select target racer'
                                  : '${_selected!.name} · ${_selected!.className} · #${_selected!.carNumber}',
                            ),
                          ),
                          if (_racers.isEmpty)
                            const Text(
                              'No eligible racers available for this event.',
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _title,
                            maxLength: 150,
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
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                            ),
                          ),
                          TextFormField(
                            controller: _amount,
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
                    const SizedBox(height: 12),
                    _imageField('target', _target),
                    _imageField('poster', _poster),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  if (_busy) ...[
                    const LinearProgressIndicator(color: _red),
                    Text(_progress),
                  ],
                  const SizedBox(height: 12),
                  if (!created || pendingUploads)
                    FilledButton.icon(
                      onPressed: _busy || (!created && _racers.isEmpty)
                          ? null
                          : _submit,
                      icon: const Icon(Icons.send),
                      label: Text(
                        created
                            ? 'Retry failed image uploads'
                            : 'Submit for approval',
                      ),
                    ),
                  if (created)
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pending administrator approval. Payment is handled outside the app.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
      ),
    );
  }
}
