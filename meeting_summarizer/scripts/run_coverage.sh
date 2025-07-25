#!/bin/bash

# Comprehensive code coverage collection and analysis script
# Usage: ./scripts/run_coverage.sh [options]
#
# Options:
#   --clean         Clean previous coverage data before running
#   --html          Generate HTML reports (default: true)
#   --badge         Generate coverage badge (default: true)  
#   --analyze       Run detailed coverage analysis (default: true)
#   --enforce       Enforce quality gates (default: false in dev, true in CI)
#   --upload        Upload coverage reports (requires CI environment)
#   --help          Show this help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COVERAGE_DIR="coverage"
LCOV_FILE="$COVERAGE_DIR/lcov.info"
HTML_DIR="$COVERAGE_DIR/html"
SCRIPTS_DIR="scripts"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Default options
CLEAN_COVERAGE=false
GENERATE_HTML=true
GENERATE_BADGE=true
RUN_ANALYSIS=true
ENFORCE_GATES=false
UPLOAD_COVERAGE=false
MINIMUM_COVERAGE=80.0

# Check if running in CI
if [[ -n "${CI}" || -n "${GITHUB_ACTIONS}" || -n "${GITLAB_CI}" ]]; then
    ENFORCE_GATES=true
    UPLOAD_COVERAGE=true
    echo -e "${BLUE}🔧 Running in CI mode - enforcing quality gates${NC}"
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_COVERAGE=true
            shift
            ;;
        --no-html)
            GENERATE_HTML=false
            shift
            ;;
        --no-badge)
            GENERATE_BADGE=false
            shift
            ;;
        --no-analyze)
            RUN_ANALYSIS=false
            shift
            ;;
        --enforce)
            ENFORCE_GATES=true
            shift
            ;;
        --upload)
            UPLOAD_COVERAGE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --clean         Clean previous coverage data"
            echo "  --no-html       Skip HTML report generation"
            echo "  --no-badge      Skip badge generation"
            echo "  --no-analyze    Skip detailed analysis"
            echo "  --enforce       Enforce quality gates"
            echo "  --upload        Upload coverage reports"
            echo "  --help          Show this help"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_dependency() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 is required but not installed"
        return 1
    fi
}

# Check dependencies
log_info "Checking dependencies..."
check_dependency "flutter"
check_dependency "dart"

# Check for lcov (optional, for advanced processing)
if command -v lcov &> /dev/null; then
    LCOV_AVAILABLE=true
    log_success "lcov found - advanced coverage processing available"
else
    LCOV_AVAILABLE=false
    log_warning "lcov not found - basic coverage processing only"
fi

# Clean previous coverage data if requested
if [[ "$CLEAN_COVERAGE" == true ]]; then
    log_info "Cleaning previous coverage data..."
    rm -rf "$COVERAGE_DIR"
    rm -rf "build/test"
    log_success "Previous coverage data cleaned"
fi

# Create coverage directory
mkdir -p "$COVERAGE_DIR"
mkdir -p "$HTML_DIR"

# Run tests with coverage
log_info "Running tests with coverage collection..."
echo "📊 Collecting code coverage data..."

# Run Flutter tests with coverage
flutter test --coverage --reporter=expanded

# Check if coverage was generated
if [[ ! -f "$LCOV_FILE" ]]; then
    log_error "Coverage file not generated: $LCOV_FILE"
    log_error "Make sure tests ran successfully and coverage was enabled"
    exit 1
fi

log_success "Coverage data collected successfully"

# Generate HTML reports using Flutter's built-in tool
if [[ "$GENERATE_HTML" == true ]]; then
    log_info "Generating HTML coverage reports..."
    
    if [[ "$LCOV_AVAILABLE" == true ]]; then
        # Use lcov/genhtml for better HTML reports
        genhtml "$LCOV_FILE" --output-directory "$HTML_DIR" \
            --title "Meeting Summarizer Coverage Report" \
            --show-details --legend --sort \
            --function-coverage --branch-coverage \
            --demangle-cpp --ignore-errors source \
            2>/dev/null || {
                log_warning "genhtml failed, using basic HTML generation"
                # Fallback to basic HTML generation
                dart pub global activate coverage 2>/dev/null || true
                dart pub global run coverage:format_coverage \
                    --lcov --in=coverage/lcov.info --out=coverage/lcov.info --report-on=lib
            }
    else
        # Use dart coverage tools
        dart pub global activate coverage 2>/dev/null || true
        dart pub global run coverage:format_coverage \
            --lcov --in=coverage/lcov.info --out=coverage/lcov.info --report-on=lib
    fi
    
    log_success "HTML reports generated in $HTML_DIR"
    log_info "View coverage report: open $HTML_DIR/index.html"
