# Vandana1 — Native Android Kotlin

Vandana1 now uses a clean native Android/Kotlin APK client.

## Architecture
- Android app: Kotlin + Gradle
- Backend: existing FastAPI Railway service
- Angel One SmartAPI: server-side session or runtime login
- NSE/MCP/strategy/AI logic remains in the backend
- No Flutter/Dart APK build path
- No paper/demo order placement in the native client

## Build
GitHub Actions workflow: .github/workflows/build-native-kotlin.yml

The APK is built as app-release.apk and uploaded as the vandana1-native-release artifact.
