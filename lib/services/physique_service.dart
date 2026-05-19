import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/physique_analysis_model.dart';

/// Thrown when the image fails client-side or GPT-4o validation.
class PhysiqueValidationException implements Exception {
  final String title;
  final String message;
  final String? code;
  PhysiqueValidationException(this.title, this.message, {this.code});
  @override
  String toString() => message;
}

class PhysiqueService {
  final _client = Supabase.instance.client;

  // ── Load last completed result (for cache display on page open) ───────────

  Future<PhysiqueAnalysis?> getLastCompletedAnalysis() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final response = await _client
          .from('physique_analyses')
          .select('result_json, status')
          .eq('user_id', user.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null || response['result_json'] == null) return null;
      return PhysiqueAnalysis.fromJson(
          Map<String, dynamic>.from(response['result_json'] as Map));
    } catch (e) {
      debugPrint('[PhysiqueService] getLastCompletedAnalysis error: $e');
      return null;
    }
  }

  // ── Load yearly usage count ───────────────────────────────────────────────

  Future<int> getYearlyUsage(String feature, int year) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return 0;
      final response = await _client
          .from('ai_feature_usage')
          .select('usage_count')
          .eq('user_id', user.id)
          .eq('feature', feature)
          .eq('year', year)
          .maybeSingle();
      if (response == null || response['usage_count'] == null) return 0;
      return response['usage_count'] as int;
    } catch (e) {
      debugPrint('[PhysiqueService] getYearlyUsage error: $e');
      return 0;
    }
  }

  // ── Full pipeline ─────────────────────────────────────────────────────────

  Future<PhysiqueAnalysis> analyzePhysique(
    Uint8List rawImageBytes, {
    void Function(String)? onStatus,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // 1. Client-side validation (fast, no network)
    onStatus?.call('Validating photo...');
    await _validateClientSide(rawImageBytes);

    // 2. Compress + convert to valid PNG bytes
    onStatus?.call('Preparing image...');
    final compressedBytes = await _compressImage(rawImageBytes);

    // 3. Hash check — skip GPT-4o if same image was already analyzed
    final imageHash = _sha256(compressedBytes);
    final hashCached = await _checkHashCache(imageHash, user.id);
    if (hashCached != null) {
      debugPrint('[PhysiqueService] Hash cache hit');
      return hashCached;
    }

    // 4. Upload to Supabase Storage
    onStatus?.call('Uploading image...');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '${user.id}/$timestamp.jpg';
    try {
      await _client.storage
          .from('physique-uploads')
          .uploadBinary(storagePath, compressedBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));
    } catch (e) {
      debugPrint('[PhysiqueService] Storage upload non-fatal: $e');
    }

    // 5. Insert pending DB row (with image hash for future cache)
    final insertRow = await _client
        .from('physique_analyses')
        .insert({
          'user_id': user.id,
          'status': 'processing',
          'image_hash': imageHash,
        })
        .select('id')
        .single();
    final analysisId = insertRow['id'].toString();

    // 6. Base64 encode
    final imageBase64 = base64Encode(compressedBytes);

    // 7. Call Edge Function with retry
    onStatus?.call('Analyzing physique with AI...');
    FunctionResponse? response;
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        response = await _client.functions
            .invoke(
              'analyze-physique',
              body: {'analysisId': analysisId, 'imageBase64': imageBase64},
            )
            .timeout(const Duration(seconds: 90));
        break;
      } catch (e) {
        debugPrint('[PhysiqueService] Attempt $attempt failed: $e');
        if (attempt == 2) {
          await _client.from('physique_analyses').update({
            'status': 'failed',
            'error_message': 'timeout',
          }).eq('id', analysisId);
          throw Exception('Analysis timed out. Please try again.');
        }
        await Future.delayed(const Duration(seconds: 4));
      }
    }

    final data = response!.data as Map<String, dynamic>?;

    // 8. Handle GPT-4o photo rejection (returned at status 200 with success:false)
    if (data?['success'] == false) {
      throw PhysiqueValidationException(
        'Photo not clear enough',
        data?['message'] as String? ??
            'Please upload a clear front-facing full-body photo with good lighting.',
        code: data?['error_code'] as String?,
      );
    }

    // 9. Handle edge function errors
    if (response.status != 200) {
      final errorCode = data?['error_code'] as String?;
      if (errorCode == 'limit_reached') {
        throw PhysiqueValidationException(
          'Limit Reached',
          data?['message'] as String? ??
              'You’ve reached your  limit for Rate My Physique AI. Please try again .',
          code: errorCode,
        );
      }
      if (errorCode == 'invalid_physique_photo') {
        throw PhysiqueValidationException(
          'Photo not suitable',
          data?['message'] as String? ??
              'Please upload a clear front-facing full-body photo.',
          code: errorCode,
        );
      }
      final errorMsg = data?['error'] ?? 'Analysis failed (${response.status})';
      throw Exception(errorMsg);
    }

    final resultMap = data?['result'];
    if (resultMap == null) throw Exception('No result returned. Please try again.');

    return PhysiqueAnalysis.fromJson(
        Map<String, dynamic>.from(resultMap as Map));
  }

  // ── Client-side image validation ──────────────────────────────────────────

  Future<void> _validateClientSide(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw PhysiqueValidationException('Empty file', 'The selected file appears to be empty.');
    }

    // Max 8MB
    if (bytes.length > 8 * 1024 * 1024) {
      final mb = (bytes.length / 1024 / 1024).toStringAsFixed(1);
      throw PhysiqueValidationException(
          'File too large', 'Please choose a photo under 8MB (yours is ${mb}MB).');
    }

    // Format check via magic bytes
    if (!_isValidFormat(bytes)) {
      throw PhysiqueValidationException(
          'Unsupported format', 'Please upload a JPG, PNG, or WebP photo.');
    }

    // Too small to be a real photo
    if (bytes.length < 8192) {
      throw PhysiqueValidationException(
          'Photo not clear enough',
          'Please upload a clear full-body photo with good lighting.');
    }

    // Brightness heuristic on a sample of bytes
    // We sample every 8th byte from the first 20KB to get a rough average
    final sampleEnd = math.min(bytes.length, 20480);
    int sum = 0;
    int count = 0;
    for (int i = 0; i < sampleEnd; i += 8) {
      sum += bytes[i];
      count++;
    }
    if (count > 0) {
      final avg = sum ~/ count;
      if (avg < 8) {
        throw PhysiqueValidationException(
            'Photo too dark',
            'Your photo appears too dark. Please use better lighting and try again.');
      }
      if (avg > 247) {
        throw PhysiqueValidationException(
            'Photo too bright',
            'Your photo appears overexposed. Please try again with even lighting.');
      }
    }
  }

  bool _isValidFormat(Uint8List b) {
    if (b.length < 4) return false;
    // JPEG: FF D8 FF
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true;
    // WebP: RIFF....WEBP
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return true;
    return false;
  }

  // ── Image compression ─────────────────────────────────────────────────────
  // Returns valid PNG bytes (OpenAI Vision accepts PNG). Resizes to max 768px
  // on the longest dimension while preserving aspect ratio.

  Future<Uint8List> _compressImage(Uint8List bytes,
      {int maxDimension = 768}) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);

      final srcW = descriptor.width;
      final srcH = descriptor.height;

      // Calculate target preserving aspect ratio
      final maxSide = math.max(srcW, srcH);
      int targetW = srcW;
      int targetH = srcH;
      if (maxSide > maxDimension) {
        final scale = maxDimension / maxSide;
        targetW = (srcW * scale).round();
        targetH = (srcH * scale).round();
      }

      // Decode at target size
      final codec = await descriptor.instantiateCodec(
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Encode to valid PNG bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return bytes;

      final result = byteData.buffer.asUint8List();
      debugPrint(
          '[PhysiqueService] Compressed ${bytes.length ~/ 1024}KB → ${result.length ~/ 1024}KB '
          '(${srcW}x$srcH → ${targetW}x$targetH)');
      return result;
    } catch (e) {
      debugPrint('[PhysiqueService] Compression error (using original): $e');
      return bytes;
    }
  }

  // ── Hashing ───────────────────────────────────────────────────────────────

  String _sha256(Uint8List bytes) => sha256.convert(bytes).toString();

  Future<PhysiqueAnalysis?> _checkHashCache(
      String imageHash, String userId) async {
    try {
      final row = await _client
          .from('physique_analyses')
          .select('result_json')
          .eq('user_id', userId)
          .eq('image_hash', imageHash)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null || row['result_json'] == null) return null;
      return PhysiqueAnalysis.fromJson(
          Map<String, dynamic>.from(row['result_json'] as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearHistory() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      await _client.from('physique_analyses').delete().eq('user_id', user.id);
    } catch (e) {
      debugPrint('[PhysiqueService] clearHistory error: $e');
    }
  }
}
