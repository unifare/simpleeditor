import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feed_screen.dart' show kLanguages;

/// Fullscreen creation & code studio (fig-2 style):
/// language dropdown, copy/paste/send, markdown bar, line numbers,
/// find bar, shortcut hints. Draft returns to the composer on exit.
class FullscreenEditorPage extends StatefulWidget {
  final String initialText;
  final String lang;

  const FullscreenEditorPage({
    required this.initialText,
    required this.lang,
    super.key,
  });

  @override
  State<FullscreenEditorPage> createState() => _FullscreenEditorPageState();
}

class FullscreenResult {
  final String text;
  final String lang;
  final bool send;
  const FullscreenResult(this.text, this.lang, this.send);
}

class _FullscreenEditorPageState extends State<FullscreenEditorPage> {
  late final TextEditingController _text;
  late String _lang;
  final FocusNode _focus = FocusNode();
  final ScrollController _mainScroll = ScrollController();
  final ScrollController _gutterScroll = ScrollController();
  bool _syncing = false;
  bool _showFind = false;
  final TextEditingController _find = TextEditingController();
  String? _findMiss;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText);
    _lang = widget.lang;
    _mainScroll.addListener(_syncGutter);
    _focus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final ctrl =
          HardwareKeyboard.instance.isControlPressed;
      if (ctrl && event.logicalKey == LogicalKeyboardKey.enter) {
        _exit(send: true);
        return KeyEventResult.handled;
      }
      if (ctrl &&
          event.logicalKey == LogicalKeyboardKey.keyF) {
        setState(() => _showFind = !_showFind);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _exit(send: false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _syncGutter() {
    if (_syncing || !_gutterScroll.hasClients) return;
    _syncing = true;
    _gutterScroll.jumpTo(_mainScroll.offset);
    _syncing = false;
  }

  @override
  void dispose() {
    _mainScroll.dispose();
    _gutterScroll.dispose();
    _text.dispose();
    _find.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _exit({required bool send}) {
    Navigator.of(context)
        .pop(FullscreenResult(_text.text, _lang, send));
  }

  Future<void> _copy() async {
    if (_text.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _text.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final s = data?.text;
    if (s == null || s.isEmpty) return;
    final sel = _text.selection;
    final i = sel.isValid && sel.start >= 0 ? sel.start : _text.text.length;
    var len = sel.isValid ? sel.end - sel.start : 0;
    if (len < 0) len = 0;
    _text.text = _text.text.replaceRange(i, i + len, s);
    _text.selection = TextSelection.collapsed(offset: i + s.length);
  }

  // --- Markdown helpers ---

  void _wrap(String before, [String after = '']) {
    final v = _text.text;
    final sel = _text.selection;
    final a =
        sel.isValid && sel.start >= 0 ? sel.start : v.length;
    var b = sel.isValid && sel.end >= 0 ? sel.end : v.length;
    if (b < a) b = a;
    final inner = v.substring(a, b);
    _text.text = v.replaceRange(a, b, '$before$inner$after');
    _text.selection = TextSelection.collapsed(
        offset: a + before.length + inner.length + after.length);
    _focus.requestFocus();
  }

  void _linePrefix(String prefix) {
    final v = _text.text;
    final sel = _text.selection;
    final cursor =
        sel.isValid && sel.start >= 0 ? sel.start : v.length;
    final ls = v.lastIndexOf('\n', cursor <= 0 ? 0 : cursor - 1) + 1;
    _text.text = v.replaceRange(ls, ls, prefix);
    _text.selection =
        TextSelection.collapsed(offset: cursor + prefix.length);
    _focus.requestFocus();
  }

  void _findNext() {
    final q = _find.text;
    if (q.isEmpty) return;
    final v = _text.text;
    final sel = _text.selection;
    final from =
        sel.isValid && sel.start >= 0 ? sel.end : 0;
    var i = v.indexOf(q, from);
    if (i < 0 && from > 0) i = v.indexOf(q, 0); // wrap around
    if (i < 0) {
      setState(() => _findMiss = 'Not found');
      return;
    }
    setState(() => _findMiss = null);
    _text.selection =
        TextSelection(baseOffset: i, extentOffset: i + q.length);
    _focus.requestFocus();
  }

  int get _lineCount => '\n'.allMatches(_text.text).length + 1;

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
              _studioBar(context),
              _mdBar(context),
              if (_showFind) _findBar(context),
              // Code area with line-number gutter
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gutter
                        Container(
                          width: 44,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            border: Border(
                              right: BorderSide(
                                  color: scheme.outlineVariant),
                            ),
                          ),
                          child: ListView.builder(
                            controller: _gutterScroll,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.only(top: 10),
                            itemCount: _lineCount,
                            itemBuilder: (_, i) => SizedBox(
                              height: 21,
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                    fontFamily: 'Roboto Mono',
                                    fontFamilyFallback: const [
                                      'monospace'
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Editor
                        Expanded(
                          child: TextField(
                            controller: _text,
                            focusNode: _focus,
                            scrollController: _mainScroll,
                            autofocus: true,
                            expands: true,
                            maxLines: null,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              fontFamily: 'Roboto Mono',
                              fontFamilyFallback: ['monospace'],
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _hintBar(context),
            ],
          ),
        ),
      ),
    );
  }

  // --- Studio top bar ---

  Widget _studioBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFF38BDF8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Fullscreen',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Close
          _iconBtn(context,
              icon: Icons.close_rounded,
              tip: 'Close (ESC)',
              onTap: () => _exit(send: false)),
          const SizedBox(width: 6),
          // Language dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
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
                    _focus.requestFocus();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          _iconBtn(context,
              icon: Icons.content_copy_rounded,
              tip: 'Copy',
              onTap: _copy),
          const SizedBox(width: 6),
          _iconBtn(context,
              icon: Icons.content_paste_rounded,
              tip: 'Paste',
              onTap: _paste),
          const SizedBox(width: 6),
          // Send
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _exit(send: true),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                  ),
                  borderRadius:
                      BorderRadius.all(Radius.circular(16)),
                ),
                child: const Icon(Icons.send_rounded,
                    size: 19, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(BuildContext context,
      {required IconData icon,
      required String tip,
      required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tip,
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, size: 18, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }

  // --- Markdown bar ---

  Widget _mdBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _mBtn(context, 'B', FontWeight.w900,
              () => _wrap('**', '**')),
          _mBtn(context, 'I', FontWeight.w400,
              () => _wrap('*', '*'),
              italic: true),
          _mBtn(context, 'S', FontWeight.w400,
              () => _wrap('~~', '~~'),
              strike: true),
          _mBtn(context, 'H1', FontWeight.w800,
              () => _linePrefix('# ')),
          _mBtn(context, 'H2', FontWeight.w800,
              () => _linePrefix('## ')),
          _mBtn(context, '</>', FontWeight.w600,
              () => _wrap('```$_lang\n', '\n```')),
          _mBtn(context, '•', FontWeight.w800,
              () => _linePrefix('- ')),
          _mBtn(context, '"', FontWeight.w600,
              () => _linePrefix('> ')),
          _mBtn(context, 'link', FontWeight.w600,
              () => _wrap('[', '](https://)')),
          _mBtn(context, 'table', FontWeight.w600,
              () => _wrap('\n| A | B |\n|---|---|\n|  |  |\n')),
        ],
      ),
    );
  }

  Widget _mBtn(BuildContext context, String label,
      FontWeight weight, VoidCallback onTap,
      {bool italic = false, bool strike = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
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

  // --- Find bar ---

  Widget _findBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35)),
              ),
              child: TextField(
                controller: _find,
                autofocus: true,
                onSubmitted: (_) => _findNext(),
                onChanged: (_) {
                  if (_findMiss != null) {
                    setState(() => _findMiss = null);
                  }
                },
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: _findMiss ?? 'Find… (Enter = next)',
                  hintStyle: TextStyle(
                      color: _findMiss != null
                          ? scheme.error
                          : scheme.onSurfaceVariant),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _iconBtn(context,
              icon: Icons.arrow_downward_rounded,
              tip: 'Next',
              onTap: _findNext),
          const SizedBox(width: 6),
          _iconBtn(context,
              icon: Icons.close_rounded,
              tip: 'Close find',
              onTap: () => setState(() {
                    _showFind = false;
                    _focus.requestFocus();
                  })),
        ],
      ),
    );
  }

  // --- Shortcut hints ---

  Widget _hintBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        'Ctrl+Enter send  |  Ctrl+F find  |  Ctrl+A select all  |  ESC exit',
        style: TextStyle(
          fontSize: 11.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
