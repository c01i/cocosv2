# Build TestCpp on current macOS

Tested with Xcode 27.2 on macOS 26.7.3. The original project targets Intel Macs, so this build uses `x86_64` and requires Rosetta on Apple silicon.

The 2.2.6 Git tree does not include its prebuilt Mac dependencies. `external/config.json` pins the official `v2-deps-4` archive. Install its ignored Mac files before building:

```sh
curl -L https://github.com/cocos2d/cocos2d-x-3rd-party-libs-bin/archive/v2-deps-4.zip -o /tmp/cocosv2-v2-deps-4.zip
unzip -q /tmp/cocosv2-v2-deps-4.zip -d /tmp/cocosv2-deps
mkdir -p cocos2dx/platform/third_party
cp -R /tmp/cocosv2-deps/cocos2d-x-3rd-party-libs-bin-2-deps-4/cocos2dx/platform/third_party/mac cocos2dx/platform/third_party/
lipo -info cocos2dx/platform/third_party/mac/libraries/libwebp.a
```

Run the following from the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project samples/Cpp/TestCpp/proj.mac/TestCpp.xcodeproj \
  -scheme TestCpp -configuration Debug -destination 'generic/platform=macOS' \
  -derivedDataPath /private/tmp/cocosv2-testcpp-task-derived \
  CODE_SIGNING_ALLOWED=NO ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO \
  MACOSX_DEPLOYMENT_TARGET=12.0 CLANG_CXX_LIBRARY=libc++ -quiet build
open /private/tmp/cocosv2-testcpp-task-derived/Build/Products/Debug/TestCpp.app
```

The Mac audio shim no longer declares SDK audio constants or calls the unavailable AudioSession API. Its status queries return `NO`. Font labels draw into a fixed RGBA8 buffer before OpenGL upload because a focused-view bitmap's pixel layout can vary on modern macOS. The TestCpp launcher makes its OpenGL context current before Cocos gathers GPU details.

On a Retina display, the Mac GL view now converts point-based viewports and scissor rectangles to backing pixels. The grid effects still render to their point-sized textures. This keeps `EffectsTest` and the scene after returning to the test list at the full window size.

Verified locally with Xcode 27.2: the Debug build exited 0 and produced `TestCpp.app`; the app opened to the test list, `ActionsTest` displayed readable text, and `EffectsTest` filled the content area. Returning from `EffectsTest` restored the full-size test list, and `ActionsTest` remained clickable.

## Resolution presets and zoom

The **View → Resolution** menu reads `~/Library/Application Support/TestCpp/resolutions.json` at launch. TestCpp creates this file with default presets on the first launch. Add entries to its `resolutions` array, for example:

```json
{"resolutions": [{"name": "Portrait 720 × 1280", "width": 720, "height": 1280}]}
```

`width` and `height` are unscaled logical pixels. They must be integers from 320 through 4096, with at most 16,777,216 total pixels. Names must be nonempty; duplicate sizes are ignored. A malformed file is kept intact and TestCpp uses built-in presets for that launch. The menu includes **Open Resolution Config…** to open the file in the default editor. Restart TestCpp after editing the file or selecting a resolution. **View → Zoom** changes only the displayed window size, without changing the logical resolution.
