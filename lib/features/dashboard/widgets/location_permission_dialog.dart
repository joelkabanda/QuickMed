import 'package:flutter/material.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionDialog extends StatefulWidget {
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;

  const LocationPermissionDialog({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
  });

  @override
  State<LocationPermissionDialog> createState() =>
      _LocationPermissionDialogState();
}

class _LocationPermissionDialogState extends State<LocationPermissionDialog> {
  bool _isLoading = false;

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoading = true);

    try {
      final permission = await LocationService.requestLocationPermission();
      
      if (mounted) {
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          widget.onPermissionGranted?.call();
          Navigator.of(context).pop(true);
        } else if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            _showOpenSettingsDialog();
          }
        } else {
          widget.onPermissionDenied?.call();
          Navigator.of(context).pop(false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is permanently denied. Please enable it in app settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enable Location Services'),
      content: const Text(
        'We need your location to show nearby pharmacies and estimate arrival times. Your location will only be used for this purpose.',
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  widget.onPermissionDenied?.call();
                  Navigator.of(context).pop(false);
                },
          child: const Text('Not Now'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _requestLocationPermission,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.location_on),
          label: const Text('Enable Location'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
