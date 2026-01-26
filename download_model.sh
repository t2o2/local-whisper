#!/bin/bash
# Script to manually download WhisperKit models
# Usage: ./download_model.sh [model_name]
# Default: openai_whisper-base

MODEL_NAME="${1:-openai_whisper-base}"
BASE_URL="https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/main"
CACHE_DIR="$HOME/.cache/huggingface/hub/models--argmaxinc--whisperkit-coreml/snapshots/main"

echo "Downloading WhisperKit model: $MODEL_NAME"
echo "Destination: $CACHE_DIR/$MODEL_NAME"
echo ""

mkdir -p "$CACHE_DIR/$MODEL_NAME"
cd "$CACHE_DIR/$MODEL_NAME"

# Model files to download
FILES=(
    "AudioEncoder.mlmodelc/analytics/coremldata.bin"
    "AudioEncoder.mlmodelc/coremldata.bin"
    "AudioEncoder.mlmodelc/metadata.json"
    "AudioEncoder.mlmodelc/model.mil"
    "AudioEncoder.mlmodelc/weights/weight.bin"
    "MelSpectrogram.mlmodelc/analytics/coremldata.bin"
    "MelSpectrogram.mlmodelc/coremldata.bin"
    "MelSpectrogram.mlmodelc/metadata.json"
    "MelSpectrogram.mlmodelc/model.mil"
    "TextDecoder.mlmodelc/analytics/coremldata.bin"
    "TextDecoder.mlmodelc/coremldata.bin"
    "TextDecoder.mlmodelc/metadata.json"
    "TextDecoder.mlmodelc/model.mil"
    "TextDecoder.mlmodelc/weights/weight.bin"
    "config.json"
    "generation_config.json"
    "merges.txt"
    "tokenizer.json"
    "vocab.json"
)

# Create directory structure
echo "Creating directory structure..."
mkdir -p AudioEncoder.mlmodelc/{analytics,weights}
mkdir -p MelSpectrogram.mlmodelc/analytics
mkdir -p TextDecoder.mlmodelc/{analytics,weights}

# Download each file
for file in "${FILES[@]}"; do
    echo "Downloading: $file"
    curl -sL "$BASE_URL/$MODEL_NAME/$file" -o "$file" --create-dirs
done

echo ""
echo "Download complete!"
echo "Model location: $CACHE_DIR/$MODEL_NAME"
echo ""
echo "You can now run LocalWhisper and it should use the cached model."
