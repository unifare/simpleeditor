import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Note {
  final String id;
  final String title;
  final String content;

  /// Quill delta JSON (rich text). Null for plain-text notes (V1 data).
  final String? deltaJson;

  /// Composer language tag (text/md/js/json/html/...). Null = plain text.
  final String? lang;
  final DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.deltaJson,
    this.lang,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  Note.create({
    String? id,
    required this.title,
    required this.content,
    this.deltaJson,
    this.lang,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = createdAt ?? DateTime.now();

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        deltaJson: json['deltaJson'] as String?,
        lang: json['lang'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        if (deltaJson != null) 'deltaJson': deltaJson,
        if (lang != null) 'lang': lang,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? deltaJson,
    String? lang,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      deltaJson: deltaJson ?? this.deltaJson,
      lang: lang ?? this.lang,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StorageService {
  static const String _currentNoteKey = 'current_note';
  static const String _notesListKey = 'notes_list';
  static const String _historyKey = 'note_history';
  static const int _historyCap = 30;
  static const Duration _historyMinGap = Duration(seconds: 60);
  static const String _themeKey = 'theme_mode';
  static const String _toolbarStyleKey = 'toolbar_style';
  static const String _showPlaceholderKey = 'show_placeholder';
  static const String _showWordCountKey = 'show_word_count';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Current note (most recently opened / being edited) ---
  Future<Note?> getCurrentNote() async {
    final jsonStr = _prefs.getString(_currentNoteKey);
    if (jsonStr == null) return null;
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Note.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveCurrentNote(Note note) async {
    final jsonStr = jsonEncode(note.toJson());
    await _prefs.setString(_currentNoteKey, jsonStr);
  }

  // --- Note content auto-save ---
  Future<void> saveNoteContent(String content, {String? deltaJson}) async {
    final note = await getCurrentNote();
    if (note == null) {
      final newNote = Note.create(
          title: '', content: content, deltaJson: deltaJson);
      await saveCurrentNote(newNote);
    } else {
      final updated = note.copyWith(
        content: content,
        deltaJson: deltaJson,
        title: _deriveTitle(content),
        updatedAt: DateTime.now(),
      );
      await saveCurrentNote(updated);
    }
  }

  String _deriveTitle(String content) {
    final firstLine = content.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final title = firstLine.trim();
    if (title.length > 80) return '${title.substring(0, 77)}...';
    return title.isEmpty ? 'Untitled' : title;
  }

  // --- Theme settings ---
  ThemeMode getSavedTheme() {
    final value = _prefs.getString(_themeKey);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveTheme(ThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
  }

  // --- Toolbar style ---
  bool getToolbarOnTap() => _prefs.getBool(_toolbarStyleKey) ?? false;
  Future<void> saveToolbarOnTap(bool enabled) async {
    await _prefs.setBool(_toolbarStyleKey, enabled);
  }

  // --- UI toggles ---
  bool getShowPlaceholder() => _prefs.getBool(_showPlaceholderKey) ?? true;
  Future<void> saveShowPlaceholder(bool enabled) async {
    await _prefs.setBool(_showPlaceholderKey, enabled);
  }

  bool getShowWordCount() => _prefs.getBool(_showWordCountKey) ?? true;
  Future<void> saveShowWordCount(bool enabled) async {
    await _prefs.setBool(_showWordCountKey, enabled);
  }

  // --- History (snapshots of past content) ---
  Future<List<Note>> getHistory() async {
    final list = _prefs.getStringList(_historyKey) ?? [];
    final notes = <Note>[];
    for (final jsonStr in list) {
      try {
        notes.add(Note.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>));
      } catch (_) {}
    }
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  Future<void> _saveHistory(List<Note> notes) async {
    final capped = notes.take(_historyCap).toList();
    final list = capped.map((n) => jsonEncode(n.toJson())).toList();
    await _prefs.setStringList(_historyKey, list);
  }

  /// Record a snapshot unless identical to the latest or within the
  /// throttle window (explicit saves use [force] to bypass the window).
  /// Trivial content (< 2 chars) is never snapshotted.
  Future<List<Note>> recordSnapshot(String content,
      {String? deltaJson, bool force = false}) async {
    if (content.trim().length < 2) return getHistory();
    final history = await getHistory();
    final now = DateTime.now();
    if (history.isNotEmpty) {
      final latest = history.first;
      if (latest.content == content) return history;
      if (!force && now.difference(latest.updatedAt) < _historyMinGap) {
        return history;
      }
    }
    final entry = Note.create(
      title: _deriveTitle(content),
      content: content,
      deltaJson: deltaJson,
      createdAt: now,
    );
    history.insert(0, entry);
    await _saveHistory(history);
    return history.take(_historyCap).toList();
  }

  Future<List<Note>> deleteHistoryEntry(String id) async {
    final history = await getHistory();
    history.removeWhere((n) => n.id == id);
    await _saveHistory(history);
    return history;
  }

  // --- All notes ---
  Future<List<Note>> getAllNotes() async {
    final list = _prefs.getStringList(_notesListKey) ?? [];
    return list
        .map((jsonStr) => Note.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveAllNotes(List<Note> notes) async {
    final list = notes.map((n) => jsonEncode(n.toJson())).toList();
    await _prefs.setStringList(_notesListKey, list);
  }

  Future<List<Note>> addNote(Note note) async {
    final notes = await getAllNotes();
    notes.insert(0, note);
    await saveAllNotes(notes);
    return notes;
  }

  Future<List<Note>> updateNote(Note note) async {
    final notes = await getAllNotes();
    final i = notes.indexWhere((n) => n.id == note.id);
    if (i >= 0) {
      notes[i] = note;
    } else {
      notes.insert(0, note);
    }
    await saveAllNotes(notes);
    return notes;
  }

  Future<List<Note>> removeNote(String id) async {
    final notes = await getAllNotes();
    notes.removeWhere((n) => n.id == id);
    await saveAllNotes(notes);
    return notes;
  }

  // --- Backup: export / import ---

  /// Full backup payload (all notes + metadata).
  String exportJson(List<Note> notes) => jsonEncode({
        'app': 'notepad',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'notes': notes.map((n) => n.toJson()).toList(),
      });

  /// Human-readable backup: one section per note.
  String exportMarkdown(List<Note> notes) {
    final buf = StringBuffer();
    buf.writeln('# Notepad Backup (${notes.length} notes)');
    buf.writeln();
    for (final n in notes) {
      final t = n.updatedAt;
      final mm = t.month.toString().padLeft(2, '0');
      final dd = t.day.toString().padLeft(2, '0');
      final hh = t.hour.toString().padLeft(2, '0');
      final min = t.minute.toString().padLeft(2, '0');
      buf.writeln('## ${n.title}');
      buf.writeln();
      buf.writeln('_${n.lang ?? 'text'} · $mm-$dd $hh:${min}_');
      buf.writeln();
      buf.writeln(n.content);
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
    }
    return buf.toString();
  }

  /// Merge a backup payload in (newer updatedAt wins per id).
  /// Throws [FormatException] on invalid payload.
  Future<List<Note>> importJson(String raw) async {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (map['app'] != 'notepad' || map['notes'] is! List) {
      throw const FormatException('Not a Notepad backup file');
    }
    final incoming = (map['notes'] as List)
        .map((e) => Note.fromJson(e as Map<String, dynamic>))
        .toList();
    final byId = <String, Note>{};
    for (final n in await getAllNotes()) {
      byId[n.id] = n;
    }
    for (final n in incoming) {
      final cur = byId[n.id];
      if (cur == null || n.updatedAt.isAfter(cur.updatedAt)) {
        byId[n.id] = n;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await saveAllNotes(merged);
    return merged;
  }
}
