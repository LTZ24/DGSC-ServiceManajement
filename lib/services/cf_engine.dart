 // cf_engine.dart
//
// Certainty Factor (CF) diagnosis engine.
// All reference data (symptoms, damages, rules) is embedded as static const data
// so diagnosis works OFFLINE with zero Firestore reads.
//
// Algorithm (same as PHP backend):
//   1. Collect all rules where symptom_id ∈ selectedSymptomIds
//   2. Group rules by damage_id, collecting cf_values
//   3. Combine CFs sequentially: cfNew = cfA + cfB * (1 - cfA)
//   4. Sort by cfCombined descending
//   5. Return CfResult list (percentage = cfCombined * 100)
//
// Usage:
//   final results = CfEngine.diagnose(categoryId: 1, selectedSymptomIds: [6, 8, 10]);

int _cfInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _cfDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

class CfCategory {
  final int id;
  final String name;
  final String description;
  const CfCategory(this.id, this.name, this.description);

  factory CfCategory.fromMap(Map<String, dynamic> map) => CfCategory(
        _cfInt(map['id']),
        map['name']?.toString() ?? '',
        map['description']?.toString() ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
      };
}

class CfSymptom {
  final int id;
  final int categoryId;
  final String code;
  final String name;
  final String? description;
  const CfSymptom(this.id, this.categoryId, this.code, this.name,
      [this.description]);

  factory CfSymptom.fromMap(Map<String, dynamic> map) => CfSymptom(
        _cfInt(map['id']),
        _cfInt(map['category_id'] ?? map['categoryId']),
        map['code']?.toString() ?? '',
        map['name']?.toString() ?? '',
        map['description']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'code': code,
        'name': name,
        'description': description,
      };
}

class CfDamage {
  final int id;
  final int categoryId;
  final String code;
  final String name;
  final String? description;
  final String? solution;
  final double? estimatedCost;
  final String? estimatedTime;
  const CfDamage(this.id, this.categoryId, this.code, this.name,
      [this.description,
      this.solution,
      this.estimatedCost,
      this.estimatedTime]);

  factory CfDamage.fromMap(Map<String, dynamic> map) => CfDamage(
        _cfInt(map['id']),
        _cfInt(map['category_id'] ?? map['categoryId']),
        map['code']?.toString() ?? '',
        map['name']?.toString() ?? '',
        map['description']?.toString(),
        map['solution']?.toString(),
        map['estimated_cost'] == null
            ? null
            : _cfDouble(map['estimated_cost']),
        map['estimated_time']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'code': code,
        'name': name,
        'description': description,
        'solution': solution,
        'estimated_cost': estimatedCost,
        'estimated_time': estimatedTime,
      };
}

class CfRule {
  final int symptomId;
  final int damageId;
  final double cfValue;
  const CfRule(this.symptomId, this.damageId, this.cfValue);

  factory CfRule.fromMap(Map<String, dynamic> map) => CfRule(
        _cfInt(map['symptom_id'] ?? map['symptomId']),
        _cfInt(map['damage_id'] ?? map['damageId']),
        _cfDouble(map['cf_value'] ?? map['cfValue']),
      );

  Map<String, dynamic> toMap() => {
        'symptom_id': symptomId,
        'damage_id': damageId,
        'cf_value': cfValue,
      };
}

/// Result of a single damage after CF combination
class CfResult {
  final CfDamage damage;
  final List<double> cfValues;
  final double cfCombined;
  final double cfPercentage;

  const CfResult({
    required this.damage,
    required this.cfValues,
    required this.cfCombined,
    required this.cfPercentage,
  });

  Map<String, dynamic> toMap() => {
        'id': damage.id,
        'code': damage.code,
        'name': damage.name,
        'description': damage.description,
        'solution': damage.solution,
        'estimated_cost': damage.estimatedCost,
        'estimated_time': damage.estimatedTime,
        'cf_values': cfValues,
        'cf_combined': cfCombined,
        'cf_percentage': cfPercentage,
      };
}

class CfEngine {
  static List<CfCategory>? _runtimeCategories;
  static List<CfSymptom>? _runtimeSymptoms;
  static List<CfDamage>? _runtimeDamages;
  static List<CfRule>? _runtimeRules;
  static int _datasetVersion = 1;
  static String? _datasetPublishedAtIso;

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA — Categories
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<CfCategory> _defaultCategories = [
    CfCategory(1, 'Handphone', 'Diagnosa kerusakan handphone/smartphone'),
    CfCategory(2, 'Laptop', 'Diagnosa kerusakan laptop/notebook'),
  ];

  static List<CfCategory> get categories =>
      List.unmodifiable(_runtimeCategories ?? _defaultCategories);

  static List<CfSymptom> get symptoms =>
      List.unmodifiable(_runtimeSymptoms ?? _defaultSymptoms);

  static List<CfDamage> get damages =>
      List.unmodifiable(_runtimeDamages ?? _defaultDamages);

  static List<CfRule> get rules =>
      List.unmodifiable(_runtimeRules ?? _defaultRules);

  static int get datasetVersion => _datasetVersion;

  static String? get datasetPublishedAtIso => _datasetPublishedAtIso;

  static void resetToDefaults() {
    _runtimeCategories = null;
    _runtimeSymptoms = null;
    _runtimeDamages = null;
    _runtimeRules = null;
    _datasetVersion = 1;
    _datasetPublishedAtIso = null;
  }

