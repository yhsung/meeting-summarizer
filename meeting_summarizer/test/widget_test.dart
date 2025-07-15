// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/main.dart';

void main() {
  testWidgets('Meeting Summarizer app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MeetingSummarizerApp());

    // Verify that recording screen is displayed
    expect(find.text('Meeting Recorder'), findsOneWidget);
    expect(find.text('Ready to record'), findsOneWidget);

    // Verify recording button is present (should find 2: one in nav bar, one in recording screen)
    expect(find.byIcon(Icons.mic), findsNWidgets(2));
    
    // Verify bottom navigation bar is present
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Transcription'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
