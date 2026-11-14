import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'app_shell.dart';

class NdrlLoginScreen extends StatefulWidget {
  const NdrlLoginScreen({super.key, required this.authService});
  final AuthService authService;
  @override
  State<NdrlLoginScreen> createState() => _NdrlLoginScreenState();
}

class _NdrlLoginScreenState extends State<NdrlLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  bool _hidePin = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = e is AuthException ? e.message : 'Something went wrong',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authService;
    return Scaffold(
      backgroundColor: ndrlBackground,
      appBar: AppBar(
        backgroundColor: ndrlBackground,
        title: const Text('Member Login'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.account_circle_outlined, color: ndrlGold, size: 70),
          const SizedBox(height: 16),
          if (auth.loading || _busy)
            const LinearProgressIndicator(color: ndrlRed),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          const Text(
            'MEMBER LOGIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ndrlGold,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use your existing NDRL website email and PIN.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || !v.contains('@') ? 'Enter your email' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pin,
                  obscureText: _hidePin,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hidePin ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _hidePin = !_hidePin),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your PIN' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () {
                    if (_form.currentState!.validate()) {
                      _run(() => auth.login(_email.text, _pin.text));
                    }
                  },
            icon: const Icon(Icons.login),
            label: const Text('Sign in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () => _run(auth.retry),
            child: const Text('Restore existing session'),
          ),
        ],
      ),
    );
  }
}
