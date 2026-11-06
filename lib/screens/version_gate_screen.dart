import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/app_update_service.dart';
import 'app_shell.dart';

class NdrlVersionGateScreen extends StatefulWidget {
  const NdrlVersionGateScreen({super.key, required this.authService});
  final AuthService authService;
  @override
  State<NdrlVersionGateScreen> createState() => _NdrlVersionGateScreenState();
}

class _NdrlVersionGateScreenState extends State<NdrlVersionGateScreen>
    with WidgetsBindingObserver {
  AppUpdatePolicy? _policy;
  bool _checking = true;
  bool _skipOptional = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking && _policy != null) return;
    if (mounted) setState(() => _checking = true);
    final result = await AppUpdateService.check();
    if (!mounted) return;
    setState(() {
      _policy = result;
      _checking = false;
      _skipOptional = false;
    });
  }

  Future<void> _update(AppUpdatePolicy policy) async {
    final uri = Uri.tryParse(policy.updateUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Update link unavailable. Please contact NDRL support.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = _policy;
    // While rechecking, never show the app behind a previously mandatory gate.
    if (_checking && (policy == null || policy.mandatory)) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC52A35)),
        ),
      );
    }
    if (policy != null &&
        !policy.mandatory &&
        (policy.status == 'current' || _skipOptional)) {
      return NdrlAppShell(authService: widget.authService);
    }
    if (policy == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: _check,
            child: const Text('Retry version check'),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF080A12),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/ndrl_logo.png',
                    height: 105,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.sports_motorsports, size: 72),
                  ),
                  const SizedBox(height: 28),
                  Icon(
                    policy.mandatory ? Icons.lock_outline : Icons.system_update,
                    color: const Color(0xFFD1AC67),
                    size: 52,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    policy.mandatory ? 'UPDATE REQUIRED' : 'UPDATE AVAILABLE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Installed build ${policy.installedBuild}  •  Latest build ${policy.latestBuild}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  if (policy.message.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      policy.message,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (policy.offline) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Using a recently saved update policy. Connect to the internet and retry to confirm.',
                      style: TextStyle(color: Color(0xFFD1AC67)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: policy.updateUrl.isEmpty
                          ? null
                          : () => _update(policy),
                      icon: const Icon(Icons.download),
                      label: const Text('UPDATE NOW'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC52A35),
                        padding: const EdgeInsets.all(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _checking ? null : _check,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Check'),
                  ),
                  if (!policy.mandatory)
                    TextButton(
                      onPressed: () => setState(() => _skipOptional = true),
                      child: const Text('Maybe Later'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
