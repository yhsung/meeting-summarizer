import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../../data/services/onboarding_service.dart';
import '../widgets/permission_setup_widget.dart';
import '../widgets/cloud_setup_widget.dart';
import '../widgets/audio_test_widget.dart';

/// Comprehensive onboarding screen with interactive tutorials
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final OnboardingService _onboardingService = OnboardingService.instance;

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: [
        _buildWelcomePage(),
        _buildFeatureOverviewPage(),
        _buildPermissionSetupPage(),
        _buildCloudSetupPage(),
        _buildAudioTestPage(),
        _buildCompletePage(),
      ],
      onDone: _completeOnboarding,
      onSkip: _skipOnboarding,
      showSkipButton: true,
      skipOrBackFlex: 0,
      nextFlex: 0,
      showBackButton: true,
      back: const Icon(Icons.arrow_back),
      skip: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w600)),
      next: const Icon(Icons.arrow_forward),
      done: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.all(16),
      controlsPadding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        color: Color(0xFFBDBDBD),
        activeSize: Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
      globalBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }

  PageViewModel _buildWelcomePage() {
    return PageViewModel(
      title: "Welcome to Meeting Summarizer",
      body:
          "Transform your meetings with AI-powered transcription and intelligent summaries. Let's get you started!",
      image: _buildPageImage(Icons.waves, Colors.blue),
      decoration: _getPageDecoration(),
    );
  }

  PageViewModel _buildFeatureOverviewPage() {
    return PageViewModel(
      title: "Powerful Features",
      bodyWidget: Column(
        children: [
          const Text(
            "Everything you need for productive meetings:",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            Icons.mic,
            "High-Quality Recording",
            "Crystal clear audio capture with background noise reduction",
          ),
          _buildFeatureItem(
            Icons.transcribe,
            "AI Transcription",
            "Accurate speech-to-text with speaker identification",
          ),
          _buildFeatureItem(
            Icons.summarize,
            "Smart Summaries",
            "AI-generated meeting summaries and action items",
          ),
          _buildFeatureItem(
            Icons.cloud,
            "Cloud Sync",
            "Secure backup and sync across all your devices",
          ),
        ],
      ),
      image: _buildPageImage(Icons.auto_awesome, Colors.purple),
      decoration: _getPageDecoration(),
    );
  }

  PageViewModel _buildPermissionSetupPage() {
    return PageViewModel(
      title: "Permission Setup",
      bodyWidget: Column(
        children: [
          const Text(
            "We need some permissions to provide the best experience:",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const PermissionSetupWidget(),
        ],
      ),
      image: _buildPageImage(Icons.security, Colors.green),
      decoration: _getPageDecoration(),
    );
  }

  PageViewModel _buildCloudSetupPage() {
    return PageViewModel(
      title: "Cloud Storage (Optional)",
      bodyWidget: Column(
        children: [
          const Text(
            "Connect your preferred cloud service for automatic backup and sync:",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const CloudSetupWidget(),
        ],
      ),
      image: _buildPageImage(Icons.cloud_sync, Colors.orange),
      decoration: _getPageDecoration(),
    );
  }

  PageViewModel _buildAudioTestPage() {
    return PageViewModel(
      title: "Audio Quality Test",
      bodyWidget: Column(
        children: [
          const Text(
            "Let's test your audio setup to ensure the best recording quality:",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const AudioTestWidget(),
        ],
      ),
      image: _buildPageImage(Icons.volume_up, Colors.red),
      decoration: _getPageDecoration(),
    );
  }

  PageViewModel _buildCompletePage() {
    return PageViewModel(
      title: "You're All Set!",
      body:
          "Your Meeting Summarizer is configured and ready to use. Start recording your first meeting to experience the power of AI-driven productivity.",
      image: _buildPageImage(Icons.check_circle, Colors.green),
      decoration: _getPageDecoration(),
    );
  }

  Widget _buildPageImage(IconData icon, Color color) {
    return Container(
      height: 175,
      width: 175,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 100, color: color),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PageDecoration _getPageDecoration() {
    return PageDecoration(
      titleTextStyle: const TextStyle(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
      ),
      bodyTextStyle: const TextStyle(fontSize: 19.0),
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Theme.of(context).scaffoldBackgroundColor,
      imagePadding: const EdgeInsets.only(top: 40),
    );
  }

  Future<void> _completeOnboarding() async {
    await _onboardingService.completeOnboarding();
    if (mounted) {
      widget.onComplete?.call();
    }
  }

  Future<void> _skipOnboarding() async {
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Onboarding?'),
        content: const Text(
          'You can always access setup options in Settings later. Are you sure you want to skip the guided setup?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (shouldSkip == true) {
      await _completeOnboarding();
    }
  }
}
