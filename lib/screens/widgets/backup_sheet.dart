import 'package:flutter/material.dart';

/// Backup sheet: export JSON / export Markdown / import JSON.
class BackupSheet extends StatelessWidget {
  final int noteCount;
  final VoidCallback onExportJson;
  final VoidCallback onExportMarkdown;
  final VoidCallback onImportJson;

  const BackupSheet({
    required this.noteCount,
    required this.onExportJson,
    required this.onExportMarkdown,
    required this.onImportJson,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.backup_outlined,
                    size: 20, color: scheme.onSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Backup ($noteCount notes)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row(
              context,
              icon: Icons.file_download_outlined,
              title: 'Export JSON',
              subtitle:
                  'Full backup with formatting + history-proof metadata',
              onTap: () {
                Navigator.of(context).pop();
                onExportJson();
              },
            ),
            _row(
              context,
              icon: Icons.description_outlined,
              title: 'Export Markdown',
              subtitle: 'Human-readable single .md file',
              onTap: () {
                Navigator.of(context).pop();
                onExportMarkdown();
              },
            ),
            _row(
              context,
              icon: Icons.file_upload_outlined,
              title: 'Import JSON',
              subtitle:
                  'Restore a backup (merges, newer wins)',
              onTap: () {
                Navigator.of(context).pop();
                onImportJson();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: scheme.onSurface),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
