import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';

class NdrlEditProfileScreen extends StatefulWidget {
  const NdrlEditProfileScreen({super.key, required this.authService, required this.member});
  final AuthService authService;
  final Map<String, dynamic> member;
  @override
  State<NdrlEditProfileScreen> createState() => _NdrlEditProfileScreenState();
}

class _NdrlEditProfileScreenState extends State<NdrlEditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  String _contactMethod = 'email';
  String get _legalName {
    final first = (widget.member['first_name'] ?? '').toString().trim();
    final last = (widget.member['last_name'] ?? '').toString().trim();
    return [first, last].where((part) => part.isNotEmpty).join(' ');
  }

  bool _saving = false;
  String? _error;

  static const _labels = <String, String>{
    'preferred_first_name': 'Preferred first name',
    'phone_mobile': 'Mobile phone',
    'phone_alt': 'Alternate phone',
    'address_line1': 'Address line 1',
    'address_line2': 'Address line 2',
    'city': 'City',
    'state': 'State',
    'postal_code': 'ZIP / Postal code',
    'country': 'Country',
  };
  static const _limits = <String, int>{
    'preferred_first_name': 100, 'phone_mobile': 50, 'phone_alt': 50,
    'address_line1': 150, 'address_line2': 150, 'city': 100,
    'state': 100, 'postal_code': 30, 'country': 100,
  };

  @override
  void initState() {
    super.initState();
    for (final key in _labels.keys) {
      _fields[key] = TextEditingController(text: widget.member[key]?.toString() ?? '');
    }
    final initial = widget.member['preferred_contact_method']?.toString();
    _contactMethod = ['email', 'phone', 'none'].contains(initial) ? initial! : 'email';
  }

  @override
  void dispose() {
    for (final controller in _fields.values) { controller.dispose(); }
    super.dispose();
  }

  Widget _field(String key, {TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_saving,
      keyboardType: keyboard,
      maxLength: _limits[key],
      decoration: InputDecoration(labelText: _labels[key],
        border: const OutlineInputBorder(), counterText: ''),
      validator: (value) => (value?.runes.length ?? 0) > _limits[key]!
        ? 'Too many characters' : null,
    ),
  );

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final changes = <String, dynamic>{};
    for (final entry in _fields.entries) {
      final next = entry.value.text.trim();
      final old = widget.member[entry.key]?.toString().trim() ?? '';
      if (next != old) changes[entry.key] = next;
    }
    if (_contactMethod != (widget.member['preferred_contact_method']?.toString() ?? 'email')) {
      changes['preferred_contact_method'] = _contactMethod;
    }
    if (changes.isEmpty) { Navigator.of(context).pop(false); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.authService.updateMemberProfile(changes);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ndrlBackground,
    appBar: AppBar(backgroundColor: ndrlBackground,
      title: const Text('Edit Profile')),
    body: Form(key: _form, child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _legalName.isEmpty
            ? 'Your legal name is managed by NDRL.'
            : 'Your legal name is $_legalName.',
          style: const TextStyle(
            color: ndrlGold, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Want us to call you something different? Enter your preferred first name below.',
        ),
        const SizedBox(height: 6),
        const Text(
          'Leave this field blank to use your legal first name.',
          style: TextStyle(color: ndrlGold, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your legal name and login email are managed by NDRL.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 18),
        _field('preferred_first_name'),
        _field('phone_mobile', keyboard: TextInputType.phone),
        _field('phone_alt', keyboard: TextInputType.phone),
        const SizedBox(height: 10),
        const Text('MAILING ADDRESS', style: TextStyle(
          color: ndrlGold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _field('address_line1'), _field('address_line2'),
        _field('city'), _field('state'), _field('postal_code'), _field('country'),
        DropdownButtonFormField<String>(
          value: _contactMethod,
          decoration: const InputDecoration(labelText: 'Preferred contact method',
            border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'email', child: Text('Email')),
            DropdownMenuItem(value: 'phone', child: Text('Phone')),
            DropdownMenuItem(value: 'none', child: Text('None')),
          ],
          onChanged: _saving ? null : (value) {
            if (value != null) setState(() => _contactMethod = value);
          },
        ),
        if (_error != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save),
          label: Text(_saving ? 'Saving...' : 'Save Changes'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel')),
      ],
    )),
  );
}
