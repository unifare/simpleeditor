import 'package:flutter/material.dart';
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
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _toolbarVisible = ValueNotifier(false);
  final ValueNotifier<bool> _showStatusBar = ValueNotifier(false);
  late final AnimationController _toolbarAnim;
  late final Animation<double> _toolbarSlide;

  int _wordCount = 0;
  String _title = 'Untitled';
  bool _showTweaks = false;
  int _tapCount = 0;
  DateTime? _lastTap;

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
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadNote() async {
    final note = widget.existingNote ?? await widget.storage.getCurrentNote();
    if (note != null && mounted) {
      _controller.text = note.content;
      _updateMetadata(note.content);
    }
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (mounted) {
      _updateMetadata(text);
      // Debounced auto-save
      Future.microtask(() {
        if (mounted && _controller.text == text) {
          widget.storage.saveNoteContent(text);
        }
      });
    }
  }

  void _updateMetadata(String content) {
    final newCount = _countWords(content);
    final newTitle = _deriveTitle(content);

    bool needsSet = false;
    if (newCount != _wordCount) {
      _wordCount = newCount;
      needsSet = true;
    }
    if (newTitle != _title) {
      _title = newTitle;
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
    return ValueListenableBuilder<bool>(
      valueListenable: _showStatusBar,
      builder: (context, show, _) {
        return AnimatedSlide(
          offset: Offset(0, show ? 0 : -0.1),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: show ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: StatusBar(
              title: _title,
              wordCount: _wordCount,
              isDark: Theme.of(context).brightness == Brightness.dark,
              onToggleTheme: () {
                context.read<ThemeProvider>().toggleTheme();
              },
              onTap: _toggleToolbar,
              showWordCount: showCount,
              onWordCountTap: _handleWordCountTap,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _toolbarAnim.dispose();
    _scrollController.dispose();
    _controller.dispose();
    _toolbarVisible.dispose();
    _showStatusBar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Status bar overlay
          _buildStatusBar(),

          // Full-screen editor (key for test targeting)
          Positioned(
            top: 44,
            left: 0,
            right: 0,
            bottom: 0,
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: TextField(
                  controller: _controller,
                  scrollController: _scrollController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textAlign: TextAlign.left,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.5,
                    fontFamily: 'Inter',
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: _controller.text.isEmpty ? '' : null,
                    hintStyle: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 17,
                    ),
                    isCollapsed: true,
                  ),
                  cursorWidth: 1.5,
                  cursorHeight: 22,
                  cursorRadius: const Radius.circular(1),
                  cursorColor: isDark
                      ? const Color(0xFF0A84FF)
                      : const Color(0xFF007AFF),
                ),
              ),
            ),
          ),

          // Placeholder when empty (with toggle)
          if (_controller.text.isEmpty &&
              widget.storage.getShowPlaceholder())
            Positioned(
              top: 88,
              left: 0,
              right: 0,
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
          if (!_toolbarVisible.value && _controller.text.isEmpty)
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

          // Toolbar (slides up from bottom)
          ValueListenableBuilder<bool>(
            valueListenable: _toolbarVisible,
            builder: (context, visible, child) {
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                bottom: visible ? 0 : -320,
                left: 0,
                right: 0,
                child: SizeTransition(
                  sizeFactor: _toolbarSlide,
                  child: RichTextToolbar(
                    onFormat: (format) {
                      // Formatting handled when Quill is integrated in V2
                    },
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
    );
  }
}
