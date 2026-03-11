# Setup Supabase untuk DGSC-ServiceManagement

## 1. Buat project Supabase
1. Login ke Supabase.
2. Buat project baru.
3. Catat:
   - `Project URL`
   - `Publishable key`

## 2. Jalankan schema database
1. Buka SQL Editor di Supabase.
2. Paste isi file `supabase/schema.sql`.
3. Jalankan sekali sampai selesai.
4. Pastikan tabel berikut terbentuk:
   - `users`
   - `customers`
   - `bookings`
   - `services`
   - `transactions`
   - `spare_parts`
   - `notifications`
   - `settings`
   - `store_settings`
   - `counter_categories`
   - `counter_transactions`
   - `counter_expenses`
   - `cf_diagnosis_history`
   - `diagnosis_configs`
   - `activity_logs`

5. Schema yang sama juga akan membuat bucket public `diagnosis-data` untuk file JSON diagnosis yang dipublish.

## 3. Buat akun admin pertama
Karena aplikasi memakai role `admin` di tabel `public.users`, buat satu akun admin manual.

### Opsi cepat
1. Buka Authentication > Users.
2. Tambah user baru dengan email admin.
3. Setelah user dibuat, buka Table Editor > `users`.
4. Ubah kolom `role` menjadi `admin`.
5. Jika perlu, isi `username` dan `phone`.

## 4. Konfigurasi Flutter app
Aplikasi sekarang membaca konfigurasi Supabase dari `dart-define`.

### Reset password langsung ke aplikasi
Flow reset password sekarang tidak lagi memakai approval admin. User cukup minta email reset, lalu email dari Supabase akan membuka aplikasi langsung ke form password baru.

#### A. Pastikan konfigurasi di aplikasi sudah sesuai
Flow yang sekarang dipakai project ini adalah:

1. User menekan `Lupa password?` di halaman login atau menu ubah password di profil.
2. App memanggil `resetPasswordForEmail(...)` dengan `redirectTo: dgsc://reset-password`.
3. Supabase mengirim email recovery ke email user.
4. User membuka link di email.
5. Android menangkap deep link `dgsc://reset-password`.
6. App menerima event recovery dan mengarahkan user ke form password baru.

Jadi, agar flow ini berhasil, ada 4 bagian yang harus benar sekaligus:

- konfigurasi URL recovery di Supabase
- template email recovery Supabase
- deep link Android di aplikasi
- app dijalankan dengan build terbaru

#### B. Konfigurasi URL recovery di Supabase
1. Buka Supabase Dashboard.
2. Masuk ke `Authentication` > `URL Configuration`.
3. Cari bagian `Redirect URLs` atau `Additional Redirect URLs`.
4. Tambahkan URL berikut persis seperti ini:

    `dgsc://reset-password`

5. Simpan.

Jika Anda memakai beberapa environment, tetap tambahkan URL ini di project Supabase yang benar-benar dipakai aplikasi Android Anda.

#### C. Cek template email reset password
1. Buka `Authentication` > `Email Templates`.
2. Pilih template `Reset Password`.
3. Pastikan template masih memakai link recovery bawaan Supabase.
4. Jangan ganti link recovery menjadi URL lain yang tidak mengarah ke token recovery Supabase.

Yang penting bukan tampilan HTML-nya, tetapi link reset di dalam email harus tetap memakai mekanisme recovery Supabase.

Jika Anda mengedit template manual, pastikan placeholder recovery link Supabase tidak dihapus.

#### D. Cek konfigurasi Android di project ini
Project ini sudah menyiapkan intent filter Android untuk reset password. Jika Anda memakai source code terbaru, seharusnya bagian ini sudah tersedia.

Yang perlu Anda pastikan:

1. Build yang terpasang di Android benar-benar build terbaru.
2. App yang dibuka dari email adalah aplikasi DGSC yang sama dengan package yang dipakai saat build.
3. Tidak ada aplikasi lain yang mengambil scheme `dgsc://`.

Jika pernah memasang versi lama aplikasi, sebaiknya uninstall dulu lalu install ulang build terbaru untuk menghindari cache deep-link lama.

#### E. Cara test end-to-end
Lakukan test ini secara berurutan:

