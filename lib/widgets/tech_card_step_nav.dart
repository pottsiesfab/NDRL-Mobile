import 'package:flutter/material.dart';

import '../services/tech_cards_service.dart';

enum TechCardStep { basics, mods, equipment, review }

/// UI navigation only. Backend remains authoritative for saves and submission.
class TechCardStepNav extends StatelessWidget {
  const TechCardStepNav({
    super.key,
    required this.current,
    required this.card,
    required this.modifications,
    required this.onSelected,
    this.busy = false,
  });

  final TechCardStep current;
  final Map<String, dynamic>? card;
  final List<TechModification>? modifications;
  final ValueChanged<TechCardStep> onSelected;
  final bool busy;

  static bool isReadOnly(Map<String, dynamic>? card) {
    if (card == null) return false;
    final status = '${card['status'] ?? ''}'.toLowerCase();
    return card['locked_at'] != null ||
        status == 'ready' ||
        status == 'approved';
  }

  static bool basicsComplete(Map<String, dynamic>? card) {
    if (card == null) return false;
    return (double.tryParse('${card['et_index'] ?? ''}') ?? 0) > 0;
  }

  /// Use persisted answers, not current unsaved selections. A full answer set
  /// with valid single-choice groups is treated as complete for navigation.
  static bool modsComplete(List<TechModification>? mods) {
    if (mods == null || mods.isEmpty) return false;
    if (mods.any((m) => m.answer == null)) return false;
    final groups = <String, List<TechModification>>{};
    for (final m in mods) {
      if (m.mode == 'single' && m.group.isNotEmpty) {
        groups.putIfAbsent(m.group, () => []).add(m);
      }
    }
    for (final group in groups.values) {
      final yes = group.where((m) => m.answer == true).length;
      if (yes > 1 || (group.any((m) => m.required) && yes != 1)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = isReadOnly(card);
    final basics = basicsComplete(card);
    final mods = modsComplete(modifications);
    const steps = TechCardStep.values;
    const labels = ['Basics', 'Mods', 'Equipment', 'Review'];
    const icons = [
      Icons.directions_car_outlined,
      Icons.tune,
      Icons.fact_check_outlined,
      Icons.assignment_turned_in_outlined,
    ];
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Builder(
              builder: (context) {
                final step = steps[i];
                final allowed =
                    readOnly ||
                    i == 0 ||
                    (i == 1 && basics) ||
                    (i >= 2 && basics && mods);
                final selected = current == step;
                final active = allowed && !busy;
                return Material(
                  color: selected
                      ? const Color(0xFFD1AC67).withValues(alpha: 0.17)
                      : const Color(0xFF111626),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: !selected && active ? () => onSelected(step) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 11,
                        horizontal: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFD1AC67)
                              : Colors.white24,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[i],
                            size: 20,
                            color: allowed
                                ? const Color(0xFFD1AC67)
                                : Colors.white38,
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: allowed ? Colors.white : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
