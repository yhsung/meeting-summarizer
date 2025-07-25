#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Comprehensive code coverage analysis and reporting tool
///
/// Features:
/// - Parses LCOV coverage data
/// - Generates detailed analysis reports
/// - Tracks coverage trends over time
/// - Enforces quality gates
/// - Generates badges and visualizations
class CoverageAnalyzer {
  final String lcovPath;
  final String configPath;
  final String outputDir;

  late Map<String, dynamic> config;
  late CoverageData coverageData;

  CoverageAnalyzer({
    this.lcovPath = 'coverage/lcov.info',
    this.configPath = 'coverage_config.yaml',
    this.outputDir = 'coverage',
  });

  /// Main entry point for coverage analysis
  Future<void> analyze() async {
    try {
      print('🔍 Starting comprehensive coverage analysis...');

      await _loadConfiguration();
      await _parseLcovData();
      await _generateReports();
      await _enforceQualityGates();
      await _updateTrends();
      await _generateBadge();

      print('✅ Coverage analysis completed successfully!');
    } catch (e, stackTrace) {
      print('❌ Coverage analysis failed: $e');
      print('Stack trace: $stackTrace');
      exit(1);
    }
  }

  /// Load configuration from YAML file
  Future<void> _loadConfiguration() async {
    print('📋 Loading coverage configuration...');

    try {
      final configFile = File(configPath);
      if (!await configFile.exists()) {
        print('⚠️ Configuration file not found, using defaults');
        config = _getDefaultConfig();
        return;
      }

      final configContent = await configFile.readAsString();
      // Simple YAML-like parsing for our needs
      config = _parseYamlLike(configContent);

      print('✅ Configuration loaded successfully');
    } catch (e) {
      print('⚠️ Failed to load configuration, using defaults: $e');
      config = _getDefaultConfig();
    }
  }

  /// Parse LCOV coverage data
  Future<void> _parseLcovData() async {
    print('📊 Parsing LCOV coverage data...');

    final lcovFile = File(lcovPath);
    if (!await lcovFile.exists()) {
      throw Exception('LCOV file not found: $lcovPath');
    }

    final lcovContent = await lcovFile.readAsString();
    coverageData = LcovParser.parse(lcovContent);

    print('✅ Parsed coverage for ${coverageData.sourceFiles.length} files');
    print(
      '📈 Overall line coverage: ${coverageData.overallLineCoverage.toStringAsFixed(2)}%',
    );
    print(
      '🔄 Overall function coverage: ${coverageData.overallFunctionCoverage.toStringAsFixed(2)}%',
    );
    print(
      '🌿 Overall branch coverage: ${coverageData.overallBranchCoverage.toStringAsFixed(2)}%',
    );
  }

  /// Generate comprehensive coverage reports
  Future<void> _generateReports() async {
    print('📝 Generating coverage reports...');

    await _generateTextSummary();
    await _generateJsonReport();
    await _generateDetailedHtmlReport();
    await _generateLowCoverageReport();

    print('✅ All reports generated successfully');
  }

