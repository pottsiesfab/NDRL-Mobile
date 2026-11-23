import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'app_shell.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'my_tech_cards_screen.dart';
import 'bounty_board_screen.dart';
import 'my_racing_stats_screen.dart';

/// Account entry point: sign in when logged out; show a simple account
/// summary when signed in. The full member profile is a separate route.
class NdrlAccountScreen extends StatefulWidget {
  const NdrlAccountScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<NdrlAccountScreen> createState() => _NdrlAccountScreenState();
}

class _NdrlAccountScreenState extends State<NdrlAccountScreen> {
  bool _loggingOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _openTechCards() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NdrlMyTechCardsScreen(authService: widget.authService),
      ),
    );
  }

  Future<void> _openChangePinSheet() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool hideCurrent = true;
    bool hideNew = true;
    bool hideConfirm = true;
    bool saving = false;
    String sheetError = '';

    final updatedMessage = await showModalBottomSheet<String>(
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
              if (!formKey.currentState!.validate() || saving) return;
              setSheetState(() {
                saving = true;
                sheetError = '';
              });
              try {
                final msg = await widget.authService.changePin(
                  currentPin: currentCtrl.text,
                  newPin: newCtrl.text,
                  confirmPin: confirmCtrl.text,
                );
                if (ctx.mounted) Navigator.of(ctx).pop(msg);
              } catch (e) {
                setSheetState(() {
                  sheetError = e is AuthException
                      ? e.message
                      : 'Unable to update PIN right now.';
                });
              } finally {
                if (ctx.mounted) setSheetState(() => saving = false);
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
                      const Text(
                        'CHANGE MEMBER PIN',
                        style: TextStyle(
                          color: ndrlGold,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter your current PIN and choose a new 4-8 digit PIN.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (sheetError.isNotEmpty) ...[
                        Text(
                          sheetError,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: currentCtrl,
                        obscureText: hideCurrent,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Current PIN',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              hideCurrent
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setSheetState(() => hideCurrent = !hideCurrent),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter current PIN'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newCtrl,
                        obscureText: hideNew,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: InputDecoration(
                          labelText: 'New PIN (4-8 digits)',
                          counterText: '',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              hideNew ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setSheetState(() => hideNew = !hideNew),
                          ),
                        ),
                        validator: (v) {
                          final val = (v ?? '').trim();
                          if (!RegExp(r'^\d{4,8}$').hasMatch(val)) {
                            return 'PIN must be 4 to 8 digits';
                          }
                          if (val == currentCtrl.text.trim()) {
                            return 'New PIN must be different from current PIN';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmCtrl,
                        obscureText: hideConfirm,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: InputDecoration(
                          labelText: 'Confirm New PIN',
                          counterText: '',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              hideConfirm
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setSheetState(() => hideConfirm = !hideConfirm),
                          ),
                        ),
                        validator: (v) => v?.trim() != newCtrl.text.trim()
                            ? 'PINs do not match'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: saving ? null : submit,
                        icon: const Icon(Icons.lock_reset),
                        label: Text(saving ? 'Updating...' : 'Update PIN'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();

    if (updatedMessage != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(updatedMessage)));
    }
  }

  Future<void> _openDeleteAccountSheet() async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool hidePin = true;
    String sheetError = '';
    String? pendingPin;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ndrlSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void submit() {
              if (!formKey.currentState!.validate()) return;
              pendingPin = pinCtrl.text;
              Navigator.of(ctx).pop(true);
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
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: ndrlRed),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'DELETE ONLINE ACCOUNT',
                              style: TextStyle(
                                color: ndrlRed,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This action is permanent and will immediately:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'â€¢ Delete your online login credentials (email & PIN)\n'
                              'â€¢ Revoke all active app sessions & push device links\n'
                              'â€¢ Remove your uploaded member and race car photos',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Official NDRL club membership records and historical race results are retained for league record-keeping.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (sheetError.isNotEmpty) ...[
                        Text(
                          sheetError,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextFormField(
                        controller: pinCtrl,
                        obscureText: hidePin,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: InputDecoration(
                          labelText: 'Current Member PIN',
                          counterText: '',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              hidePin ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setSheetState(() => hidePin = !hidePin),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter your current PIN'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Type DELETE to confirm',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v ?? '').trim().toUpperCase() != 'DELETE'
                            ? 'Type DELETE exactly to confirm'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ndrlRed,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: submit,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Permanently Delete Account'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || pendingPin == null || !mounted) return;

    setState(() {
      _loggingOut = true;
      _error = null;
    });
    try {
      final messenger = ScaffoldMessenger.of(context);
      final msg = await widget.authService.deleteAccount(pin: pendingPin!);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is AuthException
              ? e.message
              : 'Unable to delete account right now.';
        });
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Widget _garageTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: ndrlSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: ndrlGold, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ndrlGold),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant NdrlAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService) {
      oldWidget.authService.removeListener(_changed);
      widget.authService.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.authService.removeListener(_changed);
    super.dispose();
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() {
      _loggingOut = true;
      _error = null;
    });
    try {
      await widget.authService.logout();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authService;
    if (auth.loading && !auth.signedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.signedIn) {
      return NdrlLoginScreen(authService: auth);
    }

    final rawName = (auth.account?['display_name'] ?? '').toString().trim();
    final name = rawName.isEmpty ? 'NDRL Member' : rawName;
    return Scaffold(
      backgroundColor: ndrlBackground,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),

          const Text(
            'MY GARAGE',
            style: TextStyle(
              color: ndrlGold,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          const Icon(Icons.account_circle_outlined, color: ndrlGold, size: 76),

          const SizedBox(height: 12),

          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          const Text(
            'Signed in to NDRL',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 32),

          _garageTile(
            icon: Icons.person_outline,
            title: 'My Profile',
            subtitle: 'View and edit your member information',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NdrlProfileScreen(authService: auth),
              ),
            ),
          ),

          _garageTile(
            icon: Icons.directions_car_outlined,
            title: 'My Vehicles & Tech Cards',
            subtitle: 'Registered race cars and inspections',
            onTap: _openTechCards,
          ),

          _garageTile(
            icon: Icons.emoji_events_outlined,
            title: 'My Racing Stats',
            subtitle: 'Career totals and season-by-season results',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NdrlMyRacingStatsScreen(authService: auth),
              ),
            ),
          ),

          _garageTile(
            icon: Icons.gps_fixed,
            title: 'Bounty Board',
            subtitle: 'View active bounties and manage your challenges',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NdrlBountyBoardScreen(authService: auth),
              ),
            ),
          ),

          _garageTile(
            icon: Icons.pin_outlined,
            title: 'Change PIN',
            subtitle: 'Update your 4-8 digit member login PIN',
            onTap: _openChangePinSheet,
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: _loggingOut ? null : _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),

          if (_loggingOut) const LinearProgressIndicator(color: ndrlRed),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),

          const SizedBox(height: 20),

          TextButton.icon(
            onPressed: _loggingOut ? null : _openDeleteAccountSheet,
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            icon: const Icon(Icons.delete_outline, size: 20),
            label: const Text('Delete Online Account'),
          ),
        ],
      ),
    );
  }
}
