import 'package:flutter/material.dart';

/// Modern bottom toolbar: full-width, rounded top, three grouped rows.
/// Groups: Format (B/I/U/list/H) · Insert (link/mono/image) · Edit (undo/redo/copy/paste/save)
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
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;
    final outline = scheme.outlineVariant;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: 10,
        bottom: 28 + MediaQuery.of(context).padding.bottom,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: outline, width: 1)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle + close
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).hintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                right: 0,
                child: InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GroupRow(
            label: 'Style',
            children: [
              _Btn(icon: Icons.format_bold_rounded, tip: 'Bold', onTap: () => onFormat('bold')),
              _Btn(icon: Icons.format_italic_rounded, tip: 'Italic', onTap: () => onFormat('italic')),
              _Btn(icon: Icons.format_underline_rounded, tip: 'Underline', onTap: () => onFormat('underline')),
              _Btn(icon: Icons.format_list_bulleted_rounded, tip: 'List', onTap: () => onFormat('list')),
              _Btn(icon: Icons.title_rounded, tip: 'Heading', onTap: () => onFormat('heading')),
            ],
          ),
          const SizedBox(height: 10),
          _GroupRow(
            label: 'Insert',
            children: [
              _Btn(icon: Icons.link_rounded, tip: 'Link', onTap: () => onFormat('link')),
              _Btn(icon: Icons.code_rounded, tip: 'Code', onTap: () => onFormat('mono')),
              _Btn(icon: Icons.image_outlined, tip: 'Image', onTap: () => onFormat('image')),
              _Btn(icon: Icons.content_copy_rounded, tip: 'Copy', onTap: () => onFormat('copy')),
              _Btn(icon: Icons.content_paste_rounded, tip: 'Paste', onTap: () => onFormat('paste')),
            ],
          ),
          const SizedBox(height: 10),
          _GroupRow(
            label: 'Edit',
            children: [
              _Btn(icon: Icons.undo_rounded, tip: 'Undo', onTap: () => onFormat('undo')),
              _Btn(icon: Icons.redo_rounded, tip: 'Redo', onTap: () => onFormat('redo')),
              _Btn(icon: Icons.save_outlined, tip: 'Save', onTap: () => onFormat('save')),
              _Btn(icon: Icons.select_all_rounded, tip: 'Select all', onTap: () => onFormat('selectAll')),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _GroupRow({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;

  const _Btn({required this.icon, required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
