import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_exception.dart';

abstract interface class CitizenReportInputProvider {
  bool get locationPermissionPermanentlyDenied;

  Future<Position> getCurrentPosition();

  Future<XFile?> pickPhoto(ImageSource source);
}

class DeviceCitizenReportInputProvider implements CitizenReportInputProvider {
  DeviceCitizenReportInputProvider({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;
  bool _locationPermissionPermanentlyDenied = false;

  @override
  bool get locationPermissionPermanentlyDenied =>
      _locationPermissionPermanentlyDenied;

  @override
  Future<Position> getCurrentPosition() async {
    _locationPermissionPermanentlyDenied = false;
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _locationPermissionPermanentlyDenied = true;
      throw const PermissionException(
        'Location access is blocked. Enable it in your device settings to continue.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const PermissionException(
        'Location permission was denied. Allow location access to add GPS coordinates.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  @override
  Future<XFile?> pickPhoto(ImageSource source) {
    return _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
  }
}
