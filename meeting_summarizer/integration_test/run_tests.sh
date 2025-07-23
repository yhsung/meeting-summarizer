#!/bin/bash

# Integration Test Runner Script for Meeting Summarizer
# This script runs integration tests across different platforms and configurations

set -e

echo "🧪 Meeting Summarizer Integration Test Runner"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTEGRATION_TEST_DIR="$PROJECT_ROOT/integration_test"

# Default values
DEVICE=""
PLATFORM=""
TEST_FILE=""
VERBOSE=false
HEADLESS=false

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --device DEVICE     Target device (e.g., macos, chrome, etc.)"
    echo "  -p, --platform PLATFORM Platform to test (android, ios, web, macos, windows, linux)"
    echo "  -t, --test TEST_FILE    Specific test file to run (optional)"
    echo "  -v, --verbose           Enable verbose output"
    echo "  -h, --headless          Run in headless mode (for web tests)"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d macos -v                    # Run all tests on macOS with verbose output"
    echo "  $0 -d chrome -h                   # Run all tests on Chrome in headless mode"
    echo "  $0 -t app_workflow_test.dart -d macos  # Run specific test file"
    echo ""
    echo "Available Test Files:"
    echo "  - integration_test_helpers.dart   # Test utilities (not runnable)"
    echo "  - app_workflow_test.dart          # Basic app workflow tests"
    echo "  - cloud_sync_test.dart            # Cloud sync and offline tests"
    echo "  - platform_tests.dart             # Platform-specific tests"
    echo "  - user_journey_test.dart          # End-to-end user journey tests"
    echo "  - test_runner.dart                # Complete test suite runner"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -t|--test)
            TEST_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--headless)
            HEADLESS=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Function to check if flutter is available
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Flutter found: $(flutter --version | head -n1)${NC}"
}

# Function to get available devices
get_devices() {
    echo -e "${BLUE}📱 Available devices:${NC}"
    flutter devices --machine | jq -r '.[] | "  - \(.id) (\(.name)) - \(.platform)"' 2>/dev/null || {
        echo "  Unable to parse devices as JSON, showing raw output:"
        flutter devices
    }
}

# Function to run integration tests
run_integration_tests() {
    local device_flag=""
    local test_path=""
    local flutter_args=""
    
    # Set device flag if specified
    if [[ -n "$DEVICE" ]]; then
        device_flag="-d $DEVICE"
    fi
    
    # Set test path
    if [[ -n "$TEST_FILE" ]]; then
        test_path="integration_test/$TEST_FILE"
        if [[ ! -f "$PROJECT_ROOT/$test_path" ]]; then
            echo -e "${RED}❌ Test file not found: $test_path${NC}"
            exit 1
        fi
    else
        # Run all integration tests using test runner
        test_path="integration_test/test_runner.dart"
    fi
    
    # Set verbose flag
    if [[ "$VERBOSE" == true ]]; then
        flutter_args="$flutter_args --verbose"
    fi
    
    # Set headless mode for web
    if [[ "$HEADLESS" == true && "$DEVICE" == "chrome" ]]; then
        flutter_args="$flutter_args --web-renderer html"
    fi
    
    echo -e "${BLUE}🚀 Starting integration tests...${NC}"
    echo -e "${YELLOW}Command: flutter test $test_path $device_flag $flutter_args${NC}"
    echo ""
    
    cd "$PROJECT_ROOT"
    
    # Run the tests
    if flutter test $test_path $device_flag $flutter_args; then
        echo ""
        echo -e "${GREEN}✅ Integration tests completed successfully!${NC}"
    else
        echo ""
        echo -e "${RED}❌ Integration tests failed!${NC}"
        exit 1
    fi
}

# Function to run platform-specific setup
platform_setup() {
    case "$PLATFORM" in
        android)
            echo -e "${BLUE}🤖 Setting up Android testing environment...${NC}"
            # Check for Android setup
            if ! flutter doctor | grep -q "Android toolchain"; then
                echo -e "${YELLOW}⚠️  Android toolchain may not be properly configured${NC}"
            fi
            DEVICE=${DEVICE:-"android"}
            ;;
        ios)
            echo -e "${BLUE}📱 Setting up iOS testing environment...${NC}"
            # Check for iOS setup
            if ! flutter doctor | grep -q "Xcode"; then
                echo -e "${YELLOW}⚠️  Xcode may not be properly configured${NC}"
            fi
            DEVICE=${DEVICE:-"ios"}
            ;;
        web)
            echo -e "${BLUE}🌐 Setting up Web testing environment...${NC}"
            DEVICE=${DEVICE:-"chrome"}
            ;;
        macos)
            echo -e "${BLUE}🖥️  Setting up macOS testing environment...${NC}"
            DEVICE=${DEVICE:-"macos"}
            ;;
        windows)
            echo -e "${BLUE}🪟 Setting up Windows testing environment...${NC}"
            DEVICE=${DEVICE:-"windows"}
            ;;
        linux)
            echo -e "${BLUE}🐧 Setting up Linux testing environment...${NC}"
            DEVICE=${DEVICE:-"linux"}
            ;;
        *)
            if [[ -n "$PLATFORM" ]]; then
                echo -e "${YELLOW}⚠️  Unknown platform: $PLATFORM${NC}"
            fi
            ;;
    esac
}

# Function to validate test environment
validate_environment() {
    echo -e "${BLUE}🔍 Validating test environment...${NC}"
    
    # Check if integration test directory exists
    if [[ ! -d "$INTEGRATION_TEST_DIR" ]]; then
        echo -e "${RED}❌ Integration test directory not found: $INTEGRATION_TEST_DIR${NC}"
        exit 1
    fi
    
    # Check if required test files exist
    local required_files=("integration_test_helpers.dart" "test_runner.dart")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$INTEGRATION_TEST_DIR/$file" ]]; then
            echo -e "${RED}❌ Required test file not found: $file${NC}"
            exit 1
        fi
    done
    
    # Check if pubspec.yaml has integration_test dependency
    if ! grep -q "integration_test:" "$PROJECT_ROOT/pubspec.yaml"; then
        echo -e "${RED}❌ integration_test dependency not found in pubspec.yaml${NC}"
        echo -e "${YELLOW}   Add 'integration_test:' to dev_dependencies in pubspec.yaml${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Test environment validation passed${NC}"
}

# Function to show test summary
show_test_info() {
    echo -e "${BLUE}📋 Test Configuration:${NC}"
    echo "  Project Root: $PROJECT_ROOT"
    echo "  Integration Tests: $INTEGRATION_TEST_DIR"
    echo "  Device: ${DEVICE:-"auto-detect"}"
    echo "  Platform: ${PLATFORM:-"current"}"
    echo "  Test File: ${TEST_FILE:-"all tests via test_runner.dart"}"
    echo "  Verbose: $VERBOSE"
    echo "  Headless: $HEADLESS"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}Starting Meeting Summarizer Integration Tests...${NC}"
    echo ""
    
    # Validate environment first
    check_flutter
    validate_environment
    
    # Platform-specific setup
    platform_setup
    
    # Show configuration
    show_test_info
    
    # Show available devices if no device specified
    if [[ -z "$DEVICE" ]]; then
        get_devices
        echo ""
        echo -e "${YELLOW}⚠️  No device specified. Flutter will auto-select a device.${NC}"
        echo -e "${YELLOW}   Use -d <device> to specify a specific device.${NC}"
        echo ""
    fi
    
    # Run the tests
    run_integration_tests
}

# Run main function
main "$@"