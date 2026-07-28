import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quickmed/models/user_profile_model.dart';
import 'package:quickmed/services/location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.onLocationSelected,
  });

  final SavedPharmacyLocation? initialLocation;
  final VoidCallback? onLocationSelected;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  double _selectedLat = 0;
  double _selectedLon = 0;
  bool _isLoadingLocation = false;
  bool _isReverseGeocoding = false;
  String? _errorMessage;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
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
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    if (mounted) setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        if (widget.initialLocation == null) {
          _selectedLat = position.latitude;
          _selectedLon = position.longitude;
        }
      });
      await _moveCameraToSelection();
      if (widget.initialLocation == null) await _reverseGeocode();
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not get current location: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _moveCameraToSelection() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_selectedLat, _selectedLon),
        15,
      ),
    );
  }

  Future<void> _reverseGeocode() async {
    if (_isReverseGeocoding) return;
    setState(() => _isReverseGeocoding = true);
    try {
      final address = await LocationService.getAddressFromCoordinates(
        _selectedLat,
        _selectedLon,
      );
      if (!mounted) return;
      _addressController.text = address;
      setState(() => _errorMessage = null);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not get address: $error');
      }
    } finally {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  Future<void> _selectPoint(LatLng point) async {
    setState(() {
      _selectedLat = point.latitude;
      _selectedLon = point.longitude;
    });
    await _reverseGeocode();
  }

  void _saveLocation() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name')),
      );
      return;
    }

    final location = SavedPharmacyLocation(
      pharmacyId: widget.initialLocation?.pharmacyId ?? 'custom_location',
      pharmacyName: _nameController.text.trim(),
      latitude: _selectedLat,
      longitude: _selectedLon,
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : '$_selectedLat, $_selectedLon',
      savedAt: DateTime.now(),
    );

    widget.onLocationSelected?.call();
    Navigator.pop(context, location);
  }

  Future<void> _centerMapOnCurrentLocation() async {
    if (mounted) setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _selectedLat = position.latitude;
        _selectedLon = position.longitude;
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = 'My Current Location';
        }
      });
      await _moveCameraToSelection();
      await _reverseGeocode();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialLocation != null;
    final selectedPoint = LatLng(_selectedLat, _selectedLon);

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
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: selectedPoint,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _moveCameraToSelection();
                  },
                  onTap: _selectPoint,
                  mapType: MapType.normal,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  myLocationEnabled: _currentPosition != null,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected_destination'),
                      position: selectedPoint,
                      draggable: true,
                      onDragEnd: _selectPoint,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                      infoWindow: const InfoWindow(
                        title: 'Selected destination',
                      ),
                    ),
                  },
                ),
                if (_isLoadingLocation)
                  const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
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
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.12),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Text(
                      'Tap the Google Map or drag the marker to select a destination.',
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
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
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
                      suffixIcon: _nameController.text.trim().isNotEmpty
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
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
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(.3)),
                    ),
                    child: Text(
                      'Selected coordinates: '
                      '${_selectedLat.toStringAsFixed(5)}, '
                      '${_selectedLon.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveLocation,
                      icon: const Icon(Icons.check),
                      label: Text(
                        isEditing ? 'Update Location' : 'Save Location',
                      ),
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
