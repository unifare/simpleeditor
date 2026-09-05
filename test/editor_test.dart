import 'package:flutter_test/flutter_test.dart';

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
