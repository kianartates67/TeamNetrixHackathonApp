import 'package:flutter/material.dart';
import '../../models/teacher.dart';

/// Small UI card that displays conflict resolution suggestions.
///
/// The "AI" here is rule-based: it receives precomputed alternative [TimeSlot]s
/// from `SchedulerService.suggestAlternativeTimeSlots` and simply renders them
/// with an "Apply" action.
class AiSuggestionsCard extends StatelessWidget {
  final List<TimeSlot> suggestions;
  final String? conflictMessage;
  final String Function(TimeSlot) formatRange;
  final ValueChanged<TimeSlot> onApplySuggestion;

  const AiSuggestionsCard({
    super.key,
    required this.suggestions,
    required this.conflictMessage,
    required this.formatRange,
    required this.onApplySuggestion,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return Card(
        color: Colors.orange.withOpacity(0.08),
        child: ListTile(
          leading: const Icon(Icons.auto_awesome, color: Colors.orange),
          title: const Text('AI Suggestions'),
          subtitle: Text(conflictMessage ??
              'No alternatives available for this conflict.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text('AI Suggestions',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            if (conflictMessage != null) ...[
              const SizedBox(height: 8),
              Text(conflictMessage!, style: TextStyle(color: Colors.red[700])),
            ],
            const SizedBox(height: 8),
            const Text('Tap a suggested slot to apply it to the form.'),
            const SizedBox(height: 8),
            ...suggestions.map((slot) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.schedule),
                  title: Text(formatRange(slot)),
                  trailing: TextButton(
                    onPressed: () => onApplySuggestion(slot),
                    child: const Text('Apply'),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
