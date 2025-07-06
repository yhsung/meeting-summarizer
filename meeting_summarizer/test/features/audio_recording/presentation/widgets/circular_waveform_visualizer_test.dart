import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/features/audio_recording/presentation/widgets/circular_waveform_visualizer.dart';

void main() {
  group('CircularWaveformVisualizer', () {
    testWidgets('should build without error with empty data', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: [],
            currentAmplitude: 0.0,
          ),
        ),
      );

      expect(find.byType(CircularWaveformVisualizer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('should build with waveform data', (tester) async {
      const waveformData = [0.1, 0.5, 0.8, 0.3, 0.6, 0.2];
      const currentAmplitude = 0.7;

      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: waveformData,
            currentAmplitude: currentAmplitude,
          ),
        ),
      );

      expect(find.byType(CircularWaveformVisualizer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('should apply custom radius', (tester) async {
      const radius = 120.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: [0.5],
            currentAmplitude: 0.5,
            radius: radius,
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth, radius * 2);
      expect(container.constraints?.maxHeight, radius * 2);
    });

    testWidgets('should apply custom colors', (tester) async {
      const waveColor = Colors.red;
      const backgroundColor = Colors.yellow;

      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: [0.5],
            currentAmplitude: 0.5,
            waveColor: waveColor,
            backgroundColor: backgroundColor,
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect((container.decoration as BoxDecoration).color, backgroundColor);
    });

    testWidgets('should apply custom stroke width', (tester) async {
      const strokeWidth = 5.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: [0.5],
            currentAmplitude: 0.5,
            strokeWidth: strokeWidth,
          ),
        ),
      );

      expect(find.byType(CircularWaveformVisualizer), findsOneWidget);
    });

    testWidgets('should handle animation updates', (tester) async {
      const waveformData = [0.1, 0.5, 0.8];

      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: waveformData,
            currentAmplitude: 0.5,
            animationDuration: Duration(milliseconds: 150),
          ),
        ),
      );

      // Trigger animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));

      expect(find.byType(CircularWaveformVisualizer), findsOneWidget);
    });

    testWidgets('should update when data changes', (tester) async {
      const initialData = [0.1, 0.5];
      const updatedData = [0.1, 0.5, 0.8, 0.3];

      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: initialData,
            currentAmplitude: 0.5,
          ),
        ),
      );

      expect(find.byType(CircularWaveformVisualizer), findsOneWidget);

      // Update with new data
      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: updatedData,
            currentAmplitude: 0.8,
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularWaveformVisualizer), findsOneWidget);
    });

    testWidgets('should limit data points for performance', (tester) async {
      // Create data with more than maxDataPoints
      final largeData = List.generate(100, (index) => 0.5);

      await tester.pumpWidget(
        MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: largeData,
            currentAmplitude: 0.5,
            maxDataPoints: 60,
          ),
        ),
      );

      expect(find.byType(CircularWaveformVisualizer), findsOneWidget);
    });

    testWidgets('should handle zero amplitude gracefully', (tester) async {
      const waveformData = [0.0, 0.0, 0.0];
      const currentAmplitude = 0.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: waveformData,
            currentAmplitude: currentAmplitude,
          ),
        ),
      );

      expect(find.byType(CircularWaveformVisualizer), findsOneWidget);
    });

    testWidgets('should handle maximum amplitude values', (tester) async {
      const waveformData = [1.0, 1.0, 1.0];
      const currentAmplitude = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: waveformData,
            currentAmplitude: currentAmplitude,
          ),
        ),
      );

      expect(find.byType(CircularWaveformVisualizer), findsOneWidget);
    });

    testWidgets('should create circular container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: [0.5],
            currentAmplitude: 0.5,
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('should disable current amplitude display', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CircularWaveformVisualizer(
            waveformData: [0.5],
            currentAmplitude: 0.5,
            showCurrentAmplitude: false,
          ),
        ),
      );

      expect(find.byType(CircularWaveformVisualizer), findsOneWidget);
    });
  });

  group('CircularWaveformPainter', () {
    test('should create painter with required parameters', () {
      final painter = CircularWaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        strokeWidth: 3.0,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter.waveformData, equals(const [0.5]));
      expect(painter.waveColor, equals(Colors.blue));
      expect(painter.strokeWidth, equals(3.0));
      expect(painter.animationProgress, equals(1.0));
      expect(painter.showCurrentAmplitude, equals(true));
    });

    test('should detect when repainting is needed', () {
      final painter1 = CircularWaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        strokeWidth: 3.0,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      final painter2 = CircularWaveformPainter(
        waveformData: const [0.6],
        waveColor: Colors.blue,
        strokeWidth: 3.0,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('should not repaint when data is the same', () {
      final painter1 = CircularWaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        strokeWidth: 3.0,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      final painter2 = CircularWaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        strokeWidth: 3.0,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('should repaint when stroke width changes', () {
      final painter1 = CircularWaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        strokeWidth: 3.0,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      final painter2 = CircularWaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        strokeWidth: 5.0,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('should repaint when animation progress changes', () {
      final painter1 = CircularWaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        strokeWidth: 3.0,
        animationProgress: 0.5,
        showCurrentAmplitude: true,
      );

      final painter2 = CircularWaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        strokeWidth: 3.0,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('should repaint when color changes', () {
      final painter1 = CircularWaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        strokeWidth: 3.0,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      final painter2 = CircularWaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.red,
        strokeWidth: 3.0,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });
}
