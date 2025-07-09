import 'package:flutter/material.dart';
import '../screens/recording_screen.dart';

/// A test widget to demonstrate responsive design at different screen sizes
class ResponsiveTestWidget extends StatelessWidget {
  const ResponsiveTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Responsive Design Test'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Show different screen size examples
            _buildSizeExample('Mobile Portrait', const Size(400, 800)),
            const SizedBox(height: 20),
            _buildSizeExample('Tablet Portrait', const Size(600, 900)),
            const SizedBox(height: 20),
            _buildSizeExample('Desktop', const Size(1200, 800)),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeExample(String title, Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          width: size.width,
          height: size.height * 0.6, // Scale down for display
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Transform.scale(
              scale: 0.6,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: const MaterialApp(
                  debugShowCheckedModeBanner: false,
                  home: RecordingScreen(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}