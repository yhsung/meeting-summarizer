import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/database/recording.dart';
import '../models/database/transcription.dart';
import '../models/database/summary.dart';
import '../models/database/app_settings.dart';
import 'data_anonymization_service.dart';
import 'privacy_control_service.dart';

enum ExportFormat { json, csv, xml, txt }

class GDPRExportConfig {
  final List<String> includedDataTypes;
  final ExportFormat format;
  final bool includeFiles;
  final bool includeAnonymizedData;
  final bool includeMetadata;
  final bool anonymizeExport;
  final String? customPath;

  const GDPRExportConfig({
    required this.includedDataTypes,
    this.format = ExportFormat.json,
    this.includeFiles = false,
    this.includeAnonymizedData = false,
    this.includeMetadata = true,
    this.anonymizeExport = false,
    this.customPath,
  });

  static GDPRExportConfig get completeExport => const GDPRExportConfig(
    includedDataTypes: [
      'recordings',
      'transcriptions',
      'summaries',
      'settings',
      'privacy_data',
      'audit_log',
    ],
    format: ExportFormat.json,
    includeFiles: true,
    includeAnonymizedData: true,
    includeMetadata: true,
  );

  static GDPRExportConfig get minimalExport => const GDPRExportConfig(
    includedDataTypes: ['privacy_data', 'settings'],
    format: ExportFormat.json,
    includeFiles: false,
    includeAnonymizedData: false,
    includeMetadata: false,
  );
}

class GDPRExportResult {
  final String exportId;
  final String exportPath;
  final Map<String, dynamic> metadata;
  final List<String> exportedFiles;
  final DateTime exportedAt;
  final int totalRecords;
  final int totalFiles;
  final int exportSizeBytes;

  const GDPRExportResult({
    required this.exportId,
    required this.exportPath,
    required this.metadata,
    required this.exportedFiles,
    required this.exportedAt,
    required this.totalRecords,
    required this.totalFiles,
    required this.exportSizeBytes,
  });

  Map<String, dynamic> toJson() {
    return {
      'exportId': exportId,
      'exportPath': exportPath,
      'metadata': metadata,
      'exportedFiles': exportedFiles,
      'exportedAt': exportedAt.toIso8601String(),
      'totalRecords': totalRecords,
      'totalFiles': totalFiles,
      'exportSizeBytes': exportSizeBytes,
    };
  }
}

class DatabaseQueryService {
  final Database database;

  const DatabaseQueryService(this.database);

  Future<List<Recording>> getAllRecordings() async {
    final maps = await database.query(
      'recordings',
      where: 'is_deleted = ?',
      whereArgs: [0],
    );
    return maps.map((map) => Recording.fromDatabase(map)).toList();
  }

  Future<List<Transcription>> getAllTranscriptions() async {
    final maps = await database.query('transcriptions');
    return maps.map((map) => Transcription.fromDatabase(map)).toList();
  }

  Future<List<Summary>> getAllSummaries() async {
    final maps = await database.query('summaries');
    return maps.map((map) => Summary.fromDatabase(map)).toList();
  }

  Future<List<AppSettings>> getAllSettings() async {
    final maps = await database.query('app_settings');
    return maps.map((map) => AppSettings.fromDatabase(map)).toList();
  }

  Future<Map<String, dynamic>> getDatabaseStats() async {
    final recordingsCount =
        Sqflite.firstIntValue(
          await database.rawQuery(
            'SELECT COUNT(*) FROM recordings WHERE is_deleted = 0',
          ),
        ) ??
        0;

    final transcriptionsCount =
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM transcriptions'),
        ) ??
        0;

    final summariesCount =
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM summaries'),
        ) ??
        0;

    return {
      'totalRecordings': recordingsCount,
      'totalTranscriptions': transcriptionsCount,
      'totalSummaries': summariesCount,
      'databasePath': database.path,
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }
}

class GDPRExportService {
  final DataAnonymizationService _anonymizationService;
  final PrivacyControlService _privacyService;
  final DatabaseQueryService _dbService;

  GDPRExportService._(
    this._anonymizationService,
    this._privacyService,
    this._dbService,
  );

  static GDPRExportService? _instance;

  static Future<GDPRExportService> getInstance(Database database) async {
    if (_instance != null) return _instance!;

    final anonymizationService = await DataAnonymizationService.getInstance();
    final privacyService = await PrivacyControlService.getInstance();
    final dbService = DatabaseQueryService(database);

    _instance = GDPRExportService._(
      anonymizationService,
      privacyService,
      dbService,
    );
    return _instance!;
  }

