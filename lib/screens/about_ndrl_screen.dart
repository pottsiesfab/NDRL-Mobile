import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/about_ndrl_service.dart';

const _bg = Color(0xFF111111);
const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlAboutScreen extends StatefulWidget {
  const NdrlAboutScreen({super.key, this.contactsOnly = false});

  final bool contactsOnly;
  @override
  State<NdrlAboutScreen> createState() => _NdrlAboutScreenState();
}

class _NdrlAboutScreenState extends State<NdrlAboutScreen> {
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _data = AboutNdrlService.fetch();
  }

  void _refresh() {
    setState(() {
      _data = AboutNdrlService.fetch();
    });
  }

  Widget _section(String heading, Widget content) => Card(
    color: _surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    ),
  );

  Future<void> _launch(String scheme, String value) async {
    final uri = Uri(scheme: scheme, path: value);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open contact method')),
      );
    }
  }

  Future<void> _openWebUrl(String path) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open web page')));
    }
  }

  Widget _contact(Map<String, dynamic> contact) {
    final name = (contact['display_name'] ?? '').toString();
    final role = (contact['role_title'] ?? '').toString();
    final classLabel = (contact['class_label'] ?? '').toString();
    final email = (contact['email'] ?? '').toString();
    final phone = (contact['phone'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (classLabel.isNotEmpty)
            Text(classLabel, style: const TextStyle(color: _gold)),
          if (role.isNotEmpty)
            Text(role, style: const TextStyle(color: Colors.white70)),
          if (email.isNotEmpty || phone.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                if (email.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _launch('mailto', email),
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email'),
                  ),
                if (phone.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _launch('tel', phone),
                    icon: const Icon(Icons.phone_outlined),
                    label: const Text('Call'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _legalAndSupportCard() => _section(
    'LEGAL & SUPPORT',
    Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined, color: _gold),
          title: const Text('Privacy Policy'),
          subtitle: const Text('How NDRL collects and protects member data'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openWebUrl('/pages/privacy.php'),
        ),
        const Divider(color: Colors.white12, height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.gavel_outlined, color: _gold),
          title: const Text('Terms of Use'),
          subtitle: const Text('Community guidelines and league app terms'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openWebUrl('/pages/terms.php'),
        ),
        const Divider(color: Colors.white12, height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.manage_accounts_outlined, color: _gold),
          title: const Text('Account Deletion & Support'),
          subtitle: const Text('Manage or request account deletion online'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openWebUrl('/pages/account-deletion.php'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: _bg,
      title: Text(widget.contactsOnly ? 'Contact Us' : 'About NDRL'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _red));
        }
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: Text('Unable to load About NDRL.')),
              const SizedBox(height: 12),
              Center(
                child: FilledButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(height: 20),
              _legalAndSupportCard(),
            ],
          );
        }
        final data = snapshot.data!;
        final sections = (data['sections'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        final contacts = (data['contacts'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        final board = contacts
            .where((c) => c['contact_group'] == 'executive')
            .toList();
        final reps = contacts
            .where((c) => c['contact_group'] == 'class_rep')
            .toList();
        return RefreshIndicator(
          onRefresh: () async {
            final next = AboutNdrlService.fetch();
            setState(() {
              _data = next;
            });
            await next;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            children: [
              Center(
                child: Image.asset(
                  'assets/images/ndrl_logo.png',
                  height: 135,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              if (!widget.contactsOnly)
                for (final s in sections)
                  if ((s['body'] ?? '').toString().trim().isNotEmpty)
                    _section(
                      (s['heading'] ?? '').toString(),
                      SelectableText((s['body'] ?? '').toString()),
                    ),
              if (board.isNotEmpty)
                _section(
                  'EXECUTIVE BOARD',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: board.map(_contact).toList(),
                  ),
                ),
              if (reps.isNotEmpty)
                _section(
                  'CLASS REPRESENTATIVES',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: reps.map(_contact).toList(),
                  ),
                ),
              if (widget.contactsOnly
                  ? contacts.isEmpty
                  : (sections.isEmpty && contacts.isEmpty))
                _section(
                  widget.contactsOnly ? 'CONTACT US' : 'ABOUT NDRL',
                  Text(
                    widget.contactsOnly
                        ? 'Contact information is being prepared.'
                        : 'Organization information is being prepared.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              _legalAndSupportCard(),
            ],
          ),
        );
      },
    ),
  );
}
