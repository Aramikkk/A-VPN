import 'package:flutter/material.dart';

/// A small window that says what a switch on the home screen does and lets the user turn it on or off: the name, the
/// state in force in words and one control with the two states (the one in force is selected, a tap on the other
/// changes it and closes the window), then the explanation. [onChoose] gets the choice (true: on).
Future<void> showFeatureDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String stateText,
  required bool on,
  required String onLabel,
  required String offLabel,
  required String closeLabel,
  required void Function(bool on) onChoose,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialog) {
      final theme = Theme.of(dialog);
      final scheme = theme.colorScheme;
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // first what is chosen and how to change it (always in sight), then the explanation, which may be long
              Text(
                stateText,
                key: const Key('feature-state'),
                style: theme.textTheme.titleSmall?.copyWith(color: on ? scheme.primary : scheme.onSurface),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, label: Text(offLabel)),
                    ButtonSegment(value: true, label: Text(onLabel)),
                  ],
                  selected: {on},
                  onSelectionChanged: (picked) {
                    Navigator.of(dialog).pop();
                    onChoose(picked.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(body, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(closeLabel))],
      );
    },
  );
}
