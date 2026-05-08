# Family Safety Implementation Plan v2 — Jamaat Time

**Target agent:** GPT 5.5 CLI / Codex-style CLI agent
**App:** Jamaat Time Flutter Android app (`com.sadat.jamaattime`)
**Goal:** Add an optional **Family Safety** section that helps families reduce exposure to harmful and distracting content **without triggering Play Protect, Play Store policy review failures, or breaking the existing prayer/Jamaat features**.

> Honest framing: No technical pattern can guarantee Play Protect will never warn. What Play Protect actually flags is the *combination* of sensitive APIs (VPN, Accessibility, Overlay), permission breadth, behavioural opacity, and signal mismatch with the listed app purpose. This plan is engineered to keep all of those minimal, optional, transparent, and clearly named.

This v2 supersedes the original. Sections marked **[UPGRADED]** or **[NEW]** are the changes against v1. Untouched sections from v1 are still in force.

---

## 0. What changed vs v1

[NEW] Project-specific facts wired in (package, channel naming, file paths, existing AccessibilityService).
[UPGRADED] Phase 0 audit replaced with a concrete checklist of files actually present.
[NEW] Phase 0.5 — Play Protect risk model (explicit, file-by-file).
[UPGRADED] Phase 5 / 6 — VPN manifest entry now includes `foregroundServiceType` correctly for Android 14+, and avoids `BIND_VPN_SERVICE` as a `uses-permission`.
[NEW] Blocklist sourcing strategy (where the lists actually come from, license/attribution).
[NEW] DoH / Private DNS interaction strategy — what to do when the user has a third-party DoH provider set.
[NEW] Network security config + cleartext policy.
[NEW] Localization (l10n) integration plan.
[NEW] Play Store listing strategy — Family Safety must remain a *secondary* feature, not the headline.
[UPGRADED] Parent Control PIN: brute-force cooldown + tamper-resistant disable.
[NEW] Concrete consent-dialog copy ready to drop in.
[NEW] Data Safety form (Play Console) field-by-field draft.

---

## 1. Product Goal (unchanged)

Settings → **Family Safety** with sub-pages:

```text
Family Safety
├── Website Protection
├── Digital Wellbeing
├── Parent Control
├── Safe Search Setup
└── Activity Summary
```

Must not break:

```text
- Prayer time calculation
- Jamaat time sync
- Android home screen widget
- Notifications (broadcast + scheduled)
- Firebase / Supabase / admin features
- Existing Focus Guard (YouTube Shorts blocker, AccessibilityService)
- Battery optimization flow
- Bookmarks, Calendar, Ebadat, Notice Board
```

---

## 2. Mandatory Play Protect Safety Rules [UPGRADED]

The original 20 rules from v1 are kept verbatim. Adding rules 21–30:

21. **Do not declare `BIND_VPN_SERVICE` as a `uses-permission`.** It is a *service-binding* permission, declared on the `<service>` element only. Declaring it as `<uses-permission>` is a known Play Protect heuristic flag.
22. **VPN service must declare `android:foregroundServiceType="systemExempted"`** (or `"specialUse"` with a justification) for Android 14 (API 34) compliance. Without this, the service crashes on launch on modern devices.
23. **Do not enable VPN at boot.** No `BOOT_COMPLETED` receiver for the VPN service. Boot receiver already exists in the manifest **only** for prayer widget / scheduled notifications — do not extend its scope.
24. **No `QUERY_ALL_PACKAGES`.** If per-app behaviour is ever needed, request only the specific packages via `<queries>` block.
25. **No `REQUEST_INSTALL_PACKAGES`, `BIND_DEVICE_ADMIN`, `MANAGE_EXTERNAL_STORAGE`, `READ_PHONE_STATE`, `READ_SMS`, `READ_CONTACTS`, `READ_CALL_LOG`** under any circumstance for this feature.
26. **No `SYSTEM_ALERT_WINDOW` for Website Protection.** (Focus Guard may use it for the Shorts overlay; do not reuse it for blocking websites.)
27. **No DoH MITM.** If user has Private DNS set to a DoH provider, the VPN cannot see DNS queries. Detect, disclose, and offer the user a choice — do not silently override.
28. **VPN persistent notification must not be hidden, low-priority, or labelled vaguely.** Notification text must say "Family Safety – Website Protection is active" and link to the toggle.
29. **No remote configuration of blocklists in v1.** Lists are bundled as signed assets. (v2 may add a versioned, signed update channel later.)
30. **Crashlytics / analytics must not record domains, URLs, query strings, blocked categories per user, or VPN packet content.** Only aggregate counts (total blocked today) for the local Activity Summary, stored on-device.

