# DGSC Service Management / Manajemen Servis DGSC

Flutter application for DigiTech Service Center with customer service flow, admin operations, diagnosis engine, PPOB/counter transactions, bilingual UI, and Supabase backend.

Aplikasi Flutter untuk DigiTech Service Center dengan alur servis pelanggan, operasional admin, mesin diagnosis, transaksi PPOB/konter, UI dua bahasa, dan backend Supabase.

## Overview / Gambaran Umum

**English**
- Customer and admin application in one codebase
- Device service booking and repair tracking
- Offline-capable diagnosis dataset with cloud publish/sync flow
- PPOB and counter transaction management with receipt preview and Bluetooth thermal printing
- Push notifications, Google Sign-In, password reset deep link, and bilingual interface

**Indonesia**
- Aplikasi customer dan admin dalam satu codebase
- Booking servis perangkat dan pelacakan proses perbaikan
- Dataset diagnosis yang bisa berjalan offline dengan alur publish/sinkron cloud
- Manajemen transaksi PPOB dan konter dengan preview struk serta cetak thermal Bluetooth
- Push notification, Google Sign-In, deep link reset password, dan antarmuka dua bahasa

## Main Features / Fitur Utama

### 1. Authentication & Roles / Autentikasi & Role
**English**
- Email/password login with Supabase Auth
- Native Google Sign-In for customer accounts
- Role separation for `admin` and `customer`
- Reset password flow via deep link

**Indonesia**
- Login email/password menggunakan Supabase Auth
- Google Sign-In native untuk akun customer
- Pemisahan role `admin` dan `customer`
- Alur reset password melalui deep link

### 2. Customer Features / Fitur Customer
**English**
- Book device service
- View service progress and history
- Run diagnosis for device issues
- Manage profile and app settings

**Indonesia**
- Booking servis perangkat
- Melihat progres servis dan riwayat
- Menjalankan diagnosis kerusakan perangkat
- Mengelola profil dan pengaturan aplikasi

### 3. Admin Features / Fitur Admin
**English**
- Dashboard for operations and finance overview
- Booking verification and conversion to active service
- Service workflow management until pickup/payment
- Customer data management
- Spare part and finance management
- Store settings and admin settings

**Indonesia**
- Dashboard untuk ringkasan operasional dan keuangan
- Verifikasi booking dan konversi ke servis aktif
- Manajemen alur servis sampai pengambilan/pembayaran
- Pengelolaan data pelanggan
- Manajemen spare part dan keuangan
- Pengaturan toko dan pengaturan admin

### 4. PPOB & Counter / PPOB & Konter
**English**
- PPOB app/provider management
- Transaction category and service management
- Daily balance tracking and report summary
- Receipt preview, share, save, and Bluetooth printing
- Local JSON backup for PPOB master data

**Indonesia**
- Manajemen aplikasi/provider PPOB
- Manajemen kategori transaksi dan layanan
- Pelacakan saldo harian dan ringkasan laporan
- Preview struk, bagikan, simpan, dan cetak Bluetooth
- Backup JSON lokal untuk master data PPOB

### 5. Diagnosis Engine / Mesin Diagnosis
**English**
- Certainty Factor engine embedded in app
- Admin editor for diagnosis JSON dataset
- Draft, validation, publish, and local cache sync

**Indonesia**
- Mesin Certainty Factor tertanam di aplikasi
- Editor admin untuk dataset JSON diagnosis
- Draft, validasi, publish, dan sinkron cache lokal

### 6. Notifications & UX / Notifikasi & UX
**English**
- Firebase Messaging + local notification support
- Supabase Edge Function for push delivery
- Indonesian and English UI
- Light/dark theme support

**Indonesia**
- Dukungan Firebase Messaging + notifikasi lokal
- Supabase Edge Function untuk pengiriman push
- UI bahasa Indonesia dan Inggris
- Dukungan tema terang/gelap

## Tech Stack / Teknologi

**Frontend**
- Flutter
- Provider
- Material UI

