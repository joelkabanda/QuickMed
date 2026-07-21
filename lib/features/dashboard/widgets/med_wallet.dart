// lib/features/dashboard/widgets/med_wallet_card.dart

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

class MedWalletCard extends StatefulWidget {
  final String patientName;
  final String nextDoseTime;
  final String nextMedicationName;
  final int completedToday;
  final int totalToday;

  const MedWalletCard({
    super.key,
    required this.patientName,
    required this.nextDoseTime,
    required this.nextMedicationName,
    required this.completedToday,
    required this.totalToday,
  });

  @override
  State<MedWalletCard> createState() => _MedWalletCardState();
}

class _MedWalletCardState extends State<MedWalletCard> {
  bool _revealed = true;

  @override
  Widget build(BuildContext context) {
    final progress =
        widget.totalToday == 0 ? 0.0 : widget.completedToday / widget.totalToday;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row — patient identity, mirrors the phone number/name row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "My Care Plan",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.patientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Active",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // "Balance" row — now the next dose, with a reveal/hide toggle
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Next Dose",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _revealed
                          ? "${widget.nextMedicationName} · ${widget.nextDoseTime}"
                          : "•••• · ••:••",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _revealed = !_revealed),
                icon: Icon(
                  _revealed
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white70,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${widget.completedToday} of ${widget.totalToday} doses taken",
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
              ),
              Text(
                "${(progress * 100).round()}%",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}