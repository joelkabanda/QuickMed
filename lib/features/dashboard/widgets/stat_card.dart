import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';


class StatCard extends StatelessWidget {

  final String title;
  final String value;
  final IconData icon;
  final Color color;


  const StatCard({

    super.key,

    required this.title,

    required this.value,

    required this.icon,

    required this.color,

  });


  @override
  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(16),


      decoration: BoxDecoration(

        color: AppColors.surface,

        borderRadius: BorderRadius.circular(20),


        border: Border.all(

          color: AppColors.border,

        ),


      ),


      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,


        children: [


          Container(

            height: 42,

            width: 42,


            decoration: BoxDecoration(

              color: color.withOpacity(0.12),

              borderRadius: BorderRadius.circular(14),

            ),


            child: Icon(

              icon,

              color: color,

              size: 23,

            ),

          ),



          const SizedBox(height: 16),



          Text(

            value,

            style: TextStyle(

              fontSize: 26,

              fontWeight: FontWeight.bold,

              color: AppColors.textPrimary,

            ),

          ),



          const SizedBox(height: 4),



          Text(

            title,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(

              fontSize: 13,

              color: AppColors.textSecondary,

            ),

          ),


        ],

      ),

    );

  }

}