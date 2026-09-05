import 'package:flutter/material.dart';

/// Custom status bar overlay at the top of the screen.
/// Shows note title on scroll, word count, and theme toggle.
/// Tapping the status bar reveals the toolbar (iOS Notes pattern).
class StatusBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final int wordCount;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onTap;
  final bool showWordCount;
  final VoidCallback onWordCountTap;

  const StatusBar({
    required this.title,
    required this.wordCount,
    required this.isDark,
    required this.onToggleTheme,
    required this.onTap,
    required this.showWordCount,
    required this.onWordCountTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tap area to reveal toolbar (title acts as trigger)
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Row(
            children: [
              if (showWordCount)
                GestureDetector(
                  onTap: onWordCountTap,
                  child: Text(
                    '$wordCount words',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ),
              if (showWordCount) const SizedBox(width: 12),
              InkWell(
                onTap: onToggleTheme,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    isDark ? 'sun' : 'moon',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44);
}
