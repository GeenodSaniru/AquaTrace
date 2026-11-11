import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/firebase_service.dart';

class ProfilePhotoService {
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  static const supportedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
  };

  static bool supportsContentType(String contentType) =>
      supportedContentTypes.contains(contentType.toLowerCase());

  Future<String> upload({required String uid, required XFile image}) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxPhotoBytes) {
      throw StateError('Choose an image smaller than 5 MB.');
    }

    final contentType = (image.mimeType ?? 'image/jpeg').toLowerCase();
    if (!supportsContentType(contentType)) {
      throw StateError('Choose a JPEG, PNG, WebP, or HEIC image.');
    }

    if (!FirebaseService.isRealFirebase) {
      throw StateError('Profile photo upload is unavailable in demo mode.');
    }

    final reference = FirebaseStorage.instance.ref().child(
      'users/$uid/profile/avatar',
    );
    final snapshot = await reference.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return snapshot.ref.getDownloadURL();
  }
}
