import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
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

  Future<void> _openWebUrl(String path) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open web page')),
      );
    }
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

  Future<void> _openTokenRequestSheet({required String mode}) async {
    final isReset = mode == 'reset';
    final emailCtrl = TextEditingController(text: _email.text.trim());
    final formKey = GlobalKey<FormState>();
    bool sending = false;
    String? feedback;
    bool isError = false;
    bool alreadyHasPin = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ndrlSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate() || sending) return;
              setSheetState(() {
                sending = true;
                feedback = null;
                isError = false;
                alreadyHasPin = false;
              });
              try {
                final res = await widget.authService.requestLoginToken(
                  email: emailCtrl.text,
                  mode: mode,
                );
                setSheetState(() {
                  feedback = (res['message'] as String?) ??
                      'Check your inbox for instructions.';
                  alreadyHasPin = res['already_has_pin'] == true;
                  isError = false;
                });
              } catch (e) {
                setSheetState(() {
                  feedback = e is AuthException
                      ? e.message
                      : 'Unable to process request right now.';
                  isError = true;
                });
              } finally {
                if (ctx.mounted) setSheetState(() => sending = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isReset ? 'RESET MEMBER PIN' : 'REQUEST LOGIN TOKEN',
                        style: const TextStyle(
                          color: ndrlGold,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isReset
                            ? 'Enter the email on your NDRL account and we will send a PIN reset link.'
                            : 'Enter the email on file with NDRL. We will send you an account claim link to set your PIN.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Enter a valid email address'
                            : null,
                      ),
                      if (feedback != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isError
                                ? Colors.red.withValues(alpha: 0.15)
                                : Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isError
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent,
                            ),
                          ),
                          child: Text(
                            feedback!,
                            style: TextStyle(
                              color: isError
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: sending ? null : submit,
                        icon: Icon(
                          isReset ? Icons.lock_reset : Icons.mail_outline,
                        ),
                        label: Text(
                          sending
                              ? 'Sending...'
                              : (isReset
                                    ? 'Send Reset Link'
                                    : 'Send Claim Link'),
                        ),
                      ),
                      if (alreadyHasPin) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openTokenRequestSheet(mode: 'reset');
                          },
                          child: const Text('Need to reset your PIN instead?'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted && emailCtrl.text.trim().isNotEmpty) {
      _email.text = emailCtrl.text.trim();
    }
    Future<void>.delayed(const Duration(milliseconds: 400), emailCtrl.dispose);
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
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _openTokenRequestSheet(mode: 'claim'),
            icon: const Icon(Icons.vpn_key_outlined, color: ndrlGold),
            label: const Text('Request Login Token / Claim Account'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _busy
                ? null
                : () => _openTokenRequestSheet(mode: 'reset'),
            child: const Text(
              'Forgot PIN?',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => _openWebUrl('/pages/privacy.php'),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
              const Text('·', style: TextStyle(color: Colors.white38)),
              TextButton(
                onPressed: () => _openWebUrl('/pages/terms.php'),
                child: const Text(
                  'Terms of Use',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
