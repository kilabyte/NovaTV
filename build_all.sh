#!/bin/bash

# NovaTV Build Script
# Builds release binaries for macOS, iOS, Windows, and Android

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Build output directory
BUILD_OUTPUT="./release_builds"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           NovaTV Build Script              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Show Flutter version
echo -e "${BLUE}Flutter version:${NC}"
flutter --version
echo ""

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
flutter clean
flutter pub get
echo ""

# Create output directory
mkdir -p "$BUILD_OUTPUT"

# Track build results
RESULTS_FILE=$(mktemp)

# Function to log result
log_result() {
    echo "$1|$2" >> "$RESULTS_FILE"
}

# Parse command line arguments
BUILD_MACOS=false
BUILD_IOS=false
BUILD_ANDROID=false
BUILD_WINDOWS=false
BUILD_ALL=false

if [ $# -eq 0 ]; then
    BUILD_ALL=true
else
    for arg in "$@"; do
        case $arg in
            macos)   BUILD_MACOS=true ;;
            ios)     BUILD_IOS=true ;;
            android) BUILD_ANDROID=true ;;
            windows) BUILD_WINDOWS=true ;;
            all)     BUILD_ALL=true ;;
            *)
                echo -e "${RED}Unknown platform: $arg${NC}"
                echo "Usage: $0 [macos] [ios] [android] [windows] [all]"
                exit 1
                ;;
        esac
    done
fi

if [ "$BUILD_ALL" = true ]; then
    BUILD_MACOS=true
    BUILD_IOS=true
    BUILD_ANDROID=true
    BUILD_WINDOWS=true
fi

# macOS Build
if [ "$BUILD_MACOS" = true ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Building for macOS...${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        if flutter build macos --release; then
            if [ -d "build/macos/Build/Products/Release/NovaTV.app" ]; then
                cp -r "build/macos/Build/Products/Release/NovaTV.app" "$BUILD_OUTPUT/NovaTV-macOS.app"
                echo -e "${GREEN}✓ macOS build successful${NC}"
                log_result "macOS" "SUCCESS"
            else
                echo -e "${RED}✗ macOS build output not found${NC}"
                log_result "macOS" "FAILED - Output not found"
            fi
        else
            echo -e "${RED}✗ macOS build failed${NC}"
            log_result "macOS" "FAILED"
        fi
        echo ""
    else
        echo -e "${YELLOW}⚠ Skipping macOS build (not on macOS)${NC}"
        log_result "macOS" "SKIPPED - Not on macOS"
    fi
fi

# iOS Build
if [ "$BUILD_IOS" = true ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Building for iOS...${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        if flutter build ios --release --no-codesign; then
            if [ -d "build/ios/iphoneos/Runner.app" ]; then
                cp -r "build/ios/iphoneos/Runner.app" "$BUILD_OUTPUT/NovaTV-iOS.app"
                echo -e "${GREEN}✓ iOS build successful${NC}"
                log_result "iOS" "SUCCESS"

                # Create IPA
                echo -e "${YELLOW}Creating iOS IPA...${NC}"
                mkdir -p "$BUILD_OUTPUT/Payload"
                cp -r "build/ios/iphoneos/Runner.app" "$BUILD_OUTPUT/Payload/"
                cd "$BUILD_OUTPUT"
                zip -r "NovaTV-iOS.ipa" "Payload" > /dev/null 2>&1
                rm -rf "Payload"
                cd - > /dev/null
                echo -e "${GREEN}✓ IPA created${NC}"
            else
                echo -e "${RED}✗ iOS build output not found${NC}"
                log_result "iOS" "FAILED - Output not found"
            fi
        else
            echo -e "${RED}✗ iOS build failed${NC}"
            log_result "iOS" "FAILED"
        fi
        echo ""
    else
        echo -e "${YELLOW}⚠ Skipping iOS build (not on macOS)${NC}"
        log_result "iOS" "SKIPPED - Not on macOS"
    fi
fi

# Android APK Build
if [ "$BUILD_ANDROID" = true ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Building for Android (APK)...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if flutter build apk --release; then
        if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
            cp "build/app/outputs/flutter-apk/app-release.apk" "$BUILD_OUTPUT/NovaTV-Android.apk"
            echo -e "${GREEN}✓ Android APK build successful${NC}"
            log_result "Android APK" "SUCCESS"
        else
            echo -e "${RED}✗ Android APK output not found${NC}"
            log_result "Android APK" "FAILED - Output not found"
        fi
    else
        echo -e "${RED}✗ Android APK build failed${NC}"
        log_result "Android APK" "FAILED"
    fi
    echo ""

    # Android App Bundle Build
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Building for Android (App Bundle)...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if flutter build appbundle --release; then
        if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
            cp "build/app/outputs/bundle/release/app-release.aab" "$BUILD_OUTPUT/NovaTV-Android.aab"
            echo -e "${GREEN}✓ Android App Bundle build successful${NC}"
            log_result "Android AAB" "SUCCESS"
        else
            echo -e "${RED}✗ Android App Bundle output not found${NC}"
            log_result "Android AAB" "FAILED - Output not found"
        fi
    else
        echo -e "${RED}✗ Android App Bundle build failed${NC}"
        log_result "Android AAB" "FAILED"
    fi
    echo ""
fi

# Windows Build
if [ "$BUILD_WINDOWS" = true ]; then
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Building for Windows...${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        if flutter build windows --release; then
            if [ -d "build/windows/x64/runner/Release" ]; then
                cp -r "build/windows/x64/runner/Release" "$BUILD_OUTPUT/NovaTV-Windows"
                echo -e "${GREEN}✓ Windows build successful${NC}"
                log_result "Windows" "SUCCESS"
            else
                echo -e "${RED}✗ Windows build output not found${NC}"
                log_result "Windows" "FAILED - Output not found"
            fi
        else
            echo -e "${RED}✗ Windows build failed${NC}"
            log_result "Windows" "FAILED"
        fi
        echo ""
    else
        echo -e "${YELLOW}⚠ Skipping Windows build (not on Windows)${NC}"
        log_result "Windows" "SKIPPED - Not on Windows"
        echo ""
    fi
fi

# Print summary
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Build Summary                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

while IFS='|' read -r platform result; do
    if [[ "$result" == "SUCCESS" ]]; then
        echo -e "  ${GREEN}✓${NC} $platform: ${GREEN}$result${NC}"
    elif [[ "$result" == SKIPPED* ]]; then
        echo -e "  ${YELLOW}⚠${NC} $platform: ${YELLOW}$result${NC}"
    else
        echo -e "  ${RED}✗${NC} $platform: ${RED}$result${NC}"
    fi
done < "$RESULTS_FILE"

rm -f "$RESULTS_FILE"

echo ""
echo -e "${BLUE}Build outputs are in: ${BUILD_OUTPUT}/${NC}"
echo ""

# List output files
if [ -d "$BUILD_OUTPUT" ]; then
    echo -e "${BLUE}Generated files:${NC}"
    ls -lh "$BUILD_OUTPUT"
fi
