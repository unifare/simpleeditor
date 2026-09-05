import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import 'widgets/rich_text_toolbar.dart';
import 'widgets/status_bar.dart';
import 'widgets/tweaks_panel.dart';

class EditorScreen extends StatefulWidget {
  final StorageService storage;
  final Note? existingNote;

  const EditorScreen({
    required this.storage,
    this.existingNote,
    super.key,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  QuillController? _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _toolbarVisible = ValueNotifier(false);
  final ValueNotifier<bool> _showStatusBar = ValueNotifier(false);
  late final AnimationController _toolbarAnim;
  late final Animation<double> _toolbarSlide;

  int _wordCount = 0;
  String _title = 'Untitled';
  bool _showTweaks = false;
  bool _isEmptyDoc = true;
  int _tapCount = 0;
  DateTime? _lastTap;
  String _lastSavedPlain = '';
  String _saveLabel = 'Loaded · autosave on';
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _toolbarAnim = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _toolbarSlide = CurvedAnimation(
      parent: _toolbarAnim,
      curve: Curves.easeOutCubic,
    );

    _loadNote();
    _scrollController.addListener(_onScroll);
  }

  /// Plain text of the document (single source for title/count/empty/save).
  String get _plainText => _controller?.document.toPlainText() ?? '';

  Future<void> _loadNote() async {
    final note = widget.existingNote ?? await widget.storage.getCurrentNote();
    if (!mounted) return;
    Document doc;
    if (note?.deltaJson != null) {
      try {
        doc = Document.fromJson(
            jsonDecode(note!.deltaJson!) as List<dynamic>);
      } catch (_) {
        doc = note!.content.isEmpty
            ? Document()
            : Document()..insert(0, note.content);
      }
    } else if (note != null && note.content.isNotEmpty) {
      doc = Document()..insert(0, note.content);
    } else {
      doc = Document();
    }
    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    controller.addListener(_onDocChanged);
    setState(() {
      _controller = controller;
    });
    _updateMetadata(_plainText);
    _lastSavedPlain = _plainText;
  }

  void _onDocChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    final text = _plainText;
    _updateMetadata(text);
    // Debounced auto-save (skip pure selection changes)
    if (text == _lastSavedPlain) return;
    final snapshot = text;
    if (!_saving && mounted) setState(() => _saving = true);
    Future.microtask(() async {
      if (!mounted || _plainText != snapshot) return;
      _lastSavedPlain = snapshot;
      final deltaJson =
          jsonEncode(controller.document.toDelta().toJson());
      await widget.storage.saveNoteContent(snapshot, deltaJson: deltaJson);
      if (!mounted) return;
      final now = DateTime.now();
      final hh = now.hour.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');
      final ss = now.second.toString().padLeft(2, '0');
      setState(() {
        _saving = false;
        _saveLabel = 'Saved $hh:$mm:$ss';
      });
    });
  }

  /// Explicit save (toolbar save button / app pause).
  Future<void> _saveNow() async {
    final controller = _controller;
    if (controller == null) return;
    final text = _plainText;
    _lastSavedPlain = text;
    final deltaJson = jsonEncode(controller.document.toDelta().toJson());
    await widget.storage.saveNoteContent(text, deltaJson: deltaJson);
    if (!mounted) return;
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    setState(() {
      _saving = false;
      _saveLabel = 'Saved $hh:$mm:$ss';
    });
  }

