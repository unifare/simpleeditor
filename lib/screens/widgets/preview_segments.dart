import 'package:flutter/material.dart';

import '../feed_screen.dart' show PreviewMode;

/// Tap-reliable replacement for SegmentedButton (synthetic mouse taps
/// on web canvas don't reach SegmentedButton segments reliably).
/// Three toggle cells: Edit / MD / HTML.
class PreviewSegments extends StatelessWidget {
  final PreviewMode value;
  final ValueChanged<PreviewMode> onChanged;
  final double fontSize;

  const PreviewSegments({
    required this.value,
    required this.onChanged,
    this.fontSize = 11,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cell(context, PreviewMode.edit, 'Edit', first: true),
          _divider(scheme),
          _cell(context, PreviewMode.md, 'MD'),
          _divider(scheme),
          _cell(context, PreviewMode.html, 'HTML', last: true),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme scheme) => Container(
        width: 1,
        height: 22,
        color: scheme.outlineVariant,
      );

  Widget _cell(BuildContext context, PreviewMode mode, String label,
      {bool first = false, bool last = false}) {
    final scheme = Theme.of(context).colorScheme;
    final selected = value == mode;
    return Material(
      color: selected
          ? scheme.secondaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.horizontal(
        left: first ? const Radius.circular(11) : Radius.zero,
        right: last ? const Radius.circular(11) : Radius.zero,
      ),
      child: InkWell(
        onTap: () => onChanged(mode),
        borderRadius: BorderRadius.horizontal(
          left: first ? const Radius.circular(11) : Radius.zero,
          right: last ? const Radius.circular(11) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Icon(Icons.check_rounded,
                      size: 13, color: scheme.onSecondaryContainer),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
