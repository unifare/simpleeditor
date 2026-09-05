import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
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
  testWidgets('EditorScreen shows QuillEditor and empty placeholder',
      (WidgetTester tester) async {
    final storage = await _readyStorage();
    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.text('Start writing \u2026'), findsOneWidget);
    expect(find.text('Swipe up for tools'), findsOneWidget);
  });

  testWidgets('Bold button formats selection and persists delta',
      (WidgetTester tester) async {
    final storage = await _readyStorage();
    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    final controller = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;
    controller.replaceText(
        0, 0, 'hello', const TextSelection.collapsed(offset: 5));
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      ChangeSource.local,
    );
    await tester.pumpAndSettle();

    // Swipe up from the bottom edge to reveal the toolbar.
    await tester.flingFrom(
        const Offset(400, 590), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final saved = await storage.getCurrentNote();
    expect(saved, isNotNull);
    expect(saved!.content.trim(), 'hello');
    expect(saved.deltaJson, isNotNull);
    expect(saved.deltaJson!, contains('"bold":true'));
  });
}
