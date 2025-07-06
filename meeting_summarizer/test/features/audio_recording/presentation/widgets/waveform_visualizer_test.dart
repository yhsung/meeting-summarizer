import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/features/audio_recording/presentation/widgets/waveform_visualizer.dart';

void main() {
  group('WaveformVisualizer', () {
    testWidgets('should build without error with empty data', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WaveformVisualizer(waveformData: [], currentAmplitude: 0.0),
        ),
      );

      expect(find.byType(WaveformVisualizer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('should build with waveform data', (tester) async {
      const waveformData = [0.1, 0.5, 0.8, 0.3, 0.6, 0.2];
      const currentAmplitude = 0.7;

      await tester.pumpWidget(
        const MaterialApp(
          home: WaveformVisualizer(
            waveformData: waveformData,
            currentAmplitude: currentAmplitude,
          ),
        ),
      );

      expect(find.byType(WaveformVisualizer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('should apply custom dimensions', (tester) async {
      const width = 400.0;
      const height = 150.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: WaveformVisualizer(
            waveformData: [0.5],
            currentAmplitude: 0.5,
            width: width,
            height: height,
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth, width);
      expect(container.constraints?.maxHeight, height);
    });

    testWidgets('should apply custom colors', (tester) async {
      const waveColor = Colors.red;
      const backgroundColor = Colors.yellow;

      await tester.pumpWidget(
        const MaterialApp(
          home: WaveformVisualizer(
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

    testWidgets('should handle animation updates', (tester) async {
      const waveformData = [0.1, 0.5, 0.8];

      await tester.pumpWidget(
        const MaterialApp(
          home: WaveformVisualizer(
            waveformData: waveformData,
            currentAmplitude: 0.5,
            animationDuration: Duration(milliseconds: 100),
          ),
        ),
      );

      // Trigger animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(WaveformVisualizer), findsOneWidget);
    });

    testWidgets('should update when data changes', (tester) async {
      const initialData = [0.1, 0.5];
      const updatedData = [0.1, 0.5, 0.8, 0.3];

      await tester.pumpWidget(
        const MaterialApp(
          home: WaveformVisualizer(
            waveformData: initialData,
            currentAmplitude: 0.5,
          ),
        ),
      );

      expect(find.byType(WaveformVisualizer), findsOneWidget);

      // Update with new data
      await tester.pumpWidget(
        const MaterialApp(
          home: WaveformVisualizer(
            waveformData: updatedData,
            currentAmplitude: 0.8,
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(WaveformVisualizer), findsOneWidget);
    });

    testWidgets('should limit data points for performance', (tester) async {
      // Create data with more than maxDataPoints
      final largeData = List.generate(150, (index) => 0.5);

      await tester.pumpWidget(
        MaterialApp(
          home: WaveformVisualizer(
            waveformData: largeData,
            currentAmplitude: 0.5,
            maxDataPoints: 100,
          ),
        ),
      );

      expect(find.byType(WaveformVisualizer), findsOneWidget);
    });

    testWidgets('should handle zero amplitude gracefully', (tester) async {
      const waveformData = [0.0, 0.0, 0.0];
      const currentAmplitude = 0.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: WaveformVisualizer(
            waveformData: waveformData,
            currentAmplitude: currentAmplitude,
          ),
        ),
      );

      expect(find.byType(WaveformVisualizer), findsOneWidget);
    });

    testWidgets('should handle maximum amplitude values', (tester) async {
      const waveformData = [1.0, 1.0, 1.0];
      const currentAmplitude = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: WaveformVisualizer(
            waveformData: waveformData,
            currentAmplitude: currentAmplitude,
          ),
        ),
      );

      expect(find.byType(WaveformVisualizer), findsOneWidget);
    });
  });

  group('WaveformPainter', () {
    test('should create painter with required parameters', () {
      final painter = WaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter.waveformData, equals(const [0.5]));
      expect(painter.waveColor, equals(Colors.blue));
      expect(painter.animationProgress, equals(1.0));
      expect(painter.showCurrentAmplitude, equals(true));
    });

    test('should detect when repainting is needed', () {
      final painter1 = WaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      final painter2 = WaveformPainter(
        waveformData: const [0.6],
        waveColor: Colors.blue,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('should not repaint when data is the same', () {
      final painter1 = WaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      final painter2 = WaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('should repaint when animation progress changes', () {
      final painter1 = WaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        animationProgress: 0.5,
        showCurrentAmplitude: true,
      );

      final painter2 = WaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('should repaint when color changes', () {
      final painter1 = WaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      final painter2 = WaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.red,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('should repaint when showCurrentAmplitude changes', () {
      final painter1 = WaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        animationProgress: 1.0,
        showCurrentAmplitude: true,
      );

      final painter2 = WaveformPainter(
        waveformData: const [0.5],
        waveColor: Colors.blue,
        animationProgress: 1.0,
        showCurrentAmplitude: false,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });
}
