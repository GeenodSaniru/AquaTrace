import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/firebase_service.dart';

class ProfilePhotoService {
  static const int maxPhotoBytes = 5 * 1024 * 1024;

  Future<String> upload({required String uid, required XFile image}) async {
    if (!FirebaseService.isRealFirebase) {
      throw StateError('Profile photo upload is unavailable in demo mode.');
    }

    final bytes = await image.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxPhotoBytes) {
      throw StateError('Choose an image smaller than 5 MB.');
    }

    final contentType = image.mimeType ?? 'image/jpeg';
    if (!contentType.startsWith('image/')) {
      throw StateError('Choose a valid image file.');
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
