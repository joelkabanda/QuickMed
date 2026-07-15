import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/services/database_service.dart';

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
    _nameController = TextEditingController(text: widget.medication?.name ?? '');
    _dosageController = TextEditingController(text: widget.medication?.dosage ?? '');
    _descriptionController = TextEditingController(text: widget.medication?.description ?? '');
    _prescribedByController = TextEditingController(text: widget.medication?.prescribedBy ?? '');
    _sideEffectsController = TextEditingController(text: widget.medication?.sideEffects ?? '');
    _quantityController = TextEditingController(text: widget.medication?.quantity?.toString() ?? '');
    _purposeController = TextEditingController(text: widget.medication?.purpose ?? '');
    _pharmacyAddressController = TextEditingController(text: widget.medication?.pharmacyAddress ?? '');

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
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, {required bool isEndDate}) async {
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

  Future<void> _selectTime(BuildContext context, {required bool isReminder}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final timeString = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
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

  Future<void> _saveMedication() async {
    if (_nameController.text.isEmpty || _dosageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in medication name and dosage')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final medication = Medication(
        id: widget.medication?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        name: _nameController.text,
        type: _selectedType,
        dosage: _dosageController.text,
        frequency: _selectedFrequency,
        scheduleTimes: _scheduleTimes,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        prescribedBy: _prescribedByController.text.isEmpty ? null : _prescribedByController.text,
        pharmacyPharmacyId: null,
        pharmacyAddress: _pharmacyAddressController.text.isEmpty ? null : _pharmacyAddressController.text,
        sideEffects: _sideEffectsController.text.isEmpty ? null : _sideEffectsController.text,
        quantity: _quantityController.text.isEmpty ? null : int.tryParse(_quantityController.text),
        purpose: _purposeController.text.isEmpty ? null : _purposeController.text,
        startDate: _startDate,
        endDate: _endDate,
        reminderTimes: _reminderTimes,
        isActive: true,
        createdAt: widget.medication?.createdAt ?? DateTime.now(),
      );

      await DatabaseService().saveMedication(userId, medication);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.medication == null ? 'Medication added' : 'Medication updated'} successfully')),
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.medication == null ? 'Add Medication' : 'Edit Medication',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medication Name
              _buildTextField(
                label: 'Medication Name',
                controller: _nameController,
                hint: 'e.g., Aspirin, Amoxicillin',
                icon: Icons.medication,
                required: true,
              ),
              const SizedBox(height: 16),

              // Medication Type
              _buildDropdown(
                label: 'Type of Medication',
                value: _selectedType,
                items: _medicationTypes,
                onChanged: (value) {
                  setState(() => _selectedType = value);
                },
              ),
              const SizedBox(height: 16),

              // Dosage Card
              _buildDosageCard(),
              const SizedBox(height: 16),

              // Frequency
              _buildDropdown(
                label: 'Frequency',
                value: _selectedFrequency,
                items: _frequencies,
                onChanged: (value) {
                  setState(() => _selectedFrequency = value);
                },
              ),
              const SizedBox(height: 16),

              // Clear Schedule Section
              _buildSchedulingCard(),
              const SizedBox(height: 16),

              // Purpose/Reason
              _buildTextField(
                label: 'Purpose (Why taking this medication)',
                controller: _purposeController,
                hint: 'e.g., Pain relief, Hypertension treatment',
                icon: Icons.note,
              ),
              const SizedBox(height: 16),

              // Quantity
              _buildTextField(
                label: 'Quantity Available',
                controller: _quantityController,
                hint: 'Number of tablets/units',
                icon: Icons.inventory_2,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Pharmacy Address (Where to get the medication)
              _buildTextField(
                label: 'Where to Get Medication',
                controller: _pharmacyAddressController,
                hint: 'Pharmacy name or address',
                icon: Icons.location_on,
              ),
              const SizedBox(height: 16),

              // Prescribed By
              _buildTextField(
                label: 'Prescribed By (Doctor/Pharmacist)',
                controller: _prescribedByController,
                hint: 'Name of prescribing doctor',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),

              // Side Effects
              _buildTextField(
                label: 'Known Side Effects',
                controller: _sideEffectsController,
                hint: 'e.g., Dizziness, Nausea (comma-separated)',
                icon: Icons.warning,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Description
              _buildTextField(
                label: 'Additional Notes',
                controller: _descriptionController,
                hint: 'Any other important information',
                icon: Icons.description,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Start Date
              _buildDateSelector(
                label: 'Start Date',
                date: _startDate,
                onTap: () => _selectDate(context, isEndDate: false),
              ),
              const SizedBox(height: 16),

              // End Date
              _buildDateSelector(
                label: 'End Date (Optional)',
                date: _endDate,
                onTap: () => _selectDate(context, isEndDate: true),
              ),
              const SizedBox(height: 16),

              // Reminder Times
              _buildTimeSelector(
                label: 'Reminder Times',
                times: _reminderTimes,
                onAddTime: () => _selectTime(context, isReminder: true),
                onRemoveTime: (time) => _removeTime(time, isReminder: true),
                icon: Icons.notifications_active,
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveMedication,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(widget.medication == null ? 'Add Medication' : 'Update Medication'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: const Color(0xFF388E3C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _buildTimeSelector({
    required String label,
    required List<String> times,
    required VoidCallback onAddTime,
    required Function(String) onRemoveTime,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (times.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: const Text(
              'No times added yet',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final time in times)
                Chip(
                  label: Text(time),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => onRemoveTime(time),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  labelStyle: const TextStyle(color: Colors.blue),
                ),
            ],
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onAddTime,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Time'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
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

  Widget _buildSchedulingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.green.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule, color: Colors.green, size: 24),
              SizedBox(width: 12),
              Text(
                'Medicine Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Frequency',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Text(
                  _selectedFrequency,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Medication Times',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  if (_scheduleTimes.isNotEmpty)
                    Text(
                      '${_scheduleTimes.length} time(s)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_scheduleTimes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'No times set. Click below to add medication times.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _scheduleTimes.length; i++) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _scheduleTimes[i],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      _dosageController.text.isEmpty
                                          ? 'No dosage'
                                          : _dosageController.text,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  _removeTime(_scheduleTimes[i], isReminder: false),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        if (i < _scheduleTimes.length - 1)
                          const Divider(height: 12, color: Colors.grey),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _selectTime(context, isReminder: false),
                  icon: const Icon(Icons.add_alarm, size: 18),
                  label: const Text('Add Medication Time'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
