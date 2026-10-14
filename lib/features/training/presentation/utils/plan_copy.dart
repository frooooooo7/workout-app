import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../data/plan_sharing_repository.dart';

/// Kopiuje plan i przechodzi do zakładki „Plany”, gdzie lista pokazuje
/// kopię z etykietą „Nowy” i komunikat „Plan dodany”. Zwraca `false`, gdy
/// kopiowanie się nie udało (komunikat jest już na ekranie).
Future<bool> copyPlanAndOpenPlans(
  BuildContext context,
  Future<PlanCopyOutcome> Function() copy,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await copy();
  } catch (error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(planCopyErrorMessage(error))));
    return false;
  }
  if (context.mounted) context.go('/app/plans');
  return true;
}

String planCopyErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.statusCode == null) {
      return 'Kopiowanie planu wymaga internetu.';
    }
    switch (error.message) {
      case 'no_copyable_exercises':
        return 'Ten plan ma tylko własne ćwiczenia autora, '
            'których nie ma w Twojej bibliotece.';
      case 'plan_not_found':
      case 'post_not_found':
        return 'Ten plan nie jest już dostępny.';
      case 'too_many_requests':
        return 'Za dużo kopii naraz. Spróbuj za chwilę.';
    }
  }
  return 'Nie udało się skopiować planu. Spróbuj ponownie.';
}
