// lib/core/services/spkl_generator_service.dart

// SPKL GENERATOR SERVICE - BISA PREVIEW DI WEB & MOBILE

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SpklGeneratorService {
  static final SpklGeneratorService _instance = SpklGeneratorService._internal();

  factory SpklGeneratorService() => _instance;

  SpklGeneratorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache font
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  // Cache logo Pertamina
  static pw.MemoryImage? _pertaminaLogo;

  // =========================================================================
  // LOAD FONTS
  // =========================================================================

  Future<void> _loadFonts() async {
    if (_regularFont != null && _boldFont != null) return;

    try {
      final regularFontData = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/fonts/Inter-Bold.ttf');

      _regularFont = pw.Font.ttf(regularFontData);
      _boldFont = pw.Font.ttf(boldFontData);
      debugPrint('✅ Custom fonts loaded');
    } catch (e) {
      debugPrint('⚠️ Using default Helvetica font: $e');
      _regularFont = pw.Font.helvetica();
      _boldFont = pw.Font.helveticaBold();
    }
  }

  // =========================================================================
  // LOAD LOGO PERTAMINA
  // =========================================================================

  Future<void> _loadPertaminaLogo() async {
    if (_pertaminaLogo != null) return;

    try {
      final logoBytes = await rootBundle.load('assets/images/logo_pertamina.png');
      _pertaminaLogo = pw.MemoryImage(logoBytes.buffer.asUint8List());
      debugPrint('✅ Pertamina logo loaded');
    } catch (e) {
      debugPrint('⚠️ Failed to load Pertamina logo: $e');
    }
  }

  // =========================================================================
  // 🔥 EKSTRAK MITRA LIST - FLEKSIBEL DARI BERBAGAI SUMBER
  // =========================================================================

  /// Mengekstrak data mitra dari berbagai format field yang mungkin
  List<Map<String, dynamic>> _extractMitraList(Map<String, dynamic> data) {
    List<Map<String, dynamic>> mitraList = [];

    // 1️⃣ Cek dari mitra_list (FIELD BARU - prioritas utama)
    if (data['mitra_list'] is List && (data['mitra_list'] as List).isNotEmpty) {
      mitraList = (data['mitra_list'] as List)
          .where((m) => m is Map)
          .map((m) {
            final map = Map<String, dynamic>.from(m as Map);
            // Pastikan ada field yang dibutuhkan tabel
            if (!map.containsKey('nama_mitra') && map.containsKey('nama')) {
              map['nama_mitra'] = map['nama'];
            }
            if (!map.containsKey('fungsi_mitra') && map.containsKey('fungsi')) {
              map['fungsi_mitra'] = map['fungsi'];
            }
            return map;
          })
          .toList();
      debugPrint('✅ Mitra dari mitra_list: ${mitraList.length} orang');
    }

    // 2️⃣ Cek dari detail_mitra (field lama - backward compatible)
    if (mitraList.isEmpty && data['detail_mitra'] is List && (data['detail_mitra'] as List).isNotEmpty) {
      mitraList = (data['detail_mitra'] as List)
          .where((m) => m is Map)
          .map((m) {
            final map = Map<String, dynamic>.from(m as Map);
            // Normalisasi field name
            if (!map.containsKey('nama_mitra') && map.containsKey('nama')) {
              map['nama_mitra'] = map['nama'];
            }
            if (!map.containsKey('fungsi_mitra') && map.containsKey('fungsi')) {
              map['fungsi_mitra'] = map['fungsi'];
            }
            return map;
          })
          .toList();
      debugPrint('✅ Mitra dari detail_mitra: ${mitraList.length} orang');
    }

    // 3️⃣ Cek dari _mitra_list (dikirim dari widget ApprovalDetailBottomSheet)
    if (mitraList.isEmpty && data['_mitra_list'] is List && (data['_mitra_list'] as List).isNotEmpty) {
      mitraList = (data['_mitra_list'] as List)
          .where((m) => m is Map)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
      debugPrint('✅ Mitra dari _mitra_list: ${mitraList.length} orang');
    }

    // 4️⃣ Fallback ke single mitra (hanya jika benar-benar tidak ada data)
    if (mitraList.isEmpty && data['nama_mitra'] != null) {
      mitraList = [
        {
          'nama_mitra': data['nama_mitra']?.toString() ?? '-',
          'fungsi_mitra': data['fungsi_mitra']?.toString() ?? '-',
        }
      ];
      debugPrint('⚠️ Fallback ke single mitra: ${data['nama_mitra']}');
    }

    return mitraList;
  }

  // =========================================================================
  // 🔥 GENERATE SPKL DARI DATA LEMBUR MENTAH (UNTUK PREVIEW / AUTO-GENERATE)
  // =========================================================================

  /// Generate SPKL PDF dari data lembur mentah (data dari approval detail / history)
  /// Return file path untuk mobile, atau dummy path untuk web
  Future<String> generateSpklFromOvertimeData(Map<String, dynamic> data) async {
    try {
      final pdfBytes = await generateSpklPdfBytesFromOvertimeData(data);

      if (kIsWeb) {
        debugPrint('⚠️ Web preview mode - SPKL generated as bytes');
        return 'preview_spkl_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Mobile: save file
      final groupId = (data['group_id'] ?? data['id'] ?? 'UNKNOWN').toString();
      final shortId = groupId.length >= 8 ? groupId.substring(0, 8) : groupId;
      final nomorSpkl =
          'SPKL/${DateFormat('yyyyMMdd').format(DateTime.now())}/$shortId';
      final safeFileName = nomorSpkl
          .replaceAll('/', '_')
          .replaceAll('\\', '_')
          .replaceAll(':', '_');

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/SPKL_$safeFileName.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      debugPrint('✅ SPKL from overtime data saved to: $filePath');
      return filePath;
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating SPKL from overtime data: $e');
      debugPrint(stackTrace.toString());
      return '';
    }
  }

  /// Generate PDF bytes dari data lembur mentah (untuk preview)
  Future<Uint8List> generateSpklPdfBytesFromOvertimeData(
      Map<String, dynamic> data) async {
    await _loadFonts();
    await _loadPertaminaLogo();

    final pdf = pw.Document();
    final now = DateTime.now();

    // =========================================================================
    // EKSTRAK DATA MENTAH (FLEKSIBEL UNTUK BERBAGAI FORMAT FIELD)
    // =========================================================================

    // Nomor SPKL
    final nomorSpkl = data['spkl_nomor']?.toString() ??
        data['spkl_number']?.toString() ??
        'SPKL/${DateFormat('yyyyMMdd').format(now)}/${(data['group_id'] ?? 'UNKNOWN').toString().substring(0, 8)}';

    // Nama pengawas
    final pengawasNama = data['nama_pengawas']?.toString() ??
        data['nama_lengkap']?.toString() ??
        data['pengawas_nama_lengkap']?.toString() ??
        '-';

    // Fungsi pengawas
    final pengawasFungsi = data['pengawas_fungsi']?.toString() ?? '-';
    final fungsiLabel = _getFungsiLabel(pengawasFungsi);

    // Tanggal lembur
    DateTime tanggalLembur = now;
    if (data['tanggal'] is Timestamp) {
      tanggalLembur = (data['tanggal'] as Timestamp).toDate();
    } else if (data['tanggal'] is DateTime) {
      tanggalLembur = data['tanggal'] as DateTime;
    } else if (data['tanggal'] is String &&
        data['tanggal'].toString().isNotEmpty) {
      tanggalLembur = DateTime.tryParse(data['tanggal'].toString()) ?? now;
    }

    // Jika ada tanggal_mulai (multi-day), gunakan itu
    DateTime tanggalMulai = tanggalLembur;
    if (data['tanggal_mulai'] is Timestamp) {
      tanggalMulai = (data['tanggal_mulai'] as Timestamp).toDate();
    }

    // Jam
    final jamMulai = data['jam_mulai']?.toString() ?? '-';
    final jamSelesai = data['jam_selesai']?.toString() ?? '-';

    // Total jam
    final totalJam = (data['total_jam_desimal'] is num
        ? (data['total_jam_desimal'] as num).toDouble()
        : double.tryParse(data['total_jam_desimal']?.toString() ?? '0') ?? 0.0);

    // Jenis lembur
    final jenisLembur = data['jenis_lembur']?.toString() == 'hari_libur'
        ? 'Hari Libur'
        : 'Hari Kerja';

    // Alasan
    final alasan = data['alasan']?.toString() ?? '-';

    // Lokasi
    String lokasiStr = 'Kantor PGE';
    if (data['lokasi'] is Map) {
      final lokasi = data['lokasi'] as Map;
      lokasiStr = lokasi['alamat']?.toString() ?? 'Kantor PGE';
      final rt = lokasi['rt']?.toString() ?? '';
      final rw = lokasi['rw']?.toString() ?? '';
      if (rt.isNotEmpty) lokasiStr += ' RT $rt';
      if (rw.isNotEmpty) lokasiStr += ' RW $rw';
    }

    // Urgensi
    final urgensi = data['urgensi']?.toString()?.toUpperCase() ?? 'NORMAL';

    // Biaya
    double estimasiBiaya = 0.0;
    if (data['estimasi_biaya_total'] != null) {
      if (data['estimasi_biaya_total'] is double) {
        estimasiBiaya = data['estimasi_biaya_total'] as double;
      } else if (data['estimasi_biaya_total'] is int) {
        estimasiBiaya = (data['estimasi_biaya_total'] as int).toDouble();
      } else {
        estimasiBiaya =
            double.tryParse(data['estimasi_biaya_total'].toString()) ?? 0.0;
      }
    }

    // 🔥 GUNAKAN METHOD EKSTRAKSI MITRA YANG SUDAH DIPERBAIKI
    final mitraList = _extractMitraList(data);

    final totalMitra = mitraList.isNotEmpty
        ? mitraList.length
        : ((data['total_mitra'] ?? 1) as num).toInt();

    // Approver
    final approvedByName = data['approved_by_name']?.toString() ??
        data['approved_by']?.toString() ??
        '-';
    final approvedAt = data['approved_at'] is Timestamp
        ? (data['approved_at'] as Timestamp).toDate()
        : now;

    // Safe string untuk header
    final safeNomorSpkl =
        nomorSpkl.length > 30 ? '${nomorSpkl.substring(0, 30)}...' : nomorSpkl;

    // =========================================================================
    // PDF CONTENT
    // =========================================================================

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: _regularFont ?? pw.Font.helvetica(),
          bold: _boldFont ?? pw.Font.helveticaBold(),
        ),
        header: (context) => _buildHeader(safeNomorSpkl),
        footer: (context) => _buildFooter(),
        build: (context) => [
          // TITLE
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'SURAT PERINTAH KERJA LEMBUR',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '(SPKL)',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Nomor: $nomorSpkl',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // INFORMASI LEMBUR
          _buildPdfSection('I. INFORMASI LEMBUR', [
            _buildPdfRow('Tanggal',
                DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggalMulai)),
            _buildPdfRow('Waktu',
                '$jamMulai - $jamSelesai (${totalJam.toStringAsFixed(1)} jam)'),
            _buildPdfRow('Jenis', jenisLembur),
            _buildPdfRow('Lokasi', lokasiStr),
            _buildPdfRow('Urgensi', urgensi),
          ]),

          pw.SizedBox(height: 16),

          // PENGAWAS
          _buildPdfSection('II. DATA PENGAWAS', [
            _buildPdfRow('Nama', pengawasNama),
            _buildPdfRow('Fungsi', fungsiLabel),
          ]),

          pw.SizedBox(height: 16),

          // MITRA
          _buildPdfSection('III. DAFTAR MITRA ($totalMitra orang)', [
            if (mitraList.isEmpty)
              pw.Text('Tidak ada data mitra',
                  style: const pw.TextStyle(fontSize: 10))
            else
              _buildMitraTableRaw(mitraList),
          ]),

          pw.SizedBox(height: 16),

          // ALASAN
          _buildPdfSection('IV. ALASAN LEMBUR', [
            pw.Text(alasan, style: const pw.TextStyle(fontSize: 10)),
          ]),

          pw.SizedBox(height: 16),

          // BIAYA
          _buildPdfSection('V. ESTIMASI BIAYA', [
            _buildPdfRow('Total Biaya',
                'Rp ${NumberFormat('#,###', 'id_ID').format(estimasiBiaya)}'),
            _buildPdfRow('Jumlah Mitra', '$totalMitra orang'),
          ]),

          pw.SizedBox(height: 40),

          // 🔥 TANDA TANGAN - DIPERBAIKI
          _buildTandaTangan(
            pengawasNama: pengawasNama,
            fungsiLabel: fungsiLabel,
            approvedByName: approvedByName,
            tanggalLembur: tanggalMulai,
            approvedAt: approvedAt,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // GENERATE PDF BYTES (DIGUNAKAN UNTUK PREVIEW DARI DATA SPKL FIRESTORE)
  // =========================================================================

  Future<Uint8List> generatePdfBytes(Map<String, dynamic> spklData) async {
    await _loadFonts();
    await _loadPertaminaLogo();

    final pdf = pw.Document();

    // Safe data parsing
    final nomorSpkl =
        (spklData['nomor_spkl'] ?? 'SPKL/XXX/XXX').toString();
    final tanggal =
        (spklData['tanggal_lembur'] as Timestamp?)?.toDate() ?? DateTime.now();
    final pengawasNama =
        (spklData['pengawas_nama'] ?? spklData['nama_pengawas'] ?? '-')
            .toString();
    final pengawasFungsi =
        (spklData['pengawas_fungsi'] ?? '-').toString();
    final fungsiLabel = _getFungsiLabel(pengawasFungsi);
    final jamMulai = (spklData['jam_mulai'] ?? '-').toString();
    final jamSelesai = (spklData['jam_selesai'] ?? '-').toString();
    final totalJam =
        ((spklData['total_jam'] ?? spklData['total_jam_desimal'] ?? 0) as num)
            .toDouble();
    final jenisLembur = spklData['jenis_lembur'] == 'hari_libur'
        ? 'Hari Libur'
        : 'Hari Kerja';
    final alasan = (spklData['alasan'] ?? '-').toString();
    final lokasi =
        (spklData['lokasi'] as Map<String, dynamic>?) ?? {};
    final lokasiStr = (lokasi['alamat'] ?? 'Kantor PGE').toString();
    final estimasiBiaya =
        ((spklData['estimasi_biaya_total'] ?? 0) as num).toDouble();
    final totalMitra =
        ((spklData['total_mitra'] ?? 1) as num).toInt();
    final approvedByName =
        (spklData['approved_by_name'] ?? '-').toString();
    final approvedAt =
        (spklData['approved_at'] as Timestamp?)?.toDate() ?? DateTime.now();

    // 🔥 GUNAKAN METHOD EKSTRAKSI MITRA YANG SUDAH DIPERBAIKI
    final mitraList = _extractMitraList(spklData);

    // Jika masih kosong, coba dari mitra_list langsung (fallback)
    if (mitraList.isEmpty && spklData['mitra_list'] is List) {
      mitraList.addAll((spklData['mitra_list'] as List)
          .where((m) => m is Map)
          .map((m) => Map<String, dynamic>.from(m as Map)));
    }

    final safeNomorSpkl = nomorSpkl.length > 30
        ? '${nomorSpkl.substring(0, 30)}...'
        : nomorSpkl;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: _regularFont ?? pw.Font.helvetica(),
          bold: _boldFont ?? pw.Font.helveticaBold(),
        ),
        header: (context) => _buildHeader(safeNomorSpkl),
        footer: (context) => _buildFooter(),
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('SURAT PERINTAH KERJA LEMBUR',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('(SPKL)',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Text('Nomor: $nomorSpkl',
                    style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          _buildPdfSection('I. INFORMASI LEMBUR', [
            _buildPdfRow('Tanggal',
                DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggal)),
            _buildPdfRow('Waktu',
                '$jamMulai - $jamSelesai (${totalJam.toStringAsFixed(1)} jam)'),
            _buildPdfRow('Jenis', jenisLembur),
            _buildPdfRow('Lokasi', lokasiStr),
            _buildPdfRow('Urgensi',
                (spklData['urgensi'] ?? 'normal').toString().toUpperCase()),
          ]),
          pw.SizedBox(height: 16),
          _buildPdfSection('II. DATA PENGAWAS', [
            _buildPdfRow('Nama', pengawasNama),
            _buildPdfRow('Fungsi', fungsiLabel),
          ]),
          pw.SizedBox(height: 16),
          _buildPdfSection('III. DAFTAR MITRA ($totalMitra orang)', [
            if (mitraList.isEmpty)
              pw.Text('Tidak ada data mitra',
                  style: const pw.TextStyle(fontSize: 10))
            else
              _buildMitraTable(mitraList),
          ]),
          pw.SizedBox(height: 16),
          _buildPdfSection('IV. ALASAN LEMBUR', [
            pw.Text(alasan, style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.SizedBox(height: 16),
          _buildPdfSection('V. ESTIMASI BIAYA', [
            _buildPdfRow('Total Biaya',
                'Rp ${NumberFormat('#,###', 'id_ID').format(estimasiBiaya)}'),
            _buildPdfRow('Jumlah Mitra', '$totalMitra orang'),
          ]),
          pw.SizedBox(height: 40),

          // 🔥 TANDA TANGAN - DIPERBAIKI
          _buildTandaTangan(
            pengawasNama: pengawasNama,
            fungsiLabel: fungsiLabel,
            approvedByName: approvedByName,
            tanggalLembur: tanggal,
            approvedAt: approvedAt,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // GENERATE & SAVE PDF (MOBILE ONLY)
  // =========================================================================

  Future<String> generateSpklPdf(Map<String, dynamic> spklData) async {
    try {
      final pdfBytes = await generatePdfBytes(spklData);

      if (kIsWeb) {
        debugPrint('⚠️ Web preview mode - PDF generated as bytes');
        return 'preview_spkl_${DateTime.now().millisecondsSinceEpoch}';
      }

      final nomorSpkl = (spklData['nomor_spkl'] ?? 'SPKL').toString();
      final safeFileName = nomorSpkl
          .replaceAll('/', '_')
          .replaceAll('\\', '_')
          .replaceAll(':', '_');

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/SPKL_$safeFileName.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      debugPrint('✅ PDF saved to: $filePath');
      return filePath;
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving PDF: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  // =========================================================================
  // OPEN PDF
  // =========================================================================

  Future<void> openPdf(String path) async {
    try {
      if (kIsWeb) {
        debugPrint('⚠️ Open file not supported on web');
        return;
      }
      await OpenFilex.open(path);
    } catch (e) {
      debugPrint('❌ Open PDF error: $e');
    }
  }

  // =========================================================================
  // PRINT PDF
  // =========================================================================

  Future<void> printPdf(Map<String, dynamic> spklData) async {
    try {
      final pdfBytes = await generatePdfBytes(spklData);

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'SPKL_${spklData['nomor_spkl'] ?? 'document'}.pdf',
      );
    } catch (e) {
      debugPrint('❌ Print PDF error: $e');
    }
  }

  // =========================================================================
  // 🔥 TANDA TANGAN - DIPERBAIKI DENGAN LAYOUT LEBIH RAPIH
  // =========================================================================

  pw.Widget _buildTandaTangan({
    required String pengawasNama,
    required String fungsiLabel,
    required String approvedByName,
    required DateTime tanggalLembur,
    required DateTime approvedAt,
  }) {
    return pw.Column(
      children: [
        // Garis pembatas
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  height: 1,
                  color: PdfColors.grey400,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                child: pw.Text(
                  'TANDA TANGAN',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                    letterSpacing: 2,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Container(
                  height: 1,
                  color: PdfColors.grey400,
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 12),

        // Dua kolom tanda tangan
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // KIRI: PIHAK YANG MENYETUJUI
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    // Judul
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'MENYETUJUI,',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ),

                    pw.SizedBox(height: 50),

                    // Nama approver
                    pw.Container(
                      width: double.infinity,
                      child: pw.Column(
                        children: [
                          pw.Text(
                            approvedByName,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Manager',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    // Garis bawah
                    pw.Container(
                      width: 100,
                      height: 1,
                      color: PdfColors.grey400,
                    ),

                    pw.SizedBox(height: 6),

                    // Tanggal
                    pw.Text(
                      'Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(approvedAt)}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 20),

            // KANAN: PIHAK YANG MENGAJUKAN
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    // Judul
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'MENGETAHUI,',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                    ),

                    pw.SizedBox(height: 50),

                    // Nama pengawas
                    pw.Container(
                      width: double.infinity,
                      child: pw.Column(
                        children: [
                          pw.Text(
                            pengawasNama,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Pengawas $fungsiLabel',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    // Garis bawah
                    pw.Container(
                      width: 100,
                      height: 1,
                      color: PdfColors.grey400,
                    ),

                    pw.SizedBox(height: 6),

                    // Tanggal
                    pw.Text(
                      'Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(tanggalLembur)}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================

  pw.Widget _buildHeader(String nomorSpkl) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.blue, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Logo Pertamina + Nama Perusahaan
          pw.Row(
            children: [
              if (_pertaminaLogo != null)
                pw.Container(
                  width: 40,
                  height: 40,
                  margin: const pw.EdgeInsets.only(right: 8),
                  child: pw.Image(_pertaminaLogo!, fit: pw.BoxFit.contain),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'PT. PERTAMINA GEOTHERMAL ENERGY',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    'Area Kamojang',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.blue700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Text(
            'No: $nomorSpkl',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border:
            pw.Border(top: pw.BorderSide(color: PdfColors.grey, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Dicetak otomatis oleh sistem',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
          pw.Text(
              DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
              style:
                  const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900),
          ),
        ),
        pw.SizedBox(height: 8),
        ...children,
      ],
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  /// Mitra table untuk data SPKL Firestore
  pw.Widget _buildMitraTable(List mitraList) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _tableHeader('No'),
            _tableHeader('Nama'),
            _tableHeader('Fungsi'),
          ],
        ),
        ...mitraList.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final mitra = entry.value as Map<String, dynamic>;
          return pw.TableRow(
            children: [
              _tableCell(index.toString()),
              _tableCell(
                  (mitra['nama_mitra'] ?? mitra['nama'] ?? '-').toString()),
              _tableCell(
                  (mitra['fungsi_mitra'] ?? mitra['fungsi'] ?? '-').toString()),
            ],
          );
        }),
      ],
    );
  }

  /// Mitra table untuk data lembur mentah
  pw.Widget _buildMitraTableRaw(List<Map<String, dynamic>> mitraList) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _tableHeader('No'),
            _tableHeader('Nama'),
            _tableHeader('Fungsi'),
          ],
        ),
        ...mitraList.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final mitra = entry.value;
          return pw.TableRow(
            children: [
              _tableCell(index.toString()),
              _tableCell(
                  (mitra['nama_mitra'] ?? mitra['nama'] ?? '-').toString()),
              _tableCell(
                  (mitra['fungsi_mitra'] ?? mitra['fungsi'] ?? '-').toString()),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  // =========================================================================
  // HELPER: LABEL FUNGSI
  // =========================================================================

  String _getFungsiLabel(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation':
        return 'Operation';
      case 'maintenance':
        return 'Maintenance';
      case 'hsse':
        return 'HSSE';
      case 'gpr':
        return 'GPR';
      case 'bs':
        return 'Business Support';
      default:
        return fungsi.toUpperCase();
    }
  }
}