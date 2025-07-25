import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user onboarding state and preferences
class OnboardingService {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _permissionsGrantedKey = 'permissions_granted';
  static const String _cloudSetupCompleteKey = 'cloud_setup_complete';
  static const String _audioTestCompleteKey = 'audio_test_complete';
  static const String _firstLaunchKey = 'first_launch';

  static OnboardingService? _instance;
  static OnboardingService get instance => _instance ??= OnboardingService._();

  OnboardingService._();

  /// Check if user has completed the full onboarding flow
  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  /// Check if this is the user's first app launch
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool(_firstLaunchKey) ?? true;
    if (isFirst) {
      await prefs.setBool(_firstLaunchKey, false);
    }
    return isFirst;
  }

  /// Check if permissions have been granted
  Future<bool> arePermissionsGranted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionsGrantedKey) ?? false;
  }

  /// Mark permissions as granted
  Future<void> markPermissionsGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsGrantedKey, true);
  }

  /// Check if cloud setup is complete
  Future<bool> isCloudSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cloudSetupCompleteKey) ?? false;
  }

  /// Mark cloud setup as complete
  Future<void> markCloudSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudSetupCompleteKey, true);
  }

  /// Check if audio quality test is complete
  Future<bool> isAudioTestComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_audioTestCompleteKey) ?? false;
  }

  /// Mark audio test as complete
  Future<void> markAudioTestComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_audioTestCompleteKey, true);
  }

  /// Reset all onboarding state (useful for testing)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompleteKey);
    await prefs.remove(_permissionsGrantedKey);
    await prefs.remove(_cloudSetupCompleteKey);
    await prefs.remove(_audioTestCompleteKey);
    await prefs.setBool(_firstLaunchKey, true);
  }

  /// Get onboarding progress as a percentage
  Future<double> getOnboardingProgress() async {
    final List<bool> steps = [
      await arePermissionsGranted(),
      await isCloudSetupComplete(),
      await isAudioTestComplete(),
    ];

    final completedSteps = steps.where((step) => step).length;
    return completedSteps / steps.length;
  }
}
