# Notification Sounds Setup

This document explains how to add custom notification sounds to the Jamaat Time app.

## 📁 Required Sound Files

### Android (MP3 format)
- **File**: `android/app/src/main/res/raw/adhan.mp3`
- **Format**: MP3
- **Duration**: 15-30 seconds recommended
- **Quality**: Clear, audible adhan sound

### iOS (WAV format)
- **File**: `ios/Runner/Resources/adhan.wav`
- **Format**: WAV
- **Duration**: 15-30 seconds recommended
- **Quality**: Clear, audible adhan sound

## 🎵 Sound Requirements

1. **File Size**: Keep under 1MB for optimal performance
2. **Duration**: 15-30 seconds is ideal for notifications
3. **Quality**: Clear, professional adhan recording
4. **Format**: 
   - Android: MP3
   - iOS: WAV

## 📋 Setup Instructions

### Step 1: Prepare Your Sound Files
1. Obtain a clear adhan sound recording
2. Convert to appropriate format (MP3 for Android, WAV for iOS)
3. Ensure file size is reasonable (< 1MB)

### Step 2: Add to Android
1. Place your `adhan.mp3` file in: `android/app/src/main/res/raw/`
2. Make sure the filename is exactly `adhan.mp3`

### Step 3: Add to iOS
1. Place your `adhan.wav` file in: `ios/Runner/Resources/`
2. Make sure the filename is exactly `adhan.wav`

### Step 4: Rebuild the App
```bash
flutter clean
flutter pub get
flutter run
```

## 🔧 Current Configuration

The app is configured to:
- ✅ Play custom adhan sound for all notifications
- ✅ Include vibration pattern: [0, 500, 200, 500, 200, 500]
- ✅ Use high priority notifications
- ✅ Fallback to system default sound if custom sound fails

## 🎯 Notification Types with Sound

1. **Prayer Notifications**: 20 minutes before each prayer
2. **Jamaat Notifications**: 10 minutes before Jamaat time
3. **Test Notifications**: When testing the notification system

## 🚨 Troubleshooting

### Sound Not Playing
1. Check file format and naming
2. Ensure file is in correct directory
3. Verify file permissions
4. Check device volume settings

### Fallback Behavior
If custom sound fails to load, the app will:
- Use system default notification sound
- Continue to show notifications
- Log error messages for debugging

## 📱 Testing

Use the notification test button (🔔) in the app to verify:
- ✅ Sound plays correctly
- ✅ Vibration works
- ✅ Notification appears
- ✅ Timing is accurate

## 🎵 Recommended Sources

For adhan sounds, consider:
- Islamic apps and websites
- Mosque recordings
- Professional Islamic audio libraries
- Ensure you have proper rights/permissions for the audio

## 📞 Support

If you encounter issues with notification sounds:
1. Check the console logs for error messages
2. Verify file paths and naming
3. Test with different audio files
4. Ensure device notification settings are enabled 