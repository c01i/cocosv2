# HelloLua on macOS

This Xcode project is derived from the current `samples/Cpp/TestCpp/proj.mac`
project. It retains its Mac engine/audio configuration, View menu, editable
resolution presets, window state, original-resolution FBO screenshots and
`--workdir` support. TestCpp's tests and verification command-line modes are not
included. The application runs the existing `../Resources/hello.lua` scene.

Lua 5.1.5 and the Cocos Lua bindings compile from repository sources. No LuaJIT
binary or Homebrew package is needed. The project targets x86_64; Apple silicon
runs it through Rosetta. ARM64 Mac support is not provided by the original WebP
binary.

## Dependencies

Use the same original `v2-deps-4` third-party bundle as TestCpp, configured by
`external/config.json`, from
<https://github.com/cocos2d/cocos2d-x-3rd-party-libs-bin/tree/v2-deps-4>.
Restore its `cocos2dx/platform/third_party/mac` directory into the matching
repository path. In particular, `libraries/libwebp.a` and `webp/*.h` must exist.
These binary dependencies are ignored by Git. This Mac target uses the engine's
native Cocoa image backend and does not add libjpeg-turbo.

## Build and run

From the repository root, with Xcode installed and its license accepted:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project samples/Lua/HelloLua/proj.mac/HelloLua.xcodeproj \
  -scheme HelloLua -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath /private/tmp/cocosv2-hellolua-xcode \
  CODE_SIGNING_ALLOWED=NO ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO \
  MACOSX_DEPLOYMENT_TARGET=12.0 CLANG_CXX_LIBRARY=libc++ build

open /private/tmp/cocosv2-hellolua-xcode/Build/Products/Debug/HelloLua.app
```

The architecture, deployment target and C++ library overrides also apply to the
shared legacy `cocos2dx` project, as in TestCpp's build. Existing deprecation and
old WebP archive warnings may appear with modern Xcode.

For an external resource/script directory, launch the executable directly:

```sh
/private/tmp/cocosv2-hellolua-xcode/Build/Products/Debug/HelloLua.app/Contents/MacOS/HelloLua \
  --workdir /absolute/path/to/HelloLua/Resources
```

The supplied directory must contain `hello.lua`, `hello2.lua` and the scene
resources. Invalid arguments/directories exit with status 2. Lua initialization
errors are logged and the Mac app exits with status 1. Successful startup logs
`HelloLua runtime: Lua 5.1.5` and `HelloLua: Lua scene started`.

## View controls

View → Restart Application (⌘R) starts a new process, brings it to the foreground,
and exits the current one.
It reuses the original arguments, including `--workdir` and arguments containing
spaces, from the original launch directory. Window position, selected resolution
and zoom use the current state, replacing any older geometry arguments. If the
new process cannot be launched, the current app stays open and shows the error.

Choose a resolution in View → Resolution, then restart to apply it. View → Zoom
changes only window display scale; for example, a 960×640 scene at 25% saves a
960×640 PNG. View → Save Screenshot suggests
`HelloLua-ss-yyyyMMddHHmmss-SSS.png` in local time.

View → Resolution → Open Resolution Config opens
`~/Library/Application Support/HelloLua/resolutions.json`. Add entries using the
existing `name`, `width`, `height` format. The selected resolution, zoom and
window position are restored on restart under HelloLua's own preferences.

The scene's character animates and moves continuously. Dragging the farm pauses
its movement until release. The bottom-left tools image opens a popup; clicking
the popup closes it. Background music and the popup sound use the existing audio
backend.
