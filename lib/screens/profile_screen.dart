import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'app_shell.dart';
import 'edit_profile_screen.dart';
import 'emergency_contact_screen.dart';

import 'package:image_picker/image_picker.dart';

class NdrlProfileScreen extends StatefulWidget {
  const NdrlProfileScreen({super.key, required this.authService});
  final AuthService authService;
  @override
  State<NdrlProfileScreen> createState() => _NdrlProfileScreenState();
}

class _NdrlProfileScreenState extends State<NdrlProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _profileLoading = false;
  String? _profileError;
  int? _seasonId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    if (!mounted || !widget.authService.signedIn || _profileLoading) return;
    setState(() {
      _profileLoading = true;
      _profileError = null;
    });
    try {
      final result = await widget.authService.loadMemberProfile();
      if (!mounted) return;
      setState(() {
        _profile = result;
        final seasons = _maps(result['seasons']);
        final defaultId = _asInt(result['default_season_id']);
        if (!seasons.any((s) => _asInt(s['season_id']) == _seasonId)) {
          _seasonId = defaultId;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _profileError = e.toString());
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  bool _changingPhoto = false;
  Future<void> _pickPhoto({int? carId}) async {
    if (_changingPhoto) return;
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            carId == null ? 'Change profile photo?' : 'Change car photo?',
          ),
          content: Text(
            carId == null
                ? 'Upload this photo to your NDRL member profile?'
                : 'Upload this photo for your race car?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Upload'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _changingPhoto = true);
      await widget.authService.uploadProfileImage(
        carId == null ? 'avatar_upload' : 'car_avatar_upload',
        picked.path,
        carId: carId,
      );
      if (mounted) await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _changingPhoto = false);
    }
  }

  Future<void> _editContact(Map<String, dynamic>? contact) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NdrlEmergencyContactScreen(
          authService: widget.authService,
          contact: contact,
        ),
      ),
    );
    if (changed == true && mounted) await _loadProfile();
  }

  Future<void> _deleteContact(Map<String, dynamic> contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete emergency contact?'),
        content: Text(
          'Remove ${contact['contact_name']} from your emergency contacts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.authService.profileAction('emergency_delete', {
        'emergency_id': contact['emergency_id'],
      });
      if (mounted) await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  static List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : <Map<String, dynamic>>[];

  static int? _asInt(dynamic value) =>
      value is int ? value : int.tryParse('$value');

  static String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Not provided' : text;
  }

  Widget _detail(String label, dynamic value) => ListTile(
    dense: true,
    title: Text(label, style: const TextStyle(color: ndrlGold)),
    subtitle: Text(_value(value)),
  );

  Widget _profileContent() {
    if (_profileLoading && _profile == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: ndrlRed)),
      );
    }
    if (_profileError != null) {
      return Column(
        children: [
          Text(
            _profileError!,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
          TextButton.icon(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry profile'),
          ),
        ],
      );
    }
    final data = _profile;
    if (data == null) return const SizedBox.shrink();
    final member = data['member'] is Map<String, dynamic>
        ? data['member'] as Map<String, dynamic>
        : <String, dynamic>{};
    final seasons = _maps(data['seasons']);
    final contacts = _maps(data['emergency_contacts']);
    Map<String, dynamic>? selected;
    for (final season in seasons) {
      if (_asInt(season['season_id']) == _seasonId) {
        selected = season;
        break;
      }
    }
    final classes = _maps(selected?['classes']);
    final address = [
      member['address_line1'],
      member['address_line2'],
      [
        member['city'],
        member['state'],
        member['postal_code'],
      ].where((v) => v != null && '$v'.trim().isNotEmpty).join(', '),
      member['country'],
    ].where((v) => v != null && '$v'.trim().isNotEmpty).join('\n');
    final avatar = member['avatar_person_url']?.toString() ?? '';
    final avatarUri = Uri.tryParse(avatar);
    final validAvatar =
        avatarUri != null &&
        (avatarUri.scheme == 'https' || avatarUri.scheme == 'http') &&
        avatarUri.hasAuthority;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: InkWell(
            onTap: _changingPhoto ? null : () => _pickPhoto(),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: ndrlSurface,
                  foregroundImage: validAvatar ? NetworkImage(avatar) : null,
                  child: validAvatar
                      ? null
                      : const Icon(Icons.person, size: 46, color: ndrlGold),
                ),
                const CircleAvatar(
                  radius: 15,
                  backgroundColor: ndrlRed,
                  child: Icon(Icons.camera_alt, size: 17, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _changingPhoto ? null : () => _pickPhoto(),
          icon: const Icon(Icons.photo_library),
          label: Text(
            _changingPhoto ? 'Uploading photo...' : 'Change profile photo',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _value(
            ('${member['preferred_first_name'] ?? ''}').trim().isNotEmpty
                ? member['preferred_first_name']
                : member['first_name'],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loadProfile,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh profile'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => NdrlEditProfileScreen(
                  authService: widget.authService,
                  member: member,
                ),
              ),
            );
            if (changed == true && mounted) await _loadProfile();
          },
          icon: const Icon(Icons.edit),
          label: const Text('Edit Profile'),
        ),
        const SizedBox(height: 16),
        const Text(
          'PERSONAL INFORMATION',
          style: TextStyle(color: ndrlGold, fontWeight: FontWeight.bold),
        ),
        Card(
          color: ndrlSurface,
          child: Column(
            children: [
              _detail(
                'Legal name (admin managed)',
                '${_value(member['first_name'])} ${_value(member['last_name'])}',
              ),
              _detail('Preferred first name', member['preferred_first_name']),
              _detail('Email', member['email']),
              _detail('Mobile phone', member['phone_mobile']),
              _detail('Alternate phone', member['phone_alt']),
              _detail('Mailing address', address),
              _detail(
                'Preferred contact method',
                member['preferred_contact_method'],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'MEMBERSHIP',
          style: TextStyle(color: ndrlGold, fontWeight: FontWeight.bold),
        ),
        if (seasons.isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue: _seasonId,
            decoration: const InputDecoration(
              labelText: 'Season',
              border: OutlineInputBorder(),
            ),
            items: seasons
                .map(
                  (season) => DropdownMenuItem<int>(
                    value: _asInt(season['season_id']),
                    child: Text(_value(season['name'])),
                  ),
                )
                .toList(),
            onChanged: (id) => setState(() => _seasonId = id),
          )
        else
          const Text('No membership seasons found'),
        if (selected != null)
          Card(
            color: ndrlSurface,
            child: Column(
              children: [
                _detail('Membership type', selected['membership_type']),
                _detail('Membership status', selected['membership_status']),
                _detail(
                  'Expiration',
                  selected['expired_on'] ?? 'No expiration date recorded',
                ),
                if (classes.isEmpty)
                  const ListTile(title: Text('No racing classes registered')),
                ...classes.map((c) {
                  final carUrl = c['avatar_car_url']?.toString() ?? '';
                  final carUri = Uri.tryParse(carUrl);
                  final hasCarPhoto =
                      carUri != null &&
                      (carUri.scheme == 'https' || carUri.scheme == 'http') &&
                      carUri.hasAuthority;
                  final carId = _asInt(c['member_season_class_id']);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ndrlBackground,
                      foregroundImage: hasCarPhoto
                          ? NetworkImage(carUrl)
                          : null,
                      child: hasCarPhoto
                          ? null
                          : const Icon(Icons.directions_car, color: ndrlGold),
                    ),
                    title: Text(_value(c['class_name'])),
                    subtitle: Text(
                      'Car #${_value(c['car_number'])} • ${_value(c['car_desc'])}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Change car photo',
                      icon: const Icon(Icons.add_a_photo),
                      onPressed: _changingPhoto || carId == null
                          ? null
                          : () => _pickPhoto(carId: carId),
                    ),
                  );
                }),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'EMERGENCY CONTACTS',
          style: TextStyle(color: ndrlGold, fontWeight: FontWeight.bold),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _editContact(null),
            icon: const Icon(Icons.person_add),
            label: const Text('Add emergency contact'),
          ),
        ),
        if (contacts.isEmpty) const Text('No emergency contacts on file'),
        ...contacts.map(
          (contact) => Card(
            color: ndrlSurface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _detail('Name', contact['contact_name'])),
                    IconButton(
                      tooltip: 'Edit contact',
                      onPressed: () => _editContact(contact),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: 'Delete contact',
                      onPressed: () => _deleteContact(contact),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
                _detail('Relationship', contact['relationship']),
                _detail('Phone', contact['phone']),
                if (contact['email'] != null &&
                    '${contact['email']}'.isNotEmpty)
                  _detail('Email', contact['email']),
                if (contact['notes'] != null &&
                    '${contact['notes']}'.isNotEmpty)
                  _detail('Notes', contact['notes']),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authService;
    return Scaffold(
      backgroundColor: ndrlBackground,
      appBar: AppBar(
        backgroundColor: ndrlBackground,
        title: const Text('My Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: ndrlSurface,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Email'),
                  subtitle: Text('${auth.account?['email'] ?? ''}'),
                ),
                ListTile(
                  title: const Text('Member ID'),
                  subtitle: Text(
                    '${auth.account?['member_id'] ?? 'Not linked'}',
                  ),
                ),
              ],
            ),
          ),
          _profileContent(),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loggingOut ? null : () => _logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Log out of this device'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loggingOut ? null : _logoutAll,
            child: const Text('Log out of all devices'),
          ),
        ],
      ),
    );
  }

  bool _loggingOut = false;
  Future<void> _logout({bool all = false}) async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await widget.authService.logout(allDevices: all);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _logoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of all devices?'),
        content: const Text(
          'This will end every mobile session for your NDRL account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out all'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _logout(all: true);
  }
}
