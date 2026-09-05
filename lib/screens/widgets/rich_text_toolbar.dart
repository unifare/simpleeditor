import 'package:flutter/material.dart';

/// Rich text formatting toolbar that slides up from the bottom of the screen.
/// Buttons: Bold, Italic, Underline, List, Heading, Link, Monospace, Image
class RichTextToolbar extends StatelessWidget {
  final void Function(String format) onFormat;
  final VoidCallback onClose;
  final bool isDark;

  const RichTextToolbar({
    required this.onFormat,
    required this.onClose,
    required this.isDark,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).colorScheme.surface;
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: outline, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 16,
            children: [
              _ToolbarButton(
                icon: Icons.format_bold,
                label: 'B',
                onTap: () => onFormat('bold'),
              ),
              _ToolbarButton(
                icon: Icons.format_italic,
                label: 'I',
                onTap: () => onFormat('italic'),
              ),
              _ToolbarButton(
                icon: Icons.format_underline,
                label: 'U',
                onTap: () => onFormat('underline'),
              ),
              _ToolbarButton(
                icon: Icons.format_list_bulleted,
                label: '\u2022',
                onTap: () => onFormat('list'),
              ),
              _ToolbarButton(
                icon: Icons.format_size,
                label: 'H',
                onTap: () => onFormat('heading'),
              ),
              _ToolbarButton(
                icon: Icons.link,
                label: '@',
                onTap: () => onFormat('link'),
              ),
              _ToolbarButton(
                icon: Icons.code,
                label: 'M',
                onTap: () => onFormat('mono'),
              ),
              _ToolbarButton(
                icon: Icons.image,
                label: '[]',
                onTap: () => onFormat('image'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
