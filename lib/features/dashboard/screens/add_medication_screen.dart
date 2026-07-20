import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:quickmed/services/reminder_service.dart';
class AddMedicationScreen extends StatefulWidget {
  final Medication? medication;

  const AddMedicationScreen({
    super.key,
    this.medication,
  });

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _descriptionController;
  late TextEditingController _prescribedByController;
  late TextEditingController _sideEffectsController;
  late TextEditingController _quantityController;
  late TextEditingController _purposeController;
  late TextEditingController _pharmacyAddressController;

  String _selectedType = 'Tablet';
  String _selectedFrequency = 'Once daily';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  List<String> _scheduleTimes = [];
  List<String> _reminderTimes = [];
  bool _isLoading = false;
  bool _isScanning = false;
  File? _capturedMedicationImage;
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  final List<String> _medicationTypes = [
    'Tablet',
    'Capsule',
    'Liquid',
    'Injection',
    'Inhaler',
    'Cream/Ointment',
    'Drops',
    'Patches',
  ];

  final List<String> _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Four times daily',
    'Every 4 hours',
    'Every 6 hours',
    'Every 8 hours',
    'Every 12 hours',
    'As needed',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController =
        TextEditingController(text: widget.medication?.name ?? '');
    _dosageController =
        TextEditingController(text: widget.medication?.dosage ?? '');
    _descriptionController =
        TextEditingController(text: widget.medication?.description ?? '');
    _prescribedByController =
        TextEditingController(text: widget.medication?.prescribedBy ?? '');
    _sideEffectsController =
        TextEditingController(text: widget.medication?.sideEffects ?? '');
    _quantityController = TextEditingController(
        text: widget.medication?.quantity?.toString() ?? '');
    _purposeController =
        TextEditingController(text: widget.medication?.purpose ?? '');
    _pharmacyAddressController =
        TextEditingController(text: widget.medication?.pharmacyAddress ?? '');

