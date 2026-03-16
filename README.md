# DGSC Service Management — Manajemen Servis DGSC

Aplikasi dengan build Flutter untuk DigiTech Service Center dengan alur servis pelanggan, operasional admin, mesin diagnosis, transaksi PPOB/konter, antarmuka bilingual, dan backend Supabase.

## Gambaran Umum

- Aplikasi customer dan admin dalam satu codebase
- Booking servis perangkat dan pelacakan proses perbaikan
- Dataset diagnosis yang bisa berjalan offline dengan alur publish/sinkron cloud
- Manajemen transaksi PPOB dan konter dengan preview struk serta cetak thermal Bluetooth
- Push notification, Google Sign-In, deep link reset password, dan antarmuka dua bahasa

## Fitur Utama

### 1. Autentikasi & Role
- Login email/password menggunakan Supabase Auth
- Google Sign-In untuk akun customer
- Login sidik jari untuk admin (diaktifkan dari Pengaturan Admin)
- Pemisahan role `admin` dan `customer`
- Alur reset password melalui deep link

### 2. Customer
- Booking servis perangkat
- Melihat progres servis dan riwayat
- Menjalankan diagnosis kerusakan perangkat
- Mengelola profil dan pengaturan aplikasi

### 3. Admin
- Dashboard untuk ringkasan operasional dan keuangan
- Verifikasi booking dan konversi ke servis aktif
- Manajemen alur servis sampai pengambilan/pembayaran
- Pengelolaan data pelanggan
- Manajemen spare part dan keuangan
- Pengaturan toko dan pengaturan admin

### 4. PPOB 
- Manajemen aplikasi/provider PPOB
- Manajemen kategori transaksi dan layanan
- Pelacakan saldo harian dan ringkasan laporan
- Preview struk, bagikan, simpan, dan cetak Bluetooth
- Backup JSON lokal untuk master data PPOB

### 5. Tools Diagnosis
- Tools Diagnosis menggunakan logic Certainty Factor.
- Editor admin untuk dataset JSON diagnosis
- Draft, validasi, publish, dan sinkron cache lokal

### 6. Notifikasi & UX
- Dukungan Firebase Messaging + notifikasi lokal
- Supabase Edge Function untuk pengiriman push
- UI bahasa Indonesia dan Inggris
- Dukungan tema terang/gelap

## Tech Stack

**Frontend**
- Flutter, Provider, Material UI

**Backend**
- Supabase Auth, Database, Storage, Functions
- Firebase Core + Firebase Messaging

**Others**
- Google Sign-In, Bluetooth thermal printing, Share/export struk

## Struktur

- lib/main.dart — bootstrap aplikasi, providers, routes
- lib/services/backend_service.dart — abstraksi backend utama
- lib/screens/admin/counter_screen.dart — layar konter PPOB
- lib/services/cf_engine.dart — mesin diagnosis
- supabase/schema.sql — skema database
- SUPABASE_SETUP.md — panduan setup Supabase lengkap

## Cara Menjalankan

### Kebutuhan
- Flutter SDK, Android Studio / VS Code
- Project Supabase dan Firebase

### Install Dependensi
```bash
flutter pub get
```

### Jalankan Development
```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_KEY --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com
```

## Build Rilis Android APK per ABI

```bash
flutter clean && flutter pub get
flutter build apk --release --split-per-abi --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_KEY --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com
```

Output: app-armeabi-v7a-release.apk | app-arm64-v8a-release.apk | app-x86_64-release.apk

## Notes

- Backend utama berjalan di Supabase
- Firebase dipakai untuk dukungan messaging
- Master data PPOB dibackup lokal dari sinkron asset/cloud
- Aplikasi difokuskan untuk platform Android

## Setup Backend Lengkap

<p>
  <a href="SUPABASE_SETUP.md">
    <img alt="Setup Backend" src="https://img.shields.io/badge/Setup%20Backend-Buka%20Panduan-0A7EA4?style=for-the-badge">
  </a>
</p>

Klik tombol di atas untuk membuka panduan setup backend.
