# Model Guide

LocalWhisper uses [WhisperKit](https://github.com/argmaxinc/WhisperKit), which provides optimized CoreML models for Apple Silicon.

## Model Comparison

| Model | Parameters | Disk Size | Speed Factor* | WER** | Memory | Best For |
|-------|------------|-----------|---------------|-------|--------|----------|
| `tiny` | 39M | ~75MB | ~180x | ~17% | ~1GB | Quick tests |
| `tiny.en` | 39M | ~75MB | ~190x | ~16% | ~1GB | English-only, fastest |
| `base` | 74M | ~140MB | ~111x | ~15% | ~1GB | **Default, good balance** |
| `base.en` | 74M | ~140MB | ~120x | ~14% | ~1GB | English-only dictation |
| `small` | 244M | ~460MB | ~35x | ~13% | ~2GB | Better accuracy |
| `small.en` | 244M | ~460MB | ~40x | ~12% | ~2GB | English, balanced |
| `medium` | 769M | ~1.5GB | ~15x | ~11% | ~4-5GB | High accuracy |
| `medium.en` | 769M | ~1.5GB | ~18x | ~10% | ~4-5GB | English, professional |
| `large-v3` | 1550M | ~3GB | ~8x | ~8% | ~6-7GB | Maximum accuracy |
| `large-v3_turbo` | 809M | ~1.6GB | ~25x | ~9% | ~4GB | **Fast + accurate** |

> \* **Speed Factor**: Seconds of audio processed per second of wall-clock time on M4 chip. Higher is faster.  
> \*\* **WER**: Word Error Rate (lower is better). Based on [earnings22 dataset](https://huggingface.co/datasets/argmaxinc/earnings22-12hours).

## Real-World Latency

How long you'll wait after releasing the record button:

| Audio Length | tiny | base | small | medium | large-v3 | turbo |
|--------------|------|------|-------|--------|----------|-------|
| 5 seconds | 0.03s | 0.05s | 0.14s | 0.33s | 0.63s | 0.20s |
| 15 seconds | 0.08s | 0.14s | 0.43s | 1.00s | 1.88s | 0.60s |
| 30 seconds | 0.17s | 0.27s | 0.86s | 2.00s | 3.75s | 1.20s |
| 60 seconds | 0.33s | 0.54s | 1.71s | 4.00s | 7.50s | 2.40s |

*Measured on M4 Mac mini. M1/M2/M3 will be slightly slower.*

## Which Model Should I Use?

| Your Priority | Recommended Model | Why |
|---------------|-------------------|-----|
| 🚀 **Speed** (instant dictation) | `base.en` or `tiny.en` | Near-instant, good enough accuracy |
| ⚖️ **Balanced** (general use) | `base` or `small.en` | Good accuracy, minimal latency |
| 🎯 **Accuracy** (professional) | `large-v3_turbo` | Best speed/accuracy ratio |
| 🏆 **Maximum quality** | `large-v3` | Lowest error rate, worth the wait |
| 🌍 **Multilingual** | `small` or `large-v3` | Full language support (avoid `.en`) |
| 💾 **Low memory** (8GB Mac) | `tiny` or `base` | Fits comfortably in RAM |

## Changing Models

1. Click the LocalWhisper icon in the menu bar
2. Click ⚙️ Settings (or the gear icon)
3. Go to **Model** tab
4. Select your preferred model

The first time you select a model, it will be downloaded from HuggingFace (~30s to 5min depending on size and connection).

## Why WhisperKit? (vs whisper.cpp)

LocalWhisper uses **WhisperKit** instead of other Whisper implementations like **whisper.cpp**:

| Aspect | WhisperKit | whisper.cpp |
|--------|------------|-------------|
| **Apple Silicon optimization** | ✅ Neural Engine via CoreML | ⚠️ Metal/CPU only |
| **Hardware acceleration** | Neural Engine + GPU + CPU | GPU (Metal) + CPU |
| **Swift integration** | Native Swift API | Requires C/FFI bridge |
| **Model format** | CoreML (.mlmodelc) | GGML (.bin) |
| **Quantization** | CoreML optimized | 4-bit, 8-bit options |
| **Maintenance** | Active (Argmax) | Active (ggerganov) |

**Bottom line**: On Apple Silicon, WhisperKit leverages the dedicated Neural Engine that whisper.cpp cannot access, resulting in better performance for most use cases.

## Benchmarking

Run the reference benchmark script:

```bash
swift benchmark_models.swift
```

For live benchmarking with your hardware, use the [WhisperKit CLI](https://github.com/argmaxinc/WhisperKit):

```bash
git clone https://github.com/argmaxinc/WhisperKit
cd WhisperKit

swift run whisperkit-cli transcribe \
  --audio-path /path/to/audio.wav \
  --model openai_whisper-base \
  --verbose
```