fi

# Extract basic coverage statistics
log_info "Extracting coverage statistics..."

# Parse coverage percentage from lcov file
if command -v grep &> /dev/null && command -v awk &> /dev/null; then
    TOTAL_LINES=$(grep -c "^DA:" "$LCOV_FILE" 2>/dev/null || echo "0")
    COVERED_LINES=$(grep "^DA:" "$LCOV_FILE" | grep -v ",0$" | wc -l 2>/dev/null || echo "0")
    
    if [[ "$TOTAL_LINES" -gt 0 ]]; then
        COVERAGE_PERCENT=$(echo "scale=2; ($COVERED_LINES * 100) / $TOTAL_LINES" | bc 2>/dev/null || echo "0")
        echo "📈 Line Coverage: $COVERAGE_PERCENT% ($COVERED_LINES/$TOTAL_LINES lines)"
        
        # Store coverage percentage for later use
        echo "$COVERAGE_PERCENT" > "$COVERAGE_DIR/coverage_percent.txt"
    else
        log_warning "Could not calculate coverage percentage"
        COVERAGE_PERCENT="0"
    fi
else
    log_warning "grep/awk not available, skipping coverage calculation"
    COVERAGE_PERCENT="0"
fi

# Run detailed coverage analysis
if [[ "$RUN_ANALYSIS" == true ]]; then
    log_info "Running detailed coverage analysis..."
    
    if [[ -f "$SCRIPTS_DIR/coverage_analysis.dart" ]]; then
        # Run our custom coverage analyzer
        cd "$PROJECT_ROOT"
        dart run "$SCRIPTS_DIR/coverage_analysis.dart" 2>/dev/null || {
            log_warning "Custom coverage analysis failed, continuing with basic analysis"
        }
    else
        log_warning "Coverage analysis script not found: $SCRIPTS_DIR/coverage_analysis.dart"
    fi
fi

# Generate coverage badge
if [[ "$GENERATE_BADGE" == true ]]; then
    log_info "Generating coverage badge..."
    
    # Determine badge color based on coverage
    if (( $(echo "$COVERAGE_PERCENT >= 90" | bc -l 2>/dev/null || echo "0") )); then
        BADGE_COLOR="brightgreen"
    elif (( $(echo "$COVERAGE_PERCENT >= 80" | bc -l 2>/dev/null || echo "0") )); then
        BADGE_COLOR="green"
    elif (( $(echo "$COVERAGE_PERCENT >= 70" | bc -l 2>/dev/null || echo "0") )); then
        BADGE_COLOR="yellow"
    elif (( $(echo "$COVERAGE_PERCENT >= 60" | bc -l 2>/dev/null || echo "0") )); then
        BADGE_COLOR="orange"
    else
        BADGE_COLOR="red"
    fi
    
    # Generate simple SVG badge
    cat > "$COVERAGE_DIR/coverage-badge.svg" << EOF
<?xml version="1.0" encoding="UTF-8"?>
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
    <path fill="$BADGE_COLOR" d="M63 0h41v20H63z"/>
    <path fill="url(#b)" d="M0 0h104v20H0z"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="110">
    <text x="325" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="530">coverage</text>
    <text x="325" y="140" transform="scale(.1)" textLength="530">coverage</text>
    <text x="825" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="310">${COVERAGE_PERCENT}%</text>
    <text x="825" y="140" transform="scale(.1)" textLength="310">${COVERAGE_PERCENT}%</text>
  </g>
</svg>
EOF
    
    log_success "Coverage badge generated: $COVERAGE_DIR/coverage-badge.svg"
fi

