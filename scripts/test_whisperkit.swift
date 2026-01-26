#!/usr/bin/env swift

import Foundation

// Simple test to check WhisperKit model availability
// Run with: swift test_whisperkit.swift

print("Testing WhisperKit model download...")
print("This requires the WhisperKit package to be available.")
print("")
print("The model names should be like:")
print("  - openai_whisper-tiny")
print("  - openai_whisper-base") 
print("  - openai_whisper-small")
print("  - openai_whisper-medium")
print("  - openai_whisper-large-v3")
print("")
print("Models are downloaded from: https://huggingface.co/argmaxinc/whisperkit-coreml")
print("")
print("Check if you have network access to huggingface.co")

// Test network connectivity
let url = URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/main/config.json")!
let semaphore = DispatchSemaphore(value: 0)

var networkOK = false
let task = URLSession.shared.dataTask(with: url) { data, response, error in
    if let httpResponse = response as? HTTPURLResponse {
        print("HuggingFace response status: \(httpResponse.statusCode)")
        networkOK = httpResponse.statusCode == 200
    }
    if let error = error {
        print("Network error: \(error.localizedDescription)")
    }
    semaphore.signal()
}
task.resume()
semaphore.wait()

if networkOK {
    print("✓ Network connectivity to HuggingFace is OK")
} else {
    print("✗ Cannot reach HuggingFace - check your network/proxy settings")
}
