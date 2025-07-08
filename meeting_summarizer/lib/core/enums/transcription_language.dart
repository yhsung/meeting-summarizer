/// Supported languages for audio transcription
library;

/// Enumeration of supported transcription languages
///
/// Based on OpenAI Whisper supported languages with ISO 639-1 codes
enum TranscriptionLanguage {
  /// Auto-detect language (default)
  auto('auto', 'Auto-detect', '🌐'),

  /// English
  english('en', 'English', '🇺🇸'),

  /// Spanish
  spanish('es', 'Spanish', '🇪🇸'),

  /// French
  french('fr', 'French', '🇫🇷'),

  /// German
  german('de', 'German', '🇩🇪'),

  /// Italian
  italian('it', 'Italian', '🇮🇹'),

  /// Portuguese
  portuguese('pt', 'Portuguese', '🇵🇹'),

  /// Russian
  russian('ru', 'Russian', '🇷🇺'),

  /// Japanese
  japanese('ja', 'Japanese', '🇯🇵'),

  /// Korean
  korean('ko', 'Korean', '🇰🇷'),

  /// Chinese (Simplified)
  chineseSimplified('zh', 'Chinese (Simplified)', '🇨🇳'),

  /// Chinese (Traditional)
  chineseTraditional('zh-Hant', 'Chinese (Traditional)', '🇹🇼'),

  /// Arabic
  arabic('ar', 'Arabic', '🇸🇦'),

  /// Hindi
  hindi('hi', 'Hindi', '🇮🇳'),

  /// Dutch
  dutch('nl', 'Dutch', '🇳🇱'),

  /// Polish
  polish('pl', 'Polish', '🇵🇱'),

  /// Turkish
  turkish('tr', 'Turkish', '🇹🇷'),

  /// Swedish
  swedish('sv', 'Swedish', '🇸🇪'),

  /// Norwegian
  norwegian('no', 'Norwegian', '🇳🇴'),

  /// Danish
  danish('da', 'Danish', '🇩🇰'),

  /// Finnish
  finnish('fi', 'Finnish', '🇫🇮'),

  /// Greek
  greek('el', 'Greek', '🇬🇷'),

  /// Hebrew
  hebrew('he', 'Hebrew', '🇮🇱'),

  /// Thai
  thai('th', 'Thai', '🇹🇭'),

  /// Vietnamese
  vietnamese('vi', 'Vietnamese', '🇻🇳'),

  /// Ukrainian
  ukrainian('uk', 'Ukrainian', '🇺🇦'),

  /// Czech
  czech('cs', 'Czech', '🇨🇿'),

  /// Hungarian
  hungarian('hu', 'Hungarian', '🇭🇺'),

  /// Romanian
  romanian('ro', 'Romanian', '🇷🇴'),

  /// Bulgarian
  bulgarian('bg', 'Bulgarian', '🇧🇬'),

  /// Croatian
  croatian('hr', 'Croatian', '🇭🇷'),

  /// Slovak
  slovak('sk', 'Slovak', '🇸🇰'),

  /// Slovenian
  slovenian('sl', 'Slovenian', '🇸🇮'),

  /// Estonian
  estonian('et', 'Estonian', '🇪🇪'),

  /// Latvian
  latvian('lv', 'Latvian', '🇱🇻'),

  /// Lithuanian
  lithuanian('lt', 'Lithuanian', '🇱🇹'),

  /// Maltese
  maltese('mt', 'Maltese', '🇲🇹'),

  /// Indonesian
  indonesian('id', 'Indonesian', '🇮🇩'),

  /// Malay
  malay('ms', 'Malay', '🇲🇾'),

  /// Icelandic
  icelandic('is', 'Icelandic', '🇮🇸'),

  /// Welsh
  welsh('cy', 'Welsh', '🏴󠁧󠁢󠁷󠁬󠁳󠁿'),

  /// Catalan
  catalan('ca', 'Catalan', '🇨🇦'),

  /// Basque
  basque('eu', 'Basque', '🇪🇸'),

  /// Galician
  galician('gl', 'Galician', '🇪🇸'),

  /// Irish
  irish('ga', 'Irish', '🇮🇪'),

  /// Scottish Gaelic
  scottishGaelic('gd', 'Scottish Gaelic', '🏴󠁧󠁢󠁳󠁣󠁴󠁿'),

  /// Afrikaans
  afrikaans('af', 'Afrikaans', '🇿🇦'),

  /// Albanian
  albanian('sq', 'Albanian', '🇦🇱'),

  /// Armenian
  armenian('hy', 'Armenian', '🇦🇲'),

  /// Azerbaijani
  azerbaijani('az', 'Azerbaijani', '🇦🇿'),

  /// Belarusian
  belarusian('be', 'Belarusian', '🇧🇾'),

  /// Bosnian
  bosnian('bs', 'Bosnian', '🇧🇦'),

  /// Georgian
  georgian('ka', 'Georgian', '🇬🇪'),

  /// Kazakh
  kazakh('kk', 'Kazakh', '🇰🇿'),

  /// Macedonian
  macedonian('mk', 'Macedonian', '🇲🇰'),

  /// Serbian
  serbian('sr', 'Serbian', '🇷🇸'),

  /// Uzbek
  uzbek('uz', 'Uzbek', '🇺🇿');

  const TranscriptionLanguage(this.code, this.displayName, this.flag);

  /// ISO 639-1 language code
  final String code;

  /// Human-readable display name
  final String displayName;

  /// Flag emoji for the language
  final String flag;

  /// Find language by ISO code
  static TranscriptionLanguage? fromCode(String code) {
    for (final language in TranscriptionLanguage.values) {
      if (language.code.toLowerCase() == code.toLowerCase()) {
        return language;
      }
    }
    return null;
  }

  /// Get all supported language codes
  static List<String> get supportedCodes {
    return TranscriptionLanguage.values
        .where((lang) => lang != TranscriptionLanguage.auto)
        .map((lang) => lang.code)
        .toList();
  }

  /// Get commonly used languages (most popular ones)
  static List<TranscriptionLanguage> get commonLanguages {
    return [
      TranscriptionLanguage.auto,
      TranscriptionLanguage.english,
      TranscriptionLanguage.spanish,
      TranscriptionLanguage.french,
      TranscriptionLanguage.german,
      TranscriptionLanguage.italian,
      TranscriptionLanguage.portuguese,
      TranscriptionLanguage.russian,
      TranscriptionLanguage.japanese,
      TranscriptionLanguage.korean,
      TranscriptionLanguage.chineseSimplified,
      TranscriptionLanguage.arabic,
      TranscriptionLanguage.hindi,
    ];
  }

  @override
  String toString() => '$flag $displayName';
}
