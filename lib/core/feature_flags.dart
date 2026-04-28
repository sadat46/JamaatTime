/// Gates the Bengali/English language toggle. Flip to `false` as a hotfix
/// to force Bengali and hide the Settings dropdown if a regression slips
/// through; remove after one stable release.
const bool kLanguageSwitchEnabled = true;

/// Kill switch for the public Notice Board surface. Replace with Remote Config
/// when that dependency is added to the app.
const bool kNoticeBoardEnabled = true;