**Backend**
- Supabase Auth
- Supabase Database / Storage / Functions
- Firebase Core + Firebase Messaging

**Other Integrations**
- Google Sign-In
- Bluetooth thermal printing
- Share/export receipt image

## Project Structure / Struktur Proyek

- [lib/main.dart](lib/main.dart) — app bootstrap, providers, routes
- [lib/services/backend_service.dart](lib/services/backend_service.dart) — main backend abstraction
- [lib/screens/admin/counter_screen.dart](lib/screens/admin/counter_screen.dart) — PPOB counter screen
- [lib/services/ppob_print_service.dart](lib/services/ppob_print_service.dart) — receipt printing logic
- [lib/services/cf_engine.dart](lib/services/cf_engine.dart) — diagnosis engine
- [lib/services/diagnosis_config_service.dart](lib/services/diagnosis_config_service.dart) — diagnosis dataset sync/publish
- [supabase/schema.sql](supabase/schema.sql) — database schema
- [SUPABASE_SETUP.md](SUPABASE_SETUP.md) — detailed Supabase setup

## Setup / Cara Menjalankan

### Requirements / Kebutuhan
**English**
- Flutter SDK
- Android Studio / VS Code
- Supabase project
- Firebase project for push notification

**Indonesia**
- Flutter SDK
- Android Studio / VS Code
- Project Supabase
- Project Firebase untuk push notification

### Install Dependencies / Install Dependensi

```bash
flutter pub get
```

### Run in Development / Jalankan Development

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com
```

If iOS Google Sign-In is used, also add `GOOGLE_IOS_CLIENT_ID`.

Jika Google Sign-In iOS dipakai, tambahkan juga `GOOGLE_IOS_CLIENT_ID`.

## Release Build / Build Rilis

### Android APK per ABI

**English**
Recommended flow before release build when Flutter dependencies or cache were changed:

```bash
flutter doctor
flutter clean
flutter pub get
flutter build apk --release --split-per-abi --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com
```

**Indonesia**
Alur yang disarankan sebelum build rilis jika dependency atau cache Flutter berubah:

```bash
flutter doctor
flutter clean
flutter pub get
flutter build apk --release --split-per-abi --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com
```

Output / Hasil:
- [build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk](build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk)
- [build/app/outputs/flutter-apk/app-arm64-v8a-release.apk](build/app/outputs/flutter-apk/app-arm64-v8a-release.apk)
- [build/app/outputs/flutter-apk/app-x86_64-release.apk](build/app/outputs/flutter-apk/app-x86_64-release.apk)

Note / Catatan:
- This README documents APK release only, not Play Store bundle build.
- README ini hanya mendokumentasikan rilis APK, bukan build bundle Play Store.

## Security Notes / Catatan Keamanan

**English**
- Do not commit service-account JSON files
- Do not commit production signing keys
- Do not put server secrets into Flutter client code
- Keep `google-services.json` and `GoogleService-Info.plist` outside public distribution

**Indonesia**
- Jangan commit file JSON service-account
- Jangan commit signing key produksi
- Jangan letakkan secret server di code Flutter client
- Simpan `google-services.json` dan `GoogleService-Info.plist` dengan aman

## Important Notes / Catatan Penting

**English**
- Main backend has moved to Supabase
- Firebase is still used for messaging support
- PPOB master data is backed up locally from asset/cloud sync
- The app supports Android, iOS, Web, Windows, Linux, and macOS targets in the Flutter workspace

**Indonesia**
- Backend utama sudah berpindah ke Supabase
- Firebase masih dipakai untuk dukungan messaging
- Master data PPOB dibackup lokal dari sinkron asset/cloud
- Aplikasi mendukung target Android, iOS, Web, Windows, Linux, dan macOS di workspace Flutter ini

## Detailed Backend Setup / Setup Backend Lengkap

See [SUPABASE_SETUP.md](SUPABASE_SETUP.md).

Lihat [SUPABASE_SETUP.md](SUPABASE_SETUP.md).