  static void loadDatasetMap(
    Map<String, dynamic> map, {
    int? version,
    String? publishedAtIso,
  }) {
    _runtimeCategories = ((map['categories'] as List?) ?? const [])
        .map((item) => CfCategory.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    _runtimeSymptoms = ((map['symptoms'] as List?) ?? const [])
        .map((item) => CfSymptom.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    _runtimeDamages = ((map['damages'] as List?) ?? const [])
        .map((item) => CfDamage.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    _runtimeRules = ((map['rules'] as List?) ?? const [])
        .map((item) => CfRule.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    if (_runtimeCategories!.isEmpty ||
        _runtimeSymptoms!.isEmpty ||
        _runtimeDamages!.isEmpty ||
        _runtimeRules!.isEmpty) {
      resetToDefaults();
      return;
    }

    _datasetVersion = version ?? _cfInt(map['dataset_version'], fallback: 1);
    _datasetPublishedAtIso =
        publishedAtIso ?? map['published_at']?.toString();
  }

  static Map<String, dynamic> exportDatasetMap() => {
        'schema_version': 1,
        'dataset_version': _datasetVersion,
        'published_at': _datasetPublishedAtIso,
        'categories': categories.map((item) => item.toMap()).toList(),
        'symptoms': symptoms.map((item) => item.toMap()).toList(),
        'damages': damages.map((item) => item.toMap()).toList(),
        'rules': rules.map((item) => item.toMap()).toList(),
      };

  static Map<String, dynamic> exportDefaultDatasetMap() => {
        'schema_version': 1,
        'dataset_version': 1,
        'published_at': null,
        'categories': _defaultCategories.map((item) => item.toMap()).toList(),
        'symptoms': _defaultSymptoms.map((item) => item.toMap()).toList(),
        'damages': _defaultDamages.map((item) => item.toMap()).toList(),
        'rules': _defaultRules.map((item) => item.toMap()).toList(),
      };

  static CfCategory? getCategoryById(int id) {
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA — Symptoms (cf_symptoms)
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<CfSymptom> _defaultSymptoms = [
    // ── Handphone (category_id = 1) ──────────────────────────────────────
    CfSymptom(1, 1, 'GH01', 'Handphone tidak bisa dinyalakan sama sekali', 'Tidak ada respon saat tombol power ditekan'),
    CfSymptom(2, 1, 'GH02', 'Layar tidak menampilkan gambar (blank/hitam)', 'Layar hidup tapi gelap atau tidak ada tampilan'),
    CfSymptom(3, 1, 'GH03', 'Layar retak atau pecah', 'Kerusakan fisik pada layar'),
    CfSymptom(4, 1, 'GH04', 'Touchscreen tidak responsif', 'Layar sentuh tidak merespon sentuhan'),
    CfSymptom(5, 1, 'GH05', 'Touchscreen error sebagian area', 'Beberapa area touchscreen tidak berfungsi'),
    CfSymptom(6, 1, 'GH06', 'Baterai cepat habis', 'Daya baterai berkurang sangat cepat'),
    CfSymptom(7, 1, 'GH07', 'Handphone cepat panas', 'Suhu perangkat meningkat drastis saat digunakan'),
    CfSymptom(8, 1, 'GH08', 'Tidak bisa charging', 'Baterai tidak terisi saat dicolok charger'),
    CfSymptom(9, 1, 'GH09', 'Charging lambat atau terputus-putus', 'Proses pengisian daya tidak stabil'),
    CfSymptom(10, 1, 'GH10', 'Tombol power tidak berfungsi', 'Tidak ada respon saat tombol power ditekan'),
    CfSymptom(11, 1, 'GH11', 'Tombol volume tidak berfungsi', 'Tombol volume tidak merespon'),
    CfSymptom(12, 1, 'GH12', 'Speaker tidak mengeluarkan suara', 'Tidak ada audio dari speaker'),
    CfSymptom(13, 1, 'GH13', 'Microphone tidak berfungsi', 'Lawan bicara tidak mendengar suara kita'),
    CfSymptom(14, 1, 'GH14', 'Kamera tidak bisa dibuka', 'Aplikasi kamera error atau crash'),
    CfSymptom(15, 1, 'GH15', 'Hasil foto/video blur atau buram', 'Kualitas gambar tidak fokus'),
    CfSymptom(16, 1, 'GH16', 'Kamera depan/belakang tidak berfungsi', 'Salah satu kamera tidak aktif'),
    CfSymptom(17, 1, 'GH17', 'Tidak bisa mendeteksi kartu SIM', 'SIM card tidak terbaca'),
    CfSymptom(18, 1, 'GH18', 'Sinyal hilang atau lemah', 'Tidak bisa menangkap sinyal operator'),
    CfSymptom(19, 1, 'GH19', 'WiFi tidak bisa connect', 'Tidak bisa terhubung ke jaringan WiFi'),
    CfSymptom(20, 1, 'GH20', 'Bluetooth tidak berfungsi', 'Tidak bisa pairing atau connect bluetooth'),
    CfSymptom(21, 1, 'GH21', 'GPS tidak akurat atau tidak berfungsi', 'Lokasi tidak terdeteksi dengan benar'),
    CfSymptom(22, 1, 'GH22', 'Sensor fingerprint tidak berfungsi', 'Sidik jari tidak terdeteksi'),
    CfSymptom(23, 1, 'GH23', 'Face unlock tidak berfungsi', 'Pengenalan wajah tidak bekerja'),
    CfSymptom(24, 1, 'GH24', 'Port charging kendor atau rusak', 'Kabel charger tidak masuk dengan baik'),
    CfSymptom(25, 1, 'GH25', 'Headphone jack tidak berfungsi', 'Audio tidak keluar saat headphone dipasang'),
    CfSymptom(26, 1, 'GH26', 'Handphone bootloop', 'Restart terus menerus tidak masuk sistem'),
    CfSymptom(27, 1, 'GH27', 'Stuck di logo saat booting', 'Terhenti di logo brand saat dinyalakan'),
    CfSymptom(28, 1, 'GH28', 'Aplikasi sering force close', 'Aplikasi tertutup sendiri secara tiba-tiba'),
    CfSymptom(29, 1, 'GH29', 'Sistem operasi lemot/lag', 'Performa sangat lambat saat digunakan'),
    CfSymptom(30, 1, 'GH30', 'Layar freeze atau hang', 'Layar tidak merespon dan terhenti'),
    CfSymptom(31, 1, 'GH31', 'Muncul iklan/pop-up terus menerus', 'Iklan mengganggu di berbagai aplikasi'),
    CfSymptom(32, 1, 'GH32', 'Baterai drop mendadak dari persentase tinggi', 'Baterai tiba-tiba 0% dari 50%+'),
    CfSymptom(33, 1, 'GH33', 'Storage penuh padahal file sedikit', 'Memori terpakai banyak tanpa file besar'),
    CfSymptom(34, 1, 'GH34', 'Tidak bisa install/update aplikasi', 'Gagal saat install atau update apps'),
    CfSymptom(35, 1, 'GH35', 'Google Play Store error', 'Play Store tidak bisa dibuka atau error'),
    CfSymptom(36, 1, 'GH36', 'Lupa password/pola kunci layar', 'Tidak bisa masuk ke sistem karena lupa kunci'),
    CfSymptom(37, 1, 'GH37', 'Terkena virus atau malware', 'Perilaku aneh seperti iklan, data hilang, dll'),
    CfSymptom(38, 1, 'GH38', 'Auto restart sendiri', 'Handphone restart otomatis tanpa sebab'),
    CfSymptom(39, 1, 'GH39', 'Layar berkedip atau glitch', 'Tampilan layar tidak stabil'),
    CfSymptom(40, 1, 'GH40', 'Tidak ada suara notifikasi', 'Notifikasi masuk tapi tidak ada suara'),
    CfSymptom(41, 1, 'GH41', 'Handphone mati sendiri saat baterai masih banyak', 'Shutdown otomatis meski baterai 30%+'),
    CfSymptom(42, 1, 'GH42', 'Baterai bengkak atau membesar', 'Baterai terlihat menggembung fisik'),
    CfSymptom(43, 1, 'GH43', 'Getaran/vibrator tidak berfungsi', 'Tidak ada getaran saat notifikasi atau panggilan'),
    CfSymptom(44, 1, 'GH44', 'LED notifikasi tidak menyala', 'Lampu indikator notifikasi mati'),
    CfSymptom(45, 1, 'GH45', 'Flash/lampu kamera tidak berfungsi', 'LED flash tidak menyala'),
    CfSymptom(46, 1, 'GH46', 'Sensor cahaya tidak berfungsi', 'Brightness otomatis tidak bekerja'),
    CfSymptom(47, 1, 'GH47', 'Accelerometer/sensor gerak tidak berfungsi', 'Auto rotate layar tidak aktif'),
    CfSymptom(48, 1, 'GH48', 'Kompas/magnetometer tidak akurat', 'Arah navigasi selalu salah'),
    CfSymptom(49, 1, 'GH49', 'Handphone tidak terdeteksi di komputer', 'USB debugging atau MTP tidak connect'),
    CfSymptom(50, 1, 'GH50', 'Layar sentuh bereaksi sendiri (ghost touch)', 'Touchscreen aktif tanpa disentuh'),
    CfSymptom(51, 1, 'GH51', 'Suara speaker kecil atau pelan', 'Volume maksimal tapi suara tetap rendah'),
    CfSymptom(52, 1, 'GH52', 'Suara earpiece tidak terdengar saat telepon', 'Harus pakai loudspeaker untuk dengar'),
    CfSymptom(53, 1, 'GH53', 'Dual SIM salah satu slot tidak berfungsi', 'Hanya 1 SIM yang terdeteksi'),
    CfSymptom(54, 1, 'GH54', 'Sinyal 4G/LTE tidak muncul', 'Hanya dapat sinyal 2G/3G'),
    CfSymptom(55, 1, 'GH55', 'NFC tidak berfungsi', 'Tidak bisa tap untuk pembayaran digital'),
    CfSymptom(56, 1, 'GH56', 'Infrared/IR blaster tidak berfungsi', 'Tidak bisa jadi remote control'),
    CfSymptom(57, 1, 'GH57', 'Autofocus kamera lambat atau tidak fokus', 'Hasil foto selalu blur meski sudah fokus'),
    CfSymptom(58, 1, 'GH58', 'Stabilisasi kamera (OIS) tidak berfungsi', 'Video goyang tidak ada stabilisasi'),
    CfSymptom(59, 1, 'GH59', 'Zoom kamera tidak berfungsi', 'Tidak bisa zoom in/out'),
    CfSymptom(60, 1, 'GH60', 'Mode landscape kamera error', 'Kamera hanya bisa portrait'),
    CfSymptom(61, 1, 'GH61', 'Koneksi internet lambat padahal sinyal kuat', 'Browsing sangat lambat meski full signal'),
    CfSymptom(62, 1, 'GH62', 'Aplikasi tidak bisa download dari Play Store', 'Download pending atau gagal terus'),
    CfSymptom(63, 1, 'GH63', 'Sistem tidak bisa update firmware', 'OTA update selalu gagal'),
    CfSymptom(64, 1, 'GH64', 'Screenshot tidak berfungsi', 'Tidak bisa capture layar'),
    CfSymptom(65, 1, 'GH65', 'Screen recording tidak berfungsi', 'Tidak bisa rekam layar'),
    CfSymptom(66, 1, 'GH66', 'Notifikasi tidak muncul', 'Aplikasi tidak menampilkan notifikasi'),
    CfSymptom(67, 1, 'GH67', 'Keyboard virtual sering error atau lag', 'Mengetik sangat lambat atau tidak muncul'),
    CfSymptom(68, 1, 'GH68', 'Copy paste tidak berfungsi', 'Tidak bisa copy atau paste teks'),
    CfSymptom(69, 1, 'GH69', 'Aplikasi kamera crash saat buka', 'Camera app langsung tertutup'),
    CfSymptom(70, 1, 'GH70', 'Galeri foto tidak bisa dibuka', 'Error saat buka galeri'),
    CfSymptom(71, 1, 'GH71', 'Video tidak bisa diputar', 'File video error atau corrupt'),
    CfSymptom(72, 1, 'GH72', 'Audio Bluetooth putus-putus', 'Suara ke headset bluetooth tidak stabil'),
    CfSymptom(73, 1, 'GH73', 'Hotspot WiFi tidak bisa aktif', 'Tidak bisa sharing internet via WiFi'),
    CfSymptom(74, 1, 'GH74', 'USB tethering tidak berfungsi', 'Tidak bisa sharing internet via USB'),
    CfSymptom(75, 1, 'GH75', 'Aplikasi banking/e-wallet error', 'App penting tidak bisa dibuka'),
    CfSymptom(76, 1, 'GH76', 'Google Assistant tidak merespon', 'Voice command tidak berfungsi'),
    CfSymptom(77, 1, 'GH77', 'Alarm tidak berbunyi', 'Alarm set tapi tidak bunyi'),
    CfSymptom(78, 1, 'GH78', 'Jam/waktu selalu berubah sendiri', 'Setting waktu tidak tersimpan'),
    CfSymptom(79, 1, 'GH79', 'Bahasa sistem berubah sendiri', 'Language setting tidak stabil'),
    CfSymptom(80, 1, 'GH80', 'Dark mode tidak berfungsi', 'Tema gelap tidak apply'),
    // ── Laptop (category_id = 2) ─────────────────────────────────────────
    CfSymptom(81, 2, 'GL01', 'Laptop tidak bisa dinyalakan', 'Tidak ada respon saat tombol power ditekan'),
    CfSymptom(82, 2, 'GL02', 'Laptop mati tiba-tiba saat digunakan', 'Shutdown mendadak tanpa peringatan'),
    CfSymptom(83, 2, 'GL03', 'Layar blank/gelap tapi laptop hidup', 'LED menyala tapi layar tidak tampil'),
    CfSymptom(84, 2, 'GL04', 'Layar bergaris atau bercak', 'Ada garis vertikal/horizontal atau bercak warna'),
    CfSymptom(85, 2, 'GL05', 'Layar retak atau pecah', 'Kerusakan fisik pada LCD'),
    CfSymptom(86, 2, 'GL06', 'Keyboard tidak berfungsi sebagian', 'Beberapa tombol tidak merespon'),
    CfSymptom(87, 2, 'GL07', 'Keyboard tidak berfungsi sama sekali', 'Semua tombol keyboard tidak aktif'),
    CfSymptom(88, 2, 'GL08', 'Touchpad tidak berfungsi', 'Touchpad tidak merespon sentuhan'),
    CfSymptom(89, 2, 'GL09', 'Touchpad terlalu sensitif atau loncat-loncat', 'Cursor bergerak tidak terkontrol'),
    CfSymptom(90, 2, 'GL10', 'Baterai tidak bisa charging', 'Icon charging muncul tapi persentase tidak naik'),
    CfSymptom(91, 2, 'GL11', 'Baterai drop cepat', 'Baterai habis dalam waktu singkat'),
    CfSymptom(92, 2, 'GL12', 'Laptop hanya bisa hidup saat dicharge', 'Mati saat charger dicabut'),
    CfSymptom(93, 2, 'GL13', 'Laptop sangat panas saat digunakan', 'Suhu tinggi terutama di bagian bawah'),
    CfSymptom(94, 2, 'GL14', 'Kipas/fan berisik atau tidak berputar', 'Suara bising atau tidak ada aliran udara'),
    CfSymptom(95, 2, 'GL15', 'Port USB tidak berfungsi', 'Tidak mendeteksi perangkat USB'),
    CfSymptom(96, 2, 'GL16', 'Port HDMI tidak berfungsi', 'Tidak bisa output ke monitor eksternal'),
    CfSymptom(97, 2, 'GL17', 'Audio/speaker tidak bunyi', 'Tidak ada suara keluar dari speaker'),
    CfSymptom(98, 2, 'GL18', 'Audio pecah atau berisik', 'Kualitas suara buruk atau ada noise'),
    CfSymptom(99, 2, 'GL19', 'Microphone tidak berfungsi', 'Tidak merekam suara'),
    CfSymptom(100, 2, 'GL20', 'Webcam tidak terdeteksi', 'Kamera tidak bisa dibuka'),
    CfSymptom(101, 2, 'GL21', 'WiFi tidak bisa connect', 'Tidak mendeteksi jaringan WiFi'),
    CfSymptom(102, 2, 'GL22', 'Bluetooth tidak berfungsi', 'Tidak bisa pairing device'),
    CfSymptom(103, 2, 'GL23', 'Optical drive (DVD) tidak bisa baca disk', 'CD/DVD tidak terbaca'),
    CfSymptom(104, 2, 'GL24', 'Laptop tidak mendeteksi hard disk', 'Error "No Bootable Device"'),
    CfSymptom(105, 2, 'GL25', 'Hard disk bunyi clicking atau berisik', 'Suara aneh dari area hard disk'),
    CfSymptom(106, 2, 'GL26', 'Laptop bootloop atau restart terus', 'Tidak bisa masuk ke Windows'),
    CfSymptom(107, 2, 'GL27', 'Stuck di logo Windows saat booting', 'Proses booting terhenti di logo'),
    CfSymptom(108, 2, 'GL28', 'Blue Screen of Death (BSOD)', 'Muncul layar biru dengan kode error'),
    CfSymptom(109, 2, 'GL29', 'Windows sangat lambat/lemot', 'Performa sistem sangat menurun'),
    CfSymptom(110, 2, 'GL30', 'Aplikasi sering not responding', 'Program sering freeze atau hang'),
    CfSymptom(111, 2, 'GL31', 'Laptop sering freeze/hang', 'Sistem terhenti dan tidak merespon'),
    CfSymptom(112, 2, 'GL32', 'Disk usage 100% terus menerus', 'Hard disk usage selalu penuh di Task Manager'),
    CfSymptom(113, 2, 'GL33', 'CPU usage tinggi tanpa sebab', 'Processor bekerja berat tanpa aplikasi berat'),
    CfSymptom(114, 2, 'GL34', 'Memory/RAM penuh terus', 'RAM usage tinggi meskipun aplikasi sedikit'),
    CfSymptom(115, 2, 'GL35', 'Windows tidak bisa update', 'Gagal install Windows Update'),
    CfSymptom(116, 2, 'GL36', 'Muncul pop-up atau iklan terus menerus', 'Adware mengganggu aktivitas'),
    CfSymptom(117, 2, 'GL37', 'Browser redirect ke situs aneh', 'Browser dibajak malware'),
    CfSymptom(118, 2, 'GL38', 'File hilang atau terenkripsi', 'Data tidak bisa diakses atau hilang'),
    CfSymptom(119, 2, 'GL39', 'Windows tidak bisa login', 'Password salah atau corrupt user profile'),
    CfSymptom(120, 2, 'GL40', 'Muncul pesan "Operating System Not Found"', 'Sistem operasi tidak terdeteksi'),
    CfSymptom(121, 2, 'GL41', 'Laptop masuk safe mode terus', 'Tidak bisa boot ke mode normal'),
    CfSymptom(122, 2, 'GL42', 'Driver hardware error atau missing', 'Perangkat tidak terdeteksi karena driver'),
    CfSymptom(123, 2, 'GL43', 'Layar resolusi berubah atau tidak pas', 'Tampilan tidak sesuai ukuran layar'),
    CfSymptom(124, 2, 'GL44', 'Muncul artefak atau glitch di layar', 'Gangguan visual saat bermain game/video'),
    CfSymptom(125, 2, 'GL45', 'Storage penuh tapi file sedikit', 'Disk space terpakai tanpa file besar jelas'),
    CfSymptom(126, 2, 'GL46', 'Laptop mati total tidak ada indikator', 'Tidak ada LED power atau charging'),
    CfSymptom(127, 2, 'GL47', 'Baterai tidak terdeteksi di Windows', 'Icon baterai hilang atau 0%'),
    CfSymptom(128, 2, 'GL48', 'Charger colokan panas berlebihan', 'Adaptor sangat panas saat charging'),
    CfSymptom(129, 2, 'GL49', 'Laptop berbau terbakar', 'Muncul bau gosong dari dalam laptop'),
    CfSymptom(130, 2, 'GL50', 'Casing laptop retak atau patah', 'Body laptop rusak fisik'),
    CfSymptom(131, 2, 'GL51', 'Engsel laptop patah atau kendor', 'Layar tidak bisa berdiri tegak'),
    CfSymptom(132, 2, 'GL52', 'Laptop tidak bisa sleep/hibernate', 'Tidak bisa masuk mode standby'),
    CfSymptom(133, 2, 'GL53', 'Laptop tiba-tiba mati saat diangkat', 'Mati saat dipindahkan posisi'),
    CfSymptom(134, 2, 'GL54', 'LED keyboard tidak menyala', 'Backlight keyboard mati'),
    CfSymptom(135, 2, 'GL55', 'Num Lock tidak berfungsi', 'Numpad tidak aktif'),
    CfSymptom(136, 2, 'GL56', 'Fn key tidak berfungsi', 'Function key tidak merespon'),
    CfSymptom(137, 2, 'GL57', 'Layar bergaris warna-warni', 'Muncul garis rainbow di layar'),
    CfSymptom(138, 2, 'GL58', 'Layar blank hanya saat buka aplikasi tertentu', 'Layar hitam saat gaming/rendering'),
    CfSymptom(139, 2, 'GL59', 'Second screen tidak terdeteksi', 'Monitor eksternal tidak muncul'),
    CfSymptom(140, 2, 'GL60', 'Layar berkedip atau flicker', 'Brightness naik turun sendiri'),
    CfSymptom(141, 2, 'GL61', 'Pixel mati atau stuck pixel', 'Ada titik hitam/warna di layar'),
    CfSymptom(142, 2, 'GL62', 'Touchscreen laptop tidak berfungsi (jika ada)', 'Layar sentuh tidak aktif'),
    CfSymptom(143, 2, 'GL63', 'Stylus pen tidak terdeteksi', 'Pen digitizer tidak connect'),
    CfSymptom(144, 2, 'GL64', 'Card reader SD tidak berfungsi', 'SD card tidak terbaca'),
    CfSymptom(145, 2, 'GL65', 'Ethernet/LAN port tidak berfungsi', 'Kabel LAN tidak terdeteksi'),
    CfSymptom(146, 2, 'GL66', 'Laptop tidak bisa shutdown', 'Shutdown lama atau restart terus'),
    CfSymptom(147, 2, 'GL67', 'Power button harus ditekan lama', 'Tombol power tidak responsif'),
    CfSymptom(148, 2, 'GL68', 'Laptop berbunyi beep saat dinyalakan', 'Ada bunyi beep code error'),
    CfSymptom(149, 2, 'GL69', 'Laptop masuk ke BIOS terus', 'Tidak bisa boot ke Windows'),
    CfSymptom(150, 2, 'GL70', 'Tanggal dan waktu selalu reset', 'Setting waktu hilang setelah mati'),
    CfSymptom(151, 2, 'GL71', 'Antivirus terdeteksi trojan/malware', 'Scan antivirus menemukan virus'),
    CfSymptom(152, 2, 'GL72', 'Firewall Windows tidak bisa aktif', 'Error saat nyalakan firewall'),
    CfSymptom(153, 2, 'GL73', 'Windows Defender mati terus', 'Real-time protection tidak aktif'),
    CfSymptom(154, 2, 'GL74', 'Printer tidak terdeteksi', 'Tidak bisa print dokumen'),
    CfSymptom(155, 2, 'GL75', 'Sound output tidak bisa ganti', 'Stuck di 1 audio device'),
    CfSymptom(156, 2, 'GL76', 'Microfon tidak terdeteksi di aplikasi', 'Zoom/Teams tidak detect mic'),
    CfSymptom(157, 2, 'GL77', 'Network adapter hilang', 'WiFi dan LAN tidak muncul'),
    CfSymptom(158, 2, 'GL78', 'IP Address conflict', 'Koneksi internet putus-putus karena IP'),
    CfSymptom(159, 2, 'GL79', 'DNS error atau tidak bisa akses website', 'Browser tidak bisa buka situs tertentu'),
    CfSymptom(160, 2, 'GL80', 'VPN tidak bisa connect', 'Virtual Private Network error'),
    CfSymptom(161, 2, 'GL81', 'Remote Desktop tidak berfungsi', 'RDP tidak bisa connect'),
    CfSymptom(162, 2, 'GL82', 'Shared folder tidak bisa diakses', 'File sharing network error'),
    CfSymptom(163, 2, 'GL83', 'Windows activation error', 'Windows tidak genuine atau expire'),
    CfSymptom(164, 2, 'GL84', 'Office/aplikasi lisensi expired', 'Software berbayar tidak aktif'),
    CfSymptom(165, 2, 'GL85', 'Dual boot tidak muncul', 'GRUB atau bootloader hilang'),
    CfSymptom(166, 2, 'GL86', 'Partisi hard disk hilang', 'Drive D, E, dll tidak muncul'),
    CfSymptom(167, 2, 'GL87', 'External hard disk tidak terbaca', 'USB HDD tidak terdeteksi'),
    CfSymptom(168, 2, 'GL88', 'File tidak bisa dihapus (undeletable)', 'Error saat delete file'),
    CfSymptom(169, 2, 'GL89', 'Copy file sangat lambat', 'Transfer data dari/ke USB lama'),
    CfSymptom(170, 2, 'GL90', 'Recycle Bin tidak bisa dikosongkan', 'Error saat empty recycle bin'),
    CfSymptom(171, 2, 'GL91', 'Desktop icon hilang semua', 'Layar desktop kosong'),
    CfSymptom(172, 2, 'GL92', 'Taskbar hilang atau freeze', 'Taskbar Windows tidak muncul'),
    CfSymptom(173, 2, 'GL93', 'Start Menu tidak bisa dibuka', 'Tombol Start tidak respond'),
    CfSymptom(174, 2, 'GL94', 'Windows Search tidak berfungsi', 'Search bar tidak cari file'),
    CfSymptom(175, 2, 'GL95', 'Cortana error atau crash', 'Voice assistant tidak aktif'),
    CfSymptom(176, 2, 'GL96', 'Windows Store tidak bisa dibuka', 'Microsoft Store error'),
    CfSymptom(177, 2, 'GL97', 'OneDrive tidak sinkron', 'Cloud storage tidak update'),
    CfSymptom(178, 2, 'GL98', 'System Restore tidak berfungsi', 'Tidak bisa restore ke titik sebelumnya'),
    CfSymptom(179, 2, 'GL99', 'Event Viewer penuh error merah', 'Banyak critical error di log'),
    CfSymptom(180, 2, 'GL100', 'Services Windows banyak yang stopped', 'Essential services tidak running'),
  ];

  static List<CfSymptom> getSymptomsForCategory(int categoryId) =>
      symptoms.where((s) => s.categoryId == categoryId).toList();

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA — Damages (cf_damages)
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<CfDamage> _defaultDamages = [
    // ── Handphone (category_id = 1, KH01-KH50) ───────────────────────────
    CfDamage(1, 1, 'KH01', 'Baterai Rusak/Bocor', 'Baterai tidak dapat menyimpan daya atau bocor', 'Ganti baterai baru original atau compatible', 150000, '1-2 jam'),
    CfDamage(2, 1, 'KH02', 'IC Power Rusak', 'Chip pengatur daya mengalami kerusakan', 'Ganti atau reball IC power', 300000, '2-3 hari'),
    CfDamage(3, 1, 'KH03', 'LCD/OLED Rusak', 'Layar tidak menampilkan gambar atau retak', 'Ganti LCD/OLED baru', 500000, '2-4 jam'),
    CfDamage(4, 1, 'KH04', 'Touchscreen Digitizer Rusak', 'Lapisan sentuh layar tidak berfungsi', 'Ganti digitizer atau full LCD assembly', 400000, '2-3 jam'),
    CfDamage(5, 1, 'KH05', 'Konektor Charging Rusak', 'Port charging kendor atau patah', 'Ganti konektor charging', 150000, '1-2 jam'),
    CfDamage(6, 1, 'KH06', 'Motherboard Short/Rusak', 'Jalur motherboard korsleting atau komponen rusak', 'Repair jalur atau ganti motherboard', 800000, '3-5 hari'),
    CfDamage(7, 1, 'KH07', 'IC Charging Rusak', 'Chip pengisian daya tidak berfungsi', 'Ganti atau reball IC charging', 250000, '1-2 hari'),
    CfDamage(8, 1, 'KH08', 'Flexibel/Konektor LCD Rusak', 'Kabel penghubung LCD ke motherboard bermasalah', 'Ganti flexibel atau repair konektor', 200000, '1-2 jam'),
    CfDamage(9, 1, 'KH09', 'Kerusakan Tombol Power/Volume', 'Tombol fisik tidak berfungsi', 'Ganti switch button atau flexibel tombol', 100000, '1 jam'),
    CfDamage(10, 1, 'KH10', 'Speaker Rusak', 'Speaker tidak mengeluarkan suara', 'Ganti speaker baru', 100000, '1 jam'),
    CfDamage(11, 1, 'KH11', 'Microphone Rusak', 'Mic tidak menangkap suara', 'Ganti microphone', 80000, '1 jam'),
    CfDamage(12, 1, 'KH12', 'Kamera Rusak', 'Kamera depan atau belakang tidak berfungsi', 'Ganti modul kamera', 300000, '1-2 jam'),
    CfDamage(13, 1, 'KH13', 'Slot SIM Card Rusak', 'SIM card tidak terbaca', 'Ganti slot SIM card', 150000, '1-2 jam'),
    CfDamage(14, 1, 'KH14', 'IC RF/Sinyal Rusak', 'Tidak dapat menangkap sinyal operator', 'Ganti atau reball IC RF/PA', 350000, '2-3 hari'),
    CfDamage(15, 1, 'KH15', 'IC WiFi/Bluetooth Rusak', 'WiFi dan Bluetooth tidak berfungsi', 'Ganti atau reball IC WiFi', 300000, '2-3 hari'),
    CfDamage(16, 1, 'KH16', 'Sensor Fingerprint Rusak', 'Sensor sidik jari tidak mendeteksi', 'Ganti sensor fingerprint', 250000, '2-3 jam'),
    CfDamage(17, 1, 'KH17', 'IC Audio/Codec Rusak', 'Masalah pada sistem audio', 'Ganti atau reball IC audio', 280000, '2-3 hari'),
    CfDamage(18, 1, 'KH18', 'Software Corrupt/Bootloop', 'Sistem operasi rusak atau bootloop', 'Flash/install ulang firmware', 150000, '2-3 jam'),
    CfDamage(19, 1, 'KH19', 'Virus/Malware Terinfeksi', 'Perangkat terinfeksi virus atau malware', 'Factory reset dan install antivirus', 100000, '1-2 jam'),
    CfDamage(20, 1, 'KH20', 'Memory/Storage Bermasalah', 'Storage penuh atau corrupt', 'Clear cache, factory reset, atau ganti IC memory', 200000, '1-3 jam'),
    CfDamage(21, 1, 'KH21', 'GPS Module Rusak', 'GPS tidak dapat mendeteksi lokasi', 'Ganti atau reball GPS module', 280000, '2-3 hari'),
    CfDamage(22, 1, 'KH22', 'Proximity Sensor Rusak', 'Sensor jarak tidak berfungsi saat telepon', 'Ganti sensor proximity', 120000, '1 jam'),
    CfDamage(23, 1, 'KH23', 'Gyroscope Sensor Rusak', 'Sensor rotasi tidak berfungsi', 'Ganti sensor gyroscope', 200000, '1-2 jam'),
    CfDamage(24, 1, 'KH24', 'Kabel Flex Antenna Rusak', 'Kabel antena putus atau kendor', 'Ganti atau repair flex antenna', 150000, '1-2 jam'),
    CfDamage(25, 1, 'KH25', 'Overheating/IC CPU Rusak', 'Processor terlalu panas atau rusak', 'Reball atau ganti IC CPU (sangat mahal)', 1500000, '5-7 hari'),
    CfDamage(26, 1, 'KH26', 'Vibrator Motor Rusak', 'Getaran tidak berfungsi', 'Ganti vibrator motor', 80000, '1 jam'),
    CfDamage(27, 1, 'KH27', 'LED Notifikasi Rusak', 'Lampu indikator tidak menyala', 'Ganti LED notifikasi atau repair jalur', 100000, '1-2 jam'),
    CfDamage(28, 1, 'KH28', 'Flash LED Rusak', 'Lampu flash kamera tidak menyala', 'Ganti modul flash LED', 150000, '1-2 jam'),
    CfDamage(29, 1, 'KH29', 'Sensor Cahaya Rusak', 'Auto brightness tidak berfungsi', 'Ganti sensor cahaya/proximity', 150000, '1-2 jam'),
    CfDamage(30, 1, 'KH30', 'Accelerometer Rusak', 'Auto rotate tidak aktif', 'Ganti sensor accelerometer', 180000, '2-3 jam'),
    CfDamage(31, 1, 'KH31', 'Magnetometer/Kompas Rusak', 'Kompas tidak akurat', 'Kalibrasi atau ganti sensor magnetometer', 200000, '2-3 jam'),
    CfDamage(32, 1, 'KH32', 'Konektor USB/Data Rusak', 'Tidak terdeteksi di PC', 'Ganti konektor USB atau repair jalur data', 180000, '1-2 jam'),
    CfDamage(33, 1, 'KH33', 'IC Touch Rusak', 'Ghost touch atau sentuhan tidak akurat', 'Ganti atau reball IC touch controller', 350000, '2-3 hari'),
    CfDamage(34, 1, 'KH34', 'Amplifier/IC Speaker Rusak', 'Suara speaker pelan atau pecah', 'Ganti IC amplifier', 250000, '2-3 hari'),
    CfDamage(35, 1, 'KH35', 'Dual SIM Tray Rusak', 'Salah satu slot SIM tidak berfungsi', 'Ganti dual SIM tray', 150000, '1-2 jam'),
    CfDamage(36, 1, 'KH36', 'Modem 4G/LTE Rusak', 'Hanya dapat sinyal 2G/3G', 'Flash modem firmware atau ganti IC modem', 400000, '2-4 hari'),
    CfDamage(37, 1, 'KH37', 'NFC Chip Rusak', 'NFC tidak berfungsi untuk pembayaran', 'Ganti NFC chip atau antenna', 200000, '2-3 jam'),
    CfDamage(38, 1, 'KH38', 'IR Blaster Rusak', 'Infrared remote tidak berfungsi', 'Ganti IR blaster module', 120000, '1 jam'),
    CfDamage(39, 1, 'KH39', 'Autofocus Motor Rusak', 'Kamera tidak bisa fokus', 'Ganti autofocus actuator kamera', 250000, '2-3 jam'),
    CfDamage(40, 1, 'KH40', 'OIS Module Rusak', 'Stabilisasi video tidak berfungsi', 'Ganti OIS (Optical Image Stabilization)', 400000, '3-4 jam'),
    CfDamage(41, 1, 'KH41', 'Face ID/Face Unlock Sensor Rusak', 'Pengenalan wajah tidak aktif', 'Ganti sensor face recognition', 500000, '3-5 jam'),
    CfDamage(42, 1, 'KH42', 'EMMC/Storage IC Rusak', 'Storage corrupt atau tidak terbaca', 'Reball atau ganti IC EMMC', 800000, '4-6 hari'),
    CfDamage(43, 1, 'KH43', 'RAM IC Rusak', 'Bootloop atau system crash', 'Reball atau upgrade RAM (rawan)', 900000, '5-7 hari'),
    CfDamage(44, 1, 'KH44', 'System Partition Corrupt', 'Bootloop karena system corrupt', 'Flash firmware complete atau unbrick', 200000, '2-4 jam'),
    CfDamage(45, 1, 'KH45', 'Baseband Corrupt', 'IMEI hilang atau null', 'Repair baseband via flash tool khusus', 300000, '2-3 hari'),
    CfDamage(46, 1, 'KH46', 'Custom ROM Tidak Cocok', 'Bootloop atau fitur tidak jalan setelah custom ROM', 'Flash back stock ROM', 150000, '2-3 jam'),
    CfDamage(47, 1, 'KH47', 'Root Access Bermasalah', 'Bootloop atau app banking tidak jalan', 'Unroot dan restore system', 150000, '1-2 jam'),
    CfDamage(48, 1, 'KH48', 'Google Service Framework Error', 'Play Store dan Google Apps error', 'Clear data GSF dan re-login Google', 100000, '1 jam'),
    CfDamage(49, 1, 'KH49', 'Factory Reset Protection (FRP) Lock', 'Tidak bisa akses karena FRP lock', 'Bypass FRP atau verifikasi akun Google', 200000, '1-3 jam'),
    CfDamage(50, 1, 'KH50', 'Knox/Bootloader Terkunci', 'Tidak bisa flash atau root', 'Unlock bootloader (garansi hilang)', 250000, '2-3 jam'),
    // ── Laptop (category_id = 2, KL01-KL75) ─────────────────────────────
    CfDamage(51, 2, 'KL01', 'Baterai Rusak/Drop', 'Baterai tidak dapat menyimpan daya atau drop cepat', 'Ganti baterai laptop baru', 500000, '1-2 jam'),
    CfDamage(52, 2, 'KL02', 'Adaptor/Charger Rusak', 'Charger tidak mengeluarkan daya', 'Ganti adaptor/charger original', 300000, '1 jam'),
    CfDamage(53, 2, 'KL03', 'Jack Power/DC Jack Rusak', 'Port charging kendor atau tidak mengisi', 'Ganti jack power atau re-solder', 200000, '2-3 jam'),
    CfDamage(54, 2, 'KL04', 'LCD Rusak', 'Layar bergaris, bercak, atau retak', 'Ganti LCD panel baru', 1200000, '3-5 jam'),
    CfDamage(55, 2, 'KL05', 'Flexibel/Cable LCD Rusak', 'Kabel penghubung LCD ke motherboard bermasalah', 'Ganti cable LCD', 250000, '2-3 jam'),
    CfDamage(56, 2, 'KL06', 'Inverter Rusak (Laptop Lama)', 'Backlight LCD tidak menyala', 'Ganti inverter board', 300000, '2-3 jam'),
    CfDamage(57, 2, 'KL07', 'Keyboard Rusak', 'Keyboard tidak berfungsi sebagian atau total', 'Ganti keyboard laptop', 350000, '1-2 jam'),
    CfDamage(58, 2, 'KL08', 'Touchpad Rusak', 'Touchpad tidak responsif atau rusak', 'Ganti touchpad module', 300000, '2-3 jam'),
    CfDamage(59, 2, 'KL09', 'RAM Bermasalah', 'Memory error atau tidak terdeteksi', 'Ganti atau tambah RAM baru', 400000, '1 jam'),
    CfDamage(60, 2, 'KL10', 'Hard Disk Rusak/Bad Sector', 'HDD error, bunyi clicking, atau bad sector', 'Ganti HDD/SSD baru', 600000, '2-4 jam'),
    CfDamage(61, 2, 'KL11', 'Motherboard Short/Rusak', 'Jalur motherboard korsleting atau chip rusak', 'Repair motherboard atau ganti (mahal)', 1500000, '5-7 hari'),
    CfDamage(62, 2, 'KL12', 'VGA/GPU Rusak', 'Chip grafis rusak (artifact, no display, BSOD)', 'Reball atau ganti VGA chip', 1800000, '5-7 hari'),
    CfDamage(63, 2, 'KL13', 'Processor/CPU Overheat', 'CPU terlalu panas akibat thermal paste kering', 'Ganti thermal paste dan bersihkan cooling system', 150000, '1-2 jam'),
    CfDamage(64, 2, 'KL14', 'Fan/Kipas Rusak', 'Kipas tidak berputar atau berisik', 'Ganti cooling fan', 250000, '1-2 jam'),
    CfDamage(65, 2, 'KL15', 'BIOS Corrupt', 'BIOS error atau setting bermasalah', 'Flash/reset BIOS', 200000, '1-2 jam'),
    CfDamage(66, 2, 'KL16', 'CMOS Battery Habis', 'Laptop tidak menyimpan setting tanggal/waktu', 'Ganti baterai CMOS', 50000, '30 menit'),
    CfDamage(67, 2, 'KL17', 'Port USB Rusak', 'Port USB tidak mendeteksi perangkat', 'Ganti port USB atau repair solder', 150000, '1-2 jam'),
    CfDamage(68, 2, 'KL18', 'Port HDMI Rusak', 'Port HDMI tidak output video', 'Ganti port HDMI atau repair', 200000, '2-3 jam'),
    CfDamage(69, 2, 'KL19', 'Sound Card/Audio IC Rusak', 'Audio tidak berfungsi atau berisik', 'Ganti audio IC atau repair jalur audio', 300000, '2-3 hari'),
    CfDamage(70, 2, 'KL20', 'Webcam Rusak', 'Kamera laptop tidak terdeteksi', 'Ganti modul webcam', 200000, '1-2 jam'),
    CfDamage(71, 2, 'KL21', 'WiFi Card Rusak', 'WiFi tidak dapat connect', 'Ganti WiFi card module', 200000, '1 jam'),
    CfDamage(72, 2, 'KL22', 'Bluetooth Module Rusak', 'Bluetooth tidak berfungsi', 'Ganti atau install ulang driver bluetooth', 150000, '1 jam'),
    CfDamage(73, 2, 'KL23', 'Optical Drive Rusak', 'DVD/CD drive tidak bisa baca disk', 'Ganti optical drive atau clean laser', 300000, '1-2 jam'),
    CfDamage(74, 2, 'KL24', 'Windows Corrupt/Crash', 'Sistem operasi rusak atau BSOD', 'Install ulang Windows + driver', 200000, '2-4 jam'),
    CfDamage(75, 2, 'KL25', 'Virus/Malware Terinfeksi', 'Laptop terinfeksi virus berat', 'Scan antivirus mendalam atau install ulang OS', 150000, '2-3 jam'),
    CfDamage(76, 2, 'KL26', 'SSD/HDD Full/Bermasalah', 'Storage penuh atau performa lambat', 'Upgrade SSD atau clean storage', 700000, '2-3 jam'),
    CfDamage(77, 2, 'KL27', 'Driver Hardware Bermasalah', 'Driver tidak terinstall atau corrupt', 'Install/update driver yang sesuai', 100000, '1-2 jam'),
    CfDamage(78, 2, 'KL28', 'Bootloader/MBR Rusak', 'Laptop tidak bisa boot ke OS', 'Repair MBR/bootloader via command', 150000, '1-2 jam'),
    CfDamage(79, 2, 'KL29', 'Windows Update Error', 'Gagal install update atau rollback', 'Fix Windows Update component', 150000, '2-3 jam'),
    CfDamage(80, 2, 'KL30', 'Sistem Lemot/Butuh Maintenance', 'Performa sangat lambat karena sampah file', 'Clean temporary files, defrag, optimize', 100000, '1-2 jam'),
    CfDamage(81, 2, 'KL31', 'Power IC Motherboard Rusak', 'Laptop mati total atau tidak charging', 'Ganti IC power management', 600000, '3-5 hari'),
    CfDamage(82, 2, 'KL32', 'Chipset Overheat', 'Area chipset sangat panas', 'Reball chipset dan ganti thermal pad', 800000, '4-6 hari'),
    CfDamage(83, 2, 'KL33', 'Keyboard Flex Cable Rusak', 'Keyboard tidak berfungsi meski sudah ganti keyboard', 'Ganti flexibel cable keyboard', 200000, '2-3 jam'),
    CfDamage(84, 2, 'KL34', 'Touchpad Cable Rusak', 'Touchpad tidak berfungsi meski sudah ganti', 'Ganti touchpad cable', 180000, '2-3 jam'),
    CfDamage(85, 2, 'KL35', 'Heatsink Mampet Debu', 'Overheat karena sirkulasi udara tersumbat', 'Bongkar dan bersihkan heatsink', 150000, '1-2 jam'),
    CfDamage(86, 2, 'KL36', 'Thermal Paste Kering', 'CPU/GPU overheat', 'Ganti thermal paste premium', 100000, '1 jam'),
    CfDamage(87, 2, 'KL37', 'LVDS Cable Rusak', 'Layar bergaris atau blank intermittent', 'Ganti LVDS/eDP cable', 300000, '2-4 jam'),
    CfDamage(88, 2, 'KL38', 'Backlight Fuse Putus', 'Layar gelap tapi masih ada bayangan', 'Repair atau jumper backlight fuse', 250000, '2-3 hari'),
    CfDamage(89, 2, 'KL39', 'LED Driver IC Rusak', 'Backlight tidak menyala', 'Ganti LED driver IC pada LCD', 400000, '3-5 hari'),
    CfDamage(90, 2, 'KL40', 'GPU Artifacts/Dying', 'Layar bergaris warna atau artifact saat gaming', 'Reball GPU atau downgrade driver', 1500000, '5-7 hari'),
    CfDamage(91, 2, 'KL41', 'VRAM Rusak', 'Artifact atau crash saat aplikasi grafis', 'Ganti VRAM chip (sangat sulit)', 2000000, '7-10 hari'),
    CfDamage(92, 2, 'KL42', 'South Bridge Rusak', 'USB, audio, dan perangkat onboard error', 'Reball atau ganti south bridge chip', 1200000, '5-7 hari'),
    CfDamage(93, 2, 'KL43', 'North Bridge Rusak', 'Laptop tidak boot atau RAM tidak terdeteksi', 'Reball atau ganti north bridge', 1300000, '5-7 hari'),
    CfDamage(94, 2, 'KL44', 'EC (Embedded Controller) Error', 'Keyboard, fan, charging tidak normal', 'Flash atau ganti EC chip', 500000, '3-4 hari'),
    CfDamage(95, 2, 'KL45', 'BIOS Chip Rusak', 'Laptop mati total atau corrupt BIOS', 'Ganti BIOS chip dan flash ulang', 300000, '2-3 hari'),
    CfDamage(96, 2, 'KL46', 'RTC Battery/CMOS Rusak', 'Tanggal reset dan BIOS setting hilang', 'Ganti CMOS battery', 50000, '30 menit'),
    CfDamage(97, 2, 'KL47', 'Speaker Amplifier Rusak', 'Audio tidak keluar atau pecah', 'Ganti audio amplifier IC', 350000, '2-3 hari'),
    CfDamage(98, 2, 'KL48', 'Audio Codec Chip Rusak', 'Sistem audio mati total', 'Ganti audio codec IC', 400000, '3-4 hari'),
    CfDamage(99, 2, 'KL49', 'Webcam Module Rusak', 'Kamera laptop error atau gambar blur', 'Ganti modul webcam', 250000, '1-2 jam'),
    CfDamage(100, 2, 'KL50', 'WiFi Antenna Cable Putus', 'Sinyal WiFi lemah atau tidak stabil', 'Ganti antenna cable WiFi', 150000, '1-2 jam'),
    CfDamage(101, 2, 'KL51', 'Bluetooth Module Conflict', 'Bluetooth on/off terus atau tidak pair', 'Reinstall driver atau ganti module', 200000, '1-2 jam'),
    CfDamage(102, 2, 'KL52', 'SSD Controller Rusak', 'SSD tidak terdeteksi atau corrupt', 'Ganti SSD baru', 800000, '2-3 jam'),
    CfDamage(103, 2, 'KL53', 'SSD Bad Block', 'File corrupt atau sistem lambat', 'Clone ke SSD baru', 700000, '3-4 jam'),
    CfDamage(104, 2, 'KL54', 'M.2 Slot Rusak', 'SSD M.2 tidak terdeteksi', 'Repair M.2 slot atau gunakan SATA', 300000, '2-3 hari'),
    CfDamage(105, 2, 'KL55', 'SATA Port Rusak', 'Hard disk/SSD SATA tidak terbaca', 'Repair SATA port atau gunakan M.2', 250000, '2-3 hari'),
    CfDamage(106, 2, 'KL56', 'HDD PCB Board Rusak', 'Hard disk tidak berputar', 'Ganti PCB board HDD (data bisa diselamatkan)', 400000, '2-3 hari'),
    CfDamage(107, 2, 'KL57', 'HDD Motor Mati', 'Hard disk tidak berputar sama sekali', 'Recovery data ke HDD baru', 1000000, '3-7 hari'),
    CfDamage(108, 2, 'KL58', 'Optical Drive Laser Lemah', 'CD/DVD tidak bisa baca', 'Clean laser atau ganti optical drive', 300000, '1-2 jam'),
    CfDamage(109, 2, 'KL59', 'USB Controller Chip Rusak', 'Semua USB port mati', 'Ganti USB controller IC', 500000, '3-5 hari'),
    CfDamage(110, 2, 'KL60', 'HDMI IC Rusak', 'Port HDMI tidak output video', 'Ganti HDMI transmitter IC', 400000, '3-4 hari'),
    CfDamage(111, 2, 'KL61', 'Display Port Rusak', 'DP tidak mendeteksi monitor', 'Repair atau ganti DP connector', 350000, '2-3 hari'),
    CfDamage(112, 2, 'KL62', 'Thunderbolt Controller Rusak', 'Port Thunderbolt tidak berfungsi', 'Ganti Thunderbolt controller', 800000, '4-6 hari'),
    CfDamage(113, 2, 'KL63', 'SD Card Reader Controller Rusak', 'Card reader tidak detect SD card', 'Ganti card reader module', 200000, '1-2 jam'),
    CfDamage(114, 2, 'KL64', 'Ethernet Controller Rusak', 'LAN port tidak berfungsi', 'Ganti ethernet controller chip', 300000, '2-3 hari'),
    CfDamage(115, 2, 'KL65', 'Windows Corrupt Beyond Repair', 'System file corrupt parah', 'Clean install Windows', 200000, '2-4 jam'),
    CfDamage(116, 2, 'KL66', 'Ransomware Terinfeksi', 'File terenkripsi ransomware', 'Remove ransomware dan decrypt (tidak selalu berhasil)', 500000, '4-8 jam'),
    CfDamage(117, 2, 'KL67', 'Rootkit Terinstall', 'Malware deep di system', 'Format complete dan install ulang', 250000, '3-5 jam'),
    CfDamage(118, 2, 'KL68', 'MBR/GPT Corrupt', 'Laptop tidak boot dengan error disk', 'Repair MBR atau convert MBR/GPT', 200000, '1-2 jam'),
    CfDamage(119, 2, 'KL69', 'Boot Configuration Data (BCD) Error', 'Error boot Windows', 'Rebuild BCD via recovery', 150000, '1-2 jam'),
    CfDamage(120, 2, 'KL70', 'System Reserved Partition Hilang', 'Boot error setelah clone atau resize', 'Recreate system partition', 200000, '2-3 jam'),
    CfDamage(121, 2, 'KL71', 'Registry Corrupt', 'Windows error atau tidak stabil', 'Restore registry atau repair Windows', 180000, '2-3 jam'),
    CfDamage(122, 2, 'KL72', 'User Profile Corrupt', 'Tidak bisa login atau desktop error', 'Create new user profile', 150000, '1-2 jam'),
    CfDamage(123, 2, 'KL73', 'Windows Activation Hack Detected', 'Windows deactivated atau genuine error', 'Install Windows original dengan lisensi legal', 250000, '2-3 jam'),
    CfDamage(124, 2, 'KL74', 'DirectX/Graphics API Error', 'Game tidak bisa jalan atau crash', 'Reinstall DirectX dan Visual C++', 100000, '1 jam'),
    CfDamage(125, 2, 'KL75', '.NET Framework Error', 'Aplikasi tidak bisa jalan', 'Repair atau reinstall .NET Framework', 100000, '1-2 jam'),
  ];

  static List<CfDamage> getDamagesForCategory(int categoryId) =>
      damages.where((d) => d.categoryId == categoryId).toList();

  static CfDamage? getDamageById(int id) {
    try {
      return damages.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA — Rules (cf_rules: 313 rules)
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<CfRule> _defaultRules = [
    CfRule(6, 1, 0.85),  CfRule(8, 1, 0.80),  CfRule(32, 1, 0.75), CfRule(11, 1, 0.70),
    CfRule(1, 2, 0.85),  CfRule(7, 2, 0.70),  CfRule(8, 2, 0.65),
    CfRule(2, 3, 0.90),  CfRule(3, 3, 0.95),  CfRule(39, 3, 0.75),
    CfRule(4, 4, 0.90),  CfRule(5, 4, 0.85),
    CfRule(8, 5, 0.80),  CfRule(9, 5, 0.85),  CfRule(24, 5, 0.95),
    CfRule(1, 6, 0.75),  CfRule(7, 6, 0.80),  CfRule(38, 6, 0.70),
    CfRule(8, 7, 0.75),  CfRule(9, 7, 0.80),  CfRule(7, 7, 0.65),
    CfRule(2, 8, 0.70),  CfRule(39, 8, 0.80),
    CfRule(10, 9, 0.95), CfRule(11, 9, 0.95),
    CfRule(12, 10, 0.90),CfRule(40, 10, 0.75),
    CfRule(13, 11, 0.95),
    CfRule(14, 12, 0.85),CfRule(15, 12, 0.80),CfRule(16, 12, 0.90),
    CfRule(17, 13, 0.95),
    CfRule(18, 14, 0.90),CfRule(17, 14, 0.70),
    CfRule(19, 15, 0.90),CfRule(20, 15, 0.90),
    CfRule(22, 16, 0.95),
    CfRule(12, 17, 0.75),CfRule(13, 17, 0.70),CfRule(25, 17, 0.80),
    CfRule(26, 18, 0.95),CfRule(27, 18, 0.90),CfRule(30, 18, 0.70),
    CfRule(31, 19, 0.90),CfRule(37, 19, 0.95),CfRule(28, 19, 0.75),
    CfRule(33, 20, 0.85),CfRule(34, 20, 0.80),CfRule(29, 20, 0.70),
    CfRule(21, 21, 0.95),
    CfRule(2, 22, 0.60),
    CfRule(7, 25, 0.85), CfRule(29, 25, 0.75),CfRule(38, 25, 0.70),
    CfRule(43, 26, 0.95),
    CfRule(44, 27, 0.95),
    CfRule(45, 28, 0.95),
    CfRule(46, 29, 0.95),
    CfRule(47, 30, 0.95),
    CfRule(48, 31, 0.95),
    CfRule(49, 32, 0.90),
    CfRule(50, 33, 0.95),CfRule(4, 33, 0.80), CfRule(5, 33, 0.75),
    CfRule(51, 34, 0.90),CfRule(12, 34, 0.70),
    CfRule(53, 35, 0.95),
    CfRule(54, 36, 0.90),CfRule(18, 36, 0.75),
    CfRule(55, 37, 0.95),
    CfRule(56, 38, 0.95),
    CfRule(57, 39, 0.90),CfRule(15, 39, 0.85),
    CfRule(58, 40, 0.95),
    CfRule(23, 41, 0.95),
    CfRule(1, 42, 0.70), CfRule(26, 42, 0.80),CfRule(33, 42, 0.75),
    CfRule(26, 43, 0.75),CfRule(30, 43, 0.80),CfRule(29, 43, 0.70),
    CfRule(26, 44, 0.85),CfRule(27, 44, 0.90),
    CfRule(17, 45, 0.80),CfRule(18, 45, 0.85),
    CfRule(26, 46, 0.70),CfRule(28, 46, 0.75),
    CfRule(28, 47, 0.70),CfRule(75, 47, 0.85),
    CfRule(35, 48, 0.90),CfRule(62, 48, 0.85),
    CfRule(36, 49, 0.80),
    CfRule(27, 50, 0.65),
    CfRule(41, 1, 0.90), CfRule(42, 1, 0.95),
    CfRule(52, 10, 0.85),
    CfRule(59, 12, 0.70),CfRule(60, 12, 0.70),CfRule(69, 12, 0.80),
    CfRule(61, 20, 0.70),
    CfRule(62, 19, 0.65),
    CfRule(63, 20, 0.75),
    CfRule(64, 18, 0.65),
    CfRule(66, 18, 0.70),
    CfRule(67, 20, 0.75),
    CfRule(70, 18, 0.70),
    CfRule(71, 18, 0.65),
    CfRule(72, 15, 0.80),CfRule(73, 15, 0.75),
    CfRule(74, 32, 0.70),
    CfRule(75, 19, 0.80),
    CfRule(76, 11, 0.70),
    CfRule(77, 10, 0.65),
    CfRule(78, 18, 0.75),
    CfRule(79, 18, 0.70),
    CfRule(80, 18, 0.60),
    // Laptop rules (damage id 51-125)
    CfRule(91, 51, 0.90),CfRule(90, 51, 0.85),CfRule(92, 51, 0.80),
    CfRule(90, 52, 0.80),CfRule(92, 52, 0.85),
    CfRule(90, 53, 0.85),CfRule(92, 53, 0.75),
    CfRule(84, 54, 0.95),CfRule(85, 54, 0.95),CfRule(83, 54, 0.70),
    CfRule(83, 55, 0.85),CfRule(84, 55, 0.75),
    CfRule(86, 57, 0.90),CfRule(87, 57, 0.95),
    CfRule(88, 58, 0.90),CfRule(89, 58, 0.85),
    CfRule(108, 59, 0.80),CfRule(109, 59, 0.75),CfRule(114, 59, 0.85),
    CfRule(104, 60, 0.95),CfRule(105, 60, 0.90),CfRule(120, 60, 0.85),CfRule(109, 60, 0.70),
    CfRule(81, 61, 0.80),CfRule(82, 61, 0.75),CfRule(93, 61, 0.70),
    CfRule(124, 62, 0.90),CfRule(108, 62, 0.85),CfRule(83, 62, 0.75),CfRule(84, 62, 0.70),
    CfRule(93, 63, 0.90),CfRule(82, 63, 0.80),CfRule(109, 63, 0.75),
    CfRule(94, 64, 0.95),CfRule(93, 64, 0.85),
    CfRule(106, 65, 0.70),CfRule(107, 65, 0.75),CfRule(81, 65, 0.65),
    CfRule(95, 67, 0.95),
    CfRule(96, 68, 0.95),
    CfRule(97, 69, 0.90),CfRule(98, 69, 0.85),CfRule(99, 69, 0.80),
    CfRule(100, 70, 0.95),
    CfRule(101, 71, 0.90),
    CfRule(102, 72, 0.90),
    CfRule(103, 73, 0.95),
    CfRule(106, 74, 0.85),CfRule(107, 74, 0.85),CfRule(108, 74, 0.90),CfRule(111, 74, 0.75),
    CfRule(116, 75, 0.95),CfRule(117, 75, 0.95),CfRule(118, 75, 0.85),
    CfRule(112, 76, 0.85),CfRule(125, 76, 0.90),CfRule(109, 76, 0.70),
    CfRule(122, 77, 0.95),CfRule(123, 77, 0.80),
    CfRule(120, 78, 0.90),CfRule(106, 78, 0.75),
    CfRule(115, 79, 0.95),
    CfRule(109, 80, 0.80),CfRule(110, 80, 0.85),CfRule(111, 80, 0.75),CfRule(113, 80, 0.70),
    CfRule(126, 81, 0.90),CfRule(81, 81, 0.85),CfRule(90, 81, 0.75),
    CfRule(93, 82, 0.85),CfRule(82, 82, 0.80),
    CfRule(86, 83, 0.80),CfRule(87, 83, 0.85),
    CfRule(88, 84, 0.80),
    CfRule(93, 85, 0.85),CfRule(94, 85, 0.80),CfRule(109, 85, 0.70),
    CfRule(93, 86, 0.90),CfRule(82, 86, 0.75),
    CfRule(137, 87, 0.90),CfRule(84, 87, 0.85),CfRule(83, 87, 0.80),
    CfRule(83, 88, 0.90),
    CfRule(83, 89, 0.85),CfRule(134, 89, 0.75),
    CfRule(124, 90, 0.95),CfRule(137, 90, 0.85),CfRule(108, 90, 0.80),
    CfRule(124, 91, 0.90),CfRule(108, 91, 0.85),
    CfRule(95, 92, 0.80),CfRule(97, 92, 0.80),CfRule(122, 92, 0.75),
    CfRule(81, 93, 0.75),CfRule(108, 93, 0.80),
    CfRule(86, 94, 0.70),CfRule(94, 94, 0.75),CfRule(90, 94, 0.70),
    CfRule(126, 95, 0.85),CfRule(81, 95, 0.80),CfRule(148, 95, 0.90),
    CfRule(150, 96, 0.95),
    CfRule(97, 97, 0.85),CfRule(98, 97, 0.90),
    CfRule(97, 98, 0.90),CfRule(99, 98, 0.85),
    CfRule(100, 99, 0.95),CfRule(156, 99, 0.80),
    CfRule(101, 100, 0.85),
    CfRule(102, 101, 0.90),
    CfRule(104, 102, 0.90),CfRule(120, 102, 0.85),
    CfRule(109, 103, 0.80),CfRule(112, 103, 0.85),CfRule(111, 103, 0.75),
    CfRule(104, 104, 0.85),
    CfRule(104, 105, 0.80),CfRule(167, 105, 0.75),
    CfRule(104, 106, 0.85),CfRule(105, 106, 0.75),
    CfRule(104, 107, 0.90),CfRule(105, 107, 0.95),
    CfRule(103, 108, 0.95),
    CfRule(95, 109, 0.90),
    CfRule(96, 110, 0.95),CfRule(139, 110, 0.85),
    CfRule(139, 111, 0.90),
    CfRule(95, 112, 0.80),
    CfRule(144, 113, 0.95),
    CfRule(145, 114, 0.95),
    CfRule(106, 115, 0.80),CfRule(108, 115, 0.85),CfRule(111, 115, 0.80),
    CfRule(118, 116, 0.95),CfRule(151, 116, 0.90),
    CfRule(116, 117, 0.90),CfRule(117, 117, 0.90),CfRule(151, 117, 0.95),
    CfRule(120, 118, 0.95),CfRule(166, 118, 0.85),
    CfRule(106, 119, 0.85),CfRule(120, 119, 0.90),
    CfRule(120, 120, 0.85),CfRule(166, 120, 0.80),
    CfRule(108, 121, 0.80),CfRule(110, 121, 0.75),CfRule(111, 121, 0.75),
    CfRule(119, 122, 0.95),CfRule(171, 122, 0.85),
    CfRule(163, 123, 0.95),
    CfRule(124, 124, 0.70),CfRule(110, 124, 0.65),
    CfRule(110, 125, 0.70),
    CfRule(126, 61, 0.75),
    CfRule(127, 51, 0.85),
    CfRule(128, 52, 0.80),
    CfRule(129, 61, 0.85),
    CfRule(132, 74, 0.70),
    CfRule(133, 60, 0.75),
    CfRule(134, 57, 0.70),CfRule(136, 57, 0.65),
    CfRule(137, 54, 0.90),
    CfRule(138, 62, 0.85),CfRule(139, 62, 0.70),
    CfRule(140, 54, 0.80),CfRule(141, 54, 0.85),
    CfRule(142, 58, 0.90),CfRule(143, 58, 0.85),
    CfRule(146, 74, 0.75),
    CfRule(147, 94, 0.80),
    CfRule(148, 59, 0.85),
    CfRule(149, 60, 0.80),
    CfRule(151, 75, 0.90),CfRule(152, 75, 0.75),CfRule(153, 75, 0.80),
    CfRule(154, 77, 0.85),CfRule(155, 77, 0.80),
    CfRule(156, 69, 0.75),
    CfRule(157, 77, 0.90),
    CfRule(158, 71, 0.70),CfRule(159, 71, 0.75),CfRule(160, 71, 0.70),
    CfRule(164, 123, 0.70),
    CfRule(165, 118, 0.85),
    CfRule(166, 60, 0.80),
    CfRule(167, 67, 0.75),
    CfRule(168, 75, 0.70),
    CfRule(169, 60, 0.70),
    CfRule(171, 74, 0.75),CfRule(172, 74, 0.80),CfRule(173, 74, 0.85),
    CfRule(174, 74, 0.70),CfRule(176, 74, 0.75),CfRule(177, 74, 0.65),
    CfRule(178, 121, 0.80),
    CfRule(179, 74, 0.75),
    CfRule(180, 75, 0.80),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // ENGINE — CF Combination & Diagnosis
  // ═══════════════════════════════════════════════════════════════════════════

  /// Core CF sequential combination:
  ///   cfCombined = cfA + cfB * (1 - cfA)
  static double _combineCf(double cfA, double cfB) =>
      cfA + cfB * (1.0 - cfA);

  /// Run the CF diagnosis.
  ///
  /// [categoryId] — 1 = Handphone, 2 = Laptop
  /// [selectedSymptomIds] — list of chosen symptom IDs from the user
  /// [minCfPercentage] — filter out results below this threshold (default 0)
  /// [maxResults] — number of top results to return (default 5)
  static List<CfResult> diagnose({
    required int categoryId,
    required List<int> selectedSymptomIds,
    double minCfPercentage = 0,
    int maxResults = 5,
  }) {
    if (selectedSymptomIds.isEmpty) return [];

    // Index rules by damageId for efficient lookup
    final Map<int, List<double>> damageValues = {};

    for (final rule in rules) {
      if (selectedSymptomIds.contains(rule.symptomId)) {
        damageValues.putIfAbsent(rule.damageId, () => []).add(rule.cfValue);
      }
    }

    if (damageValues.isEmpty) return [];

    final List<CfResult> results = [];

    for (final entry in damageValues.entries) {
      final damage = getDamageById(entry.key);
      if (damage == null || damage.categoryId != categoryId) continue;

      final cfList = entry.value;
      // Sequentially combine all CF values
      double combined = cfList[0];
      for (int i = 1; i < cfList.length; i++) {
        combined = _combineCf(combined, cfList[i]);
      }

      final pct = combined * 100.0;
      if (pct >= minCfPercentage) {
        results.add(CfResult(
          damage: damage,
          cfValues: cfList,
          cfCombined: combined,
          cfPercentage: double.parse(pct.toStringAsFixed(2)),
        ));
      }
    }

    // Sort descending by CF percentage
    results.sort((a, b) => b.cfCombined.compareTo(a.cfCombined));
    return results.take(maxResults).toList();
  }

  /// Convenience: returns the top diagnosis name and CF% string.
  /// Returns null if no results.
  static Map<String, dynamic>? topResult(List<CfResult> results) {
    if (results.isEmpty) return null;
    final top = results.first;
    return {
      'damage_name': top.damage.name,
      'cf_percentage': top.cfPercentage,
      'solution': top.damage.solution,
      'estimated_cost': top.damage.estimatedCost,
      'estimated_time': top.damage.estimatedTime,
    };
  }

  /// Format CF result as the booking issue_description string (matches PHP format).
  static String formatDiagnosisDescription(CfResult result) =>
      'Diagnosa Otomatis (CF: ${result.cfPercentage.toStringAsFixed(0)}%):\n\n'
      'Kerusakan: ${result.damage.name}\n'
      'Deskripsi: ${result.damage.description ?? "-"}\n\n'
      'Solusi yang Direkomendasikan:\n${result.damage.solution ?? "-"}';
}
