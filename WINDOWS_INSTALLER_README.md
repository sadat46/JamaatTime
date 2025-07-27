# Windows Installer Creation Guide

This guide explains how to create a Windows installer for the Jamaat Time app with admin panel.

## Prerequisites

1. **Flutter SDK** - Make sure Flutter is installed and configured for Windows
2. **Windows Development Environment** - Visual Studio with C++ development tools
3. **Inno Setup 6** - For creating the installer (recommended method)

## Method 1: Using Inno Setup (Recommended)

### Step 1: Install Inno Setup
1. Download Inno Setup 6 from: https://jrsoftware.org/isdl.php
2. Install it on your Windows machine

### Step 2: Build the Installer
1. Open Command Prompt or PowerShell in the project directory
2. Run one of the following scripts:

**Using Batch Script:**
```cmd
build_installer_inno.bat
```

**Using PowerShell Script:**
```powershell
.\build_installer_inno.ps1
```

### Step 3: Find the Installer
The installer will be created at:
```
build/windows/installer/JamaatTime_Setup_v1.0.12.exe
```

## Method 2: Using MSIX (Alternative)

### Step 1: Install Dependencies
```cmd
flutter pub get
```

### Step 2: Build the Installer
```cmd
build_windows_installer.bat
```

or

```powershell
.\build_windows_installer.ps1
```

## Method 3: Manual Build

### Step 1: Clean and Build
```cmd
flutter clean
flutter pub get
flutter build windows --release
```

### Step 2: Create Installer
Use Inno Setup Compiler (ISCC.exe) manually:
```cmd
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\jamaat_time_setup.iss
```

## Installer Features

The created installer includes:

- **Modern UI** - Clean, professional installer interface
- **Desktop Shortcut** - Optional desktop icon creation
- **Start Menu Entry** - App appears in Windows Start Menu
- **Uninstall Support** - Proper uninstallation through Control Panel
- **Auto-Launch** - Option to launch app after installation
- **64-bit Support** - Optimized for 64-bit Windows systems
- **Low Privileges** - No admin rights required for installation

## Installer Configuration

The installer is configured with:

- **App Name**: Jamaat Time
- **Version**: 1.0.12
- **Publisher**: Jamaat Time Team
- **Default Location**: `C:\Program Files\Jamaat Time\`
- **Icon**: Uses the app's icon from assets
- **Compression**: LZMA for smaller file size

## Troubleshooting

### Common Issues:

1. **Inno Setup Not Found**
   - Install Inno Setup 6 from the official website
   - Or download the portable version and place ISCC.exe in project root

2. **Build Errors**
   - Ensure Flutter is properly configured for Windows
   - Install Visual Studio with C++ development tools
   - Run `flutter doctor` to check for issues

3. **Missing Dependencies**
   - Run `flutter pub get` to install all dependencies
   - Check that all required packages are in pubspec.yaml

### Build Requirements:

- Windows 10 or later
- Flutter 3.8.1 or later
- Visual Studio 2019 or later with C++ tools
- Inno Setup 6 (for installer creation)

## Distribution

The installer can be distributed by:

1. **Direct Download** - Share the .exe file directly
2. **Website** - Host on your website for download
3. **Email** - Send to users via email
4. **USB/Network** - Copy to USB drives or network shares

## Security Notes

- The installer is digitally signed (if certificate is provided)
- Runs with minimal privileges
- Includes proper uninstall functionality
- No registry modifications required

## Support

For issues with installer creation:
1. Check the build logs for errors
2. Ensure all prerequisites are installed
3. Verify Flutter Windows support is enabled
4. Contact the development team for assistance 