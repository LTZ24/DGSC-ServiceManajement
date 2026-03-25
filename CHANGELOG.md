# Changelog

## 1.0.2

**Release**
- Version bumped to `1.0.2+3`.
- Prepared for release tag `v1.0.2`.

**New**
- Added dedicated cashier flow, PPOB receipt preview improvements, and structured spare part transaction support.
- Added configurable App Lock timeout options, lock method dropdown, and more consistent biometric activation flow.
- Added MIT license for the repository.

**Improvements**
- Customer settings shortcut moved to the drawer header, matching the admin layout.
- Admin drawer header now also exposes an icon-only shortcut for store settings.
- Guest diagnosis landing page and diagnosis dialog were redesigned to be cleaner and more modern.
- Diagnosis JSON editor is now easier to use with quick format/copy actions and clearer validation feedback.
- Google login button icon rendering was corrected.
- Pull-to-refresh support was expanded across the main customer/admin menu screens.

**Fixes**
- Removed duplicate/obsolete settings items for customer fingerprint unlock and push notifications.
- App Lock loading and startup flow were optimized to reduce perceived delay.
- App Log reading fallback was fixed so application logs appear correctly.
- Home App Info no longer shows `Platform: Supabase`.
- Drawer header bottom corners were flattened.
- Push notification initialization was hardened and FCM payload handling was improved for better foreground delivery and debugging.

## 1.0.1

**New**
- Fingerprint activation flow improved: activation now triggers biometric prompt correctly.
- Admin menu: added **Log / Log History** to view startup + error logs and export log file.
- Log screen UI updated to modern, simple cards with level color accents (INFO/WARN/ERROR).

**Fixes**
- Logout + biometric login flow stabilized (fewer UI race issues).
- App Info text updated: `Server` now shows `Supabase PostgreSQL` (removed "(Cloud)").
- Android build/Gradle compatibility fixes (from earlier fixes in this branch).
