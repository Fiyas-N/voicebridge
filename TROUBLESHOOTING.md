 
 
 
 
 
 
 
 
 
 
 
 
 # VoiceBridge - Troubleshooting Guide

## Common Issues & Solutions

### Build Issues

#### Issue: "google-services.json not found"
**Solution:**
1. Download from Firebase Console
2. Place in `android/app/` directory
3. Run `flutter clean && flutter pub get`

#### Issue: "Firebase not initialized"
**Solution:**
- Ensure `await Firebase.initializeApp()` is in `main.dart`
- Check `.env` file exists and has correct keys
- Verify `google-services.json` is in correct location

#### Issue: "NDK version mismatch"
**Solution:**
- Already fixed in `android/app/build.gradle.kts`
- NDK version set to `27.0.12077973`

### API Issues

#### Issue: "Speech-to-Text API error 403"
**Solution:**
- Verify API key is correct in `.env`
- Enable Speech-to-Text API in Google Cloud Console
- Check API key restrictions

#### Issue: "OpenAI API error 401"
**Solution:**
- Verify API key starts with `sk-`
- Check API key is active
- Verify billing is set up

#### Issue: "Azure Speech error 401"
**Solution:**
- Check subscription key is correct
- Verify region matches (e.g., `eastus`)
- Ensure Speech Service is created

### Runtime Issues

#### Issue: "No speech detected"
**Solution:**
- Check microphone permissions
- Verify audio file is not empty
- Test with longer recording (>5 seconds)

#### Issue: "Processing takes too long"
**Solution:**
- Normal: 10-20 seconds for 30-second audio
- Check internet connection
- Verify all API services are responding

#### Issue: "App crashes on recording"
**Solution:**
- `record` package is currently disabled
- Audio recording uses stub implementation
- Re-enable when NDK 27 is stable

### Firebase Issues

#### Issue: "User not authenticated"
**Solution:**
- Sign out and sign in again
- Check Firebase Authentication is enabled
- Verify email/password provider is enabled

#### Issue: "Database permission denied"
**Solution:**
- Check security rules in Firebase Console
- Ensure user is authenticated
- Verify rules allow user access

### Data Issues

#### Issue: "Sessions not syncing"
**Solution:**
- Check internet connection
- Verify Firebase database URL is correct
- Check user is authenticated

#### Issue: "Audio files missing"
**Solution:**
- Audio files are stored locally only
- Check app permissions for storage
- Files auto-delete after 30 days

## Testing Commands

### Check Environment
```bash
flutter doctor -v
```

### Clean Build
```bash
flutter clean
flutter pub get
flutter run
```

### Check Devices
```bash
flutter devices
```

### Build Release
```bash
flutter build apk --release
```

## Debug Logs

Enable verbose logging:
```dart
// In main.dart
debugPrint('Firebase initialized: ${Firebase.apps.isNotEmpty}');
debugPrint('API keys valid: ${ApiConfig.validateAll()}');
```

## Getting Help

1. Check documentation files
2. Review error messages carefully
3. Check Firebase Console for errors
4. Verify API usage in respective consoles
5. Test with sample data first

## Contact

For issues not covered here, check:
- Technical Specification
- Quick Start Guide
- Deployment Checklist

---

**Most issues are related to API configuration. Double-check all API keys!**