  /// Generate text summary report
  Future<void> _generateTextSummary() async {
    final buffer = StringBuffer();

    buffer.writeln('# Meeting Summarizer - Code Coverage Summary');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    // Overall statistics
    buffer.writeln('## Overall Coverage Statistics');
    buffer.writeln('| Metric | Coverage | Target | Status |');
    buffer.writeln('|--------|----------|--------|--------|');

    final lineCoverage = coverageData.overallLineCoverage;
    final functionCoverage = coverageData.overallFunctionCoverage;
    final branchCoverage = coverageData.overallBranchCoverage;

    final minThreshold = config['coverage']?['minimum_threshold'] ?? 80.0;
    final targetThreshold = config['coverage']?['target_threshold'] ?? 90.0;

    buffer.writeln(
      '| Lines | ${lineCoverage.toStringAsFixed(2)}% | ${targetThreshold.toStringAsFixed(1)}% | ${_getStatusEmoji(lineCoverage, minThreshold, targetThreshold)} |',
    );
    buffer.writeln(
      '| Functions | ${functionCoverage.toStringAsFixed(2)}% | ${targetThreshold.toStringAsFixed(1)}% | ${_getStatusEmoji(functionCoverage, minThreshold, targetThreshold)} |',
    );
    buffer.writeln(
      '| Branches | ${branchCoverage.toStringAsFixed(2)}% | ${targetThreshold.toStringAsFixed(1)}% | ${_getStatusEmoji(branchCoverage, minThreshold, targetThreshold)} |',
    );
    buffer.writeln('');

    // File-level coverage breakdown
    buffer.writeln('## File Coverage Breakdown');
    buffer.writeln('');

    // Sort files by coverage (lowest first)
    final sortedFiles = coverageData.sourceFiles.values.toList()
      ..sort((a, b) => a.lineCoverage.compareTo(b.lineCoverage));

    buffer.writeln('### Lowest Coverage Files (Bottom 10)');
    buffer.writeln('| File | Lines | Functions | Branches |');
    buffer.writeln('|------|-------|-----------|----------|');

    for (final file in sortedFiles.take(10)) {
      final relativePath = file.path.replaceFirst('lib/', '');
      buffer.writeln(
        '| `$relativePath` | ${file.lineCoverage.toStringAsFixed(1)}% | ${file.functionCoverage.toStringAsFixed(1)}% | ${file.branchCoverage.toStringAsFixed(1)}% |',
      );
    }

    buffer.writeln('');
    buffer.writeln('### Highest Coverage Files (Top 10)');
    buffer.writeln('| File | Lines | Functions | Branches |');
    buffer.writeln('|------|-------|-----------|----------|');

    for (final file in sortedFiles.reversed.take(10)) {
      final relativePath = file.path.replaceFirst('lib/', '');
      buffer.writeln(
        '| `$relativePath` | ${file.lineCoverage.toStringAsFixed(1)}% | ${file.functionCoverage.toStringAsFixed(1)}% | ${file.branchCoverage.toStringAsFixed(1)}% |',
      );
    }

    // Quality assessment
    buffer.writeln('');
    buffer.writeln('## Quality Assessment');

    final lowCoverageFiles = sortedFiles
        .where((f) => f.lineCoverage < 60)
        .length;
    final mediumCoverageFiles = sortedFiles
        .where((f) => f.lineCoverage >= 60 && f.lineCoverage < 80)
        .length;
    final highCoverageFiles = sortedFiles
        .where((f) => f.lineCoverage >= 80)
        .length;

    buffer.writeln('- 🔴 Low coverage files (<60%): $lowCoverageFiles');
    buffer.writeln('- 🟡 Medium coverage files (60-80%): $mediumCoverageFiles');
    buffer.writeln('- 🟢 High coverage files (≥80%): $highCoverageFiles');

    // Recommendations
    buffer.writeln('');
    buffer.writeln('## Recommendations');

    if (lineCoverage < minThreshold) {
      buffer.writeln(
        '- ⚠️ Overall line coverage is below minimum threshold (${minThreshold.toStringAsFixed(1)}%)',
      );
      buffer.writeln(
        '- 🎯 Focus on adding tests for files with lowest coverage first',
      );
    }

    if (lowCoverageFiles > 0) {
      buffer.writeln(
        '- 📝 Consider adding unit tests for $lowCoverageFiles files with low coverage',
      );
    }

    if (functionCoverage < 85) {
      buffer.writeln(
        '- 🔧 Function coverage could be improved - ensure all public methods have tests',
      );
    }

    if (branchCoverage < 75) {
      buffer.writeln(
        '- 🌿 Branch coverage needs attention - add tests for edge cases and error paths',
      );
    }

    // Write to file
    final summaryFile = File('$outputDir/coverage-summary.md');
    await summaryFile.writeAsString(buffer.toString());

    // Also write to console
    print(buffer.toString());
  }

