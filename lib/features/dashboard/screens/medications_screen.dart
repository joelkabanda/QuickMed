import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:quickmed/routes/app_routes.dart';
import 'package:quickmed/constants/app_colors.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:quickmed/features/dashboard/widgets/medication_schedule_card.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  late DatabaseService _dbService;
  late Future<List<Medication>> _medicationsFuture;

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _loadMedications();
  }

  void _loadMedications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _medicationsFuture = _dbService.getUserMedications(userId);
    } else {
      _medicationsFuture = Future.error('User not authenticated');
    }
  }

  Future<void> _deleteMedication(String medicationId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: const Text('Are you sure you want to delete this medication?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteMedication(userId, medicationId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medication deleted successfully')),
          );
          setState(() {
            _loadMedications();
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting medication: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportMedications(List<Medication> medications) async {
    try {
      if (medications.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No medications to export')),
        );
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final jsonData = jsonEncode(
        medications.map((med) => med.toMap()).toList(),
      );
      final jsonFile = File('${directory.path}/medications_$timestamp.json');
      await jsonFile.writeAsString(jsonData);

      final csvBuffer = StringBuffer();
      csvBuffer.writeln(
        'ID,Name,Type,Dosage,Frequency,Schedule Times,Purpose,Quantity,Pharmacy Address,Prescribed By,Start Date,End Date,Is Active',
      );

      for (final med in medications) {
        csvBuffer.writeln(
          '${med.id},'
          '${med.name},'
          '${med.type},'
          '${med.dosage},'
          '${med.frequency},'
          '"${med.scheduleTimes.join(';')}",'
          '${med.purpose ?? ''},'
          '${med.quantity ?? ''},'
          '${med.pharmacyAddress ?? ''},'
          '${med.prescribedBy ?? ''},'
          '${med.startDate.toIso8601String()},'
          '${med.endDate?.toIso8601String() ?? ''},'
          '${med.isActive}',
        );
      }

      final csvFile = File('${directory.path}/medications_$timestamp.csv');
      await csvFile.writeAsString(csvBuffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Medications exported successfully\n'
              'JSON: medications_$timestamp.json\n'
              'CSV: medications_$timestamp.csv',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting medications: $e')),
        );
      }
    }
  }

  Future<void> _updateMedicationSchedule(
    Medication medication,
    List<String> updatedTimes,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final updatedMedication = medication.copyWith(scheduleTimes: updatedTimes);
    await _dbService.saveMedication(userId, updatedMedication);
    if (mounted) {
      setState(_loadMedications);
    }
  }

  Future<void> _addScheduleTime(Medication medication) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;

    final timeString =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (medication.scheduleTimes.contains(timeString)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This time is already added.')),
      );
      return;
    }

    final updatedTimes = List<String>.from(medication.scheduleTimes)
      ..add(timeString)
      ..sort();

    await _updateMedicationSchedule(medication, updatedTimes);
  }

  Future<void> _removeScheduleTime(
    Medication medication,
    String time,
  ) async {
    final updatedTimes = List<String>.from(medication.scheduleTimes)
      ..remove(time);
    await _updateMedicationSchedule(medication, updatedTimes);
  }

  Widget _buildMedicationScheduleCard(Medication medication) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          medication.type,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.of(context)
                            .pushNamed(
                                AppRoutes.editMedication
                                    .replaceAll(':id', medication.id),
                                arguments: medication)
                            .then((_) {
                          setState(() {
                            _loadMedications();
                          });
                        });
                      } else if (value == 'delete') {
                        _deleteMedication(medication.id);
                      }
                    },
                    icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Edit Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Remove', style: TextStyle(color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoColumn(
                        'Dosage', medication.dosage, Icons.balance),
                  ),
                  Expanded(
                    child: _buildInfoColumn(
                        'Frequency', medication.frequency, Icons.repeat),
                  ),
                  if (medication.purpose != null)
                    Expanded(
                      child: _buildInfoColumn(
                          'Purpose', medication.purpose!, Icons.note),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: MedicationScheduleCard(
                frequency: medication.frequency,
                scheduleTimes: medication.scheduleTimes,
                dosage: medication.dosage,
                onRemoveTime: (time) => _removeScheduleTime(medication, time),
              ),
            ),
            if (medication.prescribedBy != null ||
                medication.pharmacyAddress != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (medication.prescribedBy != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildDetailRow('Prescribed by',
                            medication.prescribedBy!, Icons.person),
                      ),
                    if (medication.pharmacyAddress != null)
                      _buildDetailRow('Pharmacy', medication.pharmacyAddress!,
                          Icons.location_on),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildScheduleTimeline(List<String> times, String dosage) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(times.length, (index) {
          return Padding(
            padding: EdgeInsets.only(right: index == times.length - 1 ? 0 : 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.success, AppColors.success],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    times[index],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dosage,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Medication Schedule',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _medicationsFuture.then((meds) {
                  _exportMedications(meds);
                });
              }
            },
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Export Data'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Medication>>(
        future: _medicationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
                  ),
                  SizedBox(height: 16),
                  Text('Loading medications...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            final errorText = snapshot.error.toString();
            final denied = errorText.contains('permission-denied');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    denied ? Icons.lock_outline : Icons.error_outline,
                    size: 48,
                    color: denied
                        ? Colors.orange.withOpacity(0.8)
                        : Colors.red.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    denied
                        ? 'Firestore permission denied.'
                        : 'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: denied ? Colors.orange[900] : Colors.red),
                  ),
                  const SizedBox(height: 12),
                  if (denied)
                    const Text(
                      'Check your Firestore security rules and ensure the current user can read users/{userId}/medications.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  if (!denied) const SizedBox.shrink(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _loadMedications();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final medications = snapshot.data ?? [];

          if (medications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No medications yet',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Start by adding your first medication to your schedule.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamed(AppRoutes.addMedication)
                          .then((_) {
                        setState(() {
                          _loadMedications();
                        });
                      });
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Medication', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${medications.length} Active',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Medication${medications.length != 1 ? 's' : ''}',
                          style:
                              const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context)
                            .pushNamed(AppRoutes.addMedication)
                            .then((_) {
                          setState(() {
                            _loadMedications();
                          });
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 18),
                          SizedBox(width: 6),
                          Padding(
                            padding: EdgeInsets.only(bottom: 1), // Optical adjustment
                            child: Text(
                              'Add New',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ...medications.map((med) => _buildMedicationScheduleCard(med)),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
