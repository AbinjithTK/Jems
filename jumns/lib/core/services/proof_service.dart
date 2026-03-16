import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'api_client.dart';

/// Handles proof image capture and upload for task completion.
class ProofService {
  final ApiClient _api;
  final ImagePicker _picker = ImagePicker();

  ProofService(this._api);

  /// Pick an image from the gallery.
  Future<File?> pickFromGallery() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    return xFile != null ? File(xFile.path) : null;
  }

  /// Capture a photo from the camera.
  Future<File?> captureFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    return xFile != null ? File(xFile.path) : null;
  }

  /// Upload a proof image and return the URL.
  Future<String?> uploadProof(File file, {String taskId = ''}) async {
    try {
      final json = await _api.uploadFile(
        '/api/upload/proof',
        file: file,
        fields: {'task_id': taskId},
      );
      final data = json as Map<String, dynamic>;
      return data['url'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final proofServiceProvider = Provider<ProofService>((ref) {
  return ProofService(ref.watch(apiClientProvider));
});
