cmake_minimum_required(VERSION 3.22)
project(HelloLua LANGUAGES C CXX)
set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
get_filename_component(COCOS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../.." ABSOLUTE)
if(NOT ANDROID)
    message(FATAL_ERROR "Use proj.mac/HelloLua.xcodeproj for macOS; this CMake entry builds Android")
endif()
include(cmake/Dependencies.cmake)
add_subdirectory("${COCOS_ROOT}/scripting/lua" "${CMAKE_CURRENT_BINARY_DIR}/lua515")
include(cmake/Sources.cmake)
include(cmake/Platforms.cmake)
add_compile_definitions(COCOS2D_DEBUG=1 CC_ENABLE_CHIPMUNK_INTEGRATION=0 CC_ENABLE_BOX2D_INTEGRATION=0 USE_FILE32API)
set(COCOS_INCLUDES "${COCOS_ROOT}/cocos2dx" "${COCOS_ROOT}/cocos2dx/include"
    "${COCOS_ROOT}/cocos2dx/platform" "${COCOS_ROOT}/cocos2dx/kazmath/include"
    "${COCOS_ROOT}/CocosDenshion/include" "${COCOS_ROOT}/extensions"
    "${COCOS_ROOT}/extensions/GUI/CCControlExtension" "${COCOS_ROOT}/extensions/GUI/CCScrollView"
    "${COCOS_ROOT}/extensions/CCBReader" "${COCOS_ROOT}/extensions/CocoStudio/Armature"
    "${COCOS_ROOT}/scripting/lua/cocos2dx_support" "${COCOS_ROOT}/scripting/lua/tolua"
    "${COCOS_ROOT}/scripting/lua/xxtea" "${COCOS_ROOT}/scripting/lua/lua")
list(APPEND COCOS_INCLUDES "${COCOS_ROOT}/cocos2dx/platform/android")
add_library(cocos2d STATIC ${COCOS_SOURCES})
target_include_directories(cocos2d PUBLIC ${COCOS_INCLUDES}
    "${jpeg_SOURCE_DIR}/src" "${jpeg_BINARY_DIR}" "${tiff_SOURCE_DIR}/libtiff" "${tiff_BINARY_DIR}/libtiff"
    "${webp_SOURCE_DIR}/src/webp")
target_link_libraries(cocos2d PUBLIC png_static jpeg-static tiff webp LibXml2)
add_dependencies(cocos2d jpeg_build)
add_library(cocos_audio STATIC ${AUDIO_SOURCES})
target_link_libraries(cocos_audio PUBLIC cocos2d)
add_library(cocos_extensions STATIC ${EXTENSION_SOURCES})
target_link_libraries(cocos_extensions PUBLIC cocos2d cocos_audio)
add_library(cocos_lua STATIC ${LUA_BINDING_SOURCES})
target_link_libraries(cocos_lua PUBLIC lua515 cocos_extensions)
target_link_libraries(cocos2d PUBLIC GLESv2 log z android)
add_library(hellolua SHARED Classes/AppDelegate.cpp proj.android/jni/hellolua/main.cpp)
target_include_directories(hellolua PRIVATE Classes)
# Java resolves JNI entry points by name, so retain engine objects with no C++ callers.
target_link_libraries(hellolua PRIVATE cocos_lua "-Wl,--whole-archive" cocos2d "-Wl,--no-whole-archive")
