/// Example program to check Google Speech service setup status
library;

import 'package:meeting_summarizer/core/services/google_speech_service.dart';

void main() async {
  print('🎤 Google Speech-to-Text Service Setup Checker\n');

  final service = GoogleSpeechService.getInstance();

  // Check initialization status
  final status = service.getInitializationStatus();

  print('📊 Current Status:');
  print('  • Initialized: ${status['isInitialized']}');
  print('  • Setup Required: ${status['setupRequired']}');
  print('  • Has API Key: ${status['hasApiKey']}');
  print('  • Has Auth Client: ${status['hasAuthClient']}');

  print('\n🔍 Credentials Check:');
  final credentials = status['credentialsFound'] as Map<String, dynamic>;
  print('  • API Key from Environment: ${credentials['apiKeyFromEnv']}');
  print(
    '  • Service Account from Environment: ${credentials['serviceAccountFromEnv']}',
  );
  print('  • Has Any Credentials: ${credentials['hasAnyCredentials']}');

  print('\n📋 Environment Variables Checked:');
  final envVars = credentials['environmentVariablesChecked'] as List<String>;
  for (final envVar in envVars) {
    print('  • $envVar');
  }

  print('\n🛠️ Setup Steps Required:');
  final setupSteps = status['setupSteps'] as List<String>;
  for (final step in setupSteps) {
    print('  $step');
  }

  print('\n✅ Service Availability Test:');
  final isAvailable = await service.isServiceAvailable();
  print('  • Service Available: $isAvailable');

  if (!isAvailable) {
    print('\n❌ Service Setup Required!');
    print('The Google Speech-to-Text service requires proper authentication.');
    print('Please follow the setup steps above to configure credentials.');
  } else {
    print('\n✅ Service Ready!');
    print(
      'The Google Speech-to-Text service is properly configured and ready to use.',
    );
  }

  await service.dispose();
}
