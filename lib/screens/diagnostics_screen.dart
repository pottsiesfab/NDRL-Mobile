import '../config/app_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

const _base = '${AppConfig.baseUrl}';
const _background = Color(0xFF111111);
const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlDiagnosticsScreen extends StatefulWidget {
  const NdrlDiagnosticsScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<NdrlDiagnosticsScreen> createState() => _NdrlDiagnosticsScreenState();
}

class _CheckResult {
  const _CheckResult(this.name, this.status, this.detail, this.ms);
  final String name;
  final String status;
  final String detail;
  final int ms;
}

class _NdrlDiagnosticsScreenState extends State<NdrlDiagnosticsScreen> {
  bool _running = false;
  bool _showToken = false;
  String? _token;
  DateTime? _checkedAt;
  List<_CheckResult> _results = [];

  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (!mounted) return;
    setState(() {
      _token = null;
      _showToken = false;
      _results = [];
      _checkedAt = null;
    });
  }

  @override
  void dispose() {
    widget.authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _revealToken() async {
    // Never expose bearer credentials in production/release builds.
    if (kReleaseMode || AppConfig.environment != 'dev') return;
    if (_showToken) {
      setState(() {
        _showToken = false;
        _token = null;
      });
      return;
    }
    final token = await widget.authService.devDiagnosticAccessToken();
    if (!mounted) return;
    setState(() {
      _token = token;
      _showToken = token != null;
    });
  }

  Future<_CheckResult> _checkAuthenticated(String name, Uri uri) async {
    final watch = Stopwatch()..start();
    try {
      final data = await widget.authService.authorizedGet(uri);
      watch.stop();
      return _CheckResult(
        name,
        'PASS',
        data['has_team'] == false
            ? 'Connected (no Fantasy team for season)'
            : 'Authenticated response received',
        watch.elapsedMilliseconds,
      );
    } catch (e) {
      watch.stop();
      return _CheckResult(
        name,
        'FAIL',
        e.toString(),
        watch.elapsedMilliseconds,
      );
    }
  }

  Future<_CheckResult> _checkPublic(String name, Uri uri) async {
    final watch = Stopwatch()..start();
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      watch.stop();
      final parsed = jsonDecode(response.body);
      final valid = parsed is Map || parsed is List;
      return _CheckResult(
        name,
        response.statusCode >= 200 && response.statusCode < 300 && valid
            ? 'PASS'
            : 'FAIL',
        'HTTP ${response.statusCode}${valid ? ' · JSON response' : ' · Unexpected response'}',
        watch.elapsedMilliseconds,
      );
    } catch (e) {
      watch.stop();
      return _CheckResult(
        name,
        'FAIL',
        e is TimeoutException ? 'Timed out' : 'Connection or response error',
        watch.elapsedMilliseconds,
      );
    }
  }

  Future<void> _runChecks() async {
    if (_running) return;
    setState(() {
      _running = true;
      _results = [];
    });
    final checks = <_CheckResult>[];
    checks.add(
      await _checkPublic(
        'Public sponsors API',
        Uri.parse('$_base/api/sponsors_api.php'),
      ),
    );
    if (widget.authService.signedIn) {
      checks.add(
        await _checkAuthenticated(
          'Member authentication',
          Uri.parse('$_base/api/mobile_auth_api.php?action=me'),
        ),
      );
      checks.add(
        await _checkAuthenticated(
          'Member profile',
          Uri.parse('$_base/api/mobile_profile_api.php?action=me'),
        ),
      );
      checks.add(
        await _checkAuthenticated(
          'Fantasy roster API',
          Uri.parse(
            '$_base/fantasy/api/mobile_fantasy_api.php?action=my_rosters&fantasy_season_id=1',
          ),
        ),
      );
      checks.add(
        await _checkAuthenticated(
          'Fantasy roster options',
          Uri.parse(
            '$_base/fantasy/api/mobile_fantasy_api.php?action=roster_options&fantasy_season_id=1&fantasy_event_id=7',
          ),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _results = checks;
      _checkedAt = DateTime.now();
      _running = false;
    });
  }

  String _report() {
    final account = widget.authService.account;
    final lines = <String>[
      'NDRL Mobile Diagnostics',
      'Environment: ${AppConfig.environment.toUpperCase()}',
      'API: $_base',
      'Build: ${kReleaseMode ? 'release' : 'debug/profile'}',
      'Platform: ${defaultTargetPlatform.name}',
      'Signed in: ${widget.authService.signedIn}',
      'Account ID: ${account?['account_id'] ?? 'unknown'}',
      'Checked: ${_checkedAt?.toIso8601String() ?? 'not run'}',
      for (final r in _results)
        '${r.name}: ${r.status} (${r.ms} ms) — ${r.detail}',
      'Credentials: REDACTED',
    ];
    return lines.join('\n');
  }

  Widget _section(String title, List<Widget> children) => Card(
    color: _surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _gold,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Expanded(child: SelectableText(value, textAlign: TextAlign.right)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final account = widget.authService.account;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('Diagnostics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _section('APPLICATION', [
            _line('Environment', AppConfig.environment.toUpperCase()),
            _line('API host', Uri.parse(AppConfig.baseUrl).host),
            _line('Build mode', kReleaseMode ? 'Release' : 'Debug / Profile'),
            _line('Platform', defaultTargetPlatform.name),
          ]),
          _section('ACCOUNT', [
            _line(
              'Authentication',
              widget.authService.signedIn ? 'Signed in' : 'Not signed in',
            ),
            _line('Account ID', '${account?['account_id'] ?? 'Unavailable'}'),
            _line('Member ID', '${account?['member_id'] ?? 'Unavailable'}'),
            if (account?['email'] != null)
              _line('Email', '${account!['email']}'),
          ]),
          _section('DEVELOPER CREDENTIALS', [
            const Text(
              'Bearer tokens grant account access. Reveal only on a trusted DEV device.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            if (kReleaseMode || AppConfig.environment != 'dev')
              const Text(
                'Token reveal available only in DEV non-release builds.',
              ),
            if (!kReleaseMode && AppConfig.environment == 'dev') ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Access token'),
                subtitle: Text(
                  _showToken ? (_token ?? 'Unavailable') : '••••••••••••••••',
                  maxLines: _showToken ? 5 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: _showToken ? 'Hide token' : 'Reveal token',
                  icon: Icon(
                    _showToken ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: _revealToken,
                ),
              ),
              if (_showToken && _token != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _token!));
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'DEV access token copied. Treat it as a password.',
                          ),
                        ),
                      );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy DEV token'),
                ),
            ],
          ]),
          _section('CONNECTION TESTS', [
            const Text(
              'Read-only checks. No roster data will be changed.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: _running ? null : _runChecks,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_running ? 'Testing...' : 'Run connection tests'),
            ),
            if (_checkedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Last checked: ${_checkedAt!.toLocal()}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            for (final r in _results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  r.status == 'PASS' ? Icons.check_circle : Icons.error_outline,
                  color: r.status == 'PASS'
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
                title: Text(r.name),
                subtitle: Text('${r.detail}\n${r.ms} ms'),
                isThreeLine: true,
              ),
            if (_results.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _report()));
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Redacted diagnostic report copied'),
                      ),
                    );
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('Copy safe support report'),
              ),
          ]),
        ],
      ),
    );
  }
}