  void _updateMetadata(String content) {
    final newCount = _countWords(content);
    final newTitle = _deriveTitle(content);
    final newEmpty = content.trim().isEmpty;

    bool needsSet = false;
    if (newCount != _wordCount) {
      _wordCount = newCount;
      needsSet = true;
    }
    if (newTitle != _title) {
      _title = newTitle;
      needsSet = true;
    }
    if (newEmpty != _isEmptyDoc) {
      _isEmptyDoc = newEmpty;
      needsSet = true;
    }
    if (needsSet) setState(() {});
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  String _deriveTitle(String content) {
    final lines = content.split('\n');
    final firstLine = lines.firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    final title = firstLine.trim();
    return title.isEmpty
        ? 'Untitled'
        : (title.length > 80 ? '${title.substring(0, 77)}...' : title);
  }

  void _onScroll() {
    final shouldShow = _scrollController.hasClients &&
        _scrollController.position.pixels > 60;
    if (_showStatusBar.value != shouldShow) {
      _showStatusBar.value = shouldShow;
    }
  }

  // --- Gesture: swipe up from bottom edge to reveal toolbar ---
  double _swipeStartY = 0;
  bool _isSwipingFromBottom = false;
  static const double _bottomEdgeZone = 120;

  void _handlePanStart(DragStartDetails details) {
    final RenderObject? renderObj = context.findRenderObject();
    if (renderObj is! RenderBox) return;
    final local = renderObj.globalToLocal(details.globalPosition);
    final screenHeight = MediaQuery.of(context).size.height;

    if (local.dy > screenHeight - _bottomEdgeZone) {
      _isSwipingFromBottom = true;
      _swipeStartY = local.dy;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isSwipingFromBottom || _toolbarAnim.isAnimating) return;

    final delta = details.delta.dy;
    if (delta < 0 && (_swipeStartY - details.localPosition.dy) > 40) {
      if (!_toolbarVisible.value) {
        _toolbarVisible.value = true;
        _toolbarAnim.forward(from: 0);
      }
      _isSwipingFromBottom = false;
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _isSwipingFromBottom = false;

    if (_toolbarVisible.value &&
        _toolbarAnim.isCompleted &&
        details.velocity.pixelsPerSecond.dy > 0) {
      _toolbarVisible.value = false;
      _toolbarAnim.reverse();
    }
  }

  void _toggleToolbar() {
    if (_toolbarVisible.value) {
      _toolbarVisible.value = false;
      _toolbarAnim.reverse();
    } else {
      _toolbarVisible.value = true;
      _toolbarAnim.forward(from: 0);
    }
  }

  void _closeToolbar() {
    _toolbarVisible.value = false;
    _toolbarAnim.reverse();
  }

  void _handleWordCountTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < 500) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTap = now;

    if (_tapCount >= 5) {
      setState(() => _showTweaks = true);
      _tapCount = 0;
    }
  }

  Widget _buildStatusBar() {
    final showCount = widget.storage.getShowWordCount();
    // Always visible: the theme toggle + word count are primary controls.
    return StatusBar(
      title: _title,
      wordCount: _wordCount,
      isDark: Theme.of(context).brightness == Brightness.dark,
      onToggleTheme: () {
        context.read<ThemeProvider>().toggleTheme();
      },
      onTap: _toggleToolbar,
      showWordCount: showCount,
      onWordCountTap: _handleWordCountTap,
    );
  }

