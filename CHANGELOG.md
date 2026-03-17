# Changelog

## 1.0.1

**New**
- Fingerprint activation flow improved: activation now triggers biometric prompt correctly.
- Admin menu: added **Log / Log History** to view startup + error logs and export log file.
- Log screen UI updated to modern, simple cards with level color accents (INFO/WARN/ERROR).

**Fixes**
- Logout + biometric login flow stabilized (fewer UI race issues).
- App Info text updated: `Server` now shows `Supabase PostgreSQL` (removed "(Cloud)").
- Android build/Gradle compatibility fixes (from earlier fixes in this branch).
