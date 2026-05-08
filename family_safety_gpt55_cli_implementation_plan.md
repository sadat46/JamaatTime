# Family Safety Implementation Plan for Jamaat Time App

**Target agent:** GPT 5.5 CLI / Codex-style CLI agent  
**App:** Jamaat Time Flutter Android app  
**Goal:** Add a practical, optional **Family Safety** section without increasing Play Protect risk unnecessarily.

> Important: No implementation can guarantee Play Protect will never flag an APK. This plan is designed to minimize risk by keeping the feature optional, transparent, permission-minimal, privacy-friendly, and clearly separated from core prayer/Jamaat functionality.

---

## 1. Product Goal

Implement a **Family Safety** feature that helps users and families reduce exposure to harmful and distracting content while keeping the app's main identity as a prayer time and Jamaat time app.

Main structure:

```text
Settings
└── Family Safety
    ├── Website Protection
    ├── Digital Wellbeing
    ├── Parent Control
    ├── Safe Search Setup
    └── Activity Summary
```

Primary safety requirement:

```text
Do not implement anything that looks hidden, forceful, spyware-like, traffic-monetizing, or permission-abusive.
```

Do not break:

```text
- Prayer time calculation
- Jamaat time sync
- Android home screen widget
- Notifications
- Firebase/Supabase/admin features
- Existing Focus Guard feature
```

---

## 2. Mandatory Play Protect Safety Rules

The CLI agent must follow these rules throughout the implementation:

1. Family Safety must be fully optional.
2. No VPN auto-start without explicit user action.
3. No hidden VPN/background traffic manipulation.
4. No full browsing history collection.
5. No password, payment, message, or page-content inspection.
6. No HTTPS MITM or certificate installation.
7. No ad traffic redirection or monetization.
8. No remote upload of DNS logs in MVP.
9. No AccessibilityService for Website Protection.
10. If AccessibilityService already exists for Shorts/Reels blocking, keep it separate and clearly disclosed.
11. Show clear disclosure before requesting VPN permission.
12. User must be able to turn protection off.
13. Parent PIN can guard settings, but must not permanently trap the user.
14. Keep permissions minimal.
15. Do not request unrelated permissions.
16. Do not use suspicious package rename tricks.
17. Do not hide foreground service notifications.
18. Do not block all internet if DNS parsing fails.
19. Fail open for unknown VPN/DNS parser errors.
20. Keep Website Protection clearly named under Family Safety.

---

## 3. Recommended Release Strategy

For lowest Play Protect risk, do not release VPN filtering immediately.

Recommended sequence:

```text
Release 1:
- Family Safety UI
- Safe Search Setup
- Private DNS guide
- Parent Control
- Local blocklist settings only

Release 2:
- Android VPN consent bridge
- Local VPN DNS filter MVP
- Privacy-safe Activity Summary

Release 3:
- Digital Wellbeing integration
- Shorts/Reels status integration
- Final policy hardening
```

---

# Phase 0: Audit Existing Project

## Objective
Understand the current architecture and identify Play Protect-sensitive areas before coding.

## Scope
Audit only relevant files:

```text
- Settings screens
- Focus Guard screens
- AndroidManifest.xml
- MainActivity.kt
- MethodChannel/native bridge files
- Existing AccessibilityService files, if any
- Existing overlay-related files, if any
- Existing storage/preferences services
- Existing routing/navigation files
```

## Output Required Before Coding

```text
1. Existing settings architecture
2. Existing permission usage
3. Existing Focus Guard implementation summary
4. Current Play Protect risk points
5. Files to modify
6. Files not to touch
7. Proposed implementation folders
```

## Rules

```text
- No code changes in Phase 0.
- Do not scan unrelated feature folders unless needed for build/navigation understanding.
- Do not modify prayer/Jamaat logic.
```

## Acceptance Criteria

```text
- Clear audit summary produced.
- Risky existing permissions identified.
- Implementation scope is narrow and file-specific.
```

---

# Phase 1: Family Safety UI Shell

## Objective
Add the user-facing Family Safety section with no sensitive behavior.

## Add

```text
Settings → Family Safety
```

Family Safety sections:

```text
1. Website Protection
2. Digital Wellbeing
3. Parent Control
4. Safe Search Setup
5. Activity Summary
6. Privacy & Safety Explanation
```

## UI Direction

```text
- Clean white/premium design
- Calm family-friendly language
- No alarming adult/gambling wording on main settings row
- Use existing app theme and components
- Avoid debug-looking cards
```

