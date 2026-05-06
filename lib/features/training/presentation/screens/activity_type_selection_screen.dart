import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/activity_session_kind.dart';
import '../widgets/activity_type_option_tile.dart';

class ActivityTypeSelectionScreen extends StatelessWidget {
  const ActivityTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Nowa aktywność',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wybierz typ aktywności',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),
              ActivityTypeOptionTile(
                icon: Icons.list_alt_rounded,
                iconColor: AppColors.primaryVariant,
                title: 'Moje plany',
                description: 'Wybierz trening z zapisanych planów.',
                onTap: () => context.pop(ActivitySessionKind.plan),
              ),
              const SizedBox(height: 12),
              ActivityTypeOptionTile(
                icon: Icons.tune_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Niestandardowa',
                description: 'Własny lub mieszany charakter treningu.',
                onTap: () => context.pushReplacement('/app/training/ongoing-workout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