  Future<GDPRExportResult> exportUserData(GDPRExportConfig config) async {
    developer.log(
      'Starting GDPR export with config: ${config.includedDataTypes}',
      name: 'GDPRExportService',
    );

    final exportId = DateTime.now().millisecondsSinceEpoch.toString();
    final exportDir = await _createExportDirectory(exportId);

    final exportData = <String, dynamic>{};
    final exportedFiles = <String>[];
    var totalRecords = 0;
    var totalFiles = 0;

    // Export privacy and anonymization data
    if (config.includedDataTypes.contains('privacy_data')) {
      exportData['privacy_data'] = await _exportPrivacyData();
      totalRecords += 1;
    }

    // Export database records
    if (config.includedDataTypes.contains('recordings')) {
      final recordings = await _dbService.getAllRecordings();
      exportData['recordings'] = await _processRecordings(recordings, config);
      totalRecords += recordings.length;

      if (config.includeFiles) {
        final audioFiles = await _copyAudioFiles(recordings, exportDir);
        exportedFiles.addAll(audioFiles);
        totalFiles += audioFiles.length;
      }
    }

    if (config.includedDataTypes.contains('transcriptions')) {
      final transcriptions = await _dbService.getAllTranscriptions();
      exportData['transcriptions'] = await _processTranscriptions(
        transcriptions,
        config,
      );
      totalRecords += transcriptions.length;
    }

    if (config.includedDataTypes.contains('summaries')) {
      final summaries = await _dbService.getAllSummaries();
      exportData['summaries'] = await _processSummaries(summaries, config);
      totalRecords += summaries.length;
    }

    if (config.includedDataTypes.contains('settings')) {
      final settings = await _dbService.getAllSettings();
      exportData['settings'] = await _processSettings(settings, config);
      totalRecords += settings.length;
    }

    // Export metadata
    if (config.includeMetadata) {
      exportData['metadata'] = await _generateExportMetadata(config, exportId);
      exportData['database_stats'] = await _dbService.getDatabaseStats();
    }

    // Export anonymized data if requested
    if (config.includeAnonymizedData) {
      final anonymizedData = await _privacyService.requestDataExport(
        includeAnonymizedData: true,
      );
      exportData['anonymized_data'] = anonymizedData.anonymizedData
          .map((data) => data.toJson())
          .toList();
      totalRecords += anonymizedData.anonymizedData.length;
    }

    // Export audit log
    if (config.includedDataTypes.contains('audit_log')) {
      exportData['audit_log'] = _privacyService.auditLog
          .map((event) => event.toJson())
          .toList();
      totalRecords += _privacyService.auditLog.length;
    }

    // Write export file
    final exportFile = await _writeExportFile(
      exportData,
      exportDir,
      config.format,
    );
    exportedFiles.add(exportFile);

    // Calculate total export size
    final exportSize = await _calculateExportSize(exportDir);

    developer.log(
      'GDPR export completed: $totalRecords records, $totalFiles files',
      name: 'GDPRExportService',
    );

    return GDPRExportResult(
      exportId: exportId,
      exportPath: exportDir.path,
      metadata: exportData['metadata'] ?? {},
      exportedFiles: exportedFiles,
      exportedAt: DateTime.now(),
      totalRecords: totalRecords,
      totalFiles: totalFiles,
      exportSizeBytes: exportSize,
    );
  }

