# Code Coverage Documentation

This document describes the comprehensive code coverage setup for the Meeting Summarizer project.

## Overview

The Meeting Summarizer project implements a comprehensive code coverage system with:

- **Minimum Coverage Threshold**: 80% line coverage
- **Quality Gates**: Automated enforcement in CI/CD
- **Comprehensive Reporting**: HTML, JSON, and markdown reports
- **Trend Analysis**: Coverage tracking over time
- **Badge Generation**: Visual coverage indicators
- **Platform Integration**: Codecov and Coveralls support

## Configuration Files

### 1. Coverage Configuration (`coverage_config.yaml`)

The main configuration file defining:
- Coverage thresholds (minimum: 80%, target: 90%)
- Quality gates for line, function, and branch coverage
- Exclusion patterns for generated files
- Report formats and output settings
- Trend analysis configuration
- CI/CD integration settings

### 2. LCOV Configuration (`.lcovrc`)

LCOV-specific settings including:
- File exclusion patterns
- HTML report customization
- Branch and function coverage settings
- Output formatting options

### 3. Test Configuration (`dart_test.yaml`)

Flutter test configuration with:
- Golden test settings
- Coverage-specific test tags
- Timeout and concurrency settings

## Scripts and Tools

### 1. Coverage Analysis Script (`scripts/coverage_analysis.dart`)

Comprehensive Dart script providing:
- **LCOV Data Parsing**: Processes coverage data from Flutter tests
- **Quality Gate Enforcement**: Validates coverage against thresholds
- **Report Generation**: Creates HTML, JSON, and markdown reports
- **Trend Analysis**: Tracks coverage changes over time
- **Badge Generation**: Creates SVG coverage badges
- **Low Coverage Reporting**: Identifies files needing attention

Key features:
- Parses `lcov.info` files
- Generates detailed HTML reports with visualizations
- Creates file-level coverage breakdown
- Identifies critical low-coverage areas
- Tracks historical trends
- Enforces quality gates with configurable thresholds

### 2. Coverage Runner Script (`scripts/run_coverage.sh`)

Bash script that orchestrates coverage collection:
- **Test Execution**: Runs Flutter tests with coverage
- **Report Generation**: Creates multiple report formats
- **Quality Enforcement**: Validates coverage thresholds
- **CI Integration**: Uploads to coverage services
- **Badge Creation**: Generates coverage badges

Usage:
```bash
# Basic coverage run
./scripts/run_coverage.sh

# With quality gates enforced
./scripts/run_coverage.sh --enforce

# Clean previous data first
./scripts/run_coverage.sh --clean --enforce

# Upload to coverage services (CI mode)
./scripts/run_coverage.sh --enforce --upload
```

## Coverage Exclusions

The system excludes the following from coverage analysis:

### Generated Files
- `**/*.g.dart` - Dart build runner generated files
- `**/*.freezed.dart` - Freezed generated classes
- `**/*.chopper.dart` - Chopper API client files
- `**/*.gr.dart` - Generated route files
- `**/*.config.dart` - Configuration files
- `**/*.mocks.dart` - Mock generation files

### Test Files
- `test/**` - All test directories
- `integration_test/**` - Integration test files
- `**/*_test.dart` - Test files
- `**/mock_*.dart` - Mock implementation files

### Platform-Specific Code
- `**/*_stub.dart` - Platform stubs
- `**/*_web.dart` - Web-specific implementations
- `**/*_io.dart` - Native-specific implementations
- `lib/core/services/local_whisper_service_stub.dart` - Web build stub

### Build and System Files
- `build/**` - Build outputs
- `android/**`, `ios/**`, `macos/**`, `windows/**`, `web/**` - Platform files
- `.dart_tool/**` - Dart tool cache
- `coverage/**` - Coverage outputs

## CI/CD Integration

### GitHub Actions Workflow

The CI/CD pipeline includes comprehensive coverage reporting:

#### Test Job with Coverage
- Runs Flutter tests with coverage collection
- Executes comprehensive coverage analysis
- Enforces quality gates (80% minimum)
- Generates coverage reports and badges
- Uploads to Codecov and Coveralls
- Comments coverage results on pull requests

#### Coverage Analysis Job
- Downloads coverage artifacts
- Runs detailed coverage analysis
- Performs trend analysis
- Generates comprehensive reports
- Updates coverage badges for main branch

### Quality Gates

The system enforces the following quality gates:

1. **Line Coverage**: Minimum 80%
2. **Function Coverage**: Minimum 85%
3. **Branch Coverage**: Minimum 75%
4. **Coverage Decrease**: Fails if coverage drops >5%

Quality gates are enforced:
- ✅ Always in CI environments
- ⚠️ Optional in development environments
- 🔴 Block merges if thresholds not met

### Environment Variables

Configure the following secrets in your CI/CD system:

