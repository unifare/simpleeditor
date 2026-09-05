import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:notepad/services/storage_service.dart';

void main() {
  test('Word count works correctly', () {
    expect(countWords(''), 0);
    expect(countWords('hello'), 1);
    expect(countWords('hello world'), 2);
    expect(countWords('hello world  '), 2);
    expect(countWords('  hello   world  '), 2);
  });

  test('Title derivation from content', () {
    expect(deriveTitle('Hello world'), 'Hello world');
    expect(deriveTitle('Hello world\nsecond line'), 'Hello world');
    expect(deriveTitle('\n\nHello'), 'Hello');
    expect(deriveTitle(''), 'Untitled');
    expect(deriveTitle('\n\n\n'), 'Untitled');
  });

  test('Title truncation at 80 chars', () {
    final long = 'A' * 100;
    expect(deriveTitle(long), '${'A' * 77}...');
  });

  test('Note deltaJson round-trip', () {
    const delta =
        '[{"insert":"hello"},{"insert":"\\n","attributes":{"bold":true}}]';
    final note = Note.create(
        title: 'hello', content: 'hello\n', deltaJson: delta);
    final restored =
        Note.fromJson(jsonDecode(jsonEncode(note.toJson())));
    expect(restored.deltaJson, delta);
    expect(restored.content, 'hello\n');
    expect(restored.title, 'hello');
  });

  test('Note without deltaJson loads as plain text (V1 compat)', () {
    final restored = Note.fromJson({
      'id': 'x',
      'title': 't',
      'content': 'c',
      'createdAt': DateTime(2024).toIso8601String(),
    });
    expect(restored.deltaJson, isNull);
    expect(restored.content, 'c');
  });

  test('Note copyWith preserves deltaJson', () {
    final note =
        Note.create(title: 't', content: 'c', deltaJson: 'd');
    final updated = note.copyWith(content: 'c2');
    expect(updated.deltaJson, 'd');
    expect(updated.content, 'c2');
  });
}

int countWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

String deriveTitle(String content) {
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
