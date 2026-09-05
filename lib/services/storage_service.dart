import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  Note.create({
    String? id,
    required this.title,
    required this.content,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = createdAt ?? DateTime.now();

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StorageService {
  static const String _currentNoteKey = 'current_note';
  static const String _notesListKey = 'notes_list';
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
  Future<void> saveNoteContent(String content) async {
    final note = await getCurrentNote();
    if (note == null) {
      final newNote = Note.create(title: '', content: content);
      await saveCurrentNote(newNote);
    } else {
      final updated = note.copyWith(
        content: content,
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
}