1. Jalankan aplikasi di Android.
2. Buka halaman login.
3. Tekan `Lupa password?`.
4. Masukkan email user yang benar-benar terdaftar di Supabase Auth.
5. Pastikan muncul snackbar sukses pengiriman email.
6. Buka inbox email user.
7. Buka email reset dari Supabase.
8. Klik tombol / link reset di email.
9. Pastikan Android menawarkan atau langsung membuka aplikasi DGSC.
10. Pastikan app masuk ke halaman reset password.
11. Masukkan password baru.
12. Setelah sukses, login ulang dengan password baru.

#### F. Tanda bahwa setup sudah benar
Setup reset password dianggap benar jika hasilnya seperti ini:

- email reset berhasil terkirim
- saat link dibuka, aplikasi terbuka, bukan berhenti di browser saja
- user masuk ke form `Reset Password`
- password baru berhasil disimpan
- user bisa login kembali dengan password baru

#### G. Gejala error umum dan artinya
- **Email tidak masuk**
   - cek email user benar-benar terdaftar
   - cek project Supabase yang dipakai aplikasi benar
   - cek folder spam
- **Klik link tetapi hanya buka browser**
   - biasanya `dgsc://reset-password` belum ditambahkan di `URL Configuration`
   - atau build Android yang terpasang belum memuat deep link terbaru
- **App terbuka tetapi tidak masuk ke form reset**
   - biasanya app belum menerima event recovery dari Supabase karena build lama / sesi app bermasalah
- **Password baru gagal disimpan**
   - biasanya token recovery sudah expired atau sesi recovery tidak aktif lagi
   - minta user kirim email reset baru

#### H. Catatan operasional
- Reset selalu mengikuti email yang user masukkan saat meminta reset.
- Token recovery berasal dari Supabase, jadi tetap terikat ke user yang benar.
- Jika aplikasi tertutup, Android tetap bisa membuka aplikasi lalu masuk ke flow reset.
- Setelah password berhasil diubah, user memang harus login ulang.

### Push notification Android untuk booking dan service
Project sekarang menyiapkan push notification Android memakai Firebase Cloud Messaging (FCM) + Supabase Edge Function.

#### A. Arsitektur push yang dipakai project ini
Flow push notification di project ini adalah:

1. App Flutter menerima FCM token dari Firebase.
2. App subscribe ke topic seperti `user_<uid>`.
3. Saat aplikasi membuat notifikasi internal, backend juga memanggil Edge Function `send-push`.
4. Edge Function memakai **Firebase service account** untuk memanggil FCM HTTP v1.
5. Firebase meneruskan push ke device Android user.

Jadi, bagian yang wajib benar adalah:

- file `google-services.json`
- service account Firebase
- secrets di Supabase Edge Functions
- deploy function `send-push`

#### B. Ambil service account dari Firebase Console
Cara paling mudah:

1. Buka Firebase Console.
2. Pilih project Firebase yang sama dengan `google-services.json` Anda.
3. Klik ikon gear > `Project settings`.
4. Masuk ke tab `Service accounts`.
5. Klik `Generate new private key`.
6. Konfirmasi download.
7. Simpan file JSON itu di tempat aman dan **jangan commit ke repository**.

File JSON ini biasanya berisi field seperti:

- `project_id`
- `client_email`
- `private_key`

Itulah 3 nilai yang nanti dipindahkan ke secrets Supabase.

#### C. Alternatif ambil service account dari Google Cloud Console
Jika menu di Firebase tidak Anda pakai, bisa lewat Google Cloud:

1. Buka Google Cloud Console.
2. Pilih project yang sama dengan Firebase project Anda.
3. Masuk ke `IAM & Admin` > `Service Accounts`.
4. Cari service account yang dipakai Firebase Admin SDK, atau buat service account baru khusus push.
5. Buka service account tersebut.
6. Masuk ke tab `Keys`.
7. Klik `Add Key` > `Create new key` > pilih `JSON`.
8. Download file JSON.

Jika Anda membuat service account baru sendiri, pastikan service account itu punya izin yang cukup untuk mengirim FCM.

#### D. Nilai JSON yang harus diambil
Dari file JSON service account, ambil nilai berikut:

