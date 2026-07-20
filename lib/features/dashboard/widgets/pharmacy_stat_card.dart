import 'package:flutter/material.dart';
import 'dart:async';
import 'package:quickmed/models/pharmacy_model.dart';
import 'package:quickmed/models/user_profile_model.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/routes/app_routes.dart';

class PharmacyStatCard extends StatefulWidget {
  final Pharmacy? pharmacy;
  final SavedPharmacyLocation? savedLocation;
  final Function(SavedPharmacyLocation)? onSaveLocation;
  final VoidCallback? onTap;

  const PharmacyStatCard({
    super.key,
    this.pharmacy,
    this.savedLocation,
    this.onSaveLocation,
    this.onTap,
  });

  @override
  State<PharmacyStatCard> createState() => _PharmacyStatCardState();
}

class _PharmacyStatCardState extends State<PharmacyStatCard> {
  bool _isLoading = false;
  String? _distanceText;
  String? _timeText;
  String? _errorMessage;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateArrivalTime();
    _startPeriodicUpdates();
  }

  @override
  void didUpdateWidget(PharmacyStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.savedLocation != widget.savedLocation ||
        oldWidget.pharmacy != widget.pharmacy) {
      _updateArrivalTime();
    }
  }

  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _updateArrivalTime();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateArrivalTime() async {
    final location = widget.savedLocation ?? widget.pharmacy;
    if (location == null) return;

    try {
      final position = await LocationService.getCurrentLocation();
      final result = LocationService.calculateDistanceAndTime(
        position.latitude,
        position.longitude,
        widget.savedLocation?.latitude ?? widget.pharmacy!.latitude,
        widget.savedLocation?.longitude ?? widget.pharmacy!.longitude,
      );

      if (mounted) {
        setState(() {
          _distanceText = result['distanceKm'];
          _timeText = result['timeText'];
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to calculate distance';
        });
      }
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.locationPicker,
      arguments: widget.savedLocation,
    );

    if (result is SavedPharmacyLocation) {
      widget.onSaveLocation?.call(result);
      _updateArrivalTime();
    }
  }

  Future<void> _savePharmacyLocation() async {
    if (widget.pharmacy == null) return;

    setState(() => _isLoading = true);

    try {
      final position = await LocationService.getCurrentLocation();
      
      final savedLocation = SavedPharmacyLocation(
        pharmacyId: widget.pharmacy!.id,
        pharmacyName: widget.pharmacy!.name,
        latitude: widget.pharmacy!.latitude,
        longitude: widget.pharmacy!.longitude,
        address: widget.pharmacy!.address,
        savedAt: DateTime.now(),
      );

      widget.onSaveLocation?.call(savedLocation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.pharmacy!.name} saved successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
        _updateArrivalTime();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayLocation = widget.savedLocation ?? widget.pharmacy;
    if (displayLocation == null) {
      return const SizedBox.shrink();
    }

    final isSaved = widget.savedLocation != null;
    final title = isSaved ? 'Saved Location' : 'Pharmacy nearby';
    final displayName = isSaved 
        ? widget.savedLocation!.pharmacyName 
        : (widget.pharmacy?.name ?? 'Unknown');

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE8F5E9),
                    child: Icon(
                      isSaved ? Icons.check_circle : Icons.local_pharmacy,
                      color: const Color(0xFF388E3C),
                      size: 20,
                    ),
                  ),
                  if (!_isLoading && isSaved)
                    Tooltip(
                      message: 'Remove saved location',
                      child: GestureDetector(
                        onTap: () => _showRemoveConfirmation(context),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  else if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.location_on_outlined,
                      label: _distanceText ?? _errorMessage ?? '--',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.schedule,
                      label: _timeText ?? '--',
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              if (!isSaved && widget.pharmacy != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _savePharmacyLocation,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bookmark_outline, size: 18),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          backgroundColor: const Color(0xFF388E3C),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _openLocationPicker,
                        icon: const Icon(Icons.edit_location, size: 18),
                        label: const Text('Custom'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isSaved) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _openLocationPicker,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.locationComparison,
                                  arguments: widget.savedLocation,
                                ),
                        icon: const Icon(Icons.navigation, size: 18),
                        label: const Text('Route'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Saved Location?'),
        content: Text(
          'Are you sure you want to remove ${widget.savedLocation?.pharmacyName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSaveLocation?.call(
                SavedPharmacyLocation(
                  pharmacyId: '',
                  pharmacyName: '',
                  latitude: 0,
                  longitude: 0,
                  address: '',
                  savedAt: DateTime.now(),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
