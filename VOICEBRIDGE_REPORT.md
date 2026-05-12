# VoiceBridge: Final Project Technical Report & System Documentation

## 1. Project Overview
VoiceBridge is an AI-powered English language pedagogy application that provides adaptive tutoring, pronunciation analysis, and conversational practice. It uses a **Dual-Hybrid Acceleration** architecture: when the network and API keys are available, cloud models deliver higher-quality responses and natural TTS; with **Full offline mode** or no connectivity, inference stays on-device so sessions can continue privately on the user’s hardware.

---

## 2. Unified AI Technology Stack

### A. Cloud-Accelerated Core (when online and keys configured)
- **LLM**: **Google Gemini 2.0 Flash** (primary) with **Groq Llama 3.3 70B** as a secondary stream, via `CloudLlmService` (`lib/services/cloud_llm_service.dart`).
- **Speech-to-Text**: **On-device Whisper** (`whisper_flutter_new`, tiny English) for all transcriptions in the current build — not Google Cloud Speech-to-Text. Cloud-only STT is not wired in this repository.
- **TTS**: **Gemini multimodal TTS** (`CloudTtsService`) when online; voice gender follows `TtsService` / SharedPreferences (`tts_voice_is_male`).

### B. Resilient Edge Architecture (100% private offline path)
- **On-device LLM**: **LiteRT / flutter_gemma** loads **Qwen3 0.6B** (`Qwen3-0.6B.litertlm`). The weights are downloaded on first use (or from the model setup gate) via Hugging Face / the plugin file manager — not a GGUF in `assets/`. Offline grammar feedback in the pipeline uses this path when cloud is unavailable or when **Full offline mode** is enabled in Settings.
- **Whisper STT**: **Whisper tiny** (`ggml-tiny.bin`) — stored under app support (or auto-downloaded on first use). Optional bundle path: `assets/models/whisper/ggml-tiny.bin` (`LocalSttService`).
- **Kokoro ONNX**: Offline (and fallback) speech uses **kokoro_tts_flutter** with `assets/models/kokoro/kokoro-v1.0.onnx` and `assets/models/kokoro/voices.json` (Kokoro-class compact vocoder, ~82M-scale behaviour as documented by the upstream package).

---

## 3. Structural Innovation & Major Upgrades

### Visual presentation: Cyber minimal & glass
- **Theme**: Deep space base `#050508`, neon cyan `#00F0FF`, violet accents — see `AppColors` in `lib/core/theme/app_theme.dart`.
- **Typography**: **Outfit** (via `google_fonts`) for the main text theme in `AppTheme.darkTheme`.
- **UI**: Glass-style cards, gradients, and practice orbs on recording / conversation flows (`glass_card`, feedback and conversation layouts).

### Data resilience & schema repair
- **`DatabaseHelper`** (`lib/data/local/database_helper.dart`): Versioned migrations (`onUpgrade`), plus **self-healing** paths when inserts/updates hit missing columns (e.g. `pronunciation_tips`) or when `lesson_progress` is missing — tables/columns are provisioned and the operation is retried. **`onOpen`** provisions `lesson_progress` if the table is absent (e.g. after partial restores).

### Pedagogical behaviour
- **Feedback prompts** (`FeedbackService`): Tutor persona, scores, grammar lines, pronunciation drill, and phonetic-style guidance in the prompt text.
- **Grammar**: Rule-based / heuristic analysis (`GrammarAnalysisService`) runs locally without a separate cloud grammar API in the default pipeline.

---

## 4. Operational Architecture (`lib/`)

### `lib/services/` (routing & inference)
| Module | Role |
| :--- | :--- |
| `CloudLlmService` / `CloudTtsService` | Gemini (and Groq for LLM) when online and allowed. |
| `LocalLlmService` | LiteRT Qwen3 path; hybrid routing with `smartStream` / `generateResponse`. |
| `LocalSttService` | Whisper tiny.en transcription. |
| `TtsService` | Singleton: cloud TTS → Kokoro → `flutter_tts`; persists voice gender. |
| `FeedbackService` | Builds prompts and routes cloud vs on-device completion. |
| `GrammarService` | Offline grammar scoring. |
| `LanguageDetectionService` | Offline language check before heavy models. |

### `lib/screens/`
- **Conversation**: Live turn-taking with on-device STT/LLM/TTS stack (`ConversationService`).
- **Practice / lessons / history**: Backed by `DatabaseHelper` and optional Firebase sync.

---

## 5. Key achievements (verified in codebase)
1. **Static analysis**: Run `dart analyze` / `flutter analyze` in CI or locally before release.
2. **Preferences**: Voice gender and offline-only flag persist via **SharedPreferences** (`tts_voice_is_male`, `use_offline_only`).
3. **Audio pipeline**: Recording uses the `record` package with explicit permission flow; TTS queue and gating live in `TtsService`.

---

## 6. Appendices: Offline model assets (required paths)

Place these files **exactly** as named so Flutter bundles them under `pubspec.yaml` `assets:` entries. Large binaries are **not** committed to git by default; add them locally or in your release pipeline before shipping offline STT/TTS.

| Asset | Path in repository (must match code) |
| :--- | :--- |
| **Whisper tiny (GGML)** | `assets/models/whisper/ggml-tiny.bin` (optional; else first online use downloads to app support) |
| **Kokoro ONNX** | `assets/models/kokoro/kokoro-v1.0.onnx` |
| **Kokoro voice manifest** | `assets/models/kokoro/voices.json` |

**LLM (Qwen3 LiteRT)** is **not** stored under `assets/`; it is installed via `LocalLlmService` / `ModelSetupScreen` into app documents. Optional Hugging Face token: `HUGGINGFACE_TOKEN` in `.env` for gated downloads.

See **`assets/models/whisper/MODEL_SOURCE.txt`** and **`assets/models/kokoro/MODEL_SOURCE.txt`** for acquisition hints.

---

*Documentation aligned with repository behaviour: 2026-05-12 | App `1.0.0+1`*
