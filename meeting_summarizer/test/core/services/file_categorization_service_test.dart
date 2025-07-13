import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/models/storage/file_category.dart';
import 'package:meeting_summarizer/core/models/storage/file_metadata.dart';
import 'package:meeting_summarizer/core/services/file_categorization_service.dart';

void main() {
  group('FileCategorizationService', () {
    group('categorizeFile', () {
      test('should categorize audio files as recordings', () {
        expect(
          FileCategorizationService.categorizeFile('/path/to/audio.wav'),
          FileCategory.recordings,
        );
        expect(
          FileCategorizationService.categorizeFile('/path/to/audio.mp3'),
          FileCategory.recordings,
        );
        expect(
          FileCategorizationService.categorizeFile('/path/to/audio.aac'),
          FileCategory.recordings,
        );
      });

      test('should categorize enhanced audio files correctly', () {
        expect(
          FileCategorizationService.categorizeFile(
            '/path/to/enhanced_audio.wav',
          ),
          FileCategory.enhancedAudio,
        );
        expect(
          FileCategorizationService.categorizeFile(
            '/path/to/processed_recording.mp3',
          ),
          FileCategory.enhancedAudio,
        );
      });

      test('should categorize transcription files', () {
        expect(
          FileCategorizationService.categorizeFile(
            '/path/to/transcription.txt',
          ),
          FileCategory.transcriptions,
        );
        expect(
          FileCategorizationService.categorizeFile(
            '/path/to/transcript_file.md',
          ),
          FileCategory.transcriptions,
        );
      });

      test('should categorize summary files', () {
        expect(
          FileCategorizationService.categorizeFile('/path/to/summary.md'),
          FileCategory.summaries,
        );
        expect(
          FileCategorizationService.categorizeFile('/path/to/report_final.pdf'),
          FileCategory.summaries,
        );
      });

      test('should categorize export files', () {
        expect(
          FileCategorizationService.categorizeFile('/path/to/export_data.pdf'),
          FileCategory.exports,
        );
        expect(
          FileCategorizationService.categorizeFile('/path/to/shared_file.docx'),
          FileCategory.exports,
        );
      });

      test('should categorize cache files', () {
        expect(
          FileCategorizationService.categorizeFile('/path/to/cache_data.json'),
          FileCategory.cache,
        );
        expect(
          FileCategorizationService.categorizeFile('/path/to/temp_file.tmp'),
          FileCategory.cache,
        );
      });

      test('should use content for categorization when provided', () {
        const transcriptContent = 'Speaker 1: Hello, this is a transcript...';
        expect(
          FileCategorizationService.categorizeFile(
            '/path/to/unknown.txt',
            content: transcriptContent,
          ),
          FileCategory.transcriptions,
        );

        const summaryContent =
            'Summary: This meeting concluded with... conclusion reached';
        expect(
          FileCategorizationService.categorizeFile(
            '/path/to/unknown.doc', // Use extension not in the mapping
            content: summaryContent,
          ),
          FileCategory.summaries,
        );
      });
    });

    group('generateAutoTags', () {
      test('should generate appropriate tags for audio files', () {
        final tags = FileCategorizationService.generateAutoTags(
          '/path/to/high_quality_recording.wav',
          FileCategory.recordings,
        );

        expect(tags, contains('wav'));
        expect(tags, contains('high-quality'));
        expect(tags, contains('audio'));
        expect(tags, contains('recording'));
      });

      test('should generate year and month tags', () {
        final tags = FileCategorizationService.generateAutoTags(
          '/path/to/test.wav',
          FileCategory.recordings,
        );

        final now = DateTime.now();
        expect(tags, contains(now.year.toString()));
        expect(
          tags,
          contains('${now.year}-${now.month.toString().padLeft(2, '0')}'),
        );
      });

      test('should generate processing-related tags', () {
        final tags = FileCategorizationService.generateAutoTags(
          '/path/to/noise-reduced_enhanced_file.wav',
          FileCategory.enhancedAudio,
        );

        expect(tags, contains('noise-reduced'));
        expect(tags, contains('enhanced'));
      });

      test('should include custom metadata tags', () {
        final tags = FileCategorizationService.generateAutoTags(
          '/path/to/test.wav',
          FileCategory.recordings,
          customMetadata: {'quality': 'high', 'duration': '120'},
        );

        expect(tags, contains('quality-high'));
        expect(tags, contains('duration'));
      });
    });

    group('validateTags', () {
      test('should remove invalid tags', () {
        final validTags = FileCategorizationService.validateTags([
          'valid-tag',
          '',
          'a', // too short
          'tag with spaces', // invalid characters
          'valid_tag',
          'file', // generic tag
          'valid-tag', // duplicate
        ]);

        expect(validTags, containsAll(['valid-tag', 'valid_tag']));
        expect(validTags, hasLength(2));
      });

      test('should convert tags to lowercase', () {
        final validTags = FileCategorizationService.validateTags([
          'UPPERCASE',
          'MixedCase',
          'lowercase',
        ]);

        expect(validTags, containsAll(['uppercase', 'mixedcase', 'lowercase']));
      });

      test('should remove duplicate tags', () {
        final validTags = FileCategorizationService.validateTags([
          'tag1',
          'tag2',
          'tag1',
          'TAG1',
          'tag3',
        ]);

        expect(validTags, containsAll(['tag1', 'tag2', 'tag3']));
        expect(validTags, hasLength(3));
      });
    });

    group('suggestTags', () {
      test('should suggest tags based on similar files', () {
        final existingFiles = [
          FileMetadata(
            id: '1',
            fileName: 'meeting_recording_1.wav',
            filePath: '/path/to/meeting_recording_1.wav',
            relativePath: 'recordings/meeting_recording_1.wav',
            category: FileCategory.recordings,
            fileSize: 1000,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            tags: ['meeting', 'audio', 'important'],
          ),
          FileMetadata(
            id: '2',
            fileName: 'meeting_recording_2.wav',
            filePath: '/path/to/meeting_recording_2.wav',
            relativePath: 'recordings/meeting_recording_2.wav',
            category: FileCategory.recordings,
            fileSize: 1200,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            tags: ['meeting', 'audio', 'quarterly'],
          ),
        ];

        final suggestions = FileCategorizationService.suggestTags(
          'meeting_recording_3.wav',
          existingFiles,
        );

        expect(suggestions, contains('meeting'));
        expect(suggestions, contains('audio'));
      });

      test('should suggest content-based tags', () {
        const content =
            'quarterly quarterly meeting meeting discussion budget budget';

        final suggestions = FileCategorizationService.suggestTags(
          'test.txt',
          [],
          content: content,
        );

        expect(suggestions, contains('quarterly'));
        expect(suggestions, contains('meeting'));
        expect(suggestions, contains('budget'));
      });
    });

    group('getSearchSuggestions', () {
      test('should provide popular tags as suggestions', () {
        final files = List.generate(
          5,
          (i) => FileMetadata(
            id: '$i',
            fileName: 'file_$i.wav',
            filePath: '/path/to/file_$i.wav',
            relativePath: 'recordings/file_$i.wav',
            category: FileCategory.recordings,
            fileSize: 1000,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            tags: ['popular-tag', 'audio', 'recording'],
          ),
        );

        final suggestions = FileCategorizationService.getSearchSuggestions(
          files,
        );

        expect(suggestions, contains('popular-tag'));
        expect(suggestions, contains('audio'));
        expect(suggestions, contains('recording'));
      });

      test('should include category names in suggestions', () {
        final suggestions = FileCategorizationService.getSearchSuggestions([]);

        expect(suggestions, contains('audio recordings'));
        expect(suggestions, contains('transcriptions'));
        expect(suggestions, contains('summaries'));
      });

      test('should include time-based suggestions', () {
        final suggestions = FileCategorizationService.getSearchSuggestions([]);

        expect(suggestions, contains('today'));
        expect(suggestions, contains('this week'));
        expect(suggestions, contains('this month'));
        expect(suggestions, contains(DateTime.now().year.toString()));
      });

      test('should filter suggestions by current query', () {
        final files = List.generate(
          5,
          (i) => FileMetadata(
            id: '$i',
            fileName: 'meeting_file_$i.wav',
            filePath: '/path/to/meeting_file_$i.wav',
            relativePath: 'recordings/meeting_file_$i.wav',
            category: FileCategory.recordings,
            fileSize: 1000,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            tags: ['meeting', 'audio', 'quarterly'],
          ),
        );

        final suggestions = FileCategorizationService.getSearchSuggestions(
          files,
          currentQuery: 'recording',
        );

        // Should find suggestions that contain 'recording' (from category display names)
        expect(suggestions.any((s) => s.contains('recording')), true);
        // Test that filtering works by ensuring we get fewer results than without filter
        final allSuggestions = FileCategorizationService.getSearchSuggestions(
          files,
        );
        expect(suggestions.length, lessThan(allSuggestions.length));
      });
    });
  });
}