  @override
  void dispose() {
    _toolbarAnim.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _controller?.dispose();
    _toolbarVisible.dispose();
    _showStatusBar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        child: Stack(
        children: [
          // Status bar overlay (Positioned: a non-Positioned child here
          // breaks web rasterization of the whole Stack)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildStatusBar(),
          ),

          // Full-screen editor (lifts above toolbar when open so the
          // input-box bottom border stays visible)
          ValueListenableBuilder<bool>(
            valueListenable: _toolbarVisible,
            builder: (context, toolbarOpen, _) {
              return Positioned(
                top: 72,
                left: 0,
                right: 0,
                bottom: toolbarOpen ? 360 : 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              onTap: () {
                // Tapping empty space dismisses keyboard
                if (_toolbarVisible.value) _closeToolbar();
              },
              child: Container(
                key: const ValueKey('editorContainer'),
                // Margin from the screen edges: 16 on all sides.
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Container(
                  // Modern input card: soft shadow + subtle border.
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _quillEditor(),
                ),
              ),
            ),
              );
            },
          ),

          // Placeholder when empty (with toggle)
          if (_isEmptyDoc && widget.storage.getShowPlaceholder())
            Positioned(
              top: 116,
              left: 32,
              right: 32,
              child: Center(
                child: Text(
                  'Start writing \u2026',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 17,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Swipe-up hint (only when toolbar not shown and note is empty)
          if (!_toolbarVisible.value && _isEmptyDoc)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'Swipe up for tools',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                    color: Theme.of(context)
                            .hintColor
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Save status chip (autosave state, below status bar)
          Positioned(
            top: 76,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_saving)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: Colors.green.shade600,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _saving ? 'Saving…' : _saveLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Toolbar (slides up from bottom, always full screen width)
          ValueListenableBuilder<bool>(
            valueListenable: _toolbarVisible,
            builder: (context, visible, child) {
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                bottom: visible ? 0 : -460,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !visible && _toolbarSlide.value == 0,
                  child: RichTextToolbar(
                    onFormat: _handleFormat,
                    onClose: _closeToolbar,
                    isDark: isDark,
                  ),
                ),
              );
            },
          ),

          // Tweaks panel
          if (_showTweaks)
            Positioned(
              top: 88,
              right: 16,
              child: TweaksPanel(
                storage: widget.storage,
                onDismiss: () => setState(() => _showTweaks = false),
              ),
            ),
        ],
        ),
      ),
    );
  }

  /// Editor widget; empty box until the note (and controller) is ready.
  Widget _quillEditor() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return QuillEditor.basic(
      controller: controller,
      focusNode: _focusNode,
      scrollController: _scrollController,
      config: const QuillEditorConfig(
        padding: EdgeInsets.zero,
        autoFocus: false,
        expands: false,
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            TextStyle(
              fontSize: 17,
              height: 1.5,
              fontFamily: 'Roboto',
            ),
            HorizontalSpacing(0, 0),
            VerticalSpacing(0, 0),
            VerticalSpacing(0, 0),
            null,
          ),
        ),
      ),
    );
  }

  // --- Rich text formatting (toolbar) ---

  bool _hasInline(String key) {
    final controller = _controller;
    if (controller == null) return false;
    return controller.getSelectionStyle().attributes.containsKey(key);
  }

  bool _hasBlock(String key, [Object? value]) {
    final controller = _controller;
    if (controller == null) return false;
    final attrs = controller.getSelectionStyle().attributes;
    if (!attrs.containsKey(key)) return false;
    if (value == null) return true;
    return attrs[key]!.value == value;
  }

  void _handleFormat(String format) {
    final controller = _controller;
    if (controller == null) return;
    switch (format) {
      case 'bold':
        controller.formatSelection(
            _hasInline('bold') ? Attribute.clone(Attribute.bold, null) : Attribute.bold);
      case 'italic':
        controller.formatSelection(_hasInline('italic')
            ? Attribute.clone(Attribute.italic, null)
            : Attribute.italic);
      case 'underline':
        controller.formatSelection(_hasInline('underline')
            ? Attribute.clone(Attribute.underline, null)
            : Attribute.underline);
      case 'list':
        controller.formatSelection(_hasBlock('list', 'bullet')
            ? const ListAttribute(null)
            : const ListAttribute('bullet'));
      case 'heading':
        controller.formatSelection(_hasBlock('header', 1)
            ? const HeaderAttribute()
            : const HeaderAttribute(level: 1));
      case 'link':
        _askLink();
      case 'mono':
        controller.formatSelection(_hasInline('code')
            ? Attribute.clone(Attribute.inlineCode, null)
            : Attribute.inlineCode);
      case 'image':
        _pickImage();
      case 'undo':
        controller.undo();
      case 'redo':
        controller.redo();
      case 'copy':
        _copySelection();
      case 'paste':
        _pasteFromClipboard();
      case 'save':
        _saveNow();
      case 'selectAll':
        _selectAll();
    }
  }

  /// Copy current selection (or full note if collapsed) to system clipboard.
  Future<void> _copySelection() async {
    final controller = _controller;
    if (controller == null) return;
    final sel = controller.selection;
    final full = controller.document.toPlainText();
    String text;
    if (sel.isValid && !sel.isCollapsed) {
      final start = sel.start < 0 ? 0 : sel.start;
      var end = sel.end;
      if (end > full.length) end = full.length;
      if (end <= start) return;
      text = full.substring(start, end);
    } else {
      text = full;
    }
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  /// Paste plain text from system clipboard at cursor.
  Future<void> _pasteFromClipboard() async {
    final controller = _controller;
    if (controller == null) return;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final sel = controller.selection;
    final index = sel.baseOffset < 0 ? controller.document.length - 1 : sel.baseOffset;
    var len = sel.extentOffset - sel.baseOffset;
    if (len < 0) len = 0;
    controller.replaceText(index, len, text, null);
  }

  void _selectAll() {
    final controller = _controller;
    if (controller == null) return;
    final len = controller.document.length;
    if (len <= 1) return;
    controller.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: len - 1),
      ChangeSource.local,
    );
  }

  Future<void> _askLink() async {
    final controller = _controller;
    if (controller == null) return;
    final style = controller.getSelectionStyle().attributes;
    final current = style['link']?.value as String?;
    final urlController = TextEditingController(text: current ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link'),
        content: TextField(
          controller: urlController,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(urlController.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    urlController.dispose();
    if (url == null) return;
    if (url.isEmpty) {
      controller.formatSelection(const LinkAttribute(null));
    } else {
      final fixed = (url.startsWith('http://') || url.startsWith('https://'))
          ? url
          : 'https://$url';
      controller.formatSelection(LinkAttribute(fixed));
    }
  }

  Future<void> _pickImage() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      final mime = picked.mimeType ?? 'image/png';
      final dataUri =
          'data:$mime;base64,${base64Encode(bytes)}';
      final sel = controller.selection;
      final index = sel.baseOffset < 0 ? 0 : sel.baseOffset;
      int len = sel.extentOffset - sel.baseOffset;
      if (len < 0) len = 0;
      controller.replaceText(index, len, BlockEmbed.image(dataUri), null);
      controller.moveCursorToPosition(index + 1);
    } catch (_) {
      // Picker unavailable/cancelled — stay silent, keep editing.
    }
  }
}
