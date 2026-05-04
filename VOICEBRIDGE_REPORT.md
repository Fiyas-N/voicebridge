# VoiceBridge: Technical Report & System Documentation

## 1. Overview
VoiceBridge is an AI-powered English language learning application designed with a **Security-First** philosophy. It enables users to practice speaking through interactive AI conversations and structured lessons, providing real-time feedback on pronunciation and grammar while keeping sensitive voice data 100% on-device.

---

## 2. Technology Stack

### Core Framework
- **Flutter (Dart)**: Cross-platform frontend framework.
- **Provider**: Robust state management for authentication, sessions, and UI state.

### On-Device AI Intelligence
- **LLM (Reasoning)**: `llama_cpp_dart` utilizing the **Qwen-1.5B** Instruct model (GGUF). Handles grammar analysis, conversation logic, and feedback generation.
- **STT (Speech-to-Text)**: `whisper_flutter_new` utilizing the **Whisper-tiny** model. Provides fast, offline transcription with per-word confidence scores.
- **TTS (Text-to-Speech)**: `kokoro_tts_flutter` utilizing the **Kokoro-v1.0** ONNX model. Delivers high-quality, natural-sounding AI voices offline.

### Data & Infrastructure
- **Authentication**: Firebase Auth (Email/Password, Display Name management).
- **Cloud Sync**: Google Cloud Firestore (High-level gamification stats like streak, XP, and daily goals).
- **Local Persistence**: SQFlite (SQLite) for detailed session history, transcripts, and feedback logs.
- **Environment**: `flutter_dotenv` for handling secure API keys (e.g., Groq fallback).

---

## 3. System Architecture

VoiceBridge follows a modular architecture separating concerns into distinct layers:

### A. Presentation Layer (`lib/screens`, `lib/widgets`)
- Implements a modern **Glassmorphism** design system.
- Uses high-contrast, vibrant color palettes optimized for legibility.
- Responsive layouts for varied mobile screen sizes.

### B. Business Logic Layer (`lib/providers`)
- **AuthProvider**: Manages user lifecycle and Firebase synchronization.
- **SessionProvider**: Orchestrates the recording-to-analysis workflow.
- **GamificationProvider**: Tracks user progress, streaks, and achievements.

### C. AI Processing Layer (`lib/services`)
- **AIProcessingPipeline**: The "brain" that coordinates multiple services.
- **LocalLlmService**: Manages the life-cycle and inference of the on-device LLM.
- **LocalSttService**: Handles real-time and file-based transcription.
- **TtsService**: Manages audio synthesis and playback.

---

## 4. The Data Journey

How data moves through VoiceBridge during a practice session:

1.  **Audio Capture**: The user speaks into the microphone. The `record` package saves a `.m4a` file locally in the application's temporary directory.
2.  **STT Transcription**: The `LocalSttService` loads the Whisper model. It processes the audio file purely on-device to produce a text transcript and per-word confidence data.
3.  **Grammar & Logic**: The transcript is passed to the `LocalLlmService`.
    - It identifies grammatical errors.
    - It generates a natural, playful AI response for the conversation.
    - it suggests personalized tips for improvement.
4.  **TTS Synthesis**: The AI's response text is converted to a `Uint8List` of audio bytes via the Kokoro ONNX model and played back using `audioplayers`.
5.  **Synchronization**: 
    - Full transcripts and feedback are saved to the local **SQFlite** database.
    - High-level stats (XP +10, Streak +1) are sent to **Firebase Firestore** to ensure progress is never lost across devices.

---

## 5. Security & Privacy Features
- **Zero-Cloud Audio**: Speech is never uploaded to a server for processing. All transcription happens on the user's silicon (GPU/CPU).
- **Local Reasoning**: Sensitive grammar mistakes and personal conversation data are analyzed by the on-device Qwen model.
- **Transparent Logging**: Users can review their full history locally, with easy "Delete Account" options that purge both cloud and local data.

---

## 6. Key Achievements (Latest Version)
- **Unified AI Pipeline**: Fully integrated STT, LLM, and TTS services into a single fluid UX.
- **Concurrency Locks**: Implemented sequential logic in AI services to prevent race conditions during high-frequency inference on mobile hardware.
- **Gamification Engine**: Robust streak and XP tracking synchronized in real-time between local cache and cloud.

---

## 7. Troubleshooting: "Reasoning Engine Not Ready"

If the application displays "Reasoning engine not ready" or fails to transcribe, it is typically because the large AI model files were not included in the build. Due to their size, these models are often managed separately from the code.

### Required Models & Paths

Ensure the following files are placed in the `assets/models/` directory before building:

1.  **LLM (Reasoning)**:
    - **Path**: `assets/models/llm/qwen2.5-1.5b-instruct.gguf`
    - **Download**: [Qwen2.5-1.5B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf) (Recommended: Q4_K_M quantization)

2.  **STT (Transcription)**:
    - **Path**: `assets/models/whisper/ggml-tiny.en.bin`
    - **Download**: [Whisper Tiny English](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin)

### Implementation Note
The app is configured to copy these assets to the device's internal storage on first launch. If you add these files, you must run `flutter clean` and a fresh build to ensure they are bundled correctly.
