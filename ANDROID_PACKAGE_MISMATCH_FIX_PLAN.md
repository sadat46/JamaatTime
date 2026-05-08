# Android Package Mismatch Fix Plan

## Summary

The update mismatch is caused by Android app identity drift. Older installs used `com.example.jamaat_time`; current builds use `com.sadat.jamaattime`. Some builds may also differ by signing key because release builds fall back to debug signing when `android/key.properties` is missing.

## Key Changes

- Keep the production package as `com.sadat.jamaattime`; do not revert to `com.example.jamaat_time`.
- Remove the debug-signing fallback from Android release builds so `flutter build apk --release` fails if `android/key.properties` or `jamaattime-release.jks` is missing.
- Add a release verification script or documented checklist that checks every APK before upload:
  - package name is `com.sadat.jamaattime`
  - signer SHA-256 is `2e97208664f2dd0777633e26a626eb972e71045934c609df4111f215d68b68e1`
  - version code is higher than the previous uploaded artifact
- Update the in-app update dialog and release notes to warn legacy users:
  - if update install says package mismatch, uninstall the old Jamaat Time app first, then install the latest APK
  - saved Firebase/account data remains server-side, but local-only settings/widgets may need setup again
- Prefer publishing one universal APK or clearly labeled ABI-specific APKs; avoid uploading mixed old/new package artifacts under the same release.

## Test Plan

- Run `flutter build apk --release`.
- Inspect generated APK with `aapt dump badging` and confirm package `com.sadat.jamaattime`.
- Inspect generated APK with `apksigner verify --print-certs` and confirm the expected release certificate SHA-256.
- Test install over a current `com.sadat.jamaattime` release-signed build; it must update in place.
- Test install over an old `com.example.jamaat_time` build; confirm Android rejects it, then uninstall old app and confirm fresh install succeeds.

## Assumptions

- `com.sadat.jamaattime` is the permanent production package.
- The release keystore at `android/jamaattime-release.jks` is the permanent production signing key.
- Legacy `com.example.jamaat_time` users cannot be updated in place unless a separately signed legacy migration APK exists, which is out of scope for the default fix.