Suggested subtitle:

```text
Help protect your family from harmful and distracting online content.
```

## Likely New Flutter Files

```text
lib/features/family_safety/
├── family_safety_page.dart
├── website_protection_page.dart
├── digital_wellbeing_page.dart
├── parent_control_page.dart
├── safe_search_setup_page.dart
├── activity_summary_page.dart
├── family_safety_models.dart
└── family_safety_storage.dart
```

Adjust paths based on existing app architecture.

## Safety Rules

```text
- No VPN.
- No AccessibilityService change.
- No new sensitive permission.
- UI only.
```

## Acceptance Criteria

```text
- App builds.
- Settings navigation works.
- Existing features unchanged.
- No new dangerous permission added.
```

---

# Phase 2: Safe Search + Private DNS Guide

## Objective
Implement low-risk guidance before any VPN feature.

## Safe Search Setup Page

Add guides for:

```text
- Google SafeSearch
- YouTube Restricted Mode
- Android Private DNS
- Browser safe mode tips
```

Recommended DNS hostname field:

```text
family-filter-dns.cleanbrowsing.org
```

## Required UI Actions

```text
- Copy DNS hostname
- Show step-by-step Android Private DNS setup
- Open Android network settings if possible
```

Use Android intent fallback if direct Private DNS settings intent is unreliable:

```text
Settings.ACTION_WIRELESS_SETTINGS
```

## Safety Rules

```text
- Do not automatically change DNS.
- Do not enable VPN.
- Do not add AccessibilityService.
- No sensitive permission.
```

## Acceptance Criteria

```text
- User can read/copy DNS guide.
- User can open settings manually.
- No Play Protect-sensitive behavior added.
```

---

# Phase 3: Parent Control Local PIN

## Objective
Add local PIN protection for Family Safety settings.

## Features

```text
- Create PIN
- Change PIN
- Require PIN to change Family Safety settings
- Require PIN before disabling Website Protection
- Optional disable delay timer
- Forgot PIN/reset flow with warning
```

## Security Rules

```text
- Store PIN hash only.
- Never store plain PIN.
- Use local secure storage if available.
- Do not upload PIN.
- Do not permanently lock user out.
```

## Suggested Storage

Use the app's existing secure/local storage. If unavailable, add minimal secure storage dependency only after checking project standards.

## Acceptance Criteria

```text
- PIN setup works.
- PIN validation works.
- PIN protects only Family Safety settings.
- Emergency reset is possible.
- No network dependency.
```

---

# Phase 4: Local Blocklist Data Layer

## Objective
Implement blocklist logic without VPN.

## Categories

```text
- Adult
- Gambling
- Proxy/VPN bypass
- Custom blocked domains
- Whitelisted domains
```

## Data Model

```text
WebsiteProtectionSettings
- enabled: bool
- blockAdult: bool
- blockGambling: bool
- blockProxyBypass: bool
- customBlockedDomains: List<String>
- whitelistedDomains: List<String>
- lastUpdatedAt: DateTime?
```

## Domain Normalization Rules

```text
- Lowercase all domains
- Remove https:// and http://
- Remove path/query/fragment
- Remove leading www.
- Trim spaces
- Support subdomain matching
- Whitelist overrides blocklist
```

Example:

```text
example.com blocks:
- example.com
- sub.example.com

example.com does not block:
- badexample.com
```

## Likely Files

```text
lib/features/family_safety/domain/
├── domain_normalizer.dart
├── block_category.dart
├── domain_block_matcher.dart
└── website_protection_settings.dart

lib/features/family_safety/data/
└── blocklist_repository.dart
```

## Acceptance Criteria

```text
- Unit tests for domain normalization.
- Unit tests for whitelist override.
- Unit tests for subdomain matching.
- No VPN yet.
- No network upload.
```

---

# Phase 5: Android Native VPN Consent Bridge

## Objective
Prepare Android VPN permission flow without starting VPN filtering yet.

## Important

```text
Do not start VPN in this phase.
Only implement permission/status bridge.
```

## Native Android Additions

Likely files:

```text
android/app/src/main/kotlin/.../family_safety/
├── VpnPermissionManager.kt
└── FamilySafetyChannel.kt
```

## MethodChannel Methods

```text
isVpnPrepared()
requestVpnPermission()
getVpnStatus()
```

## Consent Flow

Before Android VPN permission dialog, show in-app disclosure:

