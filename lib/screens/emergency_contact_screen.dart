import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';

class NdrlEmergencyContactScreen extends StatefulWidget {
  const NdrlEmergencyContactScreen({super.key, required this.authService, this.contact});
  final AuthService authService;
  final Map<String, dynamic>? contact;
  @override
  State<NdrlEmergencyContactScreen> createState() => _NdrlEmergencyContactScreenState();
}

class _NdrlEmergencyContactScreenState extends State<NdrlEmergencyContactScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _busy = false;
  String? _error;
  static const _labels = {
    'contact_name': 'Contact name', 'relationship': 'Relationship',
    'phone': 'Phone number', 'email': 'Email (optional)', 'notes': 'Notes (optional)',
  };
  static const _limits = {
    'contact_name': 150, 'relationship': 100, 'phone': 50,
    'email': 190, 'notes': 255,
  };
  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final key in _labels.keys)
        key: TextEditingController(text: widget.contact?[key]?.toString() ?? ''),
    };
  }
  @override
  void dispose() {
    for (final controller in _controllers.values) { controller.dispose(); }
    super.dispose();
  }
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final fields = {for (final entry in _controllers.entries) entry.key: entry.value.text.trim()};
    setState(() { _busy = true; _error = null; });
    try {
      if (widget.contact == null) {
        await widget.authService.profileAction('emergency_add', fields);
      } else {
        await widget.authService.profileAction('emergency_update', {
          'emergency_id': widget.contact!['emergency_id'], ...fields,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ndrlBackground,
    appBar: AppBar(backgroundColor: ndrlBackground,
      title: Text(widget.contact == null ? 'Add Emergency Contact' : 'Edit Emergency Contact')),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Emergency contact information',
        style: TextStyle(color: ndrlGold, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      for (final entry in _labels.entries) Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: _controllers[entry.key], enabled: !_busy,
          maxLength: _limits[entry.key],
          keyboardType: entry.key == 'phone' ? TextInputType.phone
            : entry.key == 'email' ? TextInputType.emailAddress : TextInputType.text,
          decoration: InputDecoration(labelText: entry.value, border: const OutlineInputBorder()),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (['contact_name', 'relationship', 'phone'].contains(entry.key) && text.isEmpty) {
              return 'Required';
            }
            if (entry.key == 'email' && text.isNotEmpty &&
                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12),
        child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
      FilledButton.icon(onPressed: _busy ? null : _save,
        icon: const Icon(Icons.save), label: Text(_busy ? 'Saving...' : 'Save Contact')),
    ])),
  );
}