- `project_id` -> untuk `FIREBASE_PROJECT_ID`
- `client_email` -> untuk `FIREBASE_CLIENT_EMAIL`
- `private_key` -> untuk `FIREBASE_PRIVATE_KEY`

Contoh bentuk JSON-nya biasanya seperti ini:

- `project_id`: nama project Firebase / Google Cloud
- `client_email`: alamat email service account
- `private_key`: blok private key panjang yang diawali `-----BEGIN PRIVATE KEY-----`

Penting:
- simpan `private_key` apa adanya
- jika Anda memasukkan via terminal, newline biasanya perlu di-escape menjadi `\n`

#### E. Simpan secrets ke Supabase Edge Functions
Setelah Anda punya 3 nilai tadi, simpan ke secrets Supabase.

Contoh dengan Supabase CLI:

1. Login dulu ke Supabase CLI.
2. Link project jika perlu.
3. Jalankan set secret untuk tiap nilai.

Contoh nama secret yang dipakai project ini:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

Contoh alur aman:

1. `FIREBASE_PROJECT_ID` diisi dari `project_id`
2. `FIREBASE_CLIENT_EMAIL` diisi dari `client_email`
3. `FIREBASE_PRIVATE_KEY` diisi dari `private_key`

Jika Anda menempelkan private key ke terminal PowerShell, pastikan newline tidak rusak. Cara paling aman adalah copy dari file JSON dan simpan sebagai secret persis sesuai isi key.

#### F. Deploy Edge Function
Setelah secret tersimpan, deploy function:

`supabase functions deploy send-push`

Jika Anda baru pertama kali deploy, pastikan project Supabase CLI sudah terhubung ke project yang benar.

#### G. Validasi fungsi push
Checklist minimal setelah deploy:

1. File `android/app/google-services.json` berasal dari project Firebase yang benar.
2. App sudah meminta izin notifikasi di Android.
3. User login ke aplikasi.
4. App berhasil subscribe topic `user_<uid>`.
5. Terjadi event yang memicu notifikasi, misalnya booking baru atau update servis.
6. Row notifikasi masuk ke tabel `public.notifications`.
7. Edge Function `send-push` ikut dipanggil.
8. Notifikasi muncul di tray Android.

#### H. Cara cek jika push belum masuk
- **Notifikasi in-app muncul, tapi push Android tidak muncul**
   - biasanya secrets Firebase belum benar
   - atau function `send-push` belum di-deploy
- **Push tidak muncul di device tertentu**
   - cek izin notifikasi Android
   - cek app sudah login dan subscribe topic user
- **Function error saat kirim ke FCM**
   - biasanya `FIREBASE_PRIVATE_KEY` rusak formatnya
   - atau `FIREBASE_PROJECT_ID` tidak cocok dengan project `google-services.json`
- **Push hanya jalan di beberapa akun**
   - cek `userId` tujuan dan topic `user_<uid>` sesuai

#### I. Catatan keamanan
- Jangan simpan file service-account JSON di repo.
- Jangan taruh private key di `dart-define` atau di aplikasi Flutter.
- Semua credential Firebase admin hanya boleh dipakai di Edge Function / server-side.

Notifikasi yang ikut masuk ke sistem Android setelah setup selesai:
- admin: booking baru, pilihan pembayaran customer, notifikasi lain yang ditujukan ke admin
- customer: booking diterima/ditolak/dikonversi, servis diproses, servis selesai, perangkat sudah diambil

### Login Google untuk customer
Aplikasi sekarang memakai **native Google Sign-In** untuk customer, sehingga pada Android login akan memakai account picker native, bukan browser.

#### Gambaran alur setelah berubah ke native Google Sign-In
Sekarang ada **3 komponen** yang harus cocok:

1. **Google Cloud / Firebase**
    - Menyediakan OAuth client untuk `Web`, `Android`, dan opsional `iOS`.
2. **Supabase**
    - Menerima `Web Client ID` + `Client Secret` untuk verifikasi login Google.
3. **Aplikasi Flutter**
    - Memakai login native Google di device, lalu mengirim token Google ke Supabase.

Artinya, masing-masing client dipakai untuk tujuan berbeda:

- **Web Client ID**
   - dipakai oleh **Supabase Google Provider**
   - dipakai juga di app Flutter sebagai `GOOGLE_WEB_CLIENT_ID`