    _selectedType = widget.medication?.type ?? 'Tablet';
    _selectedFrequency = widget.medication?.frequency ?? 'Once daily';
    _startDate = widget.medication?.startDate ?? DateTime.now();
    _endDate = widget.medication?.endDate;
    _scheduleTimes = widget.medication?.scheduleTimes ?? [];
    _reminderTimes = widget.medication?.reminderTimes ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _descriptionController.dispose();
    _prescribedByController.dispose();
    _sideEffectsController.dispose();
    _quantityController.dispose();
    _purposeController.dispose();
    _pharmacyAddressController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isEndDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEndDate ? _endDate ?? DateTime.now() : _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isEndDate) {
          _endDate = picked;
        } else {
          _startDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context,
      {required bool isReminder}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final timeString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isReminder) {
          if (!_reminderTimes.contains(timeString)) {
            _reminderTimes.add(timeString);
            _reminderTimes.sort();
          }
        } else {
          if (!_scheduleTimes.contains(timeString)) {
            _scheduleTimes.add(timeString);
            _scheduleTimes.sort();
          }
        }
      });
    }
  }

  void _removeTime(String time, {required bool isReminder}) {
    setState(() {
      if (isReminder) {
        _reminderTimes.remove(time);
      } else {
        _scheduleTimes.remove(time);
      }
    });
  }

  Future<void> _captureMedicationImage() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to scan medication details.')),
        );
      }
      return;
    }

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (pickedFile == null) {
      return;
    }

    final imageFile = File(pickedFile.path);
    setState(() {
      _capturedMedicationImage = imageFile;
      _isScanning = true;
    });

    await _extractMedicationDetails(imageFile);
  }

  Future<void> _extractMedicationDetails(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final lines = recognizedText.text
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      String? detectedName;
      String? detectedDosage;

      for (final line in lines) {
        final lower = line.toLowerCase();
        if (detectedName == null &&
            lower.length > 3 &&
            !lower.contains('tablet') &&
            !lower.contains('capsule') &&
            !lower.contains('ml') &&
            !lower.contains('mg') &&
            !lower.contains('take') &&
            !lower.contains('prescription')) {
          detectedName = line;
        }

        if (detectedDosage == null) {
          final dosageMatch = RegExp(
            r'(\d+(\.\d+)?\s*(mg|ml|g|mcg|tablet|tablets|capsule|capsules))',
          ).firstMatch(line);
          if (dosageMatch != null) {
            detectedDosage = dosageMatch.group(0);
          }
        }
      }

      if (detectedName != null || detectedDosage != null) {
        setState(() {
          if (detectedName != null) {
            _nameController.text = detectedName!;
          }
          if (detectedDosage != null) {
            _dosageController.text = detectedDosage!;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medication details were pulled from the photo. Please review them before saving.'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The photo was captured, but the label details were not clear enough. You can enter them manually.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to read the medication label: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _saveMedication() async {
    if (_nameController.text.isEmpty || _dosageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in medication name and dosage')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final medication = Medication(
        id: widget.medication?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        name: _nameController.text,
        type: _selectedType,
        dosage: _dosageController.text,
        frequency: _selectedFrequency,
        scheduleTimes: _scheduleTimes,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        prescribedBy: _prescribedByController.text.isEmpty
            ? null
            : _prescribedByController.text,
        pharmacyPharmacyId: null,
        pharmacyAddress: _pharmacyAddressController.text.isEmpty
            ? null
            : _pharmacyAddressController.text,
        sideEffects: _sideEffectsController.text.isEmpty
            ? null
            : _sideEffectsController.text,
        quantity: _quantityController.text.isEmpty
            ? null
            : int.tryParse(_quantityController.text),
        purpose:
            _purposeController.text.isEmpty ? null : _purposeController.text,
        startDate: _startDate,
        endDate: _endDate,
        reminderTimes: _reminderTimes,
        isActive: true,
        createdAt: widget.medication?.createdAt ?? DateTime.now(),
      );

      final dbService = DatabaseService();
      await dbService.saveMedication(userId, medication);

      final leadTimeMinutes = await ReminderService.estimateLeadTimeMinutesForAddress(
        _pharmacyAddressController.text.isEmpty
            ? null
            : _pharmacyAddressController.text,
      );
      final generatedReminders = ReminderService.buildRemindersForMedication(
        userId: userId,
        medication: medication,
        leadTimeMinutes: leadTimeMinutes,
      );

      for (final reminder in generatedReminders) {
        await dbService.saveReminder(reminder);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${widget.medication == null ? 'Medication added' : 'Medication updated'} successfully')),
        );
        Navigator.pop(context, medication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      debugPrint('Error saving medication: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.medication == null ? 'Add Medication' : 'Edit Medication',
          style: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1565C0), const Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.medication,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.medication == null
                                ? 'New Medication'
                                : 'Edit Medication',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fill in the details below',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildCameraCaptureCard(),
              const SizedBox(height: 24),

              // Basic Information Section
              _buildSectionHeader('Basic Information', Icons.info_outline),
              const SizedBox(height: 12),
              // Medication Name
              _buildTextField(
                label: 'Medication Name',
                controller: _nameController,
                hint: 'e.g., Aspirin, Amoxicillin',
                icon: Icons.medication,
                required: true,
              ),
              const SizedBox(height: 14),

              // Medication Type
              _buildDropdown(
                label: 'Type of Medication',
                value: _selectedType,
                items: _medicationTypes,
                onChanged: (value) {
                  setState(() => _selectedType = value);
                },
              ),
              const SizedBox(height: 14),

              // Dosage Card
              _buildDosageCard(),
              const SizedBox(height: 24),

              const SizedBox(height: 24),

              // Medical Details Section
              _buildSectionHeader('Medical Details', Icons.local_hospital),
              const SizedBox(height: 12),

              // Purpose/Reason
              _buildTextField(
                label: 'Purpose (Why taking this medication)',
                controller: _purposeController,
                hint: 'e.g., Pain relief, Hypertension treatment',
                icon: Icons.note,
              ),
              const SizedBox(height: 14),

              // Prescribed By
              _buildTextField(
                label: 'Prescribed By (Doctor/Pharmacist)',
                controller: _prescribedByController,
                hint: 'Name of prescribing doctor',
                icon: Icons.person,
              ),
              const SizedBox(height: 14),

              // Side Effects
              _buildTextField(
                label: 'Known Side Effects',
                controller: _sideEffectsController,
                hint: 'e.g., Dizziness, Nausea (comma-separated)',
                icon: Icons.warning,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Dosage & Quantity Section
              _buildSectionHeader('Dosage & Supply', Icons.inventory_2),
              const SizedBox(height: 12),

              // Quantity
              _buildTextField(
                label: 'Quantity Available',
                controller: _quantityController,
                hint: 'Number of tablets/units',
                icon: Icons.inventory_2,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),

              // Pharmacy & Notes Section
              _buildSectionHeader('Pharmacy & Notes', Icons.location_on),
              const SizedBox(height: 12),

              // Pharmacy Address (Where to get the medication)
              _buildTextField(
                label: 'Where to Get Medication',
                controller: _pharmacyAddressController,
                hint: 'Pharmacy name or address',
                icon: Icons.location_on,
              ),
              const SizedBox(height: 14),

              // Description
              _buildTextField(
                label: 'Additional Notes',
                controller: _descriptionController,
                hint: 'Any other important information',
                icon: Icons.description,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Duration Section
              _buildSectionHeader('Duration', Icons.calendar_today),
              const SizedBox(height: 12),

              // Start Date
              _buildDateSelector(
                label: 'Start Date',
                date: _startDate,
                onTap: () => _selectDate(context, isEndDate: false),
              ),
              const SizedBox(height: 14),

              // End Date
              _buildDateSelector(
                label: 'End Date (Optional)',
                date: _endDate,
                onTap: () => _selectDate(context, isEndDate: true),
              ),
              const SizedBox(height: 24),

              // Save Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF388E3C), const Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF388E3C).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _saveMedication,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          else
                            const Icon(Icons.check_circle,
                                color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            widget.medication == null
                                ? 'Add Medication'
                                : 'Update Medication',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraCaptureCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Capture medication details with your camera',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Take a photo of the medication label to auto-fill the medication name and dosage. The app will also use your pickup location to set a smarter reminder lead time.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isScanning ? null : _captureMedicationImage,
              icon: _isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt),
              label: Text(_isScanning ? 'Scanning label…' : 'Scan medication label'),
            ),
          ),
          if (_capturedMedicationImage != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                _capturedMedicationImage!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    ))
                .toList(),
            onChanged: (newValue) {
              if (newValue != null) onChanged(newValue);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Text(
                  date != null
                      ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: date != null ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDosageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_pharmacy, color: Colors.blue, size: 24),
              SizedBox(width: 12),
              Text(
                'Dosage Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Dosage Amount',
            controller: _dosageController,
            hint: 'e.g., 500mg, 2 tablets, 10ml',
            icon: Icons.balance,
            required: true,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dosage Summary',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _dosageController.text.isEmpty
                      ? 'Enter dosage to see summary'
                      : '${_dosageController.text} - $_selectedFrequency',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF1565C0), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Container(
          height: 3,
          width: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1565C0), const Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