```text
Website Protection uses Android VPN permission only to check website domains and block harmful categories such as adult, gambling, and proxy bypass sites.

It does not read messages, passwords, payment information, or full page content.

DNS logs are not uploaded in this version.
```

Then call:

```kotlin
VpnService.prepare(context)
```

## Safety Rules

```text
- No VPN starts automatically.
- No background service starts.
- No boot receiver.
- No hidden permission dialog.
```

## Acceptance Criteria

```text
- User sees in-app disclosure first.
- Android VPN consent appears only after user action.
- Permission denial is handled gracefully.
- Existing app behavior unchanged.
```

---

# Phase 6: Local VPN DNS Filter MVP

## Objective
Implement minimal DNS/domain-level filtering using Android VpnService.

## Scope

```text
- DNS/domain-level filtering only
- Block blocked domains/categories
- Allow safe domains
- No HTTPS inspection
- No page content inspection
- No certificate installation
- No remote DNS log upload
```

## Native Android Files

```text
android/app/src/main/kotlin/.../family_safety/vpn/
├── FamilySafetyVpnService.kt
├── DnsPacketParser.kt
├── DnsResponseBuilder.kt
├── DomainBlockMatcher.kt
├── VpnStatusRepository.kt
└── VpnNotificationHelper.kt
```

## Flutter Bridge Methods

```text
startWebsiteProtection()
stopWebsiteProtection()
getWebsiteProtectionStatus()
```

## VPN Behavior

```text
- Start only after user taps Enable.
- Require VPN permission first.
- Show persistent foreground notification:
  “Family Safety Website Protection is active”
- Notification action: Open Family Safety settings.
- Do not hide the notification.
- Do not auto-restart aggressively.
- Do not block all internet if parser fails.
- Fail open for unknown parsing errors.
```

## DNS Filter Behavior

```text
If domain is blocked:
- Return blocking DNS response or prevent DNS resolution safely.
- Add local summary event only.

If domain is allowed:
- Forward/allow DNS normally.
```

## Minimum Testing Domains

Use safe/internal test domains or configured test entries. Do not hardcode explicit adult domains into logs/screenshots.

## Acceptance Criteria

```text
- Test blocked domain is blocked.
- Test gambling category domain is blocked if configured.
- Whitelist works.
- Normal browsing works.
- VPN status visible.
- User can stop protection.
- No full browsing history stored.
- No DNS logs uploaded.
```

---

# Phase 7: Activity Summary Privacy-Safe

## Objective
Show useful protection summary without invading privacy.

## Allowed Data

```text
- Blocked count
- Category
- Date/time
- Protection status
```

## Avoid

```text
- Full URL
- Full browsing history
- Page title
- Search query
- User account linking
- Remote upload
```

## Example UI

```text
Today
Adult content blocked: 5
Gambling blocked: 2
Proxy bypass blocked: 1
```

## Features

```text
- Daily summary
- Weekly summary
- Clear activity summary
- Privacy explanation
```

## Acceptance Criteria

```text
- Summary is local only.
- Clear data button works.
- No sensitive browsing record is shown.
- No remote sync/upload.
```

---

# Phase 8: Digital Wellbeing Integration

## Objective
Integrate existing Shorts/Reels blocker status without mixing it with VPN.

## Rules

```text
- Do not implement new AccessibilityService in this task unless explicitly requested.
- If Focus Guard already exists, show status and navigation only.
- Keep Website Protection and Digital Wellbeing technically separate.
```

## Digital Wellbeing Page

```text
Digital Wellbeing
├── Shorts/Reels protection status
├── Distracting app limit placeholder or existing link
├── Screen break reminder placeholder
└── Usage summary placeholder
```

## If AccessibilityService Already Exists

Add clear disclosure:

```text
Digital Wellbeing may use Accessibility permission only to detect selected distracting screens such as Shorts/Reels. It does not read private messages, passwords, or payment information.
```

## Acceptance Criteria

```text
- Website Protection uses VPN/DNS only.
- Shorts/Reels uses separate Focus Guard only.
- Clear separation in UI and code.
- No new AccessibilityService abuse.
```

---

# Phase 9: Play Protect / Policy Hardening

## Objective
Audit the final implementation for Play Protect and Play Store safety.

## Required Checks