- **Android Client ID**
   - dipakai oleh Google untuk mengenali aplikasi Android Anda berdasarkan `package name` + `SHA`
- **iOS Client ID**
   - dipakai jika Anda build ke iPhone/iPad

#### Urutan setup yang disarankan
Ikuti urutan ini agar tidak tertukar:

1. Siapkan project di Google Cloud
2. Isi `OAuth consent screen`
3. Buat **Web OAuth Client**
4. Buat **Android OAuth Client**
5. Jika perlu, buat **iOS OAuth Client**
6. Masukkan **Web Client ID + Secret** ke Supabase
7. Jalankan schema terbaru Supabase
8. Jalankan app Flutter dengan `dart-define` yang benar
9. Uji login Google di Android device

Yang harus Anda buat di Google Cloud dan isi di Supabase:

#### A. Siapkan project Google Cloud
1. Buka Google Cloud Console.
2. Buat project baru atau pilih project yang akan dipakai.
3. Nama project bebas, tetapi agar rapi disarankan misalnya:

   `DGSC Service Management`

#### B. Konfigurasi OAuth consent screen
1. Buka `APIs & Services` > `OAuth consent screen`.
2. Jika diminta, pilih `External`.
   - Gunakan `External` jika login dipakai oleh akun Google umum.
   - `Internal` hanya untuk Google Workspace milik organisasi Anda sendiri.
3. Isi data aplikasi. Contoh aman:
   - `App name`: `DGSC Service Management`
   - `User support email`: email Gmail/Google Workspace Anda
   - `Developer contact information`: email yang sama atau email admin Anda
4. Simpan sampai selesai.
5. Jika status aplikasi masih `Testing`, tambahkan akun Google Anda pada `Test users`.

Catatan:
- Untuk tahap awal, pengisian logo aplikasi, domain, privacy policy, dan terms of service bisa dilewati jika belum ada.
- Scope standar login Google biasanya cukup default dari Supabase, yaitu profil dasar dan email.

#### C. Buat OAuth Client ID yang benar
1. Buka `APIs & Services` > `Credentials`.
2. Klik `+ CREATE CREDENTIALS` > `OAuth client ID`.
3. Pada `Application type`, pilih:

   `Web application`

4. Penting: jangan pilih `Android` atau `iOS` untuk koneksi Supabase ini.
   Supabase memerlukan client tipe `Web application` karena proses OAuth selalu lewat callback web Supabase terlebih dahulu.
5. Isi nama client. Disarankan pakai nama yang mudah dikenali, misalnya:

   `DGSC Supabase Auth Web Client`

   atau

   `DGSC Production OAuth Client`

6. Pada bagian `Authorized JavaScript origins`:
   - boleh dikosongkan jika tidak diwajibkan oleh form,
   - atau isi origin project Supabase Anda, misalnya:

     `https://axevqxvhtxemoqlvwsnu.supabase.co`

7. Pada bagian `Authorized redirect URIs`, tambahkan URI berikut:

   `https://axevqxvhtxemoqlvwsnu.supabase.co/auth/v1/callback`

8. Klik `Create`.
9. Salin `Client ID` dan `Client Secret` yang muncul.

#### D. Buat client native Android
1. Di Google Cloud Console, tetap pada `APIs & Services` > `Credentials`.
2. Klik `+ CREATE CREDENTIALS` > `OAuth client ID`.
3. Pada `Application type`, pilih:

   `Android`

4. Isi:
   - `Name`: `DGSC Android Client`
   - `Package name`: `com.dgsc.mobile`
   - `SHA-1 signing certificate fingerprint`: isi SHA-1 debug/release Anda
5. Jika tersedia, tambahkan juga SHA-256 untuk build yang dipakai.
6. Simpan.

##### SHA yang dipakai harus dari build yang benar
Biasanya Anda butuh minimal dua jenis fingerprint:

- **debug SHA-1 / SHA-256**
   - dipakai saat menjalankan app dari `flutter run`
- **release SHA-1 / SHA-256**
   - dipakai saat menguji APK release

Jika login Google hanya jalan di debug tetapi gagal di APK, biasanya masalahnya ada di fingerprint release yang belum didaftarkan.