```bash
# Required for coverage uploads
CODECOV_TOKEN=your_codecov_token
COVERALLS_REPO_TOKEN=your_coveralls_token

# Optional for enhanced reporting
GITHUB_TOKEN=automatic_github_token
```

## Reports and Outputs

### 1. HTML Reports (`coverage/html/`)
Interactive HTML reports with:
- Overall coverage statistics
- File-level breakdown
- Line-by-line coverage
- Function and branch coverage
- Visual indicators for coverage levels

### 2. JSON Reports (`coverage/coverage.json`)
Machine-readable coverage data for:
- Programmatic access
- Integration with other tools
- API consumption
- Custom analysis

### 3. Markdown Summary (`coverage/coverage-summary.md`)
Human-readable summary including:
- Overall statistics
- Quality assessment
- Recommendations
- File breakdown

### 4. Coverage Badge (`coverage/coverage-badge.svg`)
SVG badge showing coverage percentage with color coding:
- 🟢 Green: 90%+ (Excellent)
- 🟡 Yellow: 70-89% (Good)
- 🟠 Orange: 60-69% (Fair)
- 🔴 Red: <60% (Needs Improvement)

### 5. Trend Analysis (`coverage/trends.json`)
Historical coverage data tracking:
- Coverage over time
- Commit-level tracking
- Trend identification
- Performance analysis

## Local Development

### Running Coverage Locally

```bash
# Navigate to project directory
cd meeting_summarizer

# Run basic coverage
flutter test --coverage

# Run comprehensive analysis
./scripts/run_coverage.sh

# View HTML report
open coverage/html/index.html
```

### Pre-commit Hooks

Consider adding coverage checks to pre-commit hooks:

```bash
#!/bin/bash
# .git/hooks/pre-commit

cd meeting_summarizer
./scripts/run_coverage.sh --enforce
```

## Best Practices

### Writing Testable Code

1. **Small, Focused Functions**: Easier to test and achieve high coverage
2. **Dependency Injection**: Enables mocking for unit tests
3. **Pure Functions**: Functions without side effects are easier to test
4. **Error Handling**: Test both success and failure paths

### Improving Coverage

1. **Identify Low Coverage Areas**: Use generated reports
2. **Focus on Critical Paths**: Prioritize important business logic
3. **Test Edge Cases**: Cover error conditions and boundary cases
4. **Mock External Dependencies**: Isolate units under test

### Coverage Quality

Remember that high coverage doesn't guarantee quality:
- ✅ Aim for meaningful tests, not just coverage numbers
- ✅ Test behavior, not just code execution
- ✅ Include integration and end-to-end tests
- ✅ Review coverage reports regularly

## Troubleshooting

### Common Issues

1. **Coverage Not Generated**
   ```bash
   # Ensure tests run successfully
   flutter test
   
   # Check for lcov.info file
   ls -la coverage/
   ```

2. **Quality Gates Failing**
   ```bash
   # Check current coverage
   cat coverage/coverage_percent.txt
   
   # Review low coverage files
   cat coverage/low-coverage-report.md
   ```

3. **CI Upload Failures**
   ```bash
   # Verify tokens are set
   echo $CODECOV_TOKEN
   echo $COVERALLS_REPO_TOKEN
   ```

### Debugging Coverage

1. **Enable Verbose Logging**:
   ```bash
   ./scripts/run_coverage.sh --verbose
   ```

2. **Check LCOV Data**:
   ```bash
   # Validate LCOV format
   lcov --summary coverage/lcov.info
   ```

3. **Manual Analysis**:
   ```bash
   # Run Dart analyzer
   dart run scripts/coverage_analysis.dart
   ```

## Integration with External Services

### Codecov

- **Setup**: Add `CODECOV_TOKEN` to repository secrets
- **Features**: Detailed coverage analysis, PR comments, trend tracking
- **Dashboard**: View coverage at codecov.io

### Coveralls

- **Setup**: Add `COVERALLS_REPO_TOKEN` to repository secrets  
- **Features**: Coverage tracking, GitHub integration
- **Dashboard**: View coverage at coveralls.io

### GitHub Actions

- **Artifacts**: Coverage reports uploaded as build artifacts
- **PR Comments**: Automatic coverage comments on pull requests
- **Status Checks**: Coverage gates as required status checks

## Maintenance

### Regular Tasks

1. **Review Coverage Trends**: Monthly analysis of coverage changes
2. **Update Thresholds**: Adjust targets as project matures
3. **Refine Exclusions**: Update exclusion patterns for new file types
4. **Tool Updates**: Keep coverage tools and dependencies updated

### Monitoring

- Track coverage trends over time
- Monitor CI/CD performance impact
- Review quality gate effectiveness
- Analyze testing ROI and efficiency

---

This coverage system provides comprehensive insights into code quality and helps maintain high testing standards throughout the development lifecycle.