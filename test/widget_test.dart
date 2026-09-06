import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:notepad/providers/theme_provider.dart';
import 'package:notepad/services/storage_service.dart';
import 'package:notepad/main.dart' show NotepadApp;
import 'package:provider/provider.dart';

Future<StorageService> _readyStorage() async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return storage;
}

Widget _app(StorageService storage) {
  final theme = ThemeProvider(storage: storage);
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: theme)],
    child: NotepadApp(storage: storage),
  );
}

void main() {
  testWidgets('Feed shows empty state and composer',
      (WidgetTester tester) async {
    final storage = await _readyStorage();
    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    expect(find.text('Notepad'), findsOneWidget);
    expect(find.text('Empty — write below and Send.'), findsOneWidget);
    expect(find.text('0 notes'), findsOneWidget);
    // Composer controls exist.
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Edit'), findsWidgets);
    expect(find.text('MD'), findsOneWidget);
    expect(find.text('HTML'), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('Send creates a card that persists',
      (WidgetTester tester) async {
    final storage = await _readyStorage();
    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello card');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Card appears with lang chip + actions.
    expect(find.text('hello card'), findsWidgets);
    expect(find.text('1 notes'), findsOneWidget);
    expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    final notes = await storage.getAllNotes();
    expect(notes, hasLength(1));
    expect(notes.first.content, 'hello card');
    expect(notes.first.lang, 'text');
  });

  testWidgets('B button wraps selection in bold markers',
      (WidgetTester tester) async {
    final storage = await _readyStorage();
    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'boldme');
    await tester.pump();
    // Select all via the field, then tap B.
    final field =
        tester.widget<TextField>(find.byType(TextField));
    field.controller?.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 6,
    );
    await tester.pump();
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(
        field.controller?.text ?? tester.widget<TextField>(
            find.byType(TextField)).controller!.text,
        '**boldme**');
  });

  testWidgets('Delete removes the card', (WidgetTester tester) async {
    final storage = await _readyStorage();
    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bye');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1 notes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('0 notes'), findsOneWidget);
    expect(await storage.getAllNotes(), isEmpty);
  });

  testWidgets('PreviewSegments switches MD and HTML',
      (WidgetTester tester) async {
    final storage = await _readyStorage();
    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('MD'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownBody), findsOneWidget);

    await tester.tap(find.text('HTML'));
    await tester.pumpAndSettle();
    // HTML preview replaces the markdown preview.
    expect(find.byType(MarkdownBody), findsNothing);
  });

  testWidgets('Fullscreen studio MD preview renders',
      (WidgetTester tester) async {
    final storage = await _readyStorage();
    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    // Open fullscreen via the expand button in the md bar.
    await tester.tap(find.byIcon(Icons.open_in_full_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Fullscreen'), findsOneWidget);

    await tester.enterText(
        find.descendant(
            of: find.byType(Column), matching: find.byType(TextField)),
        '# Big');
    await tester.pump();
    await tester.tap(find.text('MD').last);
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownBody), findsOneWidget);
  });
}