Jika memakai keystore debug default, Anda bisa ambil SHA dari keystore debug Java.
Jika memakai keystore release sendiri, ambil SHA dari keystore release itu.

Saran aman:
- daftarkan **SHA-1 debug**
- daftarkan **SHA-1 release**
- jika tersedia, tambahkan juga **SHA-256** keduanya

Catatan:
- Client Android ini dipakai agar popup account picker native bisa berjalan benar.
- Jika package name atau SHA salah, login Google native di Android sering gagal atau dianggap dibatalkan.
- Jika Anda memakai lebih dari satu varian signing, semua fingerprint yang dipakai harus terdaftar.

#### E. Jika build iOS dipakai
1. Buat lagi `OAuth client ID` dengan tipe:

   `iOS`

2. Isi bundle identifier sesuai aplikasi iOS Anda.
3. Simpan `iOS Client ID` untuk konfigurasi iOS.

#### F. Masukkan ke Supabase
1. Buka Supabase Dashboard > `Authentication` > `Sign In / Providers` > `Google`.
2. Aktifkan provider Google.
3. Paste `Client ID` dan `Client Secret` dari Google Cloud.
4. Simpan.

Yang dimasukkan di sini **hanya** milik client tipe `Web application`.
Jangan masukkan Android Client ID ke bagian provider Supabase.

Tambahan penting di Supabase:

1. Buka `Authentication` > `URL Configuration`.
2. Isi `Site URL` bebas aman, misalnya:

   `https://axevqxvhtxemoqlvwsnu.supabase.co`

3. Simpan perubahan.

#### G. Konfigurasi dart-define untuk app Flutter
Saat menjalankan atau build aplikasi, tambahkan minimal:

- `GOOGLE_WEB_CLIENT_ID` = Web client ID dari Google Cloud

Untuk iOS, tambahkan juga jika diperlukan:

- `GOOGLE_IOS_CLIENT_ID` = iOS client ID dari Google Cloud

Contoh PowerShell:

`flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com`

Contoh build APK:

`flutter build apk --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com`

Jika Anda build iOS, tambahkan juga:

`--dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com`

##### Variabel mana yang dipakai app saat ini
Di implementasi sekarang:

- `SUPABASE_URL` → URL project Supabase
- `SUPABASE_ANON_KEY` → Publishable key Supabase
- `GOOGLE_WEB_CLIENT_ID` → Web Client ID Google untuk login native + Supabase
- `GOOGLE_IOS_CLIENT_ID` → iOS Client ID Google, hanya jika iOS dipakai

Jika `GOOGLE_WEB_CLIENT_ID` kosong, login Google akan gagal.

#### H. Update project Flutter setelah setup berubah
Setelah setup di dashboard selesai, lakukan ini di project:

1. Jalankan:

   `flutter pub get`

2. Pastikan SQL terbaru di [supabase/schema.sql](supabase/schema.sql) sudah dijalankan ulang jika project lama belum memiliki function terbaru.
3. Tutup app yang sedang berjalan penuh.
4. Jalankan ulang app dengan `dart-define` yang baru.

Jika Anda sebelumnya sudah pernah mencoba flow browser-based, lakukan restart penuh app agar sesi lama tidak mengganggu pengujian.

#### I. Checklist field yang paling penting
Saat membuat client Google, yang wajib benar adalah:
- `Application type`: `Web application`
- `Name`: bebas, disarankan `DGSC Supabase Auth Web Client`
- `Authorized redirect URI`:

   `https://axevqxvhtxemoqlvwsnu.supabase.co/auth/v1/callback`

Yang lalu wajib benar di Supabase:
- Provider `Google` aktif
- `Client ID` dan `Client Secret` terisi

Yang wajib benar di aplikasi native Android:
- Ada OAuth client tipe `Android`
- `Package name`: `com.dgsc.mobile`
- SHA-1 / SHA-256 sesuai sertifikat build yang dipakai
- `GOOGLE_WEB_CLIENT_ID` diisi saat `flutter run` / `flutter build`

#### J. Cara test yang benar setelah setup selesai
Urutan test yang disarankan:

1. Jalankan app di Android device / emulator Google Play.
2. Buka menu `Login Customer`.
3. Tekan tombol `Masuk dengan Google`.
4. Pastikan yang muncul adalah **account picker native Google**, bukan browser.
5. Pilih akun Google.
6. Setelah sukses:
    - user masuk ke dashboard customer
    - row di tabel `public.users` terbentuk
    - row di tabel `public.customers` terbentuk

