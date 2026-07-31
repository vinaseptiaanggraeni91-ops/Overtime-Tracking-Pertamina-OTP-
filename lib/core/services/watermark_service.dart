import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class WatermarkService {
  // Singleton
  static final WatermarkService _instance = WatermarkService._internal();
  factory WatermarkService() => _instance;
  WatermarkService._internal();

  // ===========================================================================
  // KONSTANTA
  // ===========================================================================
  static const int _maxAddressLength = 60;
  static const int _jpegQuality = 92;
  static const double _fontSizeRatio = 0.026;
  static const int _maxImageWidth = 1920;
  static const int _maxFileSize = 10 * 1024 * 1024; // 10MB

  // ===========================================================================
  // METODE UTAMA: Tambahkan watermark ke foto selfie
  // ===========================================================================

  /// Menambahkan watermark ke foto selfie menggunakan library image
  ///
  /// [imagePath] - Path file gambar original
  /// [latitude] - Latitude GPS saat absensi
  /// [longitude] - Longitude GPS saat absensi
  /// [address] - Alamat lengkap lokasi absensi
  /// [timestamp] - Waktu absensi
  /// [workerName] - Nama pekerja yang absen
  /// [customLabel] - Label custom untuk header (default: "ABSENSI LEMBUR PGE")
  ///
  /// Returns [Uint8List] berisi bytes gambar yang sudah di-watermark
  Future<Uint8List> addWatermark({
    required String imagePath,
    required double latitude,
    required double longitude,
    required String address,
    required DateTime timestamp,
    required String workerName,
    String? customLabel,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      debugPrint('🖼️ Watermark: Processing ${imagePath.split('/').last}');
      debugPrint('   Worker: $workerName');
      debugPrint('   Location: $latitude, $longitude');

      // =======================================================================
      // STEP 1: VALIDASI FILE
      // =======================================================================
      final File imageFile = File(imagePath);
      
      if (!await imageFile.exists()) {
        throw Exception('File gambar tidak ditemukan: $imagePath');
      }

      final fileSize = await imageFile.length();
      if (fileSize > _maxFileSize) {
        throw Exception(
          'Ukuran file terlalu besar: '
          '${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB '
          '(max ${_maxFileSize / 1024 / 1024}MB)',
        );
      }

      debugPrint('   Original size: ${(fileSize / 1024).toStringAsFixed(1)}KB');

      final Uint8List imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty) {
        throw Exception('File gambar kosong');
      }

      // =======================================================================
      // STEP 2: DECODE GAMBAR
      // =======================================================================
      final img.Image? originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        throw Exception(
          'Gagal decode gambar - format tidak didukung. '
          'Pastikan file adalah JPG, JPEG, atau PNG.',
        );
      }

      debugPrint(
        '   Original dimensions: ${originalImage.width}x${originalImage.height}px',
      );

      // =======================================================================
      // STEP 3: RESIZE JIKA TERLALU BESAR
      // =======================================================================
      img.Image processedImage = originalImage;
      
      if (originalImage.width > _maxImageWidth) {
        debugPrint(
          '   Resizing from ${originalImage.width}px to $_maxImageWidth px',
        );
        processedImage = img.copyResize(
          originalImage,
          width: _maxImageWidth,
          maintainAspect: true,
        );
      }

      // =======================================================================
      // STEP 4: SIAPKAN DATA WATERMARK
      // =======================================================================
      final String dateStr = DateFormat('dd MMM yyyy', 'id_ID').format(timestamp);
      final String timeStr = DateFormat('HH:mm:ss', 'id_ID').format(timestamp);
      final String coordStr = 
          '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
      final String formattedAddress = _formatAddress(address);
      final String headerLabel = customLabel ?? 'ABSENSI LEMBUR PGE';

      // =======================================================================
      // STEP 5: BUAT TEKS WATERMARK
      // =======================================================================
      final List<String> watermarkLines = [
        '┌─────────────────────────┐',
        '  $headerLabel',
        '  ─────────────────────',
        '  👤 $workerName',
        '  📅 $dateStr  ⏰ $timeStr',
        '  📍 $coordStr',
        '  🏢 $formattedAddress',
        '└─────────────────────────┘',
      ];

      // =======================================================================
      // STEP 6: HITUNG UKURAN FONT PROPORSIONAL
      // =======================================================================
      final int fontSize = (processedImage.width * _fontSizeRatio)
          .round()
          .clamp(12, 32);
      
      final int lineHeight = (fontSize * 1.5).round();
      final int padding = (fontSize * 0.8).round();

      // =======================================================================
      // STEP 7: HITUNG POSISI WATERMARK (BAWAH TENGAH)
      // =======================================================================
      final int totalHeight = (watermarkLines.length * lineHeight) + (padding * 2);
      final int watermarkY = processedImage.height - totalHeight - 30;

      debugPrint(
        '   Watermark area: ${processedImage.width}x$totalHeight px '
        'at y=$watermarkY',
      );

      // =======================================================================
      // STEP 8: GAMBAR BACKGROUND OVERLAY
      // =======================================================================
      _drawWatermarkBackground(
        processedImage,
        x: 0,
        y: watermarkY,
        width: processedImage.width,
        height: totalHeight,
      );

      // =======================================================================
      // STEP 9: GAMBAR TEKS WATERMARK
      // =======================================================================
      for (int i = 0; i < watermarkLines.length; i++) {
        final String line = watermarkLines[i];
        final int textX = padding;
        final int textY = watermarkY + padding + (i * lineHeight) + fontSize;

        // Warna berbeda untuk header (gold) dan detail (putih)
        final bool isHeader = i <= 2;
        final img.Color textColor = isHeader
            ? img.ColorRgba8(255, 215, 0, 255)   // Gold (#FFD700)
            : img.ColorRgba8(255, 255, 255, 240); // White semi-transparent

        img.drawString(
          processedImage,
          line,
          font: img.arial24,
          x: textX,
          y: textY,
          color: textColor,
        );
      }

      // =======================================================================
      // STEP 10: TAMBAHKAN TIMESTAMP DI POJOK KANAN ATAS
      // =======================================================================
      _drawCornerTimestamp(processedImage, timestamp, fontSize);

      // =======================================================================
      // STEP 11: TAMBAHKAN IDENTIFIER DI POJOK KIRI ATAS
      // =======================================================================
      _drawCornerIdentifier(processedImage, 'PGE', fontSize);

      // =======================================================================
      // STEP 12: ENCODE KE JPEG
      // =======================================================================
      final Uint8List result = Uint8List.fromList(
        img.encodeJpg(processedImage, quality: _jpegQuality),
      );

      stopwatch.stop();
      debugPrint(
        '   Final size: ${(result.length / 1024).toStringAsFixed(1)}KB '
        '(${(result.length / fileSize * 100).toStringAsFixed(0)}% of original)',
      );
      debugPrint('   Processing time: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('✅ Watermark: Complete!');

      return result;

    } catch (e, stackTrace) {
      stopwatch.stop();
      debugPrint('❌ Watermark: Failed after ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stackTrace');
      throw Exception('Gagal menambahkan watermark: ${e.toString()}');
    }
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  /// Format alamat dengan pemotongan yang lebih baik
  String _formatAddress(String address) {
    if (address.isEmpty) return 'Alamat tidak tersedia';

    // Hapus karakter berlebih
    String cleaned = address
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s,.-]'), '')
        .trim();

    if (cleaned.length > _maxAddressLength) {
      // Potong di spasi terdekat agar tidak memotong kata
      int cutIndex = _maxAddressLength;
      while (cutIndex > 0 && cleaned[cutIndex] != ' ') {
        cutIndex--;
      }
      if (cutIndex == 0) cutIndex = _maxAddressLength;
      cleaned = '${cleaned.substring(0, cutIndex)}...';
    }

    return cleaned;
  }

  /// Gambar background overlay untuk area watermark
  void _drawWatermarkBackground(
    img.Image image, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    // Background solid hitam semi-transparan
    img.fillRect(
      image,
      x1: x,
      y1: y,
      x2: x + width,
      y2: y + height,
      color: img.ColorRgba8(0, 0, 0, 180),
    );

    // Border atas (garis tipis putih)
    img.drawLine(
      image,
      x1: x + 20,
      y1: y,
      x2: x + width - 20,
      y2: y,
      color: img.ColorRgba8(255, 255, 255, 100),
      thickness: 1,
    );

    // Border bawah (garis tipis putih)
    img.drawLine(
      image,
      x1: x + 20,
      y1: y + height - 1,
      x2: x + width - 20,
      y2: y + height - 1,
      color: img.ColorRgba8(255, 255, 255, 100),
      thickness: 1,
    );
  }

  /// Tambahkan timestamp di pojok kanan atas
  void _drawCornerTimestamp(
    img.Image image,
    DateTime timestamp,
    int baseFontSize,
  ) {
    try {
      final String cornerText = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
      final int cornerFontSize = (baseFontSize * 0.55).round().clamp(8, 14);

      // Ukuran teks
      final int textWidth = (cornerText.length * cornerFontSize * 0.55).round();
      final int textHeight = cornerFontSize + 8;

      final int cornerX = image.width - textWidth - 15;
      final int cornerY = 15;

      // Background semi-transparan
      img.fillRect(
        image,
        x1: cornerX - 8,
        y1: cornerY - 8,
        x2: image.width - 8,
        y2: cornerY + textHeight,
        color: img.ColorRgba8(0, 0, 0, 140),
      );

      // Border
      img.drawRect(
        image,
        x1: cornerX - 8,
        y1: cornerY - 8,
        x2: image.width - 8,
        y2: cornerY + textHeight,
        color: img.ColorRgba8(255, 255, 255, 80),
        thickness: 1,
      );

      // Teks
      img.drawString(
        image,
        cornerText,
        font: img.arial14,
        x: cornerX,
        y: cornerY + cornerFontSize - 2,
        color: img.ColorRgba8(255, 255, 255, 200),
      );
    } catch (e) {
      // Silent fail - timestamp tidak kritikal
      debugPrint('⚠️ Watermark: Corner timestamp failed: $e');
    }
  }

  /// Tambahkan identifier "PGE" di pojok kiri atas
  void _drawCornerIdentifier(
    img.Image image,
    String text,
    int baseFontSize,
  ) {
    try {
      final int idFontSize = (baseFontSize * 0.5).round().clamp(8, 12);
      final int cornerX = 15;
      final int cornerY = 15;

      final int boxWidth = (text.length * idFontSize * 0.6).round() + 10;
      final int boxHeight = idFontSize + 8;

      // Background kecil
      img.fillRect(
        image,
        x1: cornerX - 5,
        y1: cornerY - 5,
        x2: cornerX + boxWidth,
        y2: cornerY + boxHeight,
        color: img.ColorRgba8(0, 0, 0, 120),
      );

      // Teks
      img.drawString(
        image,
        text,
        font: img.arial14,
        x: cornerX + 5,
        y: cornerY + idFontSize,
        color: img.ColorRgba8(255, 255, 255, 180),
      );
    } catch (e) {
      // Silent fail - identifier tidak kritikal
      debugPrint('⚠️ Watermark: Corner identifier failed: $e');
    }
  }

  Future<Uint8List> addWatermarkWithFlutter({
    required String imagePath,
    required double latitude,
    required double longitude,
    required String address,
    required DateTime timestamp,
    required String workerName,
    String? customLabel,
  }) async {
    // Fallback ke metode image library untuk saat ini
    return addWatermark(
      imagePath: imagePath,
      latitude: latitude,
      longitude: longitude,
      address: address,
      timestamp: timestamp,
      workerName: workerName,
      customLabel: customLabel,
    );
  }

  /// Batch watermark untuk multiple images sekaligus
  Future<List<Uint8List>> addWatermarkBatch({
    required List<String> imagePaths,
    required double latitude,
    required double longitude,
    required String address,
    required DateTime timestamp,
    required List<String> workerNames,
  }) async {
    debugPrint('🖼️ Watermark: Batch processing ${imagePaths.length} images');

    final List<Uint8List> results = [];

    for (int i = 0; i < imagePaths.length; i++) {
      debugPrint('   Processing ${i + 1}/${imagePaths.length}...');
      final result = await addWatermark(
        imagePath: imagePaths[i],
        latitude: latitude,
        longitude: longitude,
        address: address,
        timestamp: timestamp,
        workerName: workerNames[i],
      );
      results.add(result);
    }

    debugPrint('✅ Watermark: Batch complete!');
    return results;
  }

  /// Validasi apakah file bisa diproses
  static Future<bool> canProcess(String imagePath) async {
    try {
      final file = File(imagePath);
      
      if (!await file.exists()) {
        debugPrint('Watermark: File not found: $imagePath');
        return false;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('Watermark: File is empty');
        return false;
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        debugPrint('Watermark: Cannot decode image');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Watermark: Validation error: $e');
      return false;
    }
  }
}