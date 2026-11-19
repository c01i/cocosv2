# HelloLua on Android

The supported Android entry is Gradle + CMake. It compiles the engine, Lua 5.1.5,
Cocos Lua bindings and image/XML libraries from source. No LuaJIT or historical
armeabi prebuilt library is linked. macOS uses [the TestCpp-derived Xcode project](../proj.mac/README.md).

## Toolchain

- JDK 17
- Gradle 8.13 (included wrapper), Android Gradle Plugin 8.10.1
- Android SDK Platform 36, Build Tools 36.0.0
- Android NDK 28.0.13004108, SDK CMake 3.22.1
- ABI: **arm64-v8a**; minimum Android API 26

Install these SDK packages with Android Studio's SDK Manager, or `sdkmanager`:

```sh
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" \
  "ndk;28.0.13004108" "cmake;3.22.1"
```

Set `JAVA_HOME` to JDK 17 and `ANDROID_HOME` to the SDK directory. Alternatively,
put `sdk.dir=/absolute/path/to/sdk` in this directory's ignored `local.properties`.
An internet connection is needed for the first Gradle/plugin and native source
downloads. The native archive SHA-256 values are checked by CMake; the wrapper
also checks the Gradle distribution checksum.

## Build and run

From this directory:

```sh
./gradlew --no-daemon --max-workers=4 assembleDebug
adb install -r build/outputs/apk/debug/HelloLua-debug.apk
adb shell am start -W -n org.cocos2dx.hellolua/.HelloLua
adb logcat -s "cocos2d-x debug info:D" "AndroidRuntime:E" "libc:F"
```

The APK is debug signed. A connected arm64 emulator or device is required;
x86/x86_64 emulators are not supported by this target. Successful startup logs
`HelloLua runtime: Lua 5.1.5` and `HelloLua: Lua scene started`. The farm scene
contains an animated moving character, a tools button that opens/closes a popup,
and a drag gesture that pauses movement until release.

The target SDK remains 28 for this legacy sample. Recent Android versions may
show an older-app notice. This is a local development example, not a Play Store
release configuration. Only the arm64 debug build is verified; other ABIs,
release signing and store target-SDK migration are not included.

The historical Eclipse/Ant files, `jni/Android.mk`, `jni/Application.mk` and
`build_native.sh` belong to the original NDK/gnustl workflow. They are retained
for reference and are not the supported build path with NDK 28. Do not run the
old script before the Gradle build; Gradle packages `../Resources` directly.

## Native dependencies

These versions are new Android build dependencies, replacing the original
32-bit prebuilt image/XML archives. libjpeg-turbo is used only on Android;
macOS retains TestCpp's Cocoa image backend and original WebP archive. Official
source URLs and hashes are pinned in [Dependencies.cmake](../cmake/Dependencies.cmake).

| Library | Version | SHA-256 of source archive |
| --- | --- | --- |
| libpng | 1.6.50 | `71158e53cfdf2877bc99bcab33641d78df3f48e6e0daad030afe9cb8c031aa46` |
| libjpeg-turbo | 3.1.2 | `560f6338b547544c4f9721b18d8b87685d433ec78b3c644c70d77adad22c55e6` |
| libtiff | 4.7.1 | `f698d94f3103da8ca7438d84e0344e453fe0ba3b7486e04c5bf7a9a3fabe9b69` |
| libwebp | 1.5.0 | `668c9aba45565e24c27e17f7aaf7060a399f7f31dba6c97a044e1feacb930f37` |
| libxml2 | 2.12.10 | `1eb57a2a347710f7b42e96c267fa55152774924fc2dd7d653c626a96cef8ef16` |

The C++ standard library is linked statically into `libhellolua.so`. Optional
TIFF codecs and dependency command-line tools/tests are disabled. JPEG SIMD is
disabled for a reproducible source build without an assembler dependency. Engine
JNI entry points are retained with whole-archive linking because Java resolves
them by name rather than through C++ callers. Android's FORTIFY checks remain
enabled; Lua weak-table string scanning is adapted to its recorded string length.

Dependency licenses and notices are in `notices/` and are packaged as APK assets.
This software is based in part on the work of the Independent JPEG Group.
