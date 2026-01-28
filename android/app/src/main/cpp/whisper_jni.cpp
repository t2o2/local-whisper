#include <jni.h>
#include <string>
#include <android/log.h>
#include "whisper.h"

#define LOG_TAG "WhisperJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_localwhisper_android_transcription_WhisperManager_whisperInit(
        JNIEnv *env,
        jobject /* this */,
        jstring model_path) {

    const char *path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading model from: %s", path);

    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true;

    struct whisper_context *ctx = whisper_init_from_file_with_params(path, cparams);

    env->ReleaseStringUTFChars(model_path, path);

    if (ctx == nullptr) {
        LOGE("Failed to initialize whisper context");
        return 0;
    }

    LOGI("Model loaded successfully");
    return reinterpret_cast<jlong>(ctx);
}

JNIEXPORT jstring JNICALL
Java_com_localwhisper_android_transcription_WhisperManager_whisperTranscribe(
        JNIEnv *env,
        jobject /* this */,
        jlong context_ptr,
        jfloatArray samples,
        jstring language) {

    if (context_ptr == 0) {
        LOGE("Invalid context pointer");
        return env->NewStringUTF("");
    }

    struct whisper_context *ctx = reinterpret_cast<struct whisper_context *>(context_ptr);

    // Get audio samples
    jsize n_samples = env->GetArrayLength(samples);
    jfloat *audio_data = env->GetFloatArrayElements(samples, nullptr);

    LOGI("Transcribing %d samples", n_samples);

    // Get language
    const char *lang = env->GetStringUTFChars(language, nullptr);

    // Configure transcription parameters
    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_progress = false;
    params.print_special = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.translate = false;
    params.single_segment = false;
    params.no_timestamps = true;
    params.language = lang;
    params.n_threads = 4;

    // Run transcription
    int result = whisper_full(ctx, params, audio_data, n_samples);

    env->ReleaseFloatArrayElements(samples, audio_data, 0);
    env->ReleaseStringUTFChars(language, lang);

    if (result != 0) {
        LOGE("Transcription failed with code: %d", result);
        return env->NewStringUTF("");
    }

    // Collect results
    std::string text;
    int n_segments = whisper_full_n_segments(ctx);

    for (int i = 0; i < n_segments; i++) {
        const char *segment_text = whisper_full_get_segment_text(ctx, i);
        text += segment_text;
    }

    LOGI("Transcription complete: %d segments", n_segments);

    return env->NewStringUTF(text.c_str());
}

JNIEXPORT void JNICALL
Java_com_localwhisper_android_transcription_WhisperManager_whisperFree(
        JNIEnv *env,
        jobject /* this */,
        jlong context_ptr) {

    if (context_ptr != 0) {
        struct whisper_context *ctx = reinterpret_cast<struct whisper_context *>(context_ptr);
        whisper_free(ctx);
        LOGI("Whisper context freed");
    }
}

} // extern "C"
