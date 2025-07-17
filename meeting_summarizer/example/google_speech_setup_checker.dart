/// Example program to check Google Speech service setup status
library;

import 'dart:developer';

import 'package:meeting_summarizer/core/services/google_speech_service.dart';

void main() async {
  log('🎤 Google Speech-to-Text Service Setup Checker\n');

  final service = GoogleSpeechService.getInstance();

  // Check initialization status
  final status = await service.getInitializationStatus();

  log('📊 Current Status:');
  log('  • Initialized: ${status['isInitialized']}');
  log('  • Setup Required: ${status['setupRequired']}');
  log('  • Has API Key: ${status['hasApiKey']}');
  log('  • Has Auth Client: ${status['hasAuthClient']}');

  log('\n🔍 Credentials Check:');
  final credentials = status['credentialsFound'] as Map<String, dynamic>;
  log('  • API Key from Environment: ${credentials['apiKeyFromEnv']}');
  log(
    '  • Service Account from Environment: ${credentials['serviceAccountFromEnv']}',
  );
  log('  • Has Any Credentials: ${credentials['hasAnyCredentials']}');

  log('\n📋 Environment Variables Checked:');
  final envVars = credentials['environmentVariablesChecked'] as List<String>;
  for (final envVar in envVars) {
    log('  • $envVar');
  }

  log('\n🛠️ Setup Steps Required:');
  final setupSteps = status['setupSteps'] as List<String>;
  for (final step in setupSteps) {
    log('  $step');
  }

  log('\n✅ Service Availability Test:');
  final isAvailable = await service.isServiceAvailable();
  log('  • Service Available: $isAvailable');

  if (!isAvailable) {
    log('\n❌ Service Setup Required!');
    log('The Google Speech-to-Text service requires proper authentication.');
    log('Please follow the setup steps above to configure credentials.');
  } else {
    log('\n✅ Service Ready!');
    log(
      'The Google Speech-to-Text service is properly configured and ready to use.',
    );
  }

  await service.dispose();
}
