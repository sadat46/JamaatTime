# Security Policy

## Reporting a Vulnerability

If you discover a security issue, report it privately to the repository owner and do not open a public issue with exploit details.

## Secrets Handling Policy

- Do not commit API keys, access tokens, private keys, or passwords.
- Keep Firebase app config files local:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- Generate Firebase options locally with `flutterfire configure`.
- Ensure Google API keys are restricted by app/package and allowed APIs.

## Key Rotation Runbook

When a key is exposed:

1. Rotate the key in Google Cloud Console.
2. Restrict the new key by application and API.
3. Update local Firebase config files.
4. Regenerate `lib/firebase_options.dart`.
5. Purge leaked values from Git history.
6. Force-push rewritten history.
7. Verify no leaked values remain in working tree or history.

## Incident Notes

- 2026-02-24: Firebase API keys were detected in repository history and purged.
