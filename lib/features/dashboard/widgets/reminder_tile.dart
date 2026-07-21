import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';


class ReminderTile extends StatelessWidget {

  final String medicineName;
  final String dosage;
  final String time;
  final String status;


  const ReminderTile({

    super.key,

    required this.medicineName,

    required this.dosage,

    required this.time,

    required this.status,

  });



  @override
  Widget build(BuildContext context) {


    final bool completed = status == "Completed";


    return Container(

      padding: const EdgeInsets.all(16),


      decoration: BoxDecoration(

        color: AppColors.surface,

        borderRadius: BorderRadius.circular(18),


        border: Border.all(

          color: AppColors.border,

        ),

      ),


      child: Row(

        children: [


          Container(

            height: 48,

            width: 48,


            decoration: BoxDecoration(

              color: completed

                  ? AppColors.success.withOpacity(0.12)

                  : AppColors.warning.withOpacity(0.12),


              borderRadius: BorderRadius.circular(14),

            ),


            child: Icon(

              completed

                  ? Icons.check_circle_outline

                  : Icons.access_time_rounded,


              color: completed

                  ? AppColors.success

                  : AppColors.warning,


              size: 26,

            ),

          ),



          const SizedBox(width: 14),



          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,


              children: [


                Text(

                  medicineName,

                  style: TextStyle(

                    fontSize: 16,

                    fontWeight: FontWeight.w600,

                    color: AppColors.textPrimary,

                  ),

                ),



                const SizedBox(height: 5),



                Text(

                  "$dosage • $time",

                  style: TextStyle(

                    fontSize: 13,

                    color: AppColors.textSecondary,

                  ),

                ),


              ],

            ),

          ),




          Container(

            padding: const EdgeInsets.symmetric(

              horizontal: 10,

              vertical: 6,

            ),


            decoration: BoxDecoration(

              color: completed

                  ? AppColors.success.withOpacity(0.12)

                  : AppColors.warning.withOpacity(0.12),


              borderRadius: BorderRadius.circular(20),

            ),


            child: Text(

              status,

              style: TextStyle(

                fontSize: 12,

                fontWeight: FontWeight.w600,

                color: completed

                    ? AppColors.success

                    : AppColors.warning,

              ),

            ),

          ),


        ],

      ),

    );

  }

}