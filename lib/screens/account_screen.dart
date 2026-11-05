import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';

class NdrlAccountScreen extends StatefulWidget {
  const NdrlAccountScreen({super.key, required this.authService});
  final AuthService authService;
  @override
  State<NdrlAccountScreen> createState() => _NdrlAccountScreenState();
}

class _NdrlAccountScreenState extends State<NdrlAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  bool _hidePin = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_changed);
  }

  void _changed() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    widget.authService.removeListener(_changed);
    _email.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() { _busy = true; _error = null; });
    try { await task(); }
    catch (e) { if (mounted) setState(() => _error = e is AuthException ? e.message : 'Something went wrong'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authService;
    return Scaffold(
      backgroundColor: ndrlBackground,
      appBar: AppBar(backgroundColor: ndrlBackground, title: const Text('My Account')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.account_circle_outlined, color: ndrlGold, size: 70),
        const SizedBox(height: 16),
        if (auth.loading || _busy) const LinearProgressIndicator(color: ndrlRed),
        if (_error != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
        ),
        if (auth.signedIn) ...[
          Text('Welcome, ${auth.account?['display_name'] ?? 'NDRL Member'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(color: ndrlSurface, child: Column(children: [
            ListTile(title: const Text('Email'), subtitle: Text('${auth.account?['email'] ?? ''}')),
            ListTile(title: const Text('Member ID'), subtitle: Text('${auth.account?['member_id'] ?? 'Not linked'}')),
          ])),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(() => auth.logout()),
            icon: const Icon(Icons.logout), label: const Text('Log out of this device'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () async {
              final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
                title: const Text('Log out of all devices?'),
                content: const Text('This will end every mobile session for your NDRL account.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out all')),
                ],
              ));
              if (confirmed == true) await _run(() => auth.logout(allDevices: true));
            },
            child: const Text('Log out of all devices'),
          ),
        ] else if (auth.loading) ...[
          const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Checking your session...'))),
        ] else ...[
          const Text('MEMBER LOGIN', textAlign: TextAlign.center,
            style: TextStyle(color: ndrlGold, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Use your existing NDRL website email and PIN.', textAlign: TextAlign.center),
          const SizedBox(height: 22),
          Form(key: _form, child: Column(children: [
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              validator: (v) => v == null || !v.contains('@') ? 'Enter your email' : null),
            const SizedBox(height: 14),
            TextFormField(controller: _pin, obscureText: _hidePin,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: 'PIN', border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: Icon(_hidePin ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hidePin = !_hidePin))),
              validator: (v) => v == null || v.isEmpty ? 'Enter your PIN' : null),
          ])),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : () {
              if (_form.currentState!.validate()) {
                _run(() => auth.login(_email.text, _pin.text));
              }
            },
            icon: const Icon(Icons.login), label: const Text('Sign in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _busy ? null : () => _run(auth.retry),
            child: const Text('Restore existing session')),
        ],
      ]),
    );
  }
}
