import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '/core/services/network_service.dart'; // 🔥 NETWORK SERVICE

class CloudinaryStorageService {
  static final CloudinaryStorageService _instance =
      CloudinaryStorageService._internal();
  factory CloudinaryStorageService() => _instance;
  CloudinaryStorageService._internal();

  // 🔥 NETWORK SERVICE
  final NetworkService _networkService = NetworkService();

  // Konfigurasi Cloudinary
  static const String _cloudName = 'dqmfcji94';
  static const String _uploadPreset = 'absensi_preset'; // ← Upload preset (unsigned)
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1/$_cloudName';

  // ═══════════════════════════════════════════════════════════
  // 🔥 NETWORK CHECK HELPER
  // ═══════════════════════════════════════════════════════════

  bool _checkConnection(String operationName) {
    if (!_networkService.isOnline) {
      debugPrint('⚠️ [$operationName] Dibatalkan - Tidak ada koneksi internet');
      return false;
    }
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 UPLOAD FOTO (DENGAN RETRY)
  // ═══════════════════════════════════════════════════════════

  /// Upload foto absensi ke Cloudinary
  /// 
  /// [maxRetries] Jumlah maksimal retry jika gagal (default: 2)
  /// [retryDelay] Delay antar retry (default: 3 detik)
  Future<Map<String, dynamic>> uploadFoto({
    required File photoFile,
    required String fileName,
    required String lemburId,
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 3),
  }) async {
    // 🔥 CEK KONEKSI SEBELUM UPLOAD
    if (!_checkConnection('uploadFoto')) {
      return {
        'success': false,
        'message': 'Tidak ada koneksi internet. Periksa koneksi Anda dan coba lagi.',
        'error_type': 'no_connection',
      };
    }

    // 🔥 Cek file exists
    if (!await photoFile.exists()) {
      return {
        'success': false,
        'message': 'File foto tidak ditemukan. Silakan ambil foto ulang.',
        'error_type': 'file_not_found',
      };
    }

    // 🔥 Cek ukuran file (max 10MB)
    try {
      final fileSize = await photoFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        return {
          'success': false,
          'message': 'Ukuran foto terlalu besar (max 10MB). Silakan kompres foto.',
          'error_type': 'file_too_large',
        };
      }
      if (fileSize == 0) {
        return {
          'success': false,
          'message': 'File foto kosong. Silakan ambil foto ulang.',
          'error_type': 'empty_file',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Gagal cek ukuran file: $e');
    }

    // 🔥 Retry logic
    int attempt = 0;
    Exception? lastException;

    while (attempt <= maxRetries) {
      try {
        if (attempt > 0) {
          debugPrint('🔄 Retry upload foto (attempt ${attempt + 1}/$maxRetries)');
          // 🔥 Tunggu sebelum retry
          await Future.delayed(retryDelay * attempt);
          
          // 🔥 Cek ulang koneksi sebelum retry
          if (!await _networkService.checkConnection()) {
            debugPrint('⚠️ Masih offline, skip retry');
            continue;
          }
        }

        final uri = Uri.parse('$_baseUrl/image/upload');

        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = _uploadPreset
          ..fields['folder'] = 'absensi_lembur/$lemburId'
          ..fields['public_id'] = fileName
          ..files.add(
            await http.MultipartFile.fromPath('file', photoFile.path),
          );

        final response = await request.send().timeout(
          const Duration(seconds: 60),
        );

        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          final data = jsonDecode(responseBody);

          debugPrint('✅ Foto berhasil diupload: ${data['secure_url']}');

          return {
            'success': true,
            'url': data['secure_url'] ?? '',
            'publicId': data['public_id'] ?? '',
            'width': data['width'] ?? 0,
            'height': data['height'] ?? 0,
            'format': data['format'] ?? 'jpg',
            'size': data['bytes'] ?? 0,
            'attempt': attempt + 1,
          };
        }

        // 🔥 Handle specific HTTP errors
        if (response.statusCode == 401 || response.statusCode == 403) {
          return {
            'success': false,
            'message': 'Gagal upload: Autentikasi tidak valid (HTTP ${response.statusCode}). Hubungi admin.',
            'error_type': 'auth_error',
          };
        }

        if (response.statusCode == 413) {
          return {
            'success': false,
            'message': 'Ukuran foto terlalu besar untuk diupload. Silakan kompres foto.',
            'error_type': 'file_too_large',
          };
        }

        if (response.statusCode >= 500) {
          // 🔥 Server error → Retry
          debugPrint('⚠️ Server error (${response.statusCode}), akan retry...');
          attempt++;
          lastException = Exception('Server error: ${response.statusCode}');
          continue;
        }

        // 🔥 Other errors
        return {
          'success': false,
          'message': 'Upload gagal (HTTP ${response.statusCode}). Silakan coba lagi.',
          'error_type': 'http_error',
          'status_code': response.statusCode,
        };

      } on SocketException catch (e) {
        debugPrint('❌ SocketException: $e');
        lastException = e;
        
        if (attempt < maxRetries) {
          attempt++;
          debugPrint('🔄 Retry karena koneksi terputus...');
          continue;
        }
        
        return {
          'success': false,
          'message': 'Koneksi internet terputus saat upload. Periksa koneksi Anda.',
          'error_type': 'network_error',
        };
        
      } on TimeoutException catch (e) {
        debugPrint('❌ TimeoutException: $e');
        lastException = e;
        
        if (attempt < maxRetries) {
          attempt++;
          debugPrint('🔄 Retry karena timeout...');
          continue;
        }
        
        return {
          'success': false,
          'message': 'Upload timeout. Koneksi terlalu lambat. Coba lagi nanti.',
          'error_type': 'timeout',
        };
        
      } on http.ClientException catch (e) {
        debugPrint('❌ ClientException: $e');
        lastException = e;
        
        if (attempt < maxRetries) {
          attempt++;
          debugPrint('🔄 Retry karena client error...');
          continue;
        }
        
        return {
          'success': false,
          'message': 'Gagal terhubung ke server. Periksa koneksi internet Anda.',
          'error_type': 'client_error',
        };
        
      } catch (e) {
        debugPrint('❌ Error upload Cloudinary: $e');
        lastException = Exception(e.toString());
        
        if (attempt < maxRetries) {
          attempt++;
          continue;
        }
        
        return {
          'success': false,
          'message': 'Gagal upload: Terjadi kesalahan tidak terduga.',
          'error_type': 'unknown_error',
          'error_detail': e.toString(),
        };
      }
    }

    // 🔥 Semua retry gagal
    return {
      'success': false,
      'message': 'Gagal upload setelah ${maxRetries + 1} kali percobaan. '
          'Periksa koneksi internet Anda dan coba lagi.',
      'error_type': 'max_retries_exceeded',
      'attempts': maxRetries + 1,
      'last_error': lastException?.toString() ?? 'Unknown error',
    };
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 UPLOAD FOTO DENGAN RETRY (PAKAI NETWORK SERVICE)
  // ═══════════════════════════════════════════════════════════

  /// Upload foto dengan retry otomatis menggunakan NetworkService
  Future<Map<String, dynamic>> uploadFotoWithAutoRetry({
    required File photoFile,
    required String fileName,
    required String lemburId,
    int maxRetries = 3,
  }) async {
    final result = await _networkService.retryOnConnectionError<Map<String, dynamic>>(
      operation: () => uploadFoto(
        photoFile: photoFile,
        fileName: fileName,
        lemburId: lemburId,
        maxRetries: 0, // 🔥 Jangan double retry
      ),
      maxRetries: maxRetries,
      delay: const Duration(seconds: 3),
    );

    return result ?? {
      'success': false,
      'message': 'Gagal upload setelah $maxRetries kali percobaan otomatis.',
      'error_type': 'auto_retry_failed',
    };
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 DELETE FOTO (DENGAN RETRY)
  // ═══════════════════════════════════════════════════════════

  /// Hapus foto dari Cloudinary
  Future<bool> deleteFoto(String publicId, {int maxRetries = 1}) async {
    // 🔥 CEK KONEKSI
    if (!_checkConnection('deleteFoto')) return false;

    int attempt = 0;

    while (attempt <= maxRetries) {
      try {
        if (attempt > 0) {
          debugPrint('🔄 Retry hapus foto (attempt ${attempt + 1}/$maxRetries)');
          await Future.delayed(const Duration(seconds: 2));
          
          if (!await _networkService.checkConnection()) {
            continue;
          }
        }

        final uri = Uri.parse('$_baseUrl/image/destroy');

        final response = await http.post(
          uri,
          body: {
            'upload_preset': _uploadPreset,
            'public_id': publicId,
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          debugPrint('✅ Foto berhasil dihapus: $publicId');
          return true;
        }

        // 🔥 Server error → Retry
        if (response.statusCode >= 500) {
          attempt++;
          continue;
        }

        return false;

      } catch (e) {
        debugPrint('❌ Gagal hapus foto: $e');
        
        if (attempt < maxRetries) {
          attempt++;
          continue;
        }
        
        return false;
      }
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 BATCH UPLOAD (UPLOAD BANYAK FOTO SEKALIGUS)
  // ═══════════════════════════════════════════════════════════

  /// Upload banyak foto sekaligus
  Future<List<Map<String, dynamic>>> uploadMultipleFoto({
    required List<Map<String, dynamic>> fotoList,
    // fotoList format: [{file: File, fileName: String, lemburId: String}, ...]
    int maxRetries = 2,
  }) async {
    if (!_checkConnection('uploadMultipleFoto')) {
      return fotoList.map((_) => {
        'success': false,
        'message': 'Tidak ada koneksi internet',
        'error_type': 'no_connection',
      }).toList();
    }

    final results = <Map<String, dynamic>>[];

    for (final foto in fotoList) {
      final result = await uploadFoto(
        photoFile: foto['file'] as File,
        fileName: foto['fileName'] as String,
        lemburId: foto['lemburId'] as String,
        maxRetries: maxRetries,
      );
      results.add(result);
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 COMPRESS & UPLOAD (UNTUK FOTO BESAR)
  // ═══════════════════════════════════════════════════════════

  /// Upload dengan kompresi otomatis (quality: auto)
  Future<Map<String, dynamic>> uploadFotoCompressed({
    required File photoFile,
    required String fileName,
    required String lemburId,
    int quality = 80, // 🔥 Kualitas 1-100
    int maxRetries = 2,
  }) async {
    // 🔥 Bisa ditambah logic resize/compress sebelum upload
    // Untuk sekarang, Cloudinary handle kompresi via upload params

    final uri = Uri.parse('$_baseUrl/image/upload');

    try {
      if (!_checkConnection('uploadFotoCompressed')) {
        return {
          'success': false,
          'message': 'Tidak ada koneksi internet',
          'error_type': 'no_connection',
        };
      }

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = 'absensi_lembur/$lemburId'
        ..fields['public_id'] = fileName
        ..fields['quality'] = quality.toString() // 🔥 Set kualitas
        ..fields['quality_analysis'] = 'true'     // 🔥 Analisis kualitas
        ..files.add(
          await http.MultipartFile.fromPath('file', photoFile.path),
        );

      final response = await request.send().timeout(
        const Duration(seconds: 90), // 🔥 Lebih lama untuk upload besar
      );

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);

        return {
          'success': true,
          'url': data['secure_url'] ?? '',
          'publicId': data['public_id'] ?? '',
          'width': data['width'] ?? 0,
          'height': data['height'] ?? 0,
          'format': data['format'] ?? 'jpg',
          'size': data['bytes'] ?? 0,
          'original_size': data['original_bytes'] ?? 0,
          'compression_ratio': data['bytes'] != null && data['original_bytes'] != null
              ? '${((1 - (data['bytes'] / data['original_bytes'])) * 100).toStringAsFixed(1)}%'
              : 'N/A',
        };
      }

      return {
        'success': false,
        'message': 'Upload gagal (HTTP ${response.statusCode})',
      };
    } catch (e) {
      debugPrint('Error upload compressed: $e');
      
      // 🔥 Fallback ke upload biasa
      if (maxRetries > 0) {
        debugPrint('🔄 Fallback ke upload biasa...');
        return uploadFoto(
          photoFile: photoFile,
          fileName: fileName,
          lemburId: lemburId,
          maxRetries: maxRetries,
        );
      }
      
      return {
        'success': false,
        'message': 'Gagal upload: $e',
      };
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 URL GENERATORS
  // ═══════════════════════════════════════════════════════════

  /// Generate URL dengan transformasi (auto format + auto quality)
  String getOptimizedUrl(String publicId) {
    return 'https://res.cloudinary.com/$_cloudName/image/upload/'
        'f_auto,q_auto/$publicId';
    // f_auto = automatic format selection (WebP, AVIF, etc)
    // q_auto = automatic quality optimization
  }

  /// Generate thumbnail URL
  String getThumbnailUrl(String publicId, {int width = 200, int height = 200}) {
    return 'https://res.cloudinary.com/$_cloudName/image/upload/'
        'w_$width,h_$height,c_fill,f_auto,q_auto/$publicId';
  }

  /// Generate URL untuk preview (ukuran sedang)
  String getPreviewUrl(String publicId, {int width = 600}) {
    return 'https://res.cloudinary.com/$_cloudName/image/upload/'
        'w_$width,f_auto,q_auto:good/$publicId';
  }

  /// Generate URL full resolution (original)
  String getOriginalUrl(String publicId) {
    return 'https://res.cloudinary.com/$_cloudName/image/upload/$publicId';
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 CHECK CONNECTION STATUS
  // ═══════════════════════════════════════════════════════════

  /// Cek apakah bisa upload (koneksi tersedia)
  Future<bool> canUpload() async {
    return await _networkService.checkConnection();
  }

  /// Cek apakah online
  bool get isOnline => _networkService.isOnline;

  // ═══════════════════════════════════════════════════════════
  // 🔥 ERROR HELPER
  // ═══════════════════════════════════════════════════════════

  /// Cek apakah result sukses
  bool isSuccess(Map<String, dynamic> result) {
    return result['success'] == true;
  }

  /// Ambil error message dari result
  String getErrorMessage(Map<String, dynamic> result) {
    return result['message']?.toString() ?? 'Unknown error';
  }

  /// Ambil URL dari result
  String getUrl(Map<String, dynamic> result) {
    return result['url']?.toString() ?? '';
  }

  /// Ambil public ID dari result
  String getPublicId(Map<String, dynamic> result) {
    return result['publicId']?.toString() ?? '';
  }
}