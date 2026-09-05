import 'package:flutter/material.dart';

import '../../services/storage_service.dart';

/// Hidden tweaks panel (unlocked by tapping the word count 5 times).
/// Lets user toggle UI preferences without a full settings screen.
class TweaksPanel extends StatelessWidget {
  final StorageService storage;
  final VoidCallback onDismiss;

  const TweaksPanel({
    required this.storage,
    required this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).colorScheme.surface;
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: bgColor,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: outline, width: 1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tweaks',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildToggle('Show placeholder', storage.getShowPlaceholder(),
                (v) => storage.saveShowPlaceholder(v)),
            const SizedBox(height: 4),
            _buildToggle('Show word count', storage.getShowWordCount(),
                (v) => storage.saveShowWordCount(v)),
            const SizedBox(height: 4),
            _buildToggle('Toolbar on tap', storage.getToolbarOnTap(),
                (v) => storage.saveToolbarOnTap(v)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      height: 36,
      child: SwitchListTile(
        title: Text(label, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }
}
