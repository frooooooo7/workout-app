import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/last_activity.dart';
import 'last_activity_card_body.dart';
import 'last_activity_card_header.dart';

class LastActivityCard extends StatelessWidget {
  const LastActivityCard({super.key, required this.activity});

  final LastActivity activity;

  static LastActivity get mock => StrengthActivity(
        title: 'Trening siłowy',
        date: 'Dzisiaj',
        time: '18:32',
        durationLabel: '1:15:24',
        volumeKg: 6450,
        caloriesKcal: 532,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LastActivityCardHeader(),
          LastActivityCardBody(activity: activity),
        ],
      ),
    );
  }
}
