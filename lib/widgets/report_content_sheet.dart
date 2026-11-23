import 'package:flutter/material.dart';

const _surface = Color(0xFF1A1F2E);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class ReportReasonOption {
  const ReportReasonOption(this.code, this.label);
  final String code;
  final String label;
}

const kReportReasons = <ReportReasonOption>[
  ReportReasonOption('inappropriate', 'Inappropriate or explicit image'),
  ReportReasonOption('harassment', 'Harassment, hate, or offensive content'),
  ReportReasonOption('spam', 'Spam or misleading information'),
  ReportReasonOption('copyright', 'Copyright or unauthorized photo'),
  ReportReasonOption('other', 'Other policy violation'),
];

Future<void> showReportContentSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required Future<String> Function(String reason, String notes) onSubmit,
}) async {
  String selectedReason = kReportReasons.first.code;
  final notesCtrl = TextEditingController();
  bool submitting = false;
  String? error;

  final resultMessage = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> submit() async {
            if (submitting) return;
            setSheetState(() {
              submitting = true;
              error = null;
            });
            try {
              final msg = await onSubmit(selectedReason, notesCtrl.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop(msg);
            } catch (e) {
              if (!ctx.mounted) return;
              setSheetState(() {
                submitting = false;
                error = e
                    .toString()
                    .replaceFirst('Exception: ', '')
                    .replaceFirst('Bad state: ', '');
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag_outlined, color: _gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                    const SizedBox(height: 10),
                  ],
                  RadioGroup<String>(
                    groupValue: selectedReason,
                    onChanged: (val) {
                      if (!submitting && val != null) {
                        setSheetState(() => selectedReason = val);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final opt in kReportReasons)
                          RadioListTile<String>(
                            value: opt.code,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: _gold,
                            title: Text(
                              opt.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Additional details (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: submitting ? null : submit,
                    icon: const Icon(Icons.flag),
                    label: Text(submitting ? 'Submitting...' : 'Submit Report'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  // Wait for the modal sheet exit animation to complete before disposing the controller.
  Future<void>.delayed(const Duration(milliseconds: 400), notesCtrl.dispose);

  if (resultMessage != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resultMessage)),
    );
  }
}