---

## 3. Release Strategy (unchanged from v1, with one edit)

Release 1 (UI + guidance only — zero new sensitive APIs):

```text
- Family Safety UI shell
- Safe Search Setup (guidance + intent links)
- Private DNS guide (no auto-config)
- Parent Control (local PIN)
- Local blocklist data layer + unit tests
```

Release 2 (VPN, gated behind explicit opt-in):

```text
- Android VPN consent bridge
- Local VPN DNS filter MVP
- Privacy-safe Activity Summary
```

Release 3 (status integration only):

```text
- Digital Wellbeing page (read-only status of existing Focus Guard)
- Final policy + privacy hardening
- Optional signed blocklist update channel
```

Reasoning: shipping Release 1 first lets the Family Safety section establish a clean review history before the VPN ever appears. By Release 2, reviewers (human or automated) see a feature being extended, not a sudden VPN appearing in a prayer app.

---

# Phase 0 — Audit (already done; baked into this plan) [UPGRADED]

The CLI agent does **not** need to re-audit. Use these confirmed facts:

**Package and structure**

```text
Package: com.sadat.jamaattime
Kotlin tree: android/app/src/main/kotlin/com/sadat/jamaattime/
Manifest:    android/app/src/main/AndroidManifest.xml
Flutter lib: lib/
Existing feature folders: lib/features/notice_board/   (newer style)
                          lib/screens/                  (older style; settings_screen.dart lives here)
                          lib/services/                 (one service per concern)
                          lib/models/                   (data classes)
```

**Existing permissions (manifest)**

```text
ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION
RECEIVE_BOOT_COMPLETED  (for prayer widget + notification reschedule — DO NOT widen)
POST_NOTIFICATIONS
INTERNET
VIBRATE
WAKE_LOCK
SCHEDULE_EXACT_ALARM
WRITE_EXTERNAL_STORAGE  (maxSdkVersion=28 only)
READ_EXTERNAL_STORAGE   (maxSdkVersion=28 only)
```

