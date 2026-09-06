import 'package:flutter/material.dart';

import '../../services/storage_service.dart';

/// Dropdown history panel: message-style cards with copy / restore / delete.
/// Fixed max height, scrolls internally.
class HistoryPanel extends StatelessWidget {
  final List<Note> entries;
  final void Function(Note entry) onCopy;
  final void Function(Note entry) onRestore;
  final void Function(Note entry) onDelete;
  final VoidCallback onDismiss;

  const HistoryPanel({
    required this.entries,
    required this.onCopy,
    required this.onRestore,
    required this.onDelete,
    required this.onDismiss,
    super.key,
  });

  String _fmtTime(DateTime t) {
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'History (${entries.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          // List (capped height, scrolls inside)
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: entries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Text(
                        'No history yet — it builds up as you save.',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding:
                          const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final preview = e.content.length > 120
                            ? '${e.content.substring(0, 120)}…'
                            : e.content;
                        return Container(
                          padding:
                              const EdgeInsets.fromLTRB(12, 10, 6, 10),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer
                                .withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: scheme.primary
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            e.title.isEmpty
                                                ? 'Untitled'
                                                : e.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: scheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _fmtTime(e.updatedAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: scheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (preview.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        preview,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Actions: copy / restore / delete
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _IconBtn(
                                    icon: Icons.content_copy_rounded,
                                    tip: 'Copy',
                                    onTap: () => onCopy(e),
                                  ),
                                  _IconBtn(
                                    icon: Icons.restore_rounded,
                                    tip: 'Restore',
                                    onTap: () => onRestore(e),
                                  ),
                                  _IconBtn(
                                    icon: Icons.delete_outline_rounded,
                                    tip: 'Delete',
                                    onTap: () => onDelete(e),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 17, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