  Future<Directory> _createExportDirectory(String exportId) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(
      '${documentsDir.path}/gdpr_exports/export_$exportId',
    );

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    return exportDir;
  }

  Future<Map<String, dynamic>> _exportPrivacyData() async {
    final dashboardData = _privacyService.getPrivacyDashboardData();

    return {
      'privacy_settings': dashboardData['settings'],
      'anonymous_user_id': _anonymizationService.anonymousUserId,
      'privacy_validation': dashboardData['validation'],
      'privacy_stats': dashboardData['stats'],
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> _processRecordings(
    List<Recording> recordings,
    GDPRExportConfig config,
  ) async {
    final processedRecordings = <Map<String, dynamic>>[];

    for (final recording in recordings) {
      var recordingData = recording.toJson();

      if (config.anonymizeExport) {
        final anonymized = _anonymizationService.anonymizeData(
          recordingData,
          sensitiveFields: ['location', 'title', 'description', 'metadata'],
        );
        recordingData = anonymized.data;
      }

      // Remove file paths for privacy if not including files
      if (!config.includeFiles) {
        recordingData.remove('filePath');
        recordingData['note'] =
            'File path removed for privacy - files not included in export';
      }

      processedRecordings.add(recordingData);
    }

    return processedRecordings;
  }

  Future<List<Map<String, dynamic>>> _processTranscriptions(
    List<Transcription> transcriptions,
    GDPRExportConfig config,
  ) async {
    final processedTranscriptions = <Map<String, dynamic>>[];

    for (final transcription in transcriptions) {
      var transcriptionData = transcription.toJson();

      if (config.anonymizeExport) {
        // For transcriptions, we might want to anonymize the text content
        final anonymized = _anonymizationService.anonymizeData(
          transcriptionData,
          sensitiveFields: ['text'], // Anonymize transcription text
        );
        transcriptionData = anonymized.data;
        transcriptionData['anonymization_note'] =
            'Transcription text has been anonymized';
      }

      processedTranscriptions.add(transcriptionData);
    }

    return processedTranscriptions;
  }

  Future<List<Map<String, dynamic>>> _processSummaries(
    List<Summary> summaries,
    GDPRExportConfig config,
  ) async {
    final processedSummaries = <Map<String, dynamic>>[];

    for (final summary in summaries) {
      var summaryData = summary.toJson();

      if (config.anonymizeExport) {
        final anonymized = _anonymizationService.anonymizeData(
          summaryData,
          sensitiveFields: ['content', 'metadata'],
        );
        summaryData = anonymized.data;
      }

      processedSummaries.add(summaryData);
    }

    return processedSummaries;
  }

  Future<List<Map<String, dynamic>>> _processSettings(
    List<AppSettings> settings,
    GDPRExportConfig config,
  ) async {
    final processedSettings = <Map<String, dynamic>>[];

    for (final setting in settings) {
      var settingData = setting.toJson();

      // Always anonymize sensitive settings like API keys
      if (settingData['key']?.toString().toLowerCase().contains('key') ==
              true ||
          settingData['key']?.toString().toLowerCase().contains('token') ==
              true) {
        settingData['value'] = '[REDACTED_FOR_PRIVACY]';
        settingData['privacy_note'] = 'Sensitive value redacted for security';
      }

      processedSettings.add(settingData);
    }

    return processedSettings;
  }

  Future<List<String>> _copyAudioFiles(
    List<Recording> recordings,
    Directory exportDir,
  ) async {
    final audioDir = Directory('${exportDir.path}/audio_files');
    if (!await audioDir.exists()) {
      await audioDir.create();
    }

    final copiedFiles = <String>[];

    for (final recording in recordings) {
      try {
        final sourceFile = File(recording.filePath);
        if (await sourceFile.exists()) {
          final targetFile = File('${audioDir.path}/${recording.filename}');
          await sourceFile.copy(targetFile.path);
          copiedFiles.add(targetFile.path);

          developer.log(
            'Copied audio file: ${recording.filename}',
            name: 'GDPRExportService',
          );
        }
      } catch (e) {
        developer.log(
          'Failed to copy audio file ${recording.filename}: $e',
          name: 'GDPRExportService',
        );
      }
    }

    return copiedFiles;
  }

  Future<Map<String, dynamic>> _generateExportMetadata(
    GDPRExportConfig config,
    String exportId,
  ) async {
    return {
      'export_id': exportId,
      'export_type': 'GDPR Data Export',
      'export_version': '1.0.0',
      'generated_at': DateTime.now().toIso8601String(),
      'config': {
        'included_data_types': config.includedDataTypes,
        'format': config.format.name,
        'include_files': config.includeFiles,
        'include_anonymized_data': config.includeAnonymizedData,
        'include_metadata': config.includeMetadata,
        'anonymize_export': config.anonymizeExport,
      },
      'legal_notice': {
        'purpose': 'GDPR Article 20 - Right to Data Portability',
        'data_controller': 'Meeting Summarizer App',
        'export_scope': 'All personal data processed by the application',
        'retention_info': 'This export contains data as of the export date',
        'contact': 'For questions about this export, contact app support',
      },
      'technical_info': {
        'app_version': '1.0.0', // This would come from app metadata
        'anonymous_user_id': _anonymizationService.anonymousUserId,
        'export_format': config.format.name,
        'compression': 'none',
        'encryption': 'none',
      },
    };
  }

  Future<String> _writeExportFile(
    Map<String, dynamic> exportData,
    Directory exportDir,
    ExportFormat format,
  ) async {
    final filename = 'gdpr_export.${format.name}';
    final file = File('${exportDir.path}/$filename');

    String content;
    switch (format) {
      case ExportFormat.json:
        content = const JsonEncoder.withIndent('  ').convert(exportData);
        break;
      case ExportFormat.csv:
        content = _convertToCSV(exportData);
        break;
      case ExportFormat.xml:
        content = _convertToXML(exportData);
        break;
      case ExportFormat.txt:
        content = _convertToText(exportData);
        break;
    }

    await file.writeAsString(content);
    developer.log('Export file written: $filename', name: 'GDPRExportService');

    return file.path;
  }

  String _convertToCSV(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('Section,Key,Value,Type');

    void processMap(Map<String, dynamic> map, String section) {
      for (final entry in map.entries) {
        final key = entry.key;
        final value = entry.value;
        final type = value.runtimeType.toString();

        if (value is Map) {
          processMap(value as Map<String, dynamic>, '$section.$key');
        } else if (value is List) {
          buffer.writeln('$section,$key,"${value.join('; ')}",$type');
        } else {
          final valueStr = value.toString().replaceAll('"', '""');
          buffer.writeln('$section,$key,"$valueStr",$type');
        }
      }
    }

    processMap(data, 'root');
    return buffer.toString();
  }

  String _convertToXML(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gdpr_export>');

    void writeXML(dynamic value, String tag, int indent) {
      final indentStr = '  ' * indent;

      if (value is Map) {
        buffer.writeln('$indentStr<$tag>');
        for (final entry in value.entries) {
          writeXML(entry.value, entry.key, indent + 1);
        }
        buffer.writeln('$indentStr</$tag>');
      } else if (value is List) {
        buffer.writeln('$indentStr<$tag>');
        for (int i = 0; i < value.length; i++) {
          writeXML(value[i], 'item', indent + 1);
        }
        buffer.writeln('$indentStr</$tag>');
      } else {
        final escapedValue = value
            .toString()
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        buffer.writeln('$indentStr<$tag>$escapedValue</$tag>');
      }
    }

    for (final entry in data.entries) {
      writeXML(entry.value, entry.key, 1);
    }

    buffer.writeln('</gdpr_export>');
    return buffer.toString();
  }

  String _convertToText(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('GDPR DATA EXPORT');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    void writeText(dynamic value, String key, int indent) {
      final indentStr = '  ' * indent;

      if (value is Map) {
        buffer.writeln('$indentStr$key:');
        for (final entry in value.entries) {
          writeText(entry.value, entry.key, indent + 1);
        }
      } else if (value is List) {
        buffer.writeln('$indentStr$key: [${value.length} items]');
        for (int i = 0; i < value.length; i++) {
          writeText(value[i], 'Item ${i + 1}', indent + 1);
        }
      } else {
        buffer.writeln('$indentStr$key: $value');
      }
    }

    for (final entry in data.entries) {
      writeText(entry.value, entry.key, 0);
      buffer.writeln();
    }

    return buffer.toString();
  }

  Future<int> _calculateExportSize(Directory exportDir) async {
    var totalSize = 0;

    await for (final entity in exportDir.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        totalSize += stat.size;
      }
    }

    return totalSize;
  }

  Future<bool> deleteExport(String exportId) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory(
        '${documentsDir.path}/gdpr_exports/export_$exportId',
      );

      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
        developer.log('Export deleted: $exportId', name: 'GDPRExportService');
        return true;
      }

      return false;
    } catch (e) {
      developer.log(
        'Failed to delete export $exportId: $e',
        name: 'GDPRExportService',
      );
      return false;
    }
  }

  Future<List<String>> listExports() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final exportsDir = Directory('${documentsDir.path}/gdpr_exports');

      if (!await exportsDir.exists()) {
        return [];
      }

      final exports = <String>[];
      await for (final entity in exportsDir.list()) {
        if (entity is Directory) {
          final dirName = entity.path.split('/').last;
          if (dirName.startsWith('export_')) {
            exports.add(dirName.substring(7)); // Remove 'export_' prefix
          }
        }
      }

      return exports;
    } catch (e) {
      developer.log('Failed to list exports: $e', name: 'GDPRExportService');
      return [];
    }
  }
}
