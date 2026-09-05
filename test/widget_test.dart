import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {});

  testWidgets('Basic text field renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextField(),
        ),
      ),
    ));

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Can enter text in TextField', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextField(),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'Hello World');
    await tester.pump();

    expect(find.text('Hello World'), findsOneWidget);
  });

  testWidgets('Multiple lines work', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextField(
            maxLines: null,
            expands: true,
            keyboardType: TextInputType.multiline,
          ),
        ),
      ),
    ));

    await tester.enterText(
      find.byType(TextField),
      'Hello World\nSecond line',
    );
    await tester.pump();

    expect(find.text('Hello World\nSecond line'), findsOneWidget);
  });
}