#### K. Gejala error dan arti umumnya
- **Popup pilih akun muncul lalu kembali ke app tapi gagal**
   - biasanya `SHA-1` / `SHA-256` salah atau belum didaftarkan
- **Login Google dianggap dibatalkan padahal akun sudah dipilih**
   - sering juga karena konfigurasi Android client salah
- **Login Google gagal sebelum popup akun muncul**
   - cek `GOOGLE_WEB_CLIENT_ID`
- **Login Google berhasil tetapi session Supabase gagal**
   - cek provider Google di Supabase, terutama `Client ID` + `Client Secret` web
- **Berhasil di debug tapi gagal di APK**
   - fingerprint release belum ditambahkan

Catatan:
- Tombol Google hanya ditampilkan di login customer.
- Login Google admin diblokir. Google login hanya untuk customer.
- Jika user login pertama kali dengan Google, row `public.users` dan `public.customers` akan dibuat oleh trigger Supabase.
- Jika ingin akun Google tertentu menjadi admin, ubah role-nya manual di tabel `public.users`.
- Jika Anda ingin fitur tambah akun admin dari aplikasi bekerja pada project lama, jalankan ulang bagian function terbaru di `supabase/schema.sql` agar RPC `admin_create_admin_user()` ikut terpasang.

### Jalankan lokal
Gunakan nilai project milik Anda:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` → isi dengan `Publishable key`

Contoh PowerShell:

`flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY`

Catatan:
- Nama variabel aplikasi masih `SUPABASE_ANON_KEY` untuk kompatibilitas.
- Nilai yang dipakai dari dashboard Supabase adalah `Publishable key`.
- Jangan gunakan `Secret key` di aplikasi Flutter/client.

### Build APK
Contoh:

`flutter build apk --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY`

## 5. Install dependency baru
Jalankan:

`flutter pub get`

## 6. Seed data awal
Setelah login sebagai admin:
1. Buka pengaturan toko dan isi:
   - nama toko
   - nomor WhatsApp
   - rekening bank
   - QRIS
2. Buka menu counter/PPOB.
3. Kategori default akan dibuat otomatis jika masih kosong.
4. Jika ingin mengelola sistem pakar, buka menu admin `Edit Data Diagnosis` lalu:
   - validasi JSON
   - simpan draft (butuh konfirmasi password admin)
   - publish agar semua aplikasi mengunduh dataset terbaru

## 7. Catatan migrasi penting
- Backend utama sudah dipindah ke Supabase + PostgreSQL.
- File konfigurasi Firebase lama sudah tidak dipakai.
- Penyimpanan gambar saat ini masih mengikuti alur lokal/base64 yang sudah ada di aplikasi.
- Fungsi `admin_create_customer_user()` sudah disiapkan di SQL agar admin tetap bisa membuat akun pelanggan dari aplikasi.
- Dataset diagnosis sekarang disimpan dalam JSON yang dipublish ke Supabase Storage dan dicache lokal di perangkat.

## 8. Jika ingin migrasi data lama dari Firebase
Lakukan mapping data ke tabel berikut:
- collection `users` -> table `users`
- collection `customers` -> table `customers`
- collection `bookings` -> table `bookings`
- collection `services` -> table `services`
- collection `transactions` -> table `transactions`
- collection `spare_parts` -> table `spare_parts`
- collection `notifications` -> table `notifications`
- collection `counter_categories` -> table `counter_categories`
- collection `counter_transactions` -> table `counter_transactions`
- collection `counter_expenses` -> table `counter_expenses`

## 9. Validasi setelah setup
Checklist minimum:
1. Login admin berhasil.
2. Registrasi customer berhasil.
3. Booking baru masuk ke admin.
4. Booking bisa dikonversi ke servis.
5. Status servis tampil di sisi customer.
6. Notifikasi pembayaran muncul.
7. Data dashboard admin dan customer tampil.
8. Menu counter/PPOB bisa menyimpan transaksi.
9. Diagnosis customer tetap berjalan dan mengikuti versi JSON terbaru setelah publish.
