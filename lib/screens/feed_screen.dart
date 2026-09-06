import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import 'fullscreen_editor.dart';
import 'widgets/preview_segments.dart';

const Map<String, String> kLanguages = {
  'text': 'Text',
  'md': 'Markdown',
  'js': 'JavaScript',
  'json': 'JSON',
  'html': 'HTML',
  'css': 'CSS',
  'py': 'Python',
  'cs': 'C#',
  'sql': 'SQL',
  'java': 'Java',
  'cpp': 'C++',
  'xml': 'XML',
};

enum PreviewMode { edit, md, html }

/// Card feed + fixed bottom composer (language, markdown bar, shortcuts,
/// MD/HTML preview). Cards scroll vertically; each has copy/edit/delete.
class FeedScreen extends StatefulWidget {
  final StorageService storage;

  const FeedScreen({required this.storage, super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Note> _notes = [];
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _listScroll = ScrollController();
  String _lang = 'text';
  PreviewMode _preview = PreviewMode.edit;
  String? _editingId;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    // Keyboard shortcuts on the input itself (a Shortcuts-widget wrapper
    // around the composer can swallow tap gestures on web).
    _inputFocus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final ctrl = HardwareKeyboard.instance.isControlPressed;
      if (ctrl && event.logicalKey == LogicalKeyboardKey.enter) {
        _send();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _inputFocus.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _reload();
  }

  Future<void> _reload() async {
    final notes = await widget.storage.getAllNotes();
    if (!mounted) return;
    setState(() => _notes = notes);
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  String _fmtTime(DateTime t) {
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$min';
  }

  String _deriveTitle(String content) {
    final line = content.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    final t = line.trim();
    if (t.isEmpty) return 'Untitled';
    return t.length > 60 ? '${t.substring(0, 57)}…' : t;
  }

  // --- Send / CRUD ---

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    final now = DateTime.now();
    if (_editingId != null) {
      final i = _notes.indexWhere((n) => n.id == _editingId);
      if (i >= 0) {
        final updated = _notes[i].copyWith(
          title: _deriveTitle(text),
          content: text,
          lang: _lang,
          updatedAt: now,
        );
        final notes = await widget.storage.updateNote(updated);
        if (!mounted) return;
        setState(() {
          _notes = notes;
          _editingId = null;
        });
      }
    } else {
      final note = Note.create(
        title: _deriveTitle(text),
        content: text,
        lang: _lang,
        createdAt: now,
      );
      final notes = await widget.storage.addNote(note);
      if (!mounted) return;
      setState(() => _notes = notes);
    }
    _input.clear();
    setState(() => _preview = PreviewMode.edit);
  }

  Future<void> _copy(Note n) async {
    if (n.content.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: n.content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _remove(Note n) async {
    final notes = await widget.storage.removeNote(n.id);
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _expanded.remove(n.id);
      if (_editingId == n.id) {
        _editingId = null;
        _input.clear();
      }
    });
  }

  void _edit(Note n) {
    setState(() {
      _editingId = n.id;
      _lang = n.lang ?? 'text';
      _preview = PreviewMode.edit;
    });
    _input.text = n.content;
    _inputFocus.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editingId = null);
    _input.clear();
  }

  /// Open the fullscreen studio; apply its result (draft or send).
  Future<void> _openFullscreen() async {
    final result =
        await Navigator.of(context).push<FullscreenResult>(
      MaterialPageRoute(
        builder: (_) => FullscreenEditorPage(
          initialText: _input.text,
          lang: _lang,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _lang = result.lang;
      _preview = PreviewMode.edit;
    });
    _input.text = result.text;
    if (result.send) {
      await _send();
    } else {
      _inputFocus.requestFocus();
    }
  }

  // --- Markdown snippet helpers (operate on selection) ---

  void _wrap(String before, [String after = '']) {
    final text = _input.text;
    final sel = _input.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final a = start < 0 ? text.length : start;
    final b = end < 0 ? text.length : end;
    final selected = text.substring(a, b);
    final insert = '$before$selected$after';
    _input.text = text.replaceRange(a, b, insert);
    _input.selection = TextSelection.collapsed(
        offset: a + before.length + selected.length + after.length);
    _inputFocus.requestFocus();
  }

  void _linePrefix(String prefix) {
    final text = _input.text;
    final sel = _input.selection;
    final cursor = sel.isValid && sel.start >= 0 ? sel.start : text.length;
    final lineStart = text.lastIndexOf('\n', cursor <= 0 ? 0 : cursor - 1) + 1;
    _input.text = text.replaceRange(lineStart, lineStart, prefix);
    _input.selection =
        TextSelection.collapsed(offset: cursor + prefix.length);
    _inputFocus.requestFocus();
  }

  void _insertTable() {
    _wrap('\n| A | B |\n|---|---|\n|  |  |\n');
  }

  void _insertCodeBlock() {
    _wrap('```$_lang\n', '\n```');
  }

  void _insertLink() {
    _wrap('[', '](https://)');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF141422), Color(0xFF0B0B14)]
                : const [Color(0xFFF4F2FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(context),
              // Card feed (scrolls)
              Expanded(
                child: _notes.isEmpty
                    ? Center(
                        child: Text(
                          'Empty — write below and Send.',
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _listScroll,
                        padding:
                            const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: _notes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _noteCard(context, _notes[i]),
                      ),
              ),
              // Fixed bottom composer
              _composer(context),
            ],
          ),
        ),
      ),
    );
  }

  // --- Top bar ---

  Widget _topBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 52,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 6),
              Icon(Icons.edit_note_rounded,
                  size: 20, color: scheme.onSurface),
              const SizedBox(width: 6),
              Text(
                'Notepad',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_notes.length} notes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const Spacer(),
              Material(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    context.read<ThemeProvider>().setTheme(
                          isDark ? ThemeMode.light : ThemeMode.dark,
                        );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 18,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Note card ---

  Widget _noteCard(BuildContext context, Note note) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expanded = _expanded.contains(note.id);
    final langLabel = kLanguages[note.lang ?? 'text'] ?? 'Text';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: lang chip + title + time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  langLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _fmtTime(note.updatedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Content (tap to expand/collapse)
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _expanded.remove(note.id);
              } else {
                _expanded.add(note.id);
              }
            }),
            borderRadius: BorderRadius.circular(8),
            child: Text(
              note.content,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                fontFamily: 'Roboto Mono',
                fontFamilyFallback: ['monospace'],
              ),
              maxLines: expanded ? null : 8,
              overflow: expanded ? null : TextOverflow.ellipsis,
            ),
          ),
          // Actions: copy / edit / delete
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _cardBtn(context,
                  icon: Icons.content_copy_rounded,
                  tip: 'Copy',
                  onTap: () => _copy(note)),
              _cardBtn(context,
                  icon: Icons.edit_outlined,
                  tip: 'Edit',
                  onTap: () => _edit(note)),
              _cardBtn(context,
                  icon: Icons.delete_outline_rounded,
                  tip: 'Delete',
                  onTap: () => _remove(note)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardBtn(BuildContext context,
      {required IconData icon,
      required String tip,
      required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(left: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, size: 17, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }

  // --- Bottom composer ---

  Widget _composer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row: language + preview segment + send
          Row(
            children: [
              if (_editingId != null)
                InkWell(
                  onTap: _cancelEdit,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          scheme.errorContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 14,
                            color: scheme.onErrorContainer),
                        const SizedBox(width: 2),
                        Text('Edit',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.onErrorContainer)),
                      ],
                    ),
                  ),
                ),
              // Language dropdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color:
                      scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _lang,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    dropdownColor: scheme.surface,
                    items: kLanguages.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _lang = v);
                        _inputFocus.requestFocus();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Preview segment
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PreviewSegments(
                    value: _preview,
                    onChanged: (m) =>
                        setState(() => _preview = m),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _send,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF38BDF8),
                          Color(0xFF6366F1)
                        ],
                      ),
                      borderRadius:
                          BorderRadius.all(Radius.circular(16)),
                    ),
                    child: const Icon(Icons.send_rounded,
                        size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          // Markdown toolbar
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _mdIconBtn(context, Icons.open_in_full_rounded,
                    _openFullscreen),
                _mdBtn(context, 'B', FontWeight.w900,
                    () => _wrap('**', '**')),
                _mdBtn(context, 'I', FontWeight.w400,
                    () => _wrap('*', '*'),
                    italic: true),
                _mdBtn(context, 'S', FontWeight.w400,
                    () => _wrap('~~', '~~'),
                    strike: true),
                _mdBtn(context, 'H1', FontWeight.w800,
                    () => _linePrefix('# ')),
                _mdBtn(context, 'H2', FontWeight.w800,
                    () => _linePrefix('## ')),
                _mdBtn(context, '</>', FontWeight.w600,
                    _insertCodeBlock),
                _mdBtn(context, '•', FontWeight.w800,
                    () => _linePrefix('- ')),
                _mdIconBtn(context, Icons.format_quote_rounded,
                    () => _linePrefix('> ')),
                _mdIconBtn(context, Icons.link_rounded, _insertLink),
                _mdIconBtn(context, Icons.table_chart_outlined,
                    _insertTable),
              ],
            ),
          ),
          // Preview (capped) or input
          if (_preview != PreviewMode.edit)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outlineVariant,
                ),
              ),
              child: SingleChildScrollView(
                child: _preview == PreviewMode.md
                    ? MarkdownBody(
                        data: _input.text.isEmpty
                            ? '_nothing to preview_'
                            : _input.text,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(
                                    Theme.of(context))
                                .copyWith(
                          code: const TextStyle(
                            fontFamily: 'Roboto Mono',
                            fontFamilyFallback: ['monospace'],
                            fontSize: 13,
                          ),
                        ),
                        onTapText: () {},
                      )
                    : HtmlWidget(
                        _input.text.isEmpty
                            ? '<i>nothing to preview</i>'
                            : _input.text,
                        textStyle: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurface,
                        ),
                      ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outlineVariant,
                ),
              ),
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: scheme.onSurface,
                  fontFamily: 'Roboto Mono',
                  fontFamilyFallback: const ['monospace'],
                ),
                decoration: InputDecoration(
                  hintText:
                      'Quick input… (Ctrl+Enter send, ESC dismiss)',
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'Roboto',
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mdIconBtn(
      BuildContext context, IconData icon, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, size: 17, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }

  Widget _mdBtn(BuildContext context, String label,
      FontWeight weight, VoidCallback onTap,
      {bool italic = false, bool strike = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: weight,
                fontStyle:
                    italic ? FontStyle.italic : FontStyle.normal,
                decoration: strike
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