  /// Generate JSON report for programmatic access
  Future<void> _generateJsonReport() async {
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'overall': {
        'line_coverage': coverageData.overallLineCoverage,
        'function_coverage': coverageData.overallFunctionCoverage,
        'branch_coverage': coverageData.overallBranchCoverage,
        'total_lines': coverageData.totalLines,
        'covered_lines': coverageData.coveredLines,
        'total_functions': coverageData.totalFunctions,
        'covered_functions': coverageData.coveredFunctions,
        'total_branches': coverageData.totalBranches,
        'covered_branches': coverageData.coveredBranches,
      },
      'files': coverageData.sourceFiles.values
          .map(
            (file) => {
              'path': file.path,
              'line_coverage': file.lineCoverage,
              'function_coverage': file.functionCoverage,
              'branch_coverage': file.branchCoverage,
              'lines_total': file.totalLines,
              'lines_covered': file.coveredLines,
              'functions_total': file.totalFunctions,
              'functions_covered': file.coveredFunctions,
              'branches_total': file.totalBranches,
              'branches_covered': file.coveredBranches,
            },
          )
          .toList(),
      'quality_gates': {
        'minimum_threshold': config['coverage']?['minimum_threshold'] ?? 80.0,
        'target_threshold': config['coverage']?['target_threshold'] ?? 90.0,
        'passes_minimum':
            coverageData.overallLineCoverage >=
            (config['coverage']?['minimum_threshold'] ?? 80.0),
        'passes_target':
            coverageData.overallLineCoverage >=
            (config['coverage']?['target_threshold'] ?? 90.0),
      },
    };

