#!/bin/bash
# 用法：bash Tests/run-regressions.sh [已启动的模拟器 UDID，默认 booted]
# 可选：SVGA_TEST_CONFIGURATION=Release、SVGA_TEST_BUILD_DIR=/tmp/svga-tests
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
device=${1:-booted}
configuration=${SVGA_TEST_CONFIGURATION:-Debug}
build_dir=${SVGA_TEST_BUILD_DIR:-$(mktemp -d /tmp/svga-regressions.XXXXXX)}
arch=$(uname -m)
mkdir -p "$build_dir"
echo "Build and test logs: $build_dir"
xcrun simctl spawn "$device" /usr/bin/true
if ! xcodebuild -workspace "$root/SVGAPlayer.xcworkspace" -scheme SVGAPlayer \
    -configuration "$configuration" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$build_dir" ARCHS="$arch" CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES \
    build > "$build_dir/build.log" 2>&1; then
    tail -60 "$build_dir/build.log"
    exit 1
fi

# 直接链接本次构建的库源码和 Pods，使用真实 UIKit，无需增加测试 target 或依赖。
objects_dir="$build_dir/Build/Intermediates.noindex/SVGAPlayer.build/$configuration-iphonesimulator/SVGAPlayer.build/Objects-normal/$arch"
products="$build_dir/Build/Products/$configuration-iphonesimulator"
objects=()
for source in "$root"/Source/*.m "$root"/Source/pbobjc/*.m; do
    name=$(basename "$source" .m)
    objects+=("$objects_dir/$name.o")
done
sdk_path=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun clang -target "$arch-apple-ios12.0-simulator" -isysroot "$sdk_path" \
    -fobjc-arc -fblocks -I"$root/Source" "$root/Tests/SVGAPlayerRegression.m" \
    "${objects[@]}" "$products/Protobuf/libProtobuf.a" "$products/SSZipArchive/libSSZipArchive.a" \
    -framework UIKit -framework Foundation -framework QuartzCore -framework AVFoundation \
    -framework ImageIO -framework Security -lz -liconv -o "$build_dir/regressions"
xcrun simctl spawn "$device" "$build_dir/regressions" "$root/SVGAPlayer/Samples" \
    2>&1 | tee "$build_dir/tests.log"