```text
1. AndroidManifest permissions are minimal.
2. VpnService declaration is correct.
3. No hidden service start.
4. No boot auto-start unless explicit user-enabled setting exists.
5. No suspicious package rename tricks.
6. No AccessibilityService abuse.
7. No overlay abuse for website blocking.
8. No traffic redirection for ads/monetization.
9. No DNS logs uploaded.
10. No sensitive data collection.
11. App has visible privacy explanation page.
12. VPN feature is clearly named Website Protection / Family Safety.
13. Play Console VPN declaration draft is prepared.
14. Privacy policy paragraph is prepared.
```

## Output Required

```text
- Modified files list
- New files list
- Permissions added
- Data collected
- Data not collected
- Remaining Play Protect risks
- Manual test checklist
```

## Acceptance Criteria

```text
- No unrelated permissions.
- No hidden behavior.
- Clear disclosure exists.
- User can disable the feature.
- Existing app features still work.
```

---

# Phase 10: Manual Test Checklist

## Devices

Test on:

```text
- Android 10
- Android 12
- Android 13+
- Samsung device
- Oppo/Realme device if available
```

## Test Cases

```text
1. Fresh install.
2. Open Settings → Family Safety.
3. Open Safe Search Setup.
4. Copy Private DNS hostname.
5. Create Parent PIN.
6. Change Parent PIN.
7. Enable Website Protection.
8. Confirm disclosure appears before VPN permission.
9. Confirm Android VPN permission appears.
10. Deny VPN permission and confirm no crash.
11. Allow VPN permission and enable protection.
12. Confirm VPN notification is visible.
13. Test blocked domain.
14. Test gambling category domain.
15. Test normal safe websites.
16. Test whitelist.
17. Disable protection with PIN.
18. Test emergency reset/forgot PIN flow.
19. Restart app and verify correct status.
20. Restart phone and verify no aggressive/hidden behavior.
21. Confirm no crash if DNS parser fails.
22. Confirm existing prayer times still work.
23. Confirm Jamaat time sync still works.
24. Confirm home screen widget still works.
25. Confirm notifications still work.
26. Confirm existing Focus Guard still works if present.
```

---

# Final Deliverables for CLI Agent

The agent must produce:

```text
1. Implementation summary
2. File-by-file changes
3. New files list
4. Modified files list
5. Permissions added
6. Data safety summary
7. Play Console VPN declaration draft
8. Privacy policy paragraph
9. Test result checklist
10. Remaining risks
```

---

# Play Console VPN Declaration Draft

Use this as a starting draft. Final wording should match the exact implementation.

```text
The app uses Android VpnService only for the optional Family Safety → Website Protection feature.

The feature helps users block harmful website categories such as adult content, gambling, and proxy bypass domains using local DNS/domain-level filtering.

The VPN is started only after the user manually enables Website Protection and approves the Android VPN permission dialog.

The app does not inspect HTTPS page content, does not install certificates, does not read messages, passwords, payment information, or private content, and does not use VPN traffic for advertising or monetization.

In the MVP, blocked activity summaries are stored locally only and DNS logs are not uploaded to any server.
```

---

# Privacy Policy Paragraph Draft

```text
Family Safety is an optional feature designed to help users reduce access to harmful or distracting content.

Website Protection may use Android VPN permission to check website domains and block selected categories such as adult content, gambling, and proxy bypass websites. This filtering is performed at the DNS/domain level.

The app does not read private messages, passwords, payment information, or full web page content. It does not install certificates or perform HTTPS content inspection. In the current version, blocked activity summaries are stored locally on the device and are not uploaded to our servers.

Users can disable Family Safety from the app settings. If Parent Control is enabled, a local PIN may be required to change or disable protection settings.
```

---

# Strong Do-Not-Touch Rules

```text
Do not do unrelated refactor.
Do not modify prayer calculation logic.
Do not modify Jamaat time sync logic.
Do not modify notification sending logic.
Do not modify widget logic unless required for a build fix.
Do not modify admin roles or backend schema.
Do not add analytics for browsing behavior.
Do not upload DNS logs.
Do not add AccessibilityService for Website Protection.
Do not add HTTPS interception.
Do not add ad blocking/traffic monetization.
```

---

# Final Instruction to GPT 5.5 CLI Agent

```text
Implement phase by phase.
After each phase, stop and output:
- Completed files
- Changed files
- Build/test result
- Any risk introduced
- Whether it is safe to continue to the next phase

Never jump directly to VPN implementation before completing UI, disclosure, Parent Control, local blocklist logic, and policy hardening notes.
```
