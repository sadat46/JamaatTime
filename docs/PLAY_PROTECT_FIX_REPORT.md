# Play Protect Fix Report

## Summary

Jamaat Time release APKs were being warned or blocked by Google Play Protect during fresh install/update because the public APK shipped sensitive Family Safety capabilities even when those features were optional and off by default.

The debug install did not show the Play Protect warning in the observed test, but the release APK initially did. After Android build separation was implemented and the release APK was rebuilt as the `prayerOnly` flavor, Play Protect allowed installation.

Play Protect evaluates APK contents, manifest declarations, and sensitive capabilities at install time. It does not only evaluate whether a feature is currently enabled in the app UI.

## Root Cause

The public/default APK included Family Safety / Focus Guard components that are high-risk when combined:

- `FocusGuardAccessibilityService`
- `BIND_ACCESSIBILITY_SERVICE`
- YouTube-scoped Accessibility monitoring
- Accessibility window-content retrieval
- Accessibility overlay/blocking screen behavior
- YouTube navigation automation and global back fallback
- `FamilySafetyVpnService`
- `BIND_VPN_SERVICE`
- `FOREGROUND_SERVICE_SYSTEM_EXEMPTED`
- `foregroundServiceType="systemExempted"`

The feature being optional was not enough because the services and permissions were still declared in the production APK manifest.

## Fix Implemented

Android product flavors were added:

- `prayerOnly`
- `familySafetyFull`

`prayerOnly` is the production/default public APK:

- `applicationId = com.sadat.jamaattime`
- Does not include `BIND_ACCESSIBILITY_SERVICE`
- Does not include `BIND_VPN_SERVICE`
- Does not include `FOREGROUND_SERVICE_SYSTEM_EXEMPTED`
- Does not include `FocusGuardAccessibilityService`
- Does not include `FamilySafetyVpnService`
- Keeps only safe Family Safety guide pages that do not require sensitive services

`familySafetyFull` is internal/diagnostic only:

- `applicationId = com.sadat.jamaattime.safety`
- May include Focus Guard and VPN components
- Keeps disclosure screens
- Must not be distributed publicly

Sensitive native files/resources were moved into:

```text
android/app/src/familySafetyFull/...
```

Production-safe stubs were added for:

```text
FocusGuardChannel
FamilySafetyChannel
```

The Dart compile-time flag was added:

```dart
const bool kFamilySafetyFull = bool.fromEnvironment('FAMILY_SAFETY_FULL');
```

Family Safety UI is now gated:

- Safe guides remain in the public build.
- Focus Guard, VPN Website Protection, Parent Control, and Activity Summary are visible only in the full/internal build.

Release debug-signing fallback was removed so release builds require the production signing key.

The fix release version was bumped from:

```text
2.0.33+10 -> 2.0.34+11
```

Note: later local development may move `pubspec.yaml` beyond this version. The important release rule is that every production update must increase `versionCode`.

## Build Commands

Production release APK:

```bash
flutter build apk --release --flavor prayerOnly --dart-define=FAMILY_SAFETY_FULL=false --build-name=2.0.34 --build-number=11
```

Production split-per-ABI APKs:

```bash
flutter build apk --release --split-per-abi --flavor prayerOnly --dart-define=FAMILY_SAFETY_FULL=false --build-name=2.0.34 --build-number=11
```

Internal diagnostic APK:

```bash
flutter build apk --debug --flavor familySafetyFull --dart-define=FAMILY_SAFETY_FULL=true
```

Do not distribute `familySafetyFull` APKs publicly. Do not distribute debug APKs.

## Verification Commands

Set paths in PowerShell:

```powershell
$Aapt = "C:\Users\SADAT\AppData\Local\Android\sdk\build-tools\36.0.0\aapt.exe"
$Signer = "C:\Users\SADAT\AppData\Local\Android\sdk\build-tools\36.0.0\apksigner.bat"
$Apk = "build\app\outputs\apk\prayerOnly\release\app-prayerOnly-release.apk"
$Manifest = "build\app\intermediates\merged_manifest\prayerOnlyRelease\processPrayerOnlyReleaseMainManifest\AndroidManifest.xml"
```

Confirm production package/version and no debug marker:

```powershell
& $Aapt dump badging $Apk | Select-String "package:|application-debuggable"
```

Expected:

- `package: name='com.sadat.jamaattime'`
- expected `versionCode`
- no `application-debuggable`

Confirm sensitive permissions are absent from the APK:

```powershell
& $Aapt dump permissions $Apk | Select-String "BIND_ACCESSIBILITY_SERVICE|BIND_VPN_SERVICE|FOREGROUND_SERVICE_SYSTEM_EXEMPTED|SYSTEM_ALERT_WINDOW|QUERY_ALL_PACKAGES|PACKAGE_USAGE_STATS"
```

Expected: no output.

Confirm sensitive declarations are absent from the merged production manifest:

```powershell
Select-String -Path $Manifest -Pattern "BIND_ACCESSIBILITY_SERVICE","FocusGuardAccessibilityService","BIND_VPN_SERVICE","FamilySafetyVpnService","FOREGROUND_SERVICE_SYSTEM_EXEMPTED","systemExempted"
```

Expected: no output.

Confirm production signer:

```powershell
& $Signer verify --print-certs $Apk
```

Expected production signer SHA-256:

```text
2e97208664f2dd0777633e26a626eb972e71045934c609df4111f215d68b68e1
```

Optional source-set sanity check:

```powershell
rg -n -e BIND_ACCESSIBILITY_SERVICE -e BIND_VPN_SERVICE -e FOREGROUND_SERVICE_SYSTEM_EXEMPTED -e systemExempted -e FocusGuardAccessibilityService -e FamilySafetyVpnService -e VpnService -e AccessibilityService android/app/src/main android/app/src/prayerOnly
```

Expected: no output.

## Release Checklist

Before sharing a production APK:

- Build only `prayerOnly` for public distribution.
- Keep production package name as `com.sadat.jamaattime`.
- Ensure `versionCode` is higher than the previous public release.
- Verify the APK is not debuggable.
- Verify the APK is signed with the production key.
- Verify the merged `prayerOnlyRelease` manifest has no Accessibility/VPN service declarations.
- Verify `FOREGROUND_SERVICE_SYSTEM_EXEMPTED` is absent from the public APK.
- Install the APK fresh and as an update over the previous production-signed `com.sadat.jamaattime` build.
- Confirm Play Protect allows installation.

## Future Rules

- Never declare Accessibility, VPN, overlay, device-admin, package-query-all, install-packages, or system-exempted foreground-service capabilities in `src/main` unless they are intended for every public APK.
- Any sensitive Family Safety feature must live only in `src/familySafetyFull`.
- Public UI must not link to setup screens for services that are not declared in the public APK.
- Do not use release debug-signing fallback.
- Do not publish or sideload debug builds for users.
- Do not change the production package name.
- Keep `familySafetyFull` side-by-side with a separate package name only for diagnostics.
- Treat merged manifest inspection as mandatory before every release.

## Remaining Risk

`familySafetyFull` still contains the sensitive Focus Guard/VPN behavior by design, so it may still trigger Play Protect if sideloaded. That is acceptable only for internal diagnosis and must not be treated as a production APK.

Users who previously installed an old debug-signed APK or a different package name may still need to uninstall/reinstall because Android update trust depends on package name and signing key continuity.