No `SYSTEM_ALERT_WINDOW`, no `BIND_ACCESSIBILITY_SERVICE` declared as `uses-permission` (correct — it's on the service element).

**Existing sensitive surfaces**

```text
- FocusGuardAccessibilityService (com.sadat.jamaattime.focusguard) — Shorts/Reels blocker. Keep untouched.
- FocusGuardChannel.kt — Flutter <-> native bridge for accessibility status.
- FocusGuardOverlayViewFactory.kt — overlay rendering for the Shorts block.
- Home widget receiver (es.antonborri.home_widget).
- Flutter local notifications receivers.
```

**MethodChannel naming convention (must match)**

```text
jamaat_time/screen_awake
jamaat_time/focus_guard
jamaat_time/battery_optimization
jamaat_time/family_safety   ← new (this plan)
```

**Storage convention**

```text
SharedPreferences via shared_preferences package. JSON-encoded settings blobs
keyed by feature, e.g.:
  focus_guard_settings
  family_safety_settings        ← new
  family_safety_pin_hash        ← new
  family_safety_blocklist_meta  ← new
```

**Files the agent MUST NOT modify**

```text
lib/services/prayer_time_engine.dart
lib/services/prayer_aux_calculator.dart
lib/services/jamaat_service.dart
lib/services/notification_service.dart
lib/services/notifications/**
lib/services/widget_service.dart
lib/services/focus_guard_service.dart
lib/screens/focus_guard_screen.dart
android/app/src/main/kotlin/com/sadat/jamaattime/focusguard/**
android/app/src/main/kotlin/com/sadat/jamaattime/PrayerWidgetProvider.*
android/app/src/main/kotlin/com/sadat/jamaattime/WidgetMaintenanceWorker.kt
android/app/src/main/kotlin/com/sadat/jamaattime/MainActivity.kt   ← edit ONLY to register one new channel; do not refactor
firestore.rules, firestore.indexes.json
functions/**
```

**Files the agent WILL touch**

```text
ADD:
  lib/features/family_safety/**           (Dart — UI, state, models, repo)
  android/app/src/main/kotlin/com/sadat/jamaattime/familysafety/**  (Kotlin)
  assets/family_safety/blocklists/*.txt  (bundled lists + LICENSE)
  android/app/src/main/res/xml/network_security_config.xml  (if not present)

EDIT (minimally):
  android/app/src/main/AndroidManifest.xml         (add VPN <service>, FG service perm, network config)
  android/app/src/main/kotlin/.../MainActivity.kt  (one-line: register FamilySafetyChannel)
  lib/screens/settings_screen.dart                 (add one tile: "Family Safety")
  lib/main.dart                                    (route registration, only if app uses central routing)
  pubspec.yaml                                     (add asset entry for blocklists; add flutter_secure_storage IF project doesn't already have it)
  l10n: lib/l10n/app_en.arb (and other locales)    (add new strings)
```

---

# Phase 0.5 — Play Protect Risk Model [NEW]

Before any code, the agent must internalise *why* each sensitive surface is risky and the mitigation:

| Surface | Risk | Mitigation in this plan |
|---|---|---|
| `VpnService` | Highest. Reviewers and Play Protect treat this as malware-adjacent unless the app is clearly a "VPN" or has a *user-controlled* VPN feature with disclosure. | Feature is named "Website Protection", lives under "Family Safety", off by default, requires an in-app disclosure dialog *before* `VpnService.prepare`, requires user tap to start, persistent notification, easy off switch. |
| Existing Accessibility (Focus Guard) | Already in app; reviewed before. | Untouched. New feature does **not** read or extend its scope. UI clearly separates the two. |
| Persistent foreground service | Mid. | Notification visible, labelled, links to feature toggle. `foregroundServiceType` declared. |
| Boot receiver auto-start of VPN | High — looks malware-like. | **Not implemented.** VPN never auto-starts. User taps to start each session. (If "remember on boot" is added later, must be opt-in toggle with disclosure.) |
| Bundled blocklist with adult-domain strings | Low if file is plaintext + license + scoped to assets. High if obfuscated or fetched silently. | Plaintext, attributed, signed-by-app-key (because bundled), scoped to `assets/family_safety/blocklists/`. |
| Crash report leaking domains | Mid. | Crashlytics scrubbing: never log the queried domain in crash reports; log only category id + 8-bit hash. |
| Renaming package or APK to look generic | Catastrophic flag. | Package stays `com.sadat.jamaattime`. App name stays "Jamaat Time". Feature name in Settings is "Family Safety". |

**Acceptance gate before Phase 5:** The agent confirms in its phase report that no rule in Section 2 is violated and no file in the "MUST NOT modify" list has been touched.

---

# Phase 1 — Family Safety UI Shell [UPGRADED with project paths]

## Add

Settings entry in `lib/screens/settings_screen.dart`. New tile titled **Family Safety**, subtitle: *"Help protect your family from harmful and distracting online content."* Use existing list-tile style; do not introduce a new card style.

## New Flutter files

```text
lib/features/family_safety/
├── presentation/
│   ├── family_safety_page.dart
│   ├── website_protection_page.dart
│   ├── digital_wellbeing_page.dart
│   ├── parent_control_page.dart
│   ├── safe_search_setup_page.dart
│   ├── activity_summary_page.dart
│   ├── privacy_explanation_page.dart
│   └── widgets/
│       ├── family_safety_section_tile.dart
│       └── disclosure_dialog.dart
├── domain/
│   ├── domain_normalizer.dart
│   ├── block_category.dart
│   ├── domain_block_matcher.dart
│   └── website_protection_settings.dart
├── data/
│   ├── blocklist_repository.dart
│   ├── family_safety_storage.dart
│   ├── parent_control_storage.dart
│   └── activity_summary_storage.dart
└── platform/
    └── family_safety_channel.dart   ← single MethodChannel wrapper
```

## Localization (l10n) [NEW]

All new user-facing strings go through `lib/l10n/app_en.arb` (and existing locales). At minimum:

```text
familySafetyTitle
familySafetySubtitle
websiteProtectionTitle
websiteProtectionEnableCta
websiteProtectionVpnDisclosureTitle
websiteProtectionVpnDisclosureBody     ← see Phase 5 for exact copy
parentControlTitle
parentControlSetPin
parentControlChangePin
parentControlForgotPinWarning
safeSearchSetupTitle
activitySummaryTitle
digitalWellbeingTitle
familySafetyPrivacyExplanation
```

Do not hardcode any of these in widgets.

## Acceptance

App builds. Settings → Family Safety reachable. All sub-pages render placeholder content. Existing Focus Guard untouched. No new permissions in manifest.

---

# Phase 2 — Safe Search + Private DNS Guide (mostly unchanged)

Add guidance pages for Google SafeSearch, YouTube Restricted Mode, Android Private DNS, browser safe-mode tips. Provide a **copy-to-clipboard** action for `family-filter-dns.cleanbrowsing.org`. Provide an **"Open Network Settings"** action that fires `Settings.ACTION_WIRELESS_SETTINGS` (Private DNS direct intent is unreliable across OEMs — fall back to wireless settings).

[NEW] Detect on this page whether Private DNS is currently set, using read-only API:

```kotlin
val mode = Settings.Global.getString(contentResolver, "private_dns_mode")
val host = Settings.Global.getString(contentResolver, "private_dns_specifier")
```

Show user the current state read-only. **Do not modify.** If `mode == "hostname"` and host points to a known DoH provider (cloudflare-dns.com, dns.google, etc.), surface a banner: *"Private DNS is set to a DoH provider. Website Protection (when enabled later) cannot inspect DoH traffic — consider switching Private DNS to Off or to family-filter-dns.cleanbrowsing.org for stronger filtering."*

This is read-only telemetry of system state — not sensitive, no permission required.

---

# Phase 3 — Parent Control Local PIN [UPGRADED]

Same scope as v1 plus:

- **Brute-force cooldown:** 5 wrong attempts → 60s lockout. 10 wrong → 5 min. 20 wrong → 1 hour. Counter resets on correct entry. Persist counter in PIN storage.
- **PIN hash:** PBKDF2-HMAC-SHA256, 120k iterations, 16-byte random salt, store `salt + hash` only. Use `crypto` package or platform-bridged `javax.crypto.SecretKeyFactory`.
- **Storage:** prefer `flutter_secure_storage` (Android Keystore-backed). Fallback to encrypted SharedPreferences only if dependency cost is unacceptable.
- **Forgot PIN flow:** require user to confirm with explicit warning *"This will reset your PIN and disable Website Protection. To reset, type the word DISABLE."* — friction must be visible.
- **Disable delay timer (optional):** if user enables, disabling Website Protection requires correct PIN **plus** a 60–300s countdown that user cannot bypass except by reinstalling the app. (Reinstall is the legitimate escape hatch — this is "soft" parental control, never spyware.)
- **Never lock the user out of the rest of the app.** PIN guards Family Safety settings only.

---

# Phase 4 — Local Blocklist Data Layer [UPGRADED]

## Domain rules — codified

```text
1. Lowercase, trim, strip scheme and path.
2. Remove leading "www." — but not other "www-" prefixes (e.g. "www3.example.com" → keep "www3.example.com").
3. Block matching is **suffix match on label boundaries**:
     match("sub.example.com", "example.com") = true
     match("badexample.com",  "example.com") = false
     match("example.com",     "ample.com")   = false
4. Whitelist always wins.
5. IDN/punycode: convert to ACE form before matching.
6. IP literals: blocklist entries that are IPs match exactly; do not subnet match in v1.
```

Add unit tests covering: case sensitivity, www stripping, label-boundary suffix, IDN, whitelist precedence, IPv4 literal, subdomain depth >= 3.

## Blocklist sourcing strategy [NEW]

Bundle as plaintext assets at `assets/family_safety/blocklists/` with versioned filenames. Recommended sources:

```text
adult.txt        ← derived from CleanBrowsing public family filter list
                  OR StevenBlack's "fakenews+gambling+porn" hosts file
                  Both are openly licensed; include LICENSE.txt with attribution.
gambling.txt     ← StevenBlack gambling list (CC-BY-SA, attribution required)
proxy_bypass.txt ← curated short list of public DoH/DoT/proxy/VPN-bypass domains
                  (cloudflare-dns.com, dns.google, dns.adguard.com, 1dot1dot1dot1.cloudflare-dns.com, etc.)
```

Strict rules:

- Plaintext one-domain-per-line. No obfuscation, no encryption.
- Each list ships with a `.LICENSE` sibling file with source URL and license text.
- `pubspec.yaml` registers the directory as an asset bundle.
- Read once at app start into memory (Hive/SharedPreferences cache invalidated on app version bump). Do not re-parse per query.
- Build a `Set<String>` keyed by exact domain *and* a sorted list for suffix lookup.
- Optional v2 signed update: download a signed `.tar.gz` bundle from a controlled HTTPS endpoint, verify Ed25519 signature against a public key bundled in the APK, atomically swap. **Not in MVP.**

## Activity tracking format

Storage row: `(date_yyyymmdd, category_id, count)` only. No domain, no time-of-day, no user id, no device id.

---

# Phase 5 — Android VPN Consent Bridge [UPGRADED]

## Manifest additions (exact)

In `AndroidManifest.xml`, inside `<application>`:

```xml
<!-- Family Safety: Website Protection VPN (DNS-only filter) -->
<service
    android:name=".familysafety.vpn.FamilySafetyVpnService"
    android:exported="false"
    android:permission="android.permission.BIND_VPN_SERVICE"
    android:foregroundServiceType="systemExempted">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
</service>
```

Add **only** these new top-level permissions (next to existing ones):

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
```

Do **not** add `BIND_VPN_SERVICE` as a `<uses-permission>`.
Do **not** add `QUERY_ALL_PACKAGES`.
Do **not** add `BOOT_COMPLETED` extension (`RECEIVE_BOOT_COMPLETED` is already there for the prayer widget — do not enrol VPN with it).

## Network security config [NEW]

Create `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </base-config>
</network-security-config>
```

Reference it from `<application android:networkSecurityConfig="@xml/network_security_config" ...>`. This pre-empts a "cleartext traffic" Play Console warning and signals to reviewers that the VPN is not used for cleartext traffic interception.

## Native files

```text
android/app/src/main/kotlin/com/sadat/jamaattime/familysafety/
├── FamilySafetyChannel.kt        ← MethodChannel("jamaat_time/family_safety")
├── VpnPermissionManager.kt
└── vpn/
    ├── FamilySafetyVpnService.kt
    ├── DnsPacketParser.kt
    ├── DnsResponseBuilder.kt
    ├── DomainBlockMatcher.kt        (mirrors Dart matcher — share rules; ship a parity test)
    ├── VpnStatusRepository.kt
    └── VpnNotificationHelper.kt
```

Channel methods (final names):

```text
isVpnPrepared() -> Bool
requestVpnPermission() -> Bool          // returns false if user denied
getVpnStatus() -> {prepared:Bool, running:Bool, lastError:String?}
startWebsiteProtection() -> Bool
stopWebsiteProtection() -> Bool
getActivitySummary(rangeDays:Int) -> Json   // local-only counts
getPrivateDnsState() -> {mode:String, host:String?}
```

Register in `MainActivity.kt` with one new line, mirroring the Focus Guard pattern:

```kotlin
FamilySafetyChannel(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
```

## In-app disclosure dialog [NEW — exact copy]

This must appear **before** any `VpnService.prepare(context)` call. Title and body are localized.

```text
Title:  Enable Website Protection?

Body:
Website Protection helps block harmful website categories (such as adult
content, gambling, and proxy-bypass sites) for everyone using this device.

To do this, the app uses Android's VPN system locally on your device to
inspect website addresses (domain names) and block selected categories.

What this feature does NOT do:
• It does not read messages, passwords, or payment details.
• It does not inspect the contents of secure (HTTPS) pages.
• It does not install any certificates.
• It does not upload your browsing to any server.

Activity summaries (counts only) are stored on your device and you can
clear them at any time. You can disable Website Protection from this
screen whenever you want.

Buttons:
[ Not now ]   [ Continue and grant permission ]
```

Only on "Continue" do we call `VpnService.prepare(context)`. If the OS dialog is denied, surface a calm "You can enable this anytime later" state — no nag, no redial.

## Acceptance

User sees in-app disclosure first. Android VPN consent dialog appears only after explicit tap. Denial handled gracefully (no crash, no retry loop). VPN does **not** start in this phase. Existing app behaviour unchanged.

---

# Phase 6 — Local VPN DNS Filter MVP [UPGRADED]

## Behaviour spec (engineering-tight)

```text
- VpnService configures a tun interface with:
    addAddress("10.0.0.2", 32)
    addDnsServer("10.0.0.1")    ← virtual; we serve responses ourselves
    addRoute("0.0.0.0", 0)       ← required to capture DNS, but we ONLY read UDP/53
    setMtu(1500)
    setBlocking(false)
    Allow specific apps to bypass? — No. v1 is system-wide.
- Read tun fd in a loop:
    parse IP header, then UDP, then DNS query.
    if not UDP/53 → write packet straight back through a forwarded socket
                    (do NOT drop arbitrary traffic — that's how apps lose internet)
    if UDP/53 → run domain through DomainBlockMatcher
                  blocked → synthesize NXDOMAIN response, write back to tun fd
                  allowed → forward query to upstream resolver (1.1.1.1 by default,
                            user-configurable in Phase 7), write reply back to tun fd
    if TCP/53 → forward unchanged (or drop with RST in v1; document)
    if UDP/853 (DoT) → forward unchanged in v1 (cannot inspect)
    if TCP/853 (DoT) → forward unchanged
- Errors:
    Parser exception → log + forward packet unchanged (FAIL OPEN)
    Upstream timeout → return SERVFAIL, do not crash
    OutOfMemory → stop service cleanly, mark lastError, surface in UI
- Activity summary:
    Per blocked query, increment (date, category) counter.
    Never store the domain itself.
- Persistent notification:
    Channel id: "family_safety_protection"
    Importance: LOW (silent), but visible.
    Title: "Family Safety – Website Protection"
    Text:  "On — blocking selected categories"
    Tap action: opens FamilySafetyPage.
    NOT dismissible while service runs.
```

## DoH / Private DNS interaction [NEW]

When the user enables Website Protection, check `getPrivateDnsState()`:

- mode == "off" or "opportunistic" → fine, proceed.
- mode == "hostname" with non-DoH provider → fine, proceed.
- mode == "hostname" with DoH provider → show a non-blocking banner inside the Website Protection page: *"Private DNS is using a DoH provider. Some queries cannot be filtered. For best results, set Private DNS to Off in system settings."* Provide an **Open Network Settings** intent button. Do not modify the system setting.

## Bypass surfaces — be honest about them

The plan does not pretend to be airtight. Document for the user (in the Privacy Explanation page):

```text
Limits of Website Protection:
• HTTPS DNS (DoH) inside browsers (Firefox, Brave) cannot be filtered.
• Some apps with hardcoded DoH (e.g. some smart-TV or game-console apps when tethered)
  cannot be filtered.
• Apps explicitly excluded from VPN by Android, or running on another network, are not filtered.
• Disabling Wi-Fi/data disables filtering.
This is a helpful guard, not a guarantee.
```

This honesty *helps* Play review and *helps* user trust.

## Acceptance

Test domain in `adult.txt` is blocked (NXDOMAIN). Test domain in whitelist resolves normally. Random non-list domain resolves normally. VPN status visible in UI and in notification shade. Stopping protection terminates the service cleanly within 1s. No crash if upstream resolver is offline. No crash if blocklist is empty. Existing prayer/Jamaat/widget/notification features all still work.

---

# Phase 7 — Activity Summary [UPGRADED]

Identical to v1, plus:

- Storage schema enforced as `(date YYYYMMDD, category_id INT, count INT)` only — write a Dart assertion that rejects any attempt to persist a domain string.
- Default retention: 30 days. Older rows pruned on read.
- "Clear data" button wipes all rows in one transaction; show a confirmation modal.
- Add an **Export** action that exports counts as CSV to `Downloads/` via the Storage Access Framework — **opt-in only**, never auto-exports.

---

# Phase 8 — Digital Wellbeing Integration [UPGRADED — explicit isolation]

This page is **read-only display** of the existing Focus Guard state, plus links into its own settings page. No new code in `lib/services/focus_guard_service.dart`. No new code in `android/.../focusguard/`.

Allowed interactions:

```text
- Read FocusGuardService.loadSettings() to show "Shorts/Reels protection: ON / OFF".
- Provide a button "Open Focus Guard settings" that pushes the existing FocusGuardScreen.
- Show the existing Accessibility disclosure copy verbatim — do not rewrite it.
```

UI separation rule: Website Protection (VPN) and Focus Guard (Accessibility) **must look like separate features, named differently, with no shared toggle**. Reviewers and users should be able to disable one and keep the other.

---

# Phase 9 — Play Protect / Policy Hardening [UPGRADED]

## Manifest review checklist (run before any release build)

```text
[ ] Only the new permissions listed in Phase 5 added.
[ ] No `<uses-permission android:name="android.permission.BIND_VPN_SERVICE"/>` anywhere.
[ ] No QUERY_ALL_PACKAGES.
[ ] No new BOOT_COMPLETED receiver.
[ ] No SYSTEM_ALERT_WINDOW added.
[ ] Network security config referenced and disallows cleartext.
[ ] VPN <service> has correct foregroundServiceType.
[ ] FocusGuardAccessibilityService unchanged.
[ ] App label, icon, package unchanged.
[ ] No tools:replace tricks for android:label.
```

## Code review checklist

```text
[ ] No code path silently calls VpnService.prepare without disclosure.
[ ] No code path starts VPN without user tap.
[ ] No code path uploads any DNS-related telemetry.
[ ] Crashlytics scrubbing config drops any field whose key contains
    "domain", "url", "host", "query", "category".
[ ] Activity summary writer rejects domain strings (assertion).
[ ] Parent Control PIN never logged (not even hash) by Crashlytics.
[ ] Bundled blocklist files are plaintext and have a sibling .LICENSE.
```

## Play Console submission [NEW]

**Data Safety form — fields to mark:**

```text
Personal info:                   Not collected
Financial info:                  Not collected
Health & fitness:                Not collected
Messages:                        Not collected
Photos & videos:                 Not collected
Audio:                           Not collected
Files & docs:                    Not collected
Calendar:                        Not collected
Contacts:                        Not collected
App activity:                    Not collected (Activity Summary is on-device only)
Web browsing:                    Not collected
App info & performance:          Crash logs — yes (with domain scrubbing)
Device or other identifiers:     Not collected
Location:                        Approximate / Precise (already declared for prayer times — do NOT
                                 attribute to Family Safety)

Data is encrypted in transit:    Yes (HTTPS only)
Users can request data deletion: N/A (no remote data)
```

**Permissions declaration form — VPN:**

The VPN declaration draft from v1 is good. Replace the second paragraph with:

```text
The VPN connection runs entirely on the user's device. The app inspects
only the destination domain name in DNS queries (UDP/53 and TCP/53) for
the purpose of category-based filtering. All other network traffic
(HTTPS, TCP, UDP non-53) is forwarded unchanged. The app does not
perform HTTPS interception, does not install any certificates, and does
not transmit DNS query data off the device.
```

**Play Store listing copy [NEW]:**

The store listing must keep the app's primary identity as a prayer/Jamaat times app. Family Safety is mentioned as a section, not the headline.

```text
Title:    Jamaat Time
Short:    Accurate prayer times, Jamaat synchronisation, and family-friendly
          tools — for your masjid and your home.
Long description: ... [existing prayer/Jamaat content first] ...
                  Optional Family Safety section: helps reduce exposure to
                  harmful or distracting websites using on-device DNS
                  filtering. Off by default. No data leaves your phone.
```

This signal-to-purpose alignment matters more than any single technical mitigation.

---

# Phase 10 — Manual Test Checklist [UPGRADED]

All v1 tests, plus:

```text
27. With Private DNS off → Website Protection ON → blocked domain blocked, normal browsing fine.
28. With Private DNS = "auto" → behaviour unchanged (filtering still works for non-DoH browsers).
29. With Private DNS = "dns.google" (DoH) → banner appears, filtering bypassed for DoH-capable browsers (expected, documented).
30. Toggle airplane mode while VPN running → no crash, VPN reattaches when network returns.
31. Switch Wi-Fi to mobile data while VPN running → no crash, VPN reattaches.
32. Force-stop the app from Settings → VPN stops cleanly, notification clears.
33. Reboot device → VPN does NOT auto-start (this is correct).
34. Reboot device → prayer widget DOES update (existing behaviour, unaffected).
35. Open Focus Guard while Website Protection is ON → both features visible, both controllable independently.
36. Disable Focus Guard → Website Protection stays ON. Vice versa.
37. Wrong PIN 5x → 60s cooldown enforced.
38. Forgot PIN flow → user types DISABLE → PIN reset, Website Protection turned off, summary preserved.
39. Clear activity summary → counts reset to 0, no domain leak in any export.
40. Side-load APK on Pixel + Samsung + Realme → Play Protect scan runs, no warning toast.
    (If a warning appears, do NOT ship — investigate manifest/permissions/service declaration first.)
41. Run `bundletool` aab → apks → install → cold start → no Play Protect warning.
42. Internal testing track upload → review console for any policy flags.
```

---

# Final agent instructions [UPGRADED]

Implement phase by phase. After each phase the agent stops and reports:

```text
- Phase number and name
- Files added (list)
- Files modified (list)
- Permissions added (list)  ← MUST be empty in Phases 1–4
- New sensitive APIs touched (VpnService / Accessibility / Overlay) ← MUST be empty in Phases 1–4
- Build result (release + debug)
- Lint result
- Unit test result
- Manual smoke result for the affected screens
- "Safe to continue?" yes/no with one-sentence justification
```

Hard stops (agent must halt and ask):

```text
- Any need to add a permission not listed in Phase 5.
- Any failing test on existing prayer/Jamaat/widget/notification code.
- Any change in app label, package name, or icon.
- Any urge to "consolidate" Focus Guard with Family Safety. Don't.
- Any blocklist source whose license is unclear.
```

---

# Strong do-not-touch rules (kept from v1)

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
Do not add ad blocking / traffic monetization.
Do not rename the package or app.
Do not auto-start VPN on boot.
Do not silence or hide the VPN persistent notification.
```

---

*Plan v2 — built on top of v1 with project-specific paths, additional Play Protect mitigations, DoH/Private DNS handling, blocklist sourcing strategy, l10n integration, Data Safety form, and concrete consent copy.*
