import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/profile_details_cubit.dart';
import '../widgets/profile_details_fields.dart';

const kProfileDetailsRoute = '/app/profile/details';
const profileDetailsSaveButtonKey = Key('profile-details-save');

/// Ustawienia → „Dane i cele”. Wymaga [ProfileDetailsCubit] w kontekście;
/// po udanym zapisie zamyka się z zaktualizowanym profilem.
class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileDetailsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('DANE I CELE')),
      body: BlocConsumer<ProfileDetailsCubit, ProfileDetailsState>(
        listenWhen: (previous, current) =>
            previous.saved == null && current.saved != null,
        listener: (context, state) => Navigator.of(context).pop(state.saved),
        builder: (context, state) {
          if (state.initial == null) {
            if (state.loadError != null) {
              return _LoadError(
                message: state.loadError!,
                onRetry: context.read<ProfileDetailsCubit>().load,
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          return _ProfileDetailsForm(state: state);
        },
      ),
    );
  }
}

class _ProfileDetailsForm extends StatelessWidget {
  const _ProfileDetailsForm({required this.state});

  final ProfileDetailsState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProfileDetailsCubit>();
    final enabled = !state.saving;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ProfileDetailsPrivacyNote(),
            const SizedBox(height: 24),
            ProfileBodyFields(
              draft: state.draft,
              enabled: enabled,
              onGenderChanged: cubit.genderChanged,
              onBirthDateChanged: cubit.birthDateChanged,
              onHeightChanged: cubit.heightChanged,
              onWeightChanged: cubit.weightChanged,
            ),
            const SizedBox(height: 28),
            ProfileGoalFields(
              draft: state.draft,
              enabled: enabled,
              onGoalChanged: cubit.trainingGoalChanged,
              onLevelChanged: cubit.experienceLevelChanged,
              onWeeklyDaysChanged: cubit.weeklyTrainingDaysChanged,
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: const TextStyle(
                  color: AppColors.strengthWeak,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: profileDetailsSaveButtonKey,
              onPressed: state.canSave ? cubit.save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: state.saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.strengthWeak,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}
