import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/citizen_report_input_provider.dart';

class CitizenReportFormScreen extends StatefulWidget {
  final CitizenReportInputProvider? inputProvider;

  const CitizenReportFormScreen({super.key, this.inputProvider});

  @override
  State<CitizenReportFormScreen> createState() =>
      _CitizenReportFormScreenState();
}

class _CitizenReportFormScreenState extends State<CitizenReportFormScreen> {
  static const int _maxPhotoBytes = 10 * 1024 * 1024;

  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _reportId = 'AT-${DateTime.now().year}-${const Uuid().v4()}';
  final _createdAt = DateTime.now().toUtc();
  late final CitizenReportInputProvider _inputProvider;

  FaultType? _faultType;
  FaultSeverity? _severity;
  XFile? _evidencePhoto;
  Uint8List? _evidenceBytes;
  String? _contentType;
  Position? _position;
  bool _locationConfirmed = false;
  bool _isLocating = false;
  bool _isPickingPhoto = false;
  bool _isSubmitting = false;
  bool _showValidation = false;
  bool _permissionPermanentlyDenied = false;
  String? _locationError;
  String? _photoError;
  String? _submissionError;
  String? _descriptionError;
  String? _addressError;

  @override
  void initState() {
    super.initState();
    _inputProvider = widget.inputProvider ?? DeviceCitizenReportInputProvider();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Water Fault')),
      body: PopScope(
        canPop: !_isSubmitting,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Help us find and fix the issue',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add the fault details, a photo, and its confirmed GPS location.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                _sectionLabel(context, 'Fault type'),
                const SizedBox(height: 8),
                DropdownButtonFormField<FaultType>(
                  initialValue: _faultType,
                  decoration: InputDecoration(
                    labelText: 'Select fault type',
                    prefixIcon: Icon(Icons.water_drop_outlined),
                  ),
                  items: FaultType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (type) => setState(() => _faultType = type),
                ),
                if (_showValidation && _faultType == null)
                  _fieldError(context, 'Choose a fault type.'),
                const SizedBox(height: 20),
                _sectionLabel(context, 'Description'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  enabled: !_isSubmitting,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Describe what you noticed and nearby landmarks',
                    alignLabelWithHint: true,
                    errorText: _descriptionError,
                  ),
                  onChanged: (value) {
                    if (_showValidation) {
                      setState(() {
                        _descriptionError = value.trim().length < 10
                            ? 'Enter at least 10 characters.'
                            : null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _sectionLabel(context, 'Severity'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: FaultSeverity.values.map((severity) {
                    final selected = _severity == severity;
                    return ChoiceChip(
                      label: Text(severity.displayName),
                      selected: selected,
                      avatar: Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: severity.color,
                      ),
                      selectedColor: severity.color.withValues(alpha: 0.16),
                      onSelected: _isSubmitting
                          ? null
                          : (value) => setState(
                              () => _severity = value ? severity : null,
                            ),
                    );
                  }).toList(),
                ),
                if (_showValidation && _severity == null)
                  _fieldError(context, 'Choose a severity.'),
                const SizedBox(height: 20),
                _sectionLabel(context, 'Location'),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  enabled: !_isSubmitting,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Street or nearby landmark',
                    hintText: 'e.g. Galle Road, Colombo 03',
                    prefixIcon: Icon(Icons.place_outlined),
                    errorText: _addressError,
                  ),
                  onChanged: (value) {
                    if (_showValidation) {
                      setState(() {
                        _addressError = value.trim().length < 3
                            ? 'Enter a nearby street or landmark.'
                            : null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isLocating || _isSubmitting
                      ? null
                      : _getCurrentLocation,
                  icon: _isLocating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_outlined),
                  label: Text(
                    _isLocating
                        ? 'Getting GPS location...'
                        : 'Get current location',
                  ),
                ),
                if (_permissionPermanentlyDenied) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: Geolocator.openAppSettings,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Open location settings'),
                    ),
                  ),
                ],
                if (_locationError != null)
                  _fieldError(context, _locationError!),
                if (_position case final position?) ...[
                  const SizedBox(height: 10),
                  _locationReview(context, position),
                ],
                const SizedBox(height: 20),
                _sectionLabel(context, 'Repair evidence'),
                const SizedBox(height: 6),
                Text(
                  'Add a clear photo of the fault. Maximum size: 10 MB.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isPickingPhoto || _isSubmitting
                            ? null
                            : () => _pickEvidence(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Take photo'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isPickingPhoto || _isSubmitting
                            ? null
                            : () => _pickEvidence(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose photo'),
                      ),
                    ),
                  ],
                ),
                if (_evidencePhoto != null) ...[
                  const SizedBox(height: 12),
                  _photoReview(context),
                ],
                if (_photoError != null) _fieldError(context, _photoError!),
                if (_submissionError != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: _fieldError(context, _submissionError!),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: 'Submit Report',
                  icon: Icons.send_outlined,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submitReport,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _fieldError(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _locationReview(BuildContext context, Position position) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gps_fixed, color: AppColors.primaryCyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review your GPS location',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'Accuracy about ${position.accuracy.round()} m',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isSubmitting
                ? null
                : () => setState(() => _locationConfirmed = true),
            icon: Icon(
              _locationConfirmed
                  ? Icons.check_circle
                  : Icons.location_on_outlined,
            ),
            label: Text(
              _locationConfirmed
                  ? 'Location confirmed'
                  : 'Confirm this location',
            ),
          ),
          if (_showValidation && !_locationConfirmed)
            _fieldError(context, 'Review and confirm this GPS location.'),
        ],
      ),
    );
  }

  Widget _photoReview(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 76,
              height: 68,
              child: _evidenceBytes == null
                  ? const Icon(Icons.image_outlined)
                  : Image.memory(
                      _evidenceBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_not_supported_outlined),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _evidencePhoto!.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Remove evidence photo',
            onPressed: _isSubmitting
                ? null
                : () => setState(() {
                    _evidencePhoto = null;
                    _evidenceBytes = null;
                    _contentType = null;
                    _photoError = null;
                  }),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
      _locationConfirmed = false;
      _position = null;
    });

    try {
      final position = await _inputProvider.getCurrentPosition();
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude < -90 ||
          position.latitude > 90 ||
          position.longitude < -180 ||
          position.longitude > 180) {
        throw const DatabaseException(
          'The device returned invalid GPS coordinates. Please try again.',
        );
      }
      if (!mounted) return;
      setState(() => _position = position);
    } on TimeoutException {
      _setLocationError(
        'GPS did not respond. Move to an open area and try again.',
      );
    } on LocationServiceDisabledException {
      _setLocationError(
        'Location services are turned off. Enable GPS and try again.',
      );
    } on PermissionException catch (error) {
      if (mounted) {
        setState(() {
          _locationError = error.message;
          _permissionPermanentlyDenied =
              _inputProvider.locationPermissionPermanentlyDenied;
        });
      }
    } on PermissionDeniedException {
      _setLocationError(
        'Location permission was denied. Allow location access to continue.',
      );
    } catch (error) {
      _setLocationError(
        'Could not get GPS coordinates. Check your signal and try again.',
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _setLocationError(String message) {
    if (!mounted) return;
    setState(() => _locationError = message);
  }

  Future<void> _pickEvidence(ImageSource source) async {
    setState(() {
      _isPickingPhoto = true;
      _photoError = null;
    });
    try {
      final photo = await _inputProvider.pickPhoto(source);
      if (photo == null) {
        if (mounted) {
          setState(
            () => _photoError = 'No photo selected. Add a photo to continue.',
          );
        }
        return;
      }

      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty || bytes.length > _maxPhotoBytes) {
        if (mounted) {
          setState(() {
            _photoError = bytes.isEmpty
                ? 'The selected photo could not be read. Choose another photo.'
                : 'The selected photo is larger than 10 MB. Choose a smaller photo.';
            _evidencePhoto = null;
            _evidenceBytes = null;
            _contentType = null;
          });
        }
        return;
      }

      final contentType = _contentTypeFor(photo.name);
      if (contentType == null) {
        if (mounted) {
          setState(() {
            _photoError = 'Choose a JPEG, PNG, WebP, or HEIC image.';
            _evidencePhoto = null;
            _evidenceBytes = null;
            _contentType = null;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _evidencePhoto = photo;
          _evidenceBytes = bytes;
          _contentType = contentType;
        });
      }
    } on PlatformException {
      if (mounted) {
        setState(() {
          _photoError = source == ImageSource.camera
              ? 'Camera access failed. Check camera permission or choose a photo from your library.'
              : 'Photo library access failed. Check photo permission and try again.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _photoError = 'Could not read that photo. Choose another one.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  String? _contentTypeFor(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => null,
    };
  }

  Future<void> _submitReport() async {
    final description = _descriptionController.text.trim();
    final address = _addressController.text.trim();
    setState(() {
      _showValidation = true;
      _submissionError = null;
      _descriptionError = description.length < 10
          ? 'Enter at least 10 characters.'
          : null;
      _addressError = address.length < 3
          ? 'Enter a nearby street or landmark.'
          : null;
      if (_position == null) {
        _locationError = 'Get your current GPS location to continue.';
      } else if (!_locationConfirmed) {
        _locationError = 'Review and confirm this GPS location.';
      }
      if (_evidenceBytes == null) {
        _photoError = 'Add a photo of the fault to continue.';
      }
    });
    if (_descriptionError != null ||
        _addressError != null ||
        _faultType == null ||
        _severity == null ||
        _position == null ||
        !_locationConfirmed ||
        _evidenceBytes == null ||
        _contentType == null) {
      return;
    }

    final user = context.read<AuthProvider>().currentUser;
    if (user == null || user.uid.trim().isEmpty) {
      setState(() {
        _submissionError = 'Sign in with a citizen account before submitting.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    final position = _position!;
    final report = ReportModel(
      reportId: _reportId,
      reporterUid: user.uid,
      reporterName: user.displayName,
      faultType: _faultType!,
      description: description,
      severity: _severity!,
      status: FaultStatus.pending,
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
      assignedArea: user.assignedArea,
      isEmergency: _severity == FaultSeverity.critical,
      createdAt: _createdAt,
    );

    try {
      await context.read<DataRepository>().addReport(
        report,
        evidenceBytes: _evidenceBytes!,
        contentType: _contentType!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() => _submissionError = _firebaseErrorMessage(error));
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _submissionError = error.message);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submissionError =
              'Report could not be saved. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => 'Firebase denied the upload or report save. Check account access and Firebase rules.',
      'unauthenticated' =>
        'Your sign-in has expired. Sign in again before submitting.',
      'unavailable' || 'deadline-exceeded' || 'network-request-failed' => 'Connection interrupted. Your report was not confirmed as saved; check your connection and retry.',
      'object-not-found' => 'The evidence photo could not be confirmed in storage. Select it again and retry.',
      _ => 'Could not upload the photo or save the report. Please retry.',
    };
  }
}
