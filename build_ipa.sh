#!/bin/bash
# ExpenseTracker IPA Build Script
# Requires: Xcode Command Line Tools, ldid

set -e

PROJECT="ExpenseTracker"
BUILD_DIR="build"
SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || echo "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk")
MIN_IOS="14.0"
ARCH="arm64"

echo "=== Building $PROJECT IPA ==="

# Clean
rm -rf "$BUILD_DIR"

# Remove CRLF line endings to avoid macOS clang issues
echo "Normalizing line endings..."
find Source -name "*.m" -o -name "*.h" | xargs sed -i '' 's/\r$//' 2>/dev/null || true
mkdir -p "$BUILD_DIR/obj"
mkdir -p "$BUILD_DIR/Payload/$PROJECT.app"

# Compile each .m file individually
OBJC_FILES=$(find Source -name "*.m" | sort)
CFLAGS="-isysroot $SDK_PATH -miphoneos-version-min=$MIN_IOS -arch $ARCH"
CFLAGS="$CFLAGS -fobjc-arc -I Source"
LDFLAGS="-framework UIKit -framework Foundation -framework CoreGraphics"
LDFLAGS="$LDFLAGS -framework QuartzCore -framework UserNotifications"
LDFLAGS="$LDFLAGS -framework CoreText -framework Vision"
LDFLAGS="$LDFLAGS -lsqlite3"

echo "Compiling Objective-C files..."
for f in $OBJC_FILES; do
    basename=$(basename "$f" .m)
    echo "  $f -> $BUILD_DIR/obj/${basename}.o"
    clang $CFLAGS -c "$f" -o "$BUILD_DIR/obj/${basename}.o"
done

echo "Linking..."
clang $CFLAGS "$BUILD_DIR/obj/"*.o -o "$BUILD_DIR/Payload/$PROJECT.app/$PROJECT" $LDFLAGS

# Copy Info.plist
cp Resources/Info.plist "$BUILD_DIR/Payload/$PROJECT.app/"

# Create basic icon placeholder
mkdir -p "$BUILD_DIR/Payload/$PROJECT.app/Assets.car"

# Copy LaunchScreen
cp Resources/LaunchScreen.storyboard "$BUILD_DIR/Payload/$PROJECT.app/" 2>/dev/null || true

# Sign with ldid
echo "Signing with ldid..."
ldid -SEntitlements/ExpenseTracker.entitlements "$BUILD_DIR/Payload/$PROJECT.app/$PROJECT"
ldid -SEntitlements/ExpenseTracker.entitlements "$BUILD_DIR/Payload/$PROJECT.app/"

# Package as IPA
cd "$BUILD_DIR"
zip -r "${PROJECT}.ipa" Payload/
cd ..

echo "=== Build Complete ==="
echo "IPA: $BUILD_DIR/${PROJECT}.ipa"
ls -lh "$BUILD_DIR/${PROJECT}.ipa"