    final jsonFile = File('$outputDir/coverage.json');
    await jsonFile.writeAsString(JsonEncoder.withIndent('  ').convert(report));
  }

  /// Generate detailed HTML report with advanced visualizations
  Future<void> _generateDetailedHtmlReport() async {
    // This would typically use a template engine, but for simplicity we'll generate basic HTML
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('    <meta charset="UTF-8">');
    buffer.writeln(
      '    <meta name="viewport" content="width=device-width, initial-scale=1.0">',
    );
    buffer.writeln('    <title>Meeting Summarizer - Coverage Report</title>');
    buffer.writeln('    <style>');
    buffer.writeln(_getCssStyles());
    buffer.writeln('    </style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    buffer.writeln('    <header>');
    buffer.writeln(
      '        <h1>📊 Meeting Summarizer - Code Coverage Report</h1>',
    );
    buffer.writeln(
      '        <p>Generated: ${DateTime.now().toLocal().toString()}</p>',
    );
    buffer.writeln('    </header>');

    buffer.writeln('    <main>');

    // Overall metrics
    buffer.writeln('        <section class="metrics">');
    buffer.writeln('            <h2>Overall Coverage Metrics</h2>');
    buffer.writeln('            <div class="metric-cards">');
    buffer.writeln(
      '                ${_generateMetricCard("Lines", coverageData.overallLineCoverage, config['coverage']?['minimum_threshold'] ?? 80.0)}',
    );
    buffer.writeln(
      '                ${_generateMetricCard("Functions", coverageData.overallFunctionCoverage, config['coverage']?['quality_gates']?['function_coverage'] ?? 85.0)}',
    );
    buffer.writeln(
      '                ${_generateMetricCard("Branches", coverageData.overallBranchCoverage, config['coverage']?['quality_gates']?['branch_coverage'] ?? 75.0)}',
    );
    buffer.writeln('            </div>');
    buffer.writeln('        </section>');

    // File breakdown
    buffer.writeln('        <section class="file-breakdown">');
    buffer.writeln('            <h2>File Coverage Breakdown</h2>');
    buffer.writeln('            <table class="coverage-table">');
    buffer.writeln('                <thead>');
    buffer.writeln('                    <tr>');
    buffer.writeln('                        <th>File</th>');
    buffer.writeln('                        <th>Lines</th>');
    buffer.writeln('                        <th>Functions</th>');
    buffer.writeln('                        <th>Branches</th>');
    buffer.writeln('                        <th>Overall</th>');
    buffer.writeln('                    </tr>');
    buffer.writeln('                </thead>');
    buffer.writeln('                <tbody>');

    final sortedFiles = coverageData.sourceFiles.values.toList()
      ..sort((a, b) => a.lineCoverage.compareTo(b.lineCoverage));

    for (final file in sortedFiles) {
      final relativePath = file.path.replaceFirst('lib/', '');
      final overallCoverage =
          (file.lineCoverage + file.functionCoverage + file.branchCoverage) / 3;

      buffer.writeln(
        '                    <tr class="${_getCoverageClass(file.lineCoverage)}">',
      );
      buffer.writeln(
        '                        <td><code>$relativePath</code></td>',
      );
      buffer.writeln(
        '                        <td>${_formatCoverageCell(file.lineCoverage)}</td>',
      );
      buffer.writeln(
        '                        <td>${_formatCoverageCell(file.functionCoverage)}</td>',
      );
      buffer.writeln(
        '                        <td>${_formatCoverageCell(file.branchCoverage)}</td>',
      );
      buffer.writeln(
        '                        <td>${_formatCoverageCell(overallCoverage)}</td>',
      );
      buffer.writeln('                    </tr>');
    }

    buffer.writeln('                </tbody>');
    buffer.writeln('            </table>');
    buffer.writeln('        </section>');

    buffer.writeln('    </main>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    final htmlFile = File('$outputDir/detailed-coverage.html');
    await htmlFile.writeAsString(buffer.toString());
  }

  /// Generate report for files with low coverage
  Future<void> _generateLowCoverageReport() async {
    final lowCoverageThreshold =
        config['analysis']?['low_coverage_threshold'] ?? 60.0;
    final lowCoverageFiles =
        coverageData.sourceFiles.values
            .where((file) => file.lineCoverage < lowCoverageThreshold)
            .toList()
          ..sort((a, b) => a.lineCoverage.compareTo(b.lineCoverage));

    if (lowCoverageFiles.isEmpty) {
      print('🎉 No files with low coverage found!');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('# Low Coverage Files Report');
    buffer.writeln('');
    buffer.writeln(
      'Files with coverage below ${lowCoverageThreshold.toStringAsFixed(1)}%:',
    );
    buffer.writeln('');

    for (final file in lowCoverageFiles) {
      buffer.writeln('## ${file.path}');
      buffer.writeln(
        '- **Line Coverage**: ${file.lineCoverage.toStringAsFixed(2)}%',
      );
      buffer.writeln(
        '- **Function Coverage**: ${file.functionCoverage.toStringAsFixed(2)}%',
      );
      buffer.writeln(
        '- **Branch Coverage**: ${file.branchCoverage.toStringAsFixed(2)}%',
      );
      buffer.writeln(
        '- **Priority**: ${file.lineCoverage < 30
            ? 'HIGH'
            : file.lineCoverage < 50
            ? 'MEDIUM'
            : 'LOW'}',
      );
      buffer.writeln('');

      // Suggest testing strategies
      buffer.writeln('### Recommended Testing Strategy:');
      if (file.functionCoverage < 50) {
        buffer.writeln('- Add unit tests for public methods');
      }
      if (file.branchCoverage < 50) {
        buffer.writeln('- Add tests for conditional logic and edge cases');
      }
      if (file.lineCoverage < 30) {
        buffer.writeln(
          '- This file is critically under-tested - consider comprehensive test suite',
        );
      }
      buffer.writeln('');
    }

    final lowCoverageFile = File('$outputDir/low-coverage-report.md');
    await lowCoverageFile.writeAsString(buffer.toString());

    print(
      '📋 Generated low coverage report for ${lowCoverageFiles.length} files',
    );
  }

  /// Enforce quality gates and fail if thresholds not met
  Future<void> _enforceQualityGates() async {
    print('🚪 Enforcing quality gates...');

    final enforceMinimum = config['coverage']?['enforce_minimum'] ?? true;
    if (!enforceMinimum) {
      print('⚠️ Quality gate enforcement is disabled');
      return;
    }

    final qualityGates = config['coverage']?['quality_gates'] ?? {};
    final minLineCoverage = qualityGates['line_coverage'] ?? 80.0;
    final minFunctionCoverage = qualityGates['function_coverage'] ?? 85.0;
    final minBranchCoverage = qualityGates['branch_coverage'] ?? 75.0;

    final violations = <String>[];

    if (coverageData.overallLineCoverage < minLineCoverage) {
      violations.add(
        'Line coverage ${coverageData.overallLineCoverage.toStringAsFixed(2)}% is below minimum ${minLineCoverage.toStringAsFixed(1)}%',
      );
    }

    if (coverageData.overallFunctionCoverage < minFunctionCoverage) {
      violations.add(
        'Function coverage ${coverageData.overallFunctionCoverage.toStringAsFixed(2)}% is below minimum ${minFunctionCoverage.toStringAsFixed(1)}%',
      );
    }

    if (coverageData.overallBranchCoverage < minBranchCoverage) {
      violations.add(
        'Branch coverage ${coverageData.overallBranchCoverage.toStringAsFixed(2)}% is below minimum ${minBranchCoverage.toStringAsFixed(1)}%',
      );
    }

    if (violations.isNotEmpty) {
      print('❌ Quality gate violations:');
      for (final violation in violations) {
        print('  - $violation');
      }

      if (config['integration']?['ci_mode'] == true) {
        print('🚨 Failing build due to quality gate violations');
        exit(1);
      }
    } else {
      print('✅ All quality gates passed!');
    }
  }

  /// Update coverage trends over time
  Future<void> _updateTrends() async {
    if (config['analysis']?['track_trends'] != true) {
      return;
    }

    print('📈 Updating coverage trends...');

    final trendsFile = File(
      config['analysis']?['trends_file'] ?? 'coverage/trends.json',
    );
    List<dynamic> trends = [];

    if (await trendsFile.exists()) {
      final trendsContent = await trendsFile.readAsString();
      trends = json.decode(trendsContent);
    }

    final trendEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'line_coverage': coverageData.overallLineCoverage,
      'function_coverage': coverageData.overallFunctionCoverage,
      'branch_coverage': coverageData.overallBranchCoverage,
      'total_files': coverageData.sourceFiles.length,
      'git_commit': await _getGitCommit(),
    };

    trends.add(trendEntry);

    // Keep only last 100 entries
    if (trends.length > 100) {
      trends = trends.sublist(trends.length - 100);
    }

    await trendsFile.writeAsString(
      JsonEncoder.withIndent('  ').convert(trends),
    );

    // Check for coverage decrease
    if (trends.length > 1 &&
        config['integration']?['fail_on_decrease'] == true) {
      final previousCoverage = trends[trends.length - 2]['line_coverage'];
      final currentCoverage = coverageData.overallLineCoverage;
      final decreaseThreshold =
          config['integration']?['decrease_threshold'] ?? 5.0;

      if (currentCoverage < previousCoverage - decreaseThreshold) {
        print(
          '❌ Coverage decreased by ${(previousCoverage - currentCoverage).toStringAsFixed(2)}% (threshold: ${decreaseThreshold.toStringAsFixed(1)}%)',
        );
        if (config['integration']?['ci_mode'] == true) {
          exit(1);
        }
      }
    }

    print('✅ Coverage trends updated');
  }

  /// Generate coverage badge SVG
  Future<void> _generateBadge() async {
    if (config['reporting']?['badge']?['enabled'] != true) {
      return;
    }

    print('🏷️ Generating coverage badge...');

    final coverage = coverageData.overallLineCoverage;
    final color = coverage >= 90
        ? 'brightgreen'
        : coverage >= 80
        ? 'green'
        : coverage >= 70
        ? 'yellow'
        : coverage >= 60
        ? 'orange'
        : 'red';

    final badgeText = '${coverage.toStringAsFixed(1)}%';

    final svg =
        '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="104" height="20">
  <linearGradient id="b" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="a">
    <rect width="104" height="20" rx="3" fill="#fff"/>
  </clipPath>
  <g clip-path="url(#a)">
    <path fill="#555" d="M0 0h63v20H0z"/>
    <path fill="$color" d="M63 0h41v20H63z"/>
    <path fill="url(#b)" d="M0 0h104v20H0z"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="110">
    <text x="325" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="530">coverage</text>
    <text x="325" y="140" transform="scale(.1)" textLength="530">coverage</text>
    <text x="825" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="310">$badgeText</text>
    <text x="825" y="140" transform="scale(.1)" textLength="310">$badgeText</text>
  </g>
</svg>''';

    final badgeFile = File(
      config['reporting']?['badge']?['output_file'] ??
          'coverage/coverage-badge.svg',
    );
    await badgeFile.writeAsString(svg);

    print('✅ Coverage badge generated');
  }

  // Helper methods

  Map<String, dynamic> _getDefaultConfig() {
    return {
      'coverage': {
        'minimum_threshold': 80.0,
        'target_threshold': 90.0,
        'enforce_minimum': true,
        'quality_gates': {
          'line_coverage': 80,
          'function_coverage': 85,
          'branch_coverage': 75,
        },
      },
      'analysis': {'track_trends': true, 'low_coverage_threshold': 60.0},
      'reporting': {
        'badge': {'enabled': true},
      },
      'integration': {
        'ci_mode': Platform.environment.containsKey('CI'),
        'fail_on_decrease': true,
        'decrease_threshold': 5.0,
      },
    };
  }

  Map<String, dynamic> _parseYamlLike(String content) {
    // Simple YAML-like parser for our configuration
    // This is a simplified version - in production you'd use a proper YAML parser
    final lines = content.split('\n');
    final Map<String, dynamic> result = {};

    for (final line in lines) {
      if (line.trim().isEmpty || line.trim().startsWith('#')) continue;

      if (line.contains(':')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();

          if (value.isNotEmpty) {
            // Try to parse as number or boolean
            if (value == 'true') {
              result[key] = true;
            } else if (value == 'false') {
              result[key] = false;
            } else if (double.tryParse(value) != null) {
              result[key] = double.parse(value);
            } else {
              result[key] = value;
            }
          }
        }
      }
    }

    return result;
  }

  String _getStatusEmoji(double actual, double minimum, double target) {
    if (actual >= target) return '🟢 Excellent';
    if (actual >= minimum) return '🟡 Good';
    return '🔴 Needs Improvement';
  }

  String _getCoverageClass(double coverage) {
    if (coverage >= 90) return 'high-coverage';
    if (coverage >= 70) return 'medium-coverage';
    return 'low-coverage';
  }

  String _formatCoverageCell(double coverage) {
    return '<span class="${_getCoverageClass(coverage)}">${coverage.toStringAsFixed(1)}%</span>';
  }

  String _generateMetricCard(String title, double value, double threshold) {
    final status = value >= threshold ? 'good' : 'warning';
    return '''
                <div class="metric-card $status">
                    <h3>$title</h3>
                    <div class="metric-value">${value.toStringAsFixed(1)}%</div>
                    <div class="metric-threshold">Target: ${threshold.toStringAsFixed(1)}%</div>
                </div>''';
  }

  String _getCssStyles() {
    return '''
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        header { background: #fff; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { margin: 0; color: #333; }
        .metrics { background: #fff; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric-cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 20px; }
        .metric-card { padding: 20px; border-radius: 8px; text-align: center; }
        .metric-card.good { background: #d4edda; border: 1px solid #c3e6cb; }
        .metric-card.warning { background: #fff3cd; border: 1px solid #ffeaa7; }
        .metric-value { font-size: 2em; font-weight: bold; margin: 10px 0; }
        .file-breakdown { background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .coverage-table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        .coverage-table th, .coverage-table td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        .coverage-table th { background: #f8f9fa; font-weight: 600; }
        .high-coverage { background: #d4edda; }
        .medium-coverage { background: #fff3cd; }
        .low-coverage { background: #f8d7da; }
        code { background: #f1f3f4; padding: 2px 4px; border-radius: 3px; font-family: 'Monaco', 'Consolas', monospace; }
    ''';
  }

  Future<String> _getGitCommit() async {
    try {
      final result = await Process.run('git', ['rev-parse', 'HEAD']);
      return result.stdout.toString().trim();
    } catch (e) {
      return 'unknown';
    }
  }
}

/// Data classes for coverage information
class CoverageData {
  final Map<String, SourceFile> sourceFiles = {};

  int get totalLines =>
      sourceFiles.values.fold(0, (sum, file) => sum + file.totalLines);
  int get coveredLines =>
      sourceFiles.values.fold(0, (sum, file) => sum + file.coveredLines);
  double get overallLineCoverage =>
      totalLines > 0 ? (coveredLines / totalLines) * 100 : 0;

  int get totalFunctions =>
      sourceFiles.values.fold(0, (sum, file) => sum + file.totalFunctions);
  int get coveredFunctions =>
      sourceFiles.values.fold(0, (sum, file) => sum + file.coveredFunctions);
  double get overallFunctionCoverage =>
      totalFunctions > 0 ? (coveredFunctions / totalFunctions) * 100 : 0;

  int get totalBranches =>
      sourceFiles.values.fold(0, (sum, file) => sum + file.totalBranches);
  int get coveredBranches =>
      sourceFiles.values.fold(0, (sum, file) => sum + file.coveredBranches);
  double get overallBranchCoverage =>
      totalBranches > 0 ? (coveredBranches / totalBranches) * 100 : 0;
}

class SourceFile {
  final String path;
  final Map<int, int> lineHits = {};
  final Map<String, int> functionHits = {};
  final Map<int, BranchData> branchHits = {};

  SourceFile(this.path);

  int get totalLines => lineHits.length;
  int get coveredLines => lineHits.values.where((hits) => hits > 0).length;
  double get lineCoverage =>
      totalLines > 0 ? (coveredLines / totalLines) * 100 : 0;

  int get totalFunctions => functionHits.length;
  int get coveredFunctions =>
      functionHits.values.where((hits) => hits > 0).length;
  double get functionCoverage =>
      totalFunctions > 0 ? (coveredFunctions / totalFunctions) * 100 : 0;

  int get totalBranches =>
      branchHits.values.fold(0, (sum, branch) => sum + branch.totalBranches);
  int get coveredBranches =>
      branchHits.values.fold(0, (sum, branch) => sum + branch.coveredBranches);
  double get branchCoverage =>
      totalBranches > 0 ? (coveredBranches / totalBranches) * 100 : 0;
}

class BranchData {
  final int totalBranches;
  final int coveredBranches;

  BranchData(this.totalBranches, this.coveredBranches);
}

/// LCOV file parser
class LcovParser {
  static CoverageData parse(String lcovContent) {
    final data = CoverageData();
    final lines = lcovContent.split('\n');

    SourceFile? currentFile;

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        // Source file
        final path = line.substring(3);
        currentFile = SourceFile(path);
        data.sourceFiles[path] = currentFile;
      } else if (line.startsWith('DA:') && currentFile != null) {
        // Line data
        final parts = line.substring(3).split(',');
        if (parts.length >= 2) {
          final lineNumber = int.tryParse(parts[0]);
          final hits = int.tryParse(parts[1]);
          if (lineNumber != null && hits != null) {
            currentFile.lineHits[lineNumber] = hits;
          }
        }
      } else if (line.startsWith('FN:') && currentFile != null) {
        // Function data (declaration)
        final parts = line.substring(3).split(',');
        if (parts.length >= 2) {
          final functionName = parts[1];
          currentFile.functionHits[functionName] = 0; // Initialize with 0 hits
        }
      } else if (line.startsWith('FNDA:') && currentFile != null) {
        // Function data (hits)
        final parts = line.substring(5).split(',');
        if (parts.length >= 2) {
          final hits = int.tryParse(parts[0]);
          final functionName = parts[1];
          if (hits != null) {
            currentFile.functionHits[functionName] = hits;
          }
        }
      } else if (line.startsWith('BDA:') && currentFile != null) {
        // Branch data
        final parts = line.substring(4).split(',');
        if (parts.length >= 4) {
          final lineNumber = int.tryParse(parts[0]);
          final branchId = int.tryParse(parts[1]);
          final taken = parts[3] != '0' && parts[3] != '-';

          if (lineNumber != null && branchId != null) {
            final branch =
                currentFile.branchHits[lineNumber] ?? BranchData(0, 0);
            final newTotal = branch.totalBranches + 1;
            final newCovered = branch.coveredBranches + (taken ? 1 : 0);
            currentFile.branchHits[lineNumber] = BranchData(
              newTotal,
              newCovered,
            );
          }
        }
      }
    }

    return data;
  }
}

/// Main entry point
void main(List<String> args) async {
  final analyzer = CoverageAnalyzer();
  await analyzer.analyze();
}