# Quality gate enforcement
if [[ "$ENFORCE_GATES" == true ]]; then
    log_info "Enforcing quality gates..."
    
    # Check minimum coverage threshold
    if (( $(echo "$COVERAGE_PERCENT < $MINIMUM_COVERAGE" | bc -l 2>/dev/null || echo "1") )); then
        log_error "Coverage $COVERAGE_PERCENT% is below minimum threshold $MINIMUM_COVERAGE%"
        
        if [[ -n "${CI}" ]]; then
            log_error "Failing CI build due to insufficient coverage"
            exit 1
        else
            log_warning "Quality gate failed but not in CI - continuing"
        fi
    else
        log_success "Coverage $COVERAGE_PERCENT% meets minimum threshold $MINIMUM_COVERAGE%"
    fi
fi

# Upload coverage reports (in CI environments)
if [[ "$UPLOAD_COVERAGE" == true && -n "${CI}" ]]; then
    log_info "Uploading coverage reports..."
    
    # Upload to Codecov if token is available
    if [[ -n "${CODECOV_TOKEN}" ]] && command -v curl &> /dev/null; then
        log_info "Uploading to Codecov..."
        curl -s https://codecov.io/bash | bash -s -- \
            -t "${CODECOV_TOKEN}" \
            -f "$LCOV_FILE" \
            -F unittests \
            -n "meeting-summarizer-coverage" || {
                log_warning "Codecov upload failed"
            }
    fi
    
    # Upload to Coveralls if token is available
    if [[ -n "${COVERALLS_REPO_TOKEN}" ]] && command -v dart &> /dev/null; then
        log_info "Uploading to Coveralls..."
        dart pub global activate dart_coveralls 2>/dev/null || true
        dart pub global run dart_coveralls report \
            --token "${COVERALLS_REPO_TOKEN}" \
            --retry 3 \
            "$LCOV_FILE" || {
                log_warning "Coveralls upload failed"
            }
    fi
    
    # Create coverage summary for GitHub Actions
    if [[ -n "${GITHUB_ACTIONS}" ]]; then
        log_info "Creating GitHub Actions coverage summary..."
        cat >> "$GITHUB_STEP_SUMMARY" << EOF
## 📊 Code Coverage Report

- **Line Coverage**: $COVERAGE_PERCENT%
- **Minimum Threshold**: $MINIMUM_COVERAGE%
- **Status**: $(if (( $(echo "$COVERAGE_PERCENT >= $MINIMUM_COVERAGE" | bc -l 2>/dev/null || echo "0") )); then echo "✅ PASSED"; else echo "❌ FAILED"; fi)

### Coverage Details
- Total Lines: $TOTAL_LINES
- Covered Lines: $COVERED_LINES

[View detailed coverage report](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})
EOF
    fi
fi

# Summary
echo ""
echo "📋 Coverage Analysis Summary:"
echo "=============================="
echo "📈 Line Coverage: $COVERAGE_PERCENT%"
echo "🎯 Minimum Threshold: $MINIMUM_COVERAGE%"
echo "📁 Coverage Data: $LCOV_FILE"
if [[ "$GENERATE_HTML" == true ]]; then
    echo "🌐 HTML Report: $HTML_DIR/index.html"
fi
if [[ "$GENERATE_BADGE" == true ]]; then
    echo "🏷️  Badge: $COVERAGE_DIR/coverage-badge.svg"
fi

# Final status
if (( $(echo "$COVERAGE_PERCENT >= $MINIMUM_COVERAGE" | bc -l 2>/dev/null || echo "0") )); then
    log_success "Coverage analysis completed successfully! 🎉"
    echo "✨ Coverage meets quality standards"
else
    log_warning "Coverage is below minimum threshold"
    echo "💡 Consider adding more tests to improve coverage"
fi

echo ""
echo "🚀 Next steps:"
echo "  - Review HTML coverage report for detailed analysis"
echo "  - Focus on files with low coverage"
echo "  - Add tests for uncovered functions and branches"
echo "  - Update documentation with coverage badge"

# Exit with appropriate code
if [[ "$ENFORCE_GATES" == true ]]; then
    if (( $(echo "$COVERAGE_PERCENT >= $MINIMUM_COVERAGE" | bc -l 2>/dev/null || echo "0") )); then
        exit 0
    else
        exit 1
    fi
fi

exit 0