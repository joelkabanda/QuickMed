import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/models/user_profile_model.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  final SavedPharmacyLocation? initialLocation;
  final VoidCallback? onLocationSelected;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.onLocationSelected,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late MapController _mapController;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  double _selectedLat = 0.0;
  double _selectedLon = 0.0;
  bool _isLoadingLocation = false;
  bool _isReverseGeocoding = false;
  String? _errorMessage;
  String? _addressLoadingMessage;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _nameController = TextEditingController(
      text: widget.initialLocation?.pharmacyName ?? '',
    );
    _addressController = TextEditingController(
      text: widget.initialLocation?.address ?? '',
    );
    _selectedLat = widget.initialLocation?.latitude ?? -1.2921;
    _selectedLon = widget.initialLocation?.longitude ?? 36.8219;
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (widget.initialLocation == null) {
        setState(() {
          _selectedLat = position.latitude;
          _selectedLon = position.longitude;
        });
      }
      _mapController.move(
        LatLng(_selectedLat, _selectedLon),
        15,
      );
      if (widget.initialLocation == null) {
        await _reverseGeocode();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not get current location: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _reverseGeocode() async {
    if (_isReverseGeocoding) return;
    
    setState(() => _isReverseGeocoding = true);
    try {
      final address = await LocationService.getAddressFromCoordinates(
        _selectedLat,
        _selectedLon,
      );
      if (mounted) {
        _addressController.text = address;
        setState(() => _addressLoadingMessage = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not get address: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isReverseGeocoding = false);
      }
    }
  }

  void _saveLocation() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name')),
      );
      return;
    }

    final location = SavedPharmacyLocation(
      pharmacyId: widget.initialLocation?.pharmacyId ?? 'custom_location',
      pharmacyName: _nameController.text,
      latitude: _selectedLat,
      longitude: _selectedLon,
      address: _addressController.text.isNotEmpty
          ? _addressController.text
          : '$_selectedLat, $_selectedLon',
      savedAt: DateTime.now(),
    );

    Navigator.pop(context, location);
  }

  void _centerMapOnCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      setState(() {
        _selectedLat = position.latitude;
        _selectedLon = position.longitude;
      });
      _mapController.move(
        LatLng(_selectedLat, _selectedLon),
        15,
      );
      await _reverseGeocode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialLocation != null;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Location' : 'Select Location',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          if (!_isLoadingLocation)
            IconButton(
              icon: const Icon(Icons.my_location, color: Colors.blue),
              onPressed: _centerMapOnCurrentLocation,
              tooltip: 'Use current location',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: LatLng(_selectedLat, _selectedLon),
                    zoom: 15,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLat = point.latitude;
                        _selectedLon = point.longitude;
                        _addressLoadingMessage = 'Getting address...';
                      });
                      _reverseGeocode();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.quickmed.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_selectedLat, _selectedLon),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isLoadingLocation)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      'Tap on map to select location',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Text(
                    'Location Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Location Name *',
                      hintText: 'e.g., Home Pharmacy, Work Location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      suffixIcon: _nameController.text.isNotEmpty
                          ? Icon(Icons.check, color: Colors.green)
                          : null,
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    readOnly: _isReverseGeocoding,
                    decoration: InputDecoration(
                      labelText: 'Address (Optional)',
                      hintText: 'Full address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.description_outlined),
                      suffixIcon: _isReverseGeocoding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coordinates:',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedLat.toStringAsFixed(4)}, ${_selectedLon.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.blue,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveLocation,
                      icon: const Icon(Icons.check),
                      label: Text(isEditing ? 'Update Location' : 'Save Location'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
