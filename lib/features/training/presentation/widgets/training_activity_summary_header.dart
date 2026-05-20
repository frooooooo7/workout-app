import 'package:flutter/material.dart';

class TrainingActivitySummaryHeader extends StatelessWidget {
  const TrainingActivitySummaryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Podsumowanie aktywnosci',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
