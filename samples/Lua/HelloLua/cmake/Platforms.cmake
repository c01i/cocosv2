list(APPEND COCOS_SOURCES
    "${COCOS_ROOT}/cocos2dx/platform/android/CCDevice.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/CCEGLView.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/CCAccelerometer.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/CCApplication.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/CCCommon.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/CCFileUtilsAndroid.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/CCImage.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/jni/Java_org_cocos2dx_lib_Cocos2dxBitmap.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/jni/Java_org_cocos2dx_lib_Cocos2dxHelper.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/jni/Java_org_cocos2dx_lib_Cocos2dxRenderer.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/jni/Java_org_cocos2dx_lib_Cocos2dxAccelerometer.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/jni/JniHelper.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/jni/IMEJni.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/jni/TouchesJni.cpp"
    "${COCOS_ROOT}/cocos2dx/platform/android/jni/DPIJni.cpp"
)
list(APPEND EXTENSION_SOURCES "${COCOS_ROOT}/extensions/GUI/CCEditBox/CCEditBoxImplAndroid.cpp")
set(AUDIO_SOURCES "${COCOS_ROOT}/CocosDenshion/android/SimpleAudioEngine.cpp"
    "${COCOS_ROOT}/CocosDenshion/android/jni/SimpleAudioEngineJni.cpp")